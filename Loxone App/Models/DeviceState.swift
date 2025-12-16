//
//  DeviceState.swift
//  Loxone App
//
//  Model for tracking device states from Loxone
//

import Foundation
import Combine

// MARK: - Device State

/// Represents the current state of a Loxone device
struct DeviceState: Identifiable, Equatable {
    let uuid: String
    var value: Double
    var timestamp: Date
    
    var id: String { uuid }
    
    init(uuid: String, value: Double, timestamp: Date = Date()) {
        self.uuid = uuid
        self.value = value
        self.timestamp = timestamp
    }
    
    /// Check if the device is on (value > 0)
    var isOn: Bool {
        value > 0
    }
    
    /// Get value as percentage (0-100)
    var percentage: Int {
        Int(min(100, max(0, value)))
    }
    
    /// Get value as boolean
    var boolValue: Bool {
        value > 0
    }
    
    /// Format value for display based on context
    func formattedValue(unit: String? = nil, decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        
        if let unit = unit {
            return "\(formatted) \(unit)"
        }
        return formatted
    }
}

// MARK: - Device State Manager

/// Thread-safe storage for device states
@MainActor
class DeviceStateStore: ObservableObject {
    @Published private(set) var states: [String: DeviceState] = [:]
    
    /// Update a device state
    func update(uuid: String, value: Double) {
        let state = DeviceState(uuid: uuid, value: value)
        states[uuid] = state
        // Log state updates for debugging
        print("📊 [DeviceStateStore] Updated state: \(uuid) = \(value) (total states: \(states.count))")
    }
    
    /// Get state for a device
    func state(for uuid: String) -> DeviceState? {
        states[uuid]
    }
    
    /// Get value for a device
    func value(for uuid: String) -> Double? {
        states[uuid]?.value
    }
    
    /// Check if a device is on
    func isOn(_ uuid: String) -> Bool {
        states[uuid]?.isOn ?? false
    }
    
    /// Clear all states
    func clear() {
        states.removeAll()
    }
    
    /// Remove state for a specific device
    func remove(_ uuid: String) {
        states.removeValue(forKey: uuid)
    }
}

// MARK: - Sensor Value Types

/// Common sensor value interpretations
enum SensorValueType {
    case temperature
    case humidity
    case power
    case energy
    case lux
    case wind
    case rain
    case pressure
    case voltage
    case current
    case percentage
    case generic
    
    /// Detect sensor type from name
    static func detect(from name: String) -> SensorValueType {
        let lowercased = name.lowercased()
        
        if lowercased.contains("temp") || lowercased.contains("°c") {
            return .temperature
        }
        if lowercased.contains("humid") || lowercased.contains("feucht") {
            return .humidity
        }
        if lowercased.contains("power") || lowercased.contains("watt") || lowercased.contains("leistung") {
            return .power
        }
        if lowercased.contains("energy") || lowercased.contains("kwh") || lowercased.contains("energie") {
            return .energy
        }
        if lowercased.contains("lux") || lowercased.contains("hell") {
            return .lux
        }
        if lowercased.contains("wind") {
            return .wind
        }
        if lowercased.contains("rain") || lowercased.contains("regen") {
            return .rain
        }
        if lowercased.contains("pressure") || lowercased.contains("druck") || lowercased.contains("bar") {
            return .pressure
        }
        if lowercased.contains("volt") {
            return .voltage
        }
        if lowercased.contains("ampere") || lowercased.contains("strom") {
            return .current
        }
        if lowercased.contains("%") || lowercased.contains("percent") {
            return .percentage
        }
        
        return .generic
    }
    
    /// Get the unit for this sensor type
    var unit: String {
        switch self {
        case .temperature: return "°C"
        case .humidity: return "%"
        case .power: return "W"
        case .energy: return "kWh"
        case .lux: return "lux"
        case .wind: return "m/s"
        case .rain: return "mm"
        case .pressure: return "bar"
        case .voltage: return "V"
        case .current: return "A"
        case .percentage: return "%"
        case .generic: return ""
        }
    }
    
    /// Get decimal places for this sensor type
    var decimals: Int {
        switch self {
        case .temperature, .wind, .voltage: return 1
        case .energy, .pressure, .current: return 2
        case .humidity, .power, .lux, .percentage: return 0
        case .rain, .generic: return 1
        }
    }
    
    /// Get SF Symbol icon for this sensor type
    var icon: String {
        switch self {
        case .temperature: return "thermometer"
        case .humidity: return "humidity"
        case .power: return "bolt"
        case .energy: return "bolt.badge.clock"
        case .lux: return "sun.max"
        case .wind: return "wind"
        case .rain: return "cloud.rain"
        case .pressure: return "gauge"
        case .voltage: return "alternatingcurrent"
        case .current: return "power"
        case .percentage: return "percent"
        case .generic: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Notification Event Types

/// Types of events that can trigger notifications
enum NotificationEventType: String, CaseIterable {
    // Security events
    case alarmTriggered = "alarm_triggered"
    case doorOpened = "door_opened"
    case windowOpened = "window_opened"
    case smokeDetected = "smoke_detected"
    case motionDetected = "motion_detected"
    
    // Climate events
    case temperatureHigh = "temperature_high"
    case temperatureLow = "temperature_low"
    case humidityHigh = "humidity_high"
    case humidityLow = "humidity_low"
    
    var isSecurityEvent: Bool {
        switch self {
        case .alarmTriggered, .doorOpened, .windowOpened, .smokeDetected, .motionDetected:
            return true
        default:
            return false
        }
    }
    
    var isClimateEvent: Bool {
        switch self {
        case .temperatureHigh, .temperatureLow, .humidityHigh, .humidityLow:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .alarmTriggered: return "Alarm Triggered"
        case .doorOpened: return "Door Opened"
        case .windowOpened: return "Window Opened"
        case .smokeDetected: return "Smoke Detected"
        case .motionDetected: return "Motion Detected"
        case .temperatureHigh: return "Temperature High"
        case .temperatureLow: return "Temperature Low"
        case .humidityHigh: return "Humidity High"
        case .humidityLow: return "Humidity Low"
        }
    }
    
    var icon: String {
        switch self {
        case .alarmTriggered: return "bell.badge.fill"
        case .doorOpened: return "door.left.hand.open"
        case .windowOpened: return "window.horizontal"
        case .smokeDetected: return "smoke.fill"
        case .motionDetected: return "figure.walk.motion"
        case .temperatureHigh, .temperatureLow: return "thermometer"
        case .humidityHigh, .humidityLow: return "humidity"
        }
    }
}

