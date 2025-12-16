//
//  LoxoneWidget.swift
//  LoxoneWidget
//
//  Widget extension entry point
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct LoxoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeviceControlWidget()
        RoomStatusWidget()
    }
}

// MARK: - Timeline Provider

struct LoxoneTimelineProvider: TimelineProvider {
    typealias Entry = LoxoneWidgetEntry
    
    func placeholder(in context: Context) -> LoxoneWidgetEntry {
        LoxoneWidgetEntry(
            date: Date(),
            devices: [],
            isConnected: false,
            isPlaceholder: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LoxoneWidgetEntry) -> Void) {
        let entry = LoxoneWidgetEntry(
            date: Date(),
            devices: WidgetDataStore.shared.loadFavoriteDevices(),
            isConnected: WidgetDataStore.shared.loadConnectionState(),
            isPlaceholder: false
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LoxoneWidgetEntry>) -> Void) {
        let currentDate = Date()
        
        // Load data from shared storage
        let devices = WidgetDataStore.shared.loadFavoriteDevices()
        let isConnected = WidgetDataStore.shared.loadConnectionState()
        
        let entry = LoxoneWidgetEntry(
            date: currentDate,
            devices: devices,
            isConnected: isConnected,
            isPlaceholder: false
        )
        
        // Refresh every 5 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        
        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextUpdate)
        )
        
        completion(timeline)
    }
}

// MARK: - Widget Entry

struct LoxoneWidgetEntry: TimelineEntry {
    let date: Date
    let devices: [WidgetDevice]
    let isConnected: Bool
    let isPlaceholder: Bool
    
    var lastUpdateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Room Timeline Provider

struct RoomTimelineProvider: TimelineProvider {
    typealias Entry = RoomWidgetEntry
    
    func placeholder(in context: Context) -> RoomWidgetEntry {
        RoomWidgetEntry(
            date: Date(),
            rooms: [],
            isConnected: false,
            isPlaceholder: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RoomWidgetEntry) -> Void) {
        let entry = RoomWidgetEntry(
            date: Date(),
            rooms: WidgetDataStore.shared.loadRecentRooms(),
            isConnected: WidgetDataStore.shared.loadConnectionState(),
            isPlaceholder: false
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RoomWidgetEntry>) -> Void) {
        let currentDate = Date()
        
        let rooms = WidgetDataStore.shared.loadRecentRooms()
        let isConnected = WidgetDataStore.shared.loadConnectionState()
        
        let entry = RoomWidgetEntry(
            date: currentDate,
            rooms: rooms,
            isConnected: isConnected,
            isPlaceholder: false
        )
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        
        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextUpdate)
        )
        
        completion(timeline)
    }
}

// MARK: - Room Widget Entry

struct RoomWidgetEntry: TimelineEntry {
    let date: Date
    let rooms: [WidgetRoom]
    let isConnected: Bool
    let isPlaceholder: Bool
}

