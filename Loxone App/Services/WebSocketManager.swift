//
//  WebSocketManager.swift
//  Loxone App
//
//  WebSocket connection handler for real-time Loxone state updates
//

import Foundation
import Combine

// MARK: - WebSocket State

enum WebSocketState: Equatable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case error(String)
    
    var isConnected: Bool {
        self == .connected
    }
    
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .authenticating: return "Authenticating..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
}

// MARK: - WebSocket Message

enum WebSocketMessage {
    case text(String)
    case binary(Data)
    case stateUpdate(uuid: String, value: Double)
}

// MARK: - WebSocket Manager

@MainActor
final class WebSocketManager: NSObject, ObservableObject {
    @Published private(set) var state: WebSocketState = .disconnected
    @Published private(set) var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var serverURL: URL?
    private var username: String = ""
    private var password: String = ""
    
    private var reconnectAttempts = 0
    private var reconnectTask: Task<Void, Never>?
    
    // Callbacks
    var onStateChange: ((String, Double) -> Void)?
    var onConnectionStateChange: ((WebSocketState) -> Void)?
    var onMessage: ((WebSocketMessage) -> Void)?
    
    override init() {
        super.init()
    }
    
    // MARK: - Connection
    
    /// Connect to WebSocket server
    func connect(to url: URL, username: String, password: String) {
        self.serverURL = url
        self.username = username
        self.password = password
        
        disconnect()
        
        state = .connecting
        onConnectionStateChange?(.connecting)
        
        // Create URLSession with delegate
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = LoxoneConstants.connectionTimeout
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        // Create WebSocket task
        var request = URLRequest(url: url)
        request.setValue(LoxoneConstants.websocketProtocol, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
    }
    
    /// Disconnect from WebSocket server
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        
        state = .disconnected
        onConnectionStateChange?(.disconnected)
    }
    
    // MARK: - Authentication
    
    /// Send authentication after connection
    private func authenticate() {
        state = .authenticating
        onConnectionStateChange?(.authenticating)
        
        // Request authentication key
        send(text: "jdev/sys/getkey")
    }
    
    /// Complete authentication with key
    private func completeAuthentication(with key: String) {
        // For basic auth, we send credentials directly
        // More secure implementations would use HMAC with the key
        send(text: "authenticate/\(username)/\(password)")
    }
    
    /// Enable binary status updates
    private func enableStatusUpdates() {
        send(text: "jdev/sps/enablebinstatusupdate")
    }
    
    // MARK: - Sending Messages
    
    /// Send text message
    func send(text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }
    
    /// Send binary data
    func send(data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }
    
    // MARK: - Receiving Messages
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    // Continue receiving
                    self?.receiveMessage()
                    
                case .failure(let error):
                    self?.handleError(error)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            handleBinaryMessage(data)
        @unknown default:
            break
        }
    }
    
    private func handleTextMessage(_ text: String) {
        onMessage?(.text(text))
        
        // Parse JSON response
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ll = json["LL"] as? [String: Any] else {
            return
        }
        
        // Check for authentication key response
        if let control = ll["control"] as? String,
           control == "jdev/sys/getkey",
           let value = ll["value"] as? String {
            completeAuthentication(with: value)
            return
        }
        
        // Check for authentication success
        if let code = ll["Code"] as? String, code == "200" {
            state = .connected
            onConnectionStateChange?(.connected)
            reconnectAttempts = 0
            enableStatusUpdates()
            return
        }
        
        // Check for authentication failure
        if let code = ll["Code"] as? String, code == "401" {
            state = .error("Authentication failed")
            onConnectionStateChange?(.error("Authentication failed"))
            disconnect()
            return
        }
    }
    
    private func handleBinaryMessage(_ data: Data) {
        onMessage?(.binary(data))
        
        // Parse Loxone binary state update format
        parseBinaryStateUpdate(data)
    }
    
    /// Parse Loxone's binary state update format
    private func parseBinaryStateUpdate(_ data: Data) {
        // Loxone binary format:
        // - First byte: message type
        // - Bytes 4-7: payload size (little endian)
        // - Rest: payload
        
        guard data.count >= 8 else { return }
        
        let messageType = data[0]
        
        // Type 0 = text, 1 = binary file, 2 = event table, 3 = value states, 4 = text states
        guard messageType == 3 else { return }
        
        // Parse value states (each entry is 24 bytes: 16 byte UUID + 8 byte double value)
        let payloadStart = 8
        let entrySize = 24
        
        var offset = payloadStart
        while offset + entrySize <= data.count {
            // Read UUID (16 bytes)
            let uuidData = data.subdata(in: offset..<(offset + 16))
            let uuid = formatUUID(from: uuidData)
            
            // Read value (8 bytes, little-endian double)
            let valueData = data.subdata(in: (offset + 16)..<(offset + 24))
            let value = valueData.withUnsafeBytes { $0.load(as: Double.self) }
            
            if !uuid.isEmpty && !value.isNaN {
                onStateChange?(uuid, value)
                onMessage?(.stateUpdate(uuid: uuid, value: value))
            }
            
            offset += entrySize
        }
    }
    
    /// Format UUID bytes to string
    private func formatUUID(from data: Data) -> String {
        guard data.count == 16 else { return "" }
        
        let bytes = [UInt8](data)
        
        // Break into separate expressions to help the compiler
        let part1 = formatHexPart(Array(bytes[0..<4]))
        let part2 = formatHexPart(Array(bytes[4..<6]))
        let part3 = formatHexPart(Array(bytes[6..<8]))
        let part4 = formatHexPart(Array(bytes[8..<10]))
        let part5 = formatHexPart(Array(bytes[10..<16]))
        
        return "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
    }
    
    /// Helper to format bytes as hex string
    private func formatHexPart(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        lastError = error.localizedDescription
        state = .error(error.localizedDescription)
        onConnectionStateChange?(.error(error.localizedDescription))
        
        // Attempt reconnection
        scheduleReconnect()
    }
    
    // MARK: - Reconnection
    
    private func scheduleReconnect() {
        guard reconnectAttempts < LoxoneConstants.maxReconnectAttempts,
              let url = serverURL else {
            return
        }
        
        reconnectAttempts += 1
        let delay = LoxoneConstants.reconnectDelayBase * Double(reconnectAttempts)
        
        reconnectTask = Task {
            try? await Task.sleep(seconds: delay)
            
            guard !Task.isCancelled else { return }
            
            connect(to: url, username: username, password: password)
        }
    }
    
    /// Reset reconnection counter
    func resetReconnectAttempts() {
        reconnectAttempts = 0
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor [weak self] in
            self?.authenticate()
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor [weak self] in
            self?.state = .disconnected
            self?.onConnectionStateChange?(.disconnected)
            self?.scheduleReconnect()
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Accept self-signed certificates for local connections
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

