//
//  RoomStatusWidget.swift
//  LoxoneWidget
//
//  Widget showing room overview and status
//

import WidgetKit
import SwiftUI

// MARK: - Room Status Widget

struct RoomStatusWidget: Widget {
    let kind: String = "RoomStatusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoomTimelineProvider()) { entry in
            RoomStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Room Status")
        .description("Overview of your rooms and active devices")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Widget View

struct RoomStatusWidgetView: View {
    let entry: RoomWidgetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if entry.isPlaceholder {
            placeholderView
        } else if entry.rooms.isEmpty {
            emptyStateView
        } else {
            switch family {
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            default:
                mediumWidgetView
            }
        }
    }
    
    // MARK: - Medium Widget
    
    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            headerView
            
            Spacer()
            
            // Room list (2 rooms)
            HStack(spacing: 12) {
                ForEach(entry.rooms.prefix(2)) { room in
                    RoomWidgetCard(room: room)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Large Widget
    
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView
            
            // Room grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(entry.rooms.prefix(6)) { room in
                    RoomWidgetCard(room: room)
                }
            }
            
            Spacer()
            
            // Summary
            HStack {
                let totalActive = entry.rooms.reduce(0) { $0 + $1.activeDeviceCount }
                Text("\(totalActive) active device\(totalActive == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(lastUpdateString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "house.fill")
                .foregroundStyle(.green)
            
            Text("Rooms")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Circle()
                .fill(entry.isConnected ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
        }
    }
    
    // MARK: - Placeholder
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Rooms")
                .font(.headline)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "house")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No Rooms")
                .font(.caption)
                .fontWeight(.medium)
            
            Text("Connect to see your rooms")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var lastUpdateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.date, relativeTo: Date())
    }
}

// MARK: - Room Widget Card

struct RoomWidgetCard: View {
    let room: WidgetRoom
    
    var body: some View {
        Link(destination: URL(string: "loxone://room/\(room.uuid)")!) {
            VStack(alignment: .leading, spacing: 6) {
                // Icon and name
                HStack {
                    Image(systemName: room.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(room.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Active devices
                HStack(spacing: 4) {
                    Circle()
                        .fill(room.activeDeviceCount > 0 ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Text("\(room.activeDeviceCount) active")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground).opacity(0.5))
            )
        }
    }
}

// MARK: - Preview

#Preview("Medium", as: .systemMedium) {
    RoomStatusWidget()
} timeline: {
    RoomWidgetEntry(
        date: Date(),
        rooms: [
            WidgetRoom(uuid: "1", name: "Living Room", devices: [], activeDeviceCount: 3),
            WidgetRoom(uuid: "2", name: "Kitchen", devices: [], activeDeviceCount: 1)
        ],
        isConnected: true,
        isPlaceholder: false
    )
}

#Preview("Large", as: .systemLarge) {
    RoomStatusWidget()
} timeline: {
    RoomWidgetEntry(
        date: Date(),
        rooms: [
            WidgetRoom(uuid: "1", name: "Living Room", devices: [], activeDeviceCount: 3),
            WidgetRoom(uuid: "2", name: "Kitchen", devices: [], activeDeviceCount: 1),
            WidgetRoom(uuid: "3", name: "Bedroom", devices: [], activeDeviceCount: 0),
            WidgetRoom(uuid: "4", name: "Bathroom", devices: [], activeDeviceCount: 2),
            WidgetRoom(uuid: "5", name: "Office", devices: [], activeDeviceCount: 1),
            WidgetRoom(uuid: "6", name: "Garage", devices: [], activeDeviceCount: 0)
        ],
        isConnected: true,
        isPlaceholder: false
    )
}

