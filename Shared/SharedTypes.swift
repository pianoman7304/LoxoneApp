//
//  SharedTypes.swift
//  Loxone App
//
//  Types shared between main app and widget extension
//

import Foundation

// MARK: - Shared Constants

/// Constants shared between main app and widgets
enum SharedConstants {
    /// App Group identifier for sharing data with widgets
    static let appGroupIdentifier = "group.langmuriweg.Loxone-App"
}

// MARK: - Widget Device Data

/// Lightweight device representation for widgets
struct WidgetDevice: Codable, Identifiable {
    let uuid: String
    let name: String
    let type: String
    let roomName: String
    var state: Double
    var lastUpdated: Date
    
    var id: String { uuid }
    
    var isOn: Bool {
        state > 0
    }
    
    var icon: String {
        switch type.lowercased() {
        case let t where t.contains("switch"):
            return "power"
        case let t where t.contains("light"):
            return isOn ? "lightbulb.fill" : "lightbulb"
        case let t where t.contains("dimmer"):
            return isOn ? "sun.max.fill" : "sun.max"
        case let t where t.contains("jalousie"), let t where t.contains("blind"):
            return "blinds.horizontal.closed"
        case let t where t.contains("sensor"):
            return "chart.line.uptrend.xyaxis"
        case let t where t.contains("temp"):
            return "thermometer"
        default:
            return "power"
        }
    }
}

// MARK: - Widget Room Data

struct WidgetRoom: Codable, Identifiable {
    let uuid: String
    let name: String
    var devices: [WidgetDevice]
    var activeDeviceCount: Int
    
    var id: String { uuid }
    
    var icon: String {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("living") || lowercaseName.contains("wohn") {
            return "sofa"
        } else if lowercaseName.contains("bed") || lowercaseName.contains("schlaf") {
            return "bed.double"
        } else if lowercaseName.contains("kitchen") || lowercaseName.contains("küche") {
            return "fork.knife"
        } else if lowercaseName.contains("bath") || lowercaseName.contains("bad") {
            return "shower"
        } else if lowercaseName.contains("office") || lowercaseName.contains("büro") {
            return "desktopcomputer"
        } else if lowercaseName.contains("garage") {
            return "car"
        } else if lowercaseName.contains("garden") || lowercaseName.contains("garten") {
            return "leaf"
        }
        
        return "house"
    }
}

// MARK: - Widget Data Store

/// Keys for widget data in shared UserDefaults
enum WidgetDataKeys {
    static let favoriteDevices = "widget_favorite_devices"
    static let recentRooms = "widget_recent_rooms"
    static let lastUpdate = "widget_last_update"
    static let connectionState = "widget_connection_state"
}

/// Helper class for reading/writing widget data
class WidgetDataStore {
    static let shared = WidgetDataStore()
    
    private let userDefaults: UserDefaults
    
    private init() {
        // Use app group for sharing data with widget
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) {
            userDefaults = defaults
        } else {
            userDefaults = .standard
        }
    }
    
    // MARK: - Favorite Devices
    
    func saveFavoriteDevices(_ devices: [WidgetDevice]) {
        if let encoded = try? JSONEncoder().encode(devices) {
            userDefaults.set(encoded, forKey: WidgetDataKeys.favoriteDevices)
        }
    }
    
    func loadFavoriteDevices() -> [WidgetDevice] {
        guard let data = userDefaults.data(forKey: WidgetDataKeys.favoriteDevices),
              let devices = try? JSONDecoder().decode([WidgetDevice].self, from: data) else {
            return []
        }
        return devices
    }
    
    // MARK: - Recent Rooms
    
    func saveRecentRooms(_ rooms: [WidgetRoom]) {
        if let encoded = try? JSONEncoder().encode(rooms) {
            userDefaults.set(encoded, forKey: WidgetDataKeys.recentRooms)
        }
    }
    
    func loadRecentRooms() -> [WidgetRoom] {
        guard let data = userDefaults.data(forKey: WidgetDataKeys.recentRooms),
              let rooms = try? JSONDecoder().decode([WidgetRoom].self, from: data) else {
            return []
        }
        return rooms
    }
    
    // MARK: - Last Update
    
    func saveLastUpdate(_ date: Date) {
        userDefaults.set(date, forKey: WidgetDataKeys.lastUpdate)
    }
    
    func loadLastUpdate() -> Date? {
        userDefaults.object(forKey: WidgetDataKeys.lastUpdate) as? Date
    }
    
    // MARK: - Connection State
    
    func saveConnectionState(_ isConnected: Bool) {
        userDefaults.set(isConnected, forKey: WidgetDataKeys.connectionState)
    }
    
    func loadConnectionState() -> Bool {
        userDefaults.bool(forKey: WidgetDataKeys.connectionState)
    }
}

