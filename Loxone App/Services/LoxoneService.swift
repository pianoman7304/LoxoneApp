//
//  LoxoneService.swift
//  Loxone App
//
//  Main API client for communicating with Loxone Miniserver
//

import Foundation
import Combine

// MARK: - Connection State

enum LoxoneConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var isConnected: Bool {
        self == .connected
    }
    
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var icon: String {
        switch self {
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .connected: return "circle.fill"
        case .error: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "orange"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}

// MARK: - Loxone Service Error

enum LoxoneServiceError: Error, LocalizedError {
    case notConfigured
    case connectionFailed(String)
    case authenticationFailed
    case invalidResponse
    case commandFailed(String)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server not configured"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed - check username and password"
        case .invalidResponse:
            return "Invalid response from server"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// MARK: - Loxone Service

@MainActor
final class LoxoneService: ObservableObject {
    static let shared = LoxoneService()
    
    // Published state
    @Published private(set) var connectionState: LoxoneConnectionState = .disconnected
    @Published private(set) var structure: LoxoneStructure?
    @Published private(set) var miniserverName: String?
    @Published private(set) var lastError: String?
    
    // Dependencies
    private let networkMonitor = NetworkMonitor.shared
    private let webSocketManager = WebSocketManager()
    let stateStore = DeviceStateStore()
    
    // Configuration
    private var localServerAddress: String?
    private var remoteServerAddress: String?
    private var username: String = ""
    private var password: String = ""
    
    // Polling
    private var pollingTask: Task<Void, Never>?
    private var currentRoomUUID: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWebSocketCallbacks()
    }
    
    // MARK: - Configuration
    
    /// Configure the service with server addresses and credentials
    func configure(
        localAddress: String?,
        remoteAddress: String?,
        username: String,
        password: String
    ) {
        print("🏠 [LoxoneService] Configuring...")
        print("🏠 [LoxoneService]   localAddress: \(localAddress ?? "nil")")
        print("🏠 [LoxoneService]   remoteAddress: \(remoteAddress ?? "nil")")
        print("🏠 [LoxoneService]   username: \(username)")
        print("🏠 [LoxoneService]   password length: \(password.count)")
        
        self.localServerAddress = localAddress?.trimmedTrailingSlash
        self.remoteServerAddress = remoteAddress?.trimmedTrailingSlash
        self.username = username
        self.password = password
        
        // Update network monitor
        networkMonitor.setLocalServerAddress(localAddress)
        print("🏠 [LoxoneService] ✅ Configuration complete")
    }
    
    /// Get current server address based on network conditions
    var currentServerAddress: String? {
        networkMonitor.bestServerAddress(
            local: localServerAddress,
            remote: remoteServerAddress
        )
    }
    
    /// Check if service is configured
    var isConfigured: Bool {
        (localServerAddress != nil || remoteServerAddress != nil) && !username.isEmpty
    }
    
    // MARK: - Connection
    
    /// Currently active server address (set after successful connection)
    private(set) var activeServerAddress: String?
    
    /// Connect to Loxone Miniserver
    /// Tries local server first, falls back to remote if local fails
    func connect() async throws {
        guard isConfigured else {
            throw LoxoneServiceError.notConfigured
        }
        
        guard networkMonitor.status.isConnected else {
            throw LoxoneServiceError.networkUnavailable
        }
        
        connectionState = .connecting
        lastError = nil
        activeServerAddress = nil
        
        // Try local first, then remote
        let serversToTry: [(name: String, address: String?)] = [
            ("local", localServerAddress),
            ("remote", remoteServerAddress)
        ].filter { $0.address != nil }
        
        var lastConnectionError: Error?
        
        for (serverName, serverAddress) in serversToTry {
            guard let address = serverAddress else { continue }
            
            print("🏠 [LoxoneService] Trying \(serverName) server: \(address)")
            
            do {
                try await fetchStructure(from: address)
                
                // Success! Save the active server and continue setup
                activeServerAddress = address
                print("🏠 [LoxoneService] ✅ Connected via \(serverName) server")
                
                // Try WebSocket connection for live updates
                connectWebSocket()
                
                // Start polling as fallback
                startPolling()
                
                connectionState = .connected
                return // Success, exit
                
            } catch LoxoneServiceError.authenticationFailed {
                // Auth failed - don't try other servers, credentials are wrong
                print("🏠 [LoxoneService] ❌ Authentication failed on \(serverName) - not trying other servers")
                connectionState = .error("Authentication failed - check username and password")
                lastError = "Authentication failed - check username and password"
                throw LoxoneServiceError.authenticationFailed
                
            } catch {
                // Connection failed - try next server
                print("🏠 [LoxoneService] ❌ \(serverName) failed: \(error.localizedDescription)")
                lastConnectionError = error
                continue
            }
        }
        
        // All servers failed
        let errorMessage = lastConnectionError?.localizedDescription ?? "Could not connect to any server"
        connectionState = .error(errorMessage)
        lastError = errorMessage
        throw lastConnectionError ?? LoxoneServiceError.connectionFailed("Could not connect to any server")
    }
    
    /// Disconnect from Loxone Miniserver
    func disconnect() {
        webSocketManager.disconnect()
        stopPolling()
        connectionState = .disconnected
    }
    
    // MARK: - Structure
    
    /// Fetch structure file from Miniserver
    /// - Parameter serverAddress: Optional specific server to use. If nil, uses activeServerAddress or tries to determine best server.
    func fetchStructure(from serverAddress: String? = nil) async throws {
        print("🏠 [LoxoneService] Fetching structure...")
        
        // Use provided address, or active address, or try to determine best
        let address: String
        if let provided = serverAddress {
            address = provided
        } else if let active = activeServerAddress {
            address = active
        } else if let best = currentServerAddress {
            address = best
        } else {
            print("🏠 [LoxoneService] ❌ No server address available")
            throw LoxoneServiceError.notConfigured
        }
        
        print("🏠 [LoxoneService] Using server: \(address)")
        
        guard let url = networkMonitor.buildURL(
            for: address,
            endpoint: LoxoneConstants.structureEndpoint
        ) else {
            print("🏠 [LoxoneService] ❌ Invalid URL")
            throw LoxoneServiceError.connectionFailed("Invalid URL")
        }
        
        print("🏠 [LoxoneService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = LoxoneConstants.connectionTimeout
        
        let authHeader = Data.basicAuthHeader(username: username, password: password)
        print("🏠 [LoxoneService] Auth header: \(authHeader)")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        print("🏠 [LoxoneService] Making request...")
        let (data, response) = try await makeRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🏠 [LoxoneService] ❌ Invalid response type")
            throw LoxoneServiceError.invalidResponse
        }
        
        print("🏠 [LoxoneService] HTTP Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            print("🏠 [LoxoneService] ❌ Authentication FAILED (401)")
            print("🏠 [LoxoneService] ❌ username: '\(username)', password length: \(password.count)")
            throw LoxoneServiceError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            print("🏠 [LoxoneService] ❌ HTTP error: \(httpResponse.statusCode)")
            throw LoxoneServiceError.connectionFailed("HTTP \(httpResponse.statusCode)")
        }
        
        print("🏠 [LoxoneService] ✅ Structure received, parsing...")
        let decoder = JSONDecoder()
        structure = try decoder.decode(LoxoneStructure.self, from: data)
        
        miniserverName = structure?.msInfo?.msName
        print("🏠 [LoxoneService] ✅ Structure parsed, miniserver: \(miniserverName ?? "unknown")")
        print("🏠 [LoxoneService] Total rooms: \(structure?.rooms?.count ?? 0)")
        print("🏠 [LoxoneService] Total controls: \(structure?.controls?.count ?? 0)")
        
        // Fetch initial states in background (non-blocking)
        // This allows the UI to load immediately while states are fetched
        Task.detached { @MainActor in
            await self.fetchAllInitialStates()
        }
    }
    
    /// Fetch initial states for all controls after structure is loaded
    private func fetchAllInitialStates() async {
        guard let controls = structure?.controls else { return }
        
        print("🏠 [LoxoneService] Fetching initial states for \(controls.count) controls...")
        
        // Collect all UUIDs to fetch (including state UUIDs from controls)
        var uuidsToFetch = Set<String>()
        
        for (uuid, control) in controls {
            // Add the main control UUID
            uuidsToFetch.insert(uuid)
            
            // Add state UUIDs if they exist
            if let states = control.states {
                for (_, stateValue) in states {
                    if let stateUUID = stateValue.uuidString, !stateUUID.isEmpty {
                        uuidsToFetch.insert(stateUUID)
                    }
                }
            }
            
            // Add subControl UUIDs
            if let subControls = control.subControls {
                for (subUUID, _) in subControls {
                    uuidsToFetch.insert(subUUID)
                }
            }
        }
        
        print("🏠 [LoxoneService] Total UUIDs to fetch: \(uuidsToFetch.count)")
        
        // Fetch states in smaller batches with longer delays to avoid overwhelming the server
        // The Miniserver has connection limits and will reset connections if overwhelmed
        let allUUIDs = Array(uuidsToFetch)
        let batchSize = 3  // Reduced from 10 to 3
        let delayBetweenBatches: UInt64 = 50_000_000  // 50ms between batches
        
        for batch in stride(from: 0, to: allUUIDs.count, by: batchSize) {
            let endIndex = min(batch + batchSize, allUUIDs.count)
            let batchUUIDs = Array(allUUIDs[batch..<endIndex])
            
            // Fetch sequentially within each batch to avoid connection resets
            for uuid in batchUUIDs {
                await fetchStateValue(uuid)
            }
            
            // Delay between batches
            if endIndex < allUUIDs.count {
                try? await Task.sleep(nanoseconds: delayBetweenBatches)
            }
            
            // Progress indicator every 100 UUIDs
            if batch % 100 == 0 && batch > 0 {
                print("🏠 [LoxoneService] Progress: \(batch)/\(allUUIDs.count) states fetched")
            }
        }
        
        print("🏠 [LoxoneService] ✅ Initial states fetched (\(uuidsToFetch.count) UUIDs)")
    }
    
    // MARK: - WebSocket
    
    private func setupWebSocketCallbacks() {
        webSocketManager.onStateChange = { [weak self] uuid, value in
            Task { @MainActor [weak self] in
                self?.stateStore.update(uuid: uuid, value: value)
            }
        }
        
        webSocketManager.onConnectionStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .connected:
                    self?.connectionState = .connected
                case .error(let message):
                    // Don't set error state if we have HTTP fallback
                    self?.lastError = "WebSocket: \(message)"
                default:
                    break
                }
            }
        }
    }
    
    private func connectWebSocket() {
        guard let serverAddress = activeServerAddress ?? currentServerAddress,
              let url = networkMonitor.buildWebSocketURL(for: serverAddress) else {
            return
        }
        
        webSocketManager.connect(to: url, username: username, password: password)
    }
    
    // MARK: - Commands
    
    /// Send command to a control
    func sendCommand(_ uuid: String, command: String) async throws {
        guard let serverAddress = activeServerAddress ?? currentServerAddress else {
            throw LoxoneServiceError.notConfigured
        }
        
        let endpoint = "\(LoxoneConstants.commandEndpoint)/\(uuid)/\(command)"
        
        guard let url = networkMonitor.buildURL(for: serverAddress, endpoint: endpoint) else {
            throw LoxoneServiceError.connectionFailed("Invalid URL")
        }
        
        print("🎮 [LoxoneService] Sending command: \(endpoint)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = LoxoneConstants.connectionTimeout
        request.setValue(
            Data.basicAuthHeader(username: username, password: password),
            forHTTPHeaderField: "Authorization"
        )
        
        let (data, response) = try await makeRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoxoneServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw LoxoneServiceError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LoxoneServiceError.commandFailed("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse response to update state
        if let json = try? JSONDecoder().decode(LoxoneCommandResponse.self, from: data) {
            print("✅ [LoxoneService] Command response: \(json)")
            
            // Update state from response value
            if let value = json.LL.value?.doubleValue {
                // Get the control to check for state UUIDs
                let control = getControl(uuid)
                
                // Update the appropriate state UUID
                if let activeStateUUID = control?.states?["active"]?.uuidString {
                    stateStore.update(uuid: activeStateUUID, value: value)
                } else if let valueStateUUID = control?.states?["value"]?.uuidString {
                    stateStore.update(uuid: valueStateUUID, value: value)
                } else if let positionStateUUID = control?.states?["position"]?.uuidString {
                    stateStore.update(uuid: positionStateUUID, value: value)
                } else {
                    stateStore.update(uuid: uuid, value: value)
                }
            }
        }
    }
    
    /// Toggle a switch
    func toggleSwitch(_ uuid: String) async throws {
        // Get the control to check for state UUIDs
        let control = getControl(uuid)
        
        // Check state from the correct UUID (state UUID or main UUID)
        var currentState = false
        if let activeStateUUID = control?.states?["active"]?.uuidString {
            currentState = stateStore.isOn(activeStateUUID)
        } else {
            currentState = stateStore.isOn(uuid)
        }
        
        let command = currentState ? "Off" : "On"
        print("🔘 [LoxoneService] Toggle switch \(uuid): current=\(currentState), sending=\(command)")
        
        try await sendCommand(uuid, command: command)
        
        // Immediately update local state for responsive UI
        if let activeStateUUID = control?.states?["active"]?.uuidString {
            stateStore.update(uuid: activeStateUUID, value: currentState ? 0 : 1)
        } else {
            stateStore.update(uuid: uuid, value: currentState ? 0 : 1)
        }
        
        // Fetch actual state after a short delay to confirm
        try? await Task.sleep(nanoseconds: 200_000_000)
        await fetchControlState(uuid)
    }
    
    /// Set dimmer value (0-100)
    func setDimmerValue(_ uuid: String, value: Int) async throws {
        let clampedValue = min(100, max(0, value))
        print("💡 [LoxoneService] Set dimmer \(uuid) to \(clampedValue)%")
        
        // Get the control to check for state UUIDs
        let control = getControl(uuid)
        
        // Immediately update local state for responsive UI
        if let positionStateUUID = control?.states?["position"]?.uuidString {
            stateStore.update(uuid: positionStateUUID, value: Double(clampedValue))
        } else if let valueStateUUID = control?.states?["value"]?.uuidString {
            stateStore.update(uuid: valueStateUUID, value: Double(clampedValue))
        } else {
            stateStore.update(uuid: uuid, value: Double(clampedValue))
        }
        
        try await sendCommand(uuid, command: String(clampedValue))
        
        // Fetch actual state after a short delay to confirm
        try? await Task.sleep(nanoseconds: 200_000_000)
        await fetchControlState(uuid)
    }
    
    /// Send jalousie command
    func sendJalousieCommand(_ uuid: String, command: JalousieCommand) async throws {
        try await sendCommand(uuid, command: command.rawValue)
    }
    
    // MARK: - State Polling
    
    /// Set current room for focused polling
    func setCurrentRoom(_ roomUUID: String?) {
        currentRoomUUID = roomUUID
        if let roomUUID = roomUUID {
            Task {
                await fetchRoomStates(roomUUID)
            }
        }
    }
    
    private func startPolling() {
        stopPolling()
        
        pollingTask = Task {
            while !Task.isCancelled {
                if let roomUUID = currentRoomUUID {
                    await fetchRoomStates(roomUUID)
                }
                try? await Task.sleep(seconds: LoxoneConstants.pollingInterval)
            }
        }
    }
    
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    /// Fetch states for all controls in a room (used by polling)
    private func fetchRoomStates(_ roomUUID: String) async {
        let controls = getControls(for: roomUUID)
        
        // Fetch in batches
        let batchSize = 5
        for batch in stride(from: 0, to: controls.count, by: batchSize) {
            let endIndex = min(batch + batchSize, controls.count)
            let batchControls = Array(controls[batch..<endIndex])
            
            await withTaskGroup(of: Void.self) { group in
                for control in batchControls {
                    group.addTask {
                        await self.fetchControlState(control.uuid)
                    }
                }
            }
        }
    }
    
    /// Fetch states for all controls in a room immediately (public, for UI)
    func fetchRoomStatesImmediate(_ roomUUID: String) async {
        let controls = getControls(for: roomUUID)
        print("🔄 [LoxoneService] Fetching states for room \(roomUUID) - \(controls.count) controls")
        
        // Fetch all states in parallel with a reasonable batch size
        let batchSize = 10
        for batch in stride(from: 0, to: controls.count, by: batchSize) {
            let endIndex = min(batch + batchSize, controls.count)
            let batchControls = Array(controls[batch..<endIndex])
            
            await withTaskGroup(of: Void.self) { group in
                for control in batchControls {
                    group.addTask {
                        await self.fetchControlState(control.uuid)
                    }
                }
            }
            
            // Small delay between batches to avoid overwhelming the server
            if endIndex < controls.count {
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            }
        }
        
        print("✅ [LoxoneService] Finished fetching states for room \(roomUUID)")
    }
    
    /// Fetch state for a single control (used during polling)
    private func fetchControlState(_ uuid: String) async {
        // Fetch the control's main state
        await fetchStateValue(uuid)
        
        // Also fetch state UUIDs if they exist
        if let control = getControl(uuid), let states = control.states {
            for (_, stateValue) in states {
                if let stateUUID = stateValue.uuidString, !stateUUID.isEmpty {
                    await fetchStateValue(stateUUID)
                }
            }
        }
    }
    
    /// Fetch a specific state value by UUID
    private func fetchStateValue(_ uuid: String) async {
        // Use cached active server address to avoid repeated network checks
        guard let serverAddress = activeServerAddress else {
            print("⚠️ [LoxoneService] fetchStateValue - no active server address")
            return
        }
        
        let endpoint = "\(LoxoneConstants.commandEndpoint)/\(uuid)/state"
        guard let url = networkMonitor.buildURL(for: serverAddress, endpoint: endpoint) else {
            print("⚠️ [LoxoneService] fetchStateValue - failed to build URL for \(uuid)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3  // Reduced timeout for faster failures
        request.setValue(
            Data.basicAuthHeader(username: username, password: password),
            forHTTPHeaderField: "Authorization"
        )
        
        do {
            let (data, _) = try await makeRequest(request)
            if let json = try? JSONDecoder().decode(LoxoneCommandResponse.self, from: data),
               let value = json.LL.value?.doubleValue {
                print("📊 [LoxoneService] State fetched for \(uuid): \(value)")
                stateStore.update(uuid: uuid, value: value)
            } else {
                print("⚠️ [LoxoneService] Failed to decode state for \(uuid)")
            }
        } catch {
            // Log failures for debugging
            print("⚠️ [LoxoneService] Error fetching state for \(uuid): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Access
    
    /// Get all rooms
    func getRooms() -> [LoxoneRoom] {
        guard let rooms = structure?.rooms else { return [] }
        return rooms.map { uuid, room in
            LoxoneRoom(
                uuid: uuid,
                name: room.name,
                image: room.image,
                defaultRating: room.defaultRating,
                isFavorite: room.isFavorite,
                type: room.type
            )
        }.sorted { $0.name < $1.name }
    }
    
    /// Get controls for a specific room
    func getControls(for roomUUID: String) -> [LoxoneControl] {
        guard let controls = structure?.controls else {
            print("⚠️ [LoxoneService] getControls - no structure.controls available")
            return []
        }
        
        let roomControls = controls.compactMap { uuid, control in
            guard control.room == roomUUID else { return nil }
            
            // Create a new control with the UUID properly set from the dictionary key
            return LoxoneControl(
                uuid: uuid,
                name: control.name,
                type: control.type,
                room: control.room,
                cat: control.cat,
                states: control.states,
                details: control.details,
                subControls: control.subControls,
                isFavorite: control.isFavorite,
                isSecured: control.isSecured,
                defaultRating: control.defaultRating
            )
        }.sorted { $0.name < $1.name }
        
        print("🏠 [LoxoneService] getControls for room \(roomUUID): found \(roomControls.count) controls")
        for control in roomControls {
            print("  📦 \(control.name) (\(control.type)) - UUID: \(control.uuid)")
        }
        return roomControls
    }
    
    /// Get all controls
    func getAllControls() -> [LoxoneControl] {
        guard let controls = structure?.controls else { return [] }
        return controls.map { uuid, control in
            LoxoneControl(
                uuid: uuid,
                name: control.name,
                type: control.type,
                room: control.room,
                cat: control.cat,
                states: control.states,
                details: control.details,
                subControls: control.subControls,
                isFavorite: control.isFavorite,
                isSecured: control.isSecured,
                defaultRating: control.defaultRating
            )
        }
    }
    
    /// Get control by UUID
    func getControl(_ uuid: String) -> LoxoneControl? {
        guard let control = structure?.controls?[uuid] else { return nil }
        
        // Create a new control with the UUID properly set from the dictionary key
        return LoxoneControl(
            uuid: uuid,
            name: control.name,
            type: control.type,
            room: control.room,
            cat: control.cat,
            states: control.states,
            details: control.details,
            subControls: control.subControls,
            isFavorite: control.isFavorite,
            isSecured: control.isSecured,
            defaultRating: control.defaultRating
        )
    }
    
    /// Get room by UUID
    func getRoom(_ uuid: String) -> LoxoneRoom? {
        guard let room = structure?.rooms?[uuid] else { return nil }
        return LoxoneRoom(
            uuid: uuid,
            name: room.name,
            image: room.image,
            defaultRating: room.defaultRating,
            isFavorite: room.isFavorite,
            type: room.type
        )
    }
    
    // MARK: - Network Request Helper
    
    private func makeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = request.timeoutInterval
        
        let session = URLSession(configuration: config, delegate: SelfSignedCertificateDelegate(), delegateQueue: nil)
        
        return try await session.data(for: request)
    }
}

// MARK: - Jalousie Commands

enum JalousieCommand: String {
    case fullUp = "FullUp"
    case fullDown = "FullDown"
    case stop = "Stop"
    case up = "Up"
    case down = "Down"
}

// MARK: - Self-Signed Certificate Handler

private class SelfSignedCertificateDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

