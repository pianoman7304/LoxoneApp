//
//  DeviceControlWidget.swift
//  LoxoneWidget
//
//  Widget for quick device control (toggle switches)
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Device Control Widget

struct DeviceControlWidget: Widget {
    let kind: String = "DeviceControlWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LoxoneTimelineProvider()) { entry in
            DeviceControlWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Device Control")
        .description("Quick controls for your favorite devices")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View

struct DeviceControlWidgetView: View {
    let entry: LoxoneWidgetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if entry.isPlaceholder {
            placeholderView
        } else if entry.devices.isEmpty {
            emptyStateView
        } else {
            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            default:
                smallWidgetView
            }
        }
    }
    
    // MARK: - Small Widget
    
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .foregroundStyle(.green)
                
                Text("Loxone")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                connectionIndicator
            }
            
            Spacer()
            
            // Single device
            if let device = entry.devices.first {
                DeviceWidgetButton(device: device, size: .large)
            }
            
            // Last update
            Text(entry.lastUpdateString)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Medium Widget
    
    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .foregroundStyle(.green)
                
                Text("Loxone Home")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                connectionIndicator
                
                Text(entry.lastUpdateString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Device grid (2x2)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(entry.devices.prefix(4)) { device in
                    DeviceWidgetButton(device: device, size: .small)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Connection Indicator
    
    private var connectionIndicator: some View {
        Circle()
            .fill(entry.isConnected ? Color.green : Color.gray)
            .frame(width: 6, height: 6)
    }
    
    // MARK: - Placeholder
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Loxone")
                .font(.headline)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No Favorites")
                .font(.caption)
                .fontWeight(.medium)
            
            Text("Add devices in the app")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Device Widget Button

struct DeviceWidgetButton: View {
    let device: WidgetDevice
    let size: DeviceButtonSize
    
    enum DeviceButtonSize {
        case small, large
    }
    
    var body: some View {
        Link(destination: URL(string: "loxone://device/\(device.uuid)")!) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(device.isOn ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: size == .large ? 50 : 36, height: size == .large ? 50 : 36)
                    
                    Image(systemName: device.icon)
                        .font(size == .large ? .title2 : .caption)
                        .foregroundStyle(device.isOn ? .green : .secondary)
                }
                
                if size == .large {
                    Text(device.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(device.isOn ? "On" : "Off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(device.name)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    DeviceControlWidget()
} timeline: {
    LoxoneWidgetEntry(
        date: Date(),
        devices: [
            WidgetDevice(uuid: "1", name: "Living Light", type: "Switch", roomName: "Living Room", state: 1, lastUpdated: Date())
        ],
        isConnected: true,
        isPlaceholder: false
    )
}

#Preview("Medium", as: .systemMedium) {
    DeviceControlWidget()
} timeline: {
    LoxoneWidgetEntry(
        date: Date(),
        devices: [
            WidgetDevice(uuid: "1", name: "Living Light", type: "Switch", roomName: "Living Room", state: 1, lastUpdated: Date()),
            WidgetDevice(uuid: "2", name: "Kitchen", type: "LightController", roomName: "Kitchen", state: 0, lastUpdated: Date()),
            WidgetDevice(uuid: "3", name: "Blinds", type: "Jalousie", roomName: "Living Room", state: 50, lastUpdated: Date()),
            WidgetDevice(uuid: "4", name: "Bedroom", type: "Dimmer", roomName: "Bedroom", state: 75, lastUpdated: Date())
        ],
        isConnected: true,
        isPlaceholder: false
    )
}

