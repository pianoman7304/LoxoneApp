//
//  SensorCard.swift
//  Loxone App
//
//  Device card for sensors (temperature, humidity, analog values)
//

import SwiftUI

struct SensorCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    
    private var state: DeviceState? {
        // First try to get state from the control's "value" state UUID
        if let valueStateUUID = control.states?["value"]?.uuidString {
            if let valueState = stateStore.state(for: valueStateUUID) {
                return valueState
            } else {
                print("⚠️ [SensorCard] No state found for value UUID: \(valueStateUUID) (control: \(control.name))")
            }
        } else {
            print("⚠️ [SensorCard] No value state UUID for control: \(control.name)")
            print("⚠️ [SensorCard] Available states: \(control.states?.keys.joined(separator: ", ") ?? "none")")
        }
        
        // Fallback to the control's main UUID
        let mainState = stateStore.state(for: control.uuid)
        if mainState == nil {
            print("⚠️ [SensorCard] No state found for main UUID: \(control.uuid) (control: \(control.name))")
        }
        return mainState
    }
    
    private var sensorType: SensorValueType {
        SensorValueType.detect(from: control.name)
    }
    
    private var formattedValue: String {
        guard let value = state?.value else { return "--" }
        return value.formatted(decimals: sensorType.decimals)
    }
    
    private var hasValue: Bool {
        state != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(sensorColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: sensorType.icon)
                        .font(.title3)
                        .foregroundStyle(sensorColor)
                }
                
                Spacer()
                
                // Trend indicator (if we had historical data)
                if hasValue {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Value display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedValue)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(hasValue ? .primary : .secondary)
                
                Text(sensorType.unit)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            // Name and type
            VStack(alignment: .leading, spacing: 2) {
                Text(control.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(sensorTypeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondarySystemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(sensorColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private var sensorColor: Color {
        switch sensorType {
        case .temperature:
            return .orange
        case .humidity:
            return .blue
        case .power, .energy:
            return .yellow
        case .lux:
            return .yellow
        case .wind, .rain, .pressure:
            return .cyan
        case .voltage, .current:
            return .purple
        case .percentage:
            return .green
        case .generic:
            return .gray
        }
    }
    
    private var sensorTypeLabel: String {
        switch sensorType {
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .power: return "Power"
        case .energy: return "Energy"
        case .lux: return "Brightness"
        case .wind: return "Wind Speed"
        case .rain: return "Rain"
        case .pressure: return "Pressure"
        case .voltage: return "Voltage"
        case .current: return "Current"
        case .percentage: return "Percentage"
        case .generic: return "Sensor"
        }
    }
}

// MARK: - Digital Sensor Card

struct DigitalSensorCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    
    private var state: DeviceState? {
        // First try to get state from the control's "value" or "active" state UUID
        if let valueStateUUID = control.states?["value"]?.uuidString,
           let valueState = stateStore.state(for: valueStateUUID) {
            return valueState
        }
        
        if let activeStateUUID = control.states?["active"]?.uuidString,
           let activeState = stateStore.state(for: activeStateUUID) {
            return activeState
        }
        
        // Fallback to the control's main UUID
        return stateStore.state(for: control.uuid)
    }
    
    private var isActive: Bool {
        state?.isOn ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isActive ? "circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isActive ? .green : .secondary)
                }
                
                Spacer()
                
                // Status
                Text(isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isActive ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isActive ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                    )
            }
            
            Spacer()
            
            // Large status indicator
            HStack {
                Circle()
                    .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .shadow(color: isActive ? .green.opacity(0.5) : .clear, radius: 4)
                
                Text(isActive ? "ON" : "OFF")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(control.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Digital Sensor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondarySystemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
        SensorCard(
            control: LoxoneControl.preview(name: "Temperature Living", type: "InfoOnlyAnalog", uuid: "temp"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "temp", value: 22.5)
                return store
            }()
        )
        
        SensorCard(
            control: LoxoneControl.preview(name: "Humidity Bath", type: "InfoOnlyAnalog", uuid: "humid"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "humid", value: 58)
                return store
            }()
        )
        
        SensorCard(
            control: LoxoneControl.preview(name: "Power Usage", type: "Meter", uuid: "power"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "power", value: 1450)
                return store
            }()
        )
        
        DigitalSensorCard(
            control: LoxoneControl.preview(name: "Motion Sensor", type: "InfoOnlyDigital", uuid: "motion"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "motion", value: 1)
                return store
            }()
        )
    }
    .padding()
}

