//
//  NetworkMonitor.swift
//  Loxone App
//
//  Monitor network connectivity and detect local vs remote network
//

import Foundation
import Network
import Combine

// MARK: - Network Status

enum NetworkStatus: Equatable {
    case disconnected
    case wifi
    case cellular
    case wired
    case unknown
    
    var isConnected: Bool {
        self != .disconnected
    }
    
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wired: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .disconnected: return "wifi.slash"
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wired: return "cable.connector"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Connection Mode

enum ConnectionMode: Equatable {
    case local
    case remote
    case auto
    
    var description: String {
        switch self {
        case .local: return "Local"
        case .remote: return "Remote"
        case .auto: return "Automatic"
        }
    }
}

// MARK: - Network Monitor

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var status: NetworkStatus = .unknown
    @Published private(set) var isOnLocalNetwork: Bool = false
    @Published private(set) var preferredConnectionMode: ConnectionMode = .auto
    @Published var localServerReachable: Bool = false
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var localServerAddress: String?
    private var checkTask: Task<Void, Never>?
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
        checkTask?.cancel()
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        // Determine network status
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                status = .wifi
            } else if path.usesInterfaceType(.cellular) {
                status = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                status = .wired
            } else {
                status = .unknown
            }
        } else {
            status = .disconnected
        }
        
        // Check if we might be on local network
        // WiFi and wired connections could be local
        let couldBeLocal = path.status == .satisfied &&
            (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
        
        if couldBeLocal && localServerAddress != nil {
            checkLocalServerReachability()
        } else {
            isOnLocalNetwork = false
            localServerReachable = false
        }
    }
    
    // MARK: - Configuration
    
    /// Set the local server address to check
    func setLocalServerAddress(_ address: String?) {
        localServerAddress = address?.withoutProtocol.trimmedTrailingSlash
        if address != nil {
            checkLocalServerReachability()
        } else {
            isOnLocalNetwork = false
            localServerReachable = false
        }
    }
    
    /// Set preferred connection mode
    func setPreferredMode(_ mode: ConnectionMode) {
        preferredConnectionMode = mode
    }
    
    // MARK: - Server Reachability
    
    /// Check if local server is reachable
    func checkLocalServerReachability() {
        checkTask?.cancel()
        
        checkTask = Task {
            guard let address = localServerAddress else {
                localServerReachable = false
                isOnLocalNetwork = false
                return
            }
            
            let reachable = await pingServer(address)
            
            guard !Task.isCancelled else { return }
            
            localServerReachable = reachable
            isOnLocalNetwork = reachable
        }
    }
    
    /// Ping a server to check reachability
    private func pingServer(_ address: String) async -> Bool {
        // Try to make a quick HTTP request to the server
        let urlString = address.isLocalIP ? "http://\(address)" : "https://\(address)"
        print("🌐 [NetworkMonitor] Pinging server: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("🌐 [NetworkMonitor] ❌ Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3 // Quick timeout
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Any response (even 401 unauthorized) means the server is reachable
                print("🌐 [NetworkMonitor] ✅ Ping response: \(httpResponse.statusCode)")
                return httpResponse.statusCode > 0
            }
            print("🌐 [NetworkMonitor] ❌ No HTTP response")
            return false
        } catch {
            print("🌐 [NetworkMonitor] ❌ Ping failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Connection Decision
    
    /// Determine which server address to use based on current conditions
    func bestServerAddress(local: String?, remote: String?) -> String? {
        switch preferredConnectionMode {
        case .local:
            return local
        case .remote:
            return remote
        case .auto:
            // Use local if reachable, otherwise remote
            if localServerReachable, let local = local {
                return local
            }
            return remote ?? local
        }
    }
    
    /// Determine if we should use HTTPS
    func shouldUseHTTPS(for address: String) -> Bool {
        // Use HTTP for local IPs, HTTPS for everything else
        !address.withoutProtocol.isLocalIP
    }
    
    /// Build the full URL for a server address
    func buildURL(for address: String, endpoint: String) -> URL? {
        let cleanAddress = address.withoutProtocol.trimmedTrailingSlash
        let useHTTPS = shouldUseHTTPS(for: cleanAddress)
        let urlString = "\(useHTTPS ? "https" : "http")://\(cleanAddress)\(endpoint)"
        return URL(string: urlString)
    }
    
    /// Build WebSocket URL for a server address
    func buildWebSocketURL(for address: String) -> URL? {
        let cleanAddress = address.withoutProtocol.trimmedTrailingSlash
        let useSecure = shouldUseHTTPS(for: cleanAddress)
        let urlString = "\(useSecure ? "wss" : "ws")://\(cleanAddress)\(LoxoneConstants.websocketEndpoint)"
        return URL(string: urlString)
    }
}

