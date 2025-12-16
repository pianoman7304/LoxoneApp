//
//  Constants.swift
//  Loxone App
//
//  App-wide constants and configuration
//

import Foundation

// MARK: - App Constants

enum AppConstants {
    /// App name
    static let appName = "Loxone Home"
    
    /// App version
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Build number
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// App Group identifier for sharing data with widgets
    static let appGroupIdentifier = "group.langmuriweg.Loxone-App"
    
    /// Keychain service name
    static let keychainService = "com.langmuriweg.loxone"
}

// MARK: - Loxone API Constants

enum LoxoneConstants {
    /// Structure file endpoint
    static let structureEndpoint = "/data/LoxAPP3.json"
    
    /// Command endpoint prefix
    static let commandEndpoint = "/jdev/sps/io"
    
    /// Status endpoint
    static let statusEndpoint = "/jdev/sps/status"
    
    /// WebSocket endpoint
    static let websocketEndpoint = "/ws/rfc6455"
    
    /// WebSocket protocol
    static let websocketProtocol = "remotecontrol"
    
    /// Default HTTP port
    static let defaultHTTPPort = 80
    
    /// Default HTTPS port
    static let defaultHTTPSPort = 443
    
    /// Connection timeout in seconds
    static let connectionTimeout: TimeInterval = 30
    
    /// Polling interval for state updates (seconds)
    static let pollingInterval: TimeInterval = 5
    
    /// Max reconnection attempts
    static let maxReconnectAttempts = 5
    
    /// Reconnection delay base (seconds)
    static let reconnectDelayBase: TimeInterval = 2
}

// MARK: - Keychain Keys

enum KeychainKeys {
    /// Local server address
    static let localServerAddress = "localServerAddress"
    
    /// Remote server address
    static let remoteServerAddress = "remoteServerAddress"
    
    /// Password prefix for user
    static func userPassword(_ userId: UUID) -> String {
        "user.\(userId.uuidString).password"
    }
}

// MARK: - UserDefaults Keys

enum UserDefaultsKeys {
    /// Last selected user profile ID
    static let lastSelectedUserProfileId = "lastSelectedUserProfileId"
    
    /// Local server address (non-sensitive, can be in UserDefaults)
    static let localServerAddress = "localServerAddress"
    
    /// Remote server address (non-sensitive, can be in UserDefaults)
    static let remoteServerAddress = "remoteServerAddress"
    
    /// Notification preferences
    static let notificationsEnabled = "notificationsEnabled"
    static let securityNotificationsEnabled = "securityNotificationsEnabled"
    static let climateNotificationsEnabled = "climateNotificationsEnabled"
    
    /// Climate thresholds
    static let temperatureHighThreshold = "temperatureHighThreshold"
    static let temperatureLowThreshold = "temperatureLowThreshold"
    static let humidityHighThreshold = "humidityHighThreshold"
    static let humidityLowThreshold = "humidityLowThreshold"
    
    /// Widget data
    static let widgetFavoriteDevices = "widgetFavoriteDevices"
    static let widgetLastUpdate = "widgetLastUpdate"
}

// MARK: - Default Values

enum DefaultValues {
    /// Default temperature high threshold (°C)
    static let temperatureHighThreshold: Double = 28.0
    
    /// Default temperature low threshold (°C)
    static let temperatureLowThreshold: Double = 16.0
    
    /// Default humidity high threshold (%)
    static let humidityHighThreshold: Double = 70.0
    
    /// Default humidity low threshold (%)
    static let humidityLowThreshold: Double = 30.0
}

// MARK: - Notification Identifiers

enum NotificationIdentifiers {
    /// Category for security notifications
    static let securityCategory = "SECURITY_CATEGORY"
    
    /// Category for climate notifications
    static let climateCategory = "CLIMATE_CATEGORY"
    
    /// Action to acknowledge
    static let acknowledgeAction = "ACKNOWLEDGE_ACTION"
    
    /// Action to view in app
    static let viewAction = "VIEW_ACTION"
}

