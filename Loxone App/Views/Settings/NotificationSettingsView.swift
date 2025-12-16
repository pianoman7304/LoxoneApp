//
//  NotificationSettingsView.swift
//  Loxone App
//
//  Configure notification preferences
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var isRequestingPermission = false
    
    var body: some View {
        Form {
            // Authorization status
            Section {
                HStack {
                    Label {
                        Text("Notifications")
                    } icon: {
                        Image(systemName: notificationService.isAuthorized ? "bell.badge" : "bell.slash")
                            .foregroundStyle(notificationService.isAuthorized ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if notificationService.isAuthorized {
                        Text("Enabled")
                            .foregroundStyle(.green)
                    } else {
                        Button("Enable") {
                            requestPermission()
                        }
                        .disabled(isRequestingPermission)
                    }
                }
            } footer: {
                if !notificationService.isAuthorized {
                    Text("Enable notifications to receive alerts for security and climate events.")
                }
            }
            
            // Security notifications
            Section {
                Toggle("Security Alerts", isOn: $notificationService.securityNotificationsEnabled)
                    .onChange(of: notificationService.securityNotificationsEnabled) { _, _ in
                        notificationService.saveSettings()
                    }
                
                if notificationService.securityNotificationsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        NotificationTypeRow(icon: "bell.badge", title: "Alarm triggered")
                        NotificationTypeRow(icon: "door.left.hand.open", title: "Door opened")
                        NotificationTypeRow(icon: "window.horizontal", title: "Window opened")
                        NotificationTypeRow(icon: "smoke", title: "Smoke detected")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Security")
            } footer: {
                Text("Get notified about security-related events like alarms and open doors/windows.")
            }
            
            // Climate notifications
            Section {
                Toggle("Climate Alerts", isOn: $notificationService.climateNotificationsEnabled)
                    .onChange(of: notificationService.climateNotificationsEnabled) { _, _ in
                        notificationService.saveSettings()
                    }
                
                if notificationService.climateNotificationsEnabled {
                    // Temperature thresholds
                    VStack(alignment: .leading, spacing: 8) {
                        ThresholdRow(
                            title: "High Temperature",
                            value: $notificationService.temperatureHighThreshold,
                            range: 20...40,
                            unit: "°C"
                        )
                        
                        ThresholdRow(
                            title: "Low Temperature",
                            value: $notificationService.temperatureLowThreshold,
                            range: 5...20,
                            unit: "°C"
                        )
                    }
                    
                    Divider()
                    
                    // Humidity thresholds
                    VStack(alignment: .leading, spacing: 8) {
                        ThresholdRow(
                            title: "High Humidity",
                            value: $notificationService.humidityHighThreshold,
                            range: 50...90,
                            unit: "%"
                        )
                        
                        ThresholdRow(
                            title: "Low Humidity",
                            value: $notificationService.humidityLowThreshold,
                            range: 10...50,
                            unit: "%"
                        )
                    }
                }
            } header: {
                Text("Climate")
            } footer: {
                Text("Get notified when temperature or humidity exceeds your set thresholds.")
            }
            
            // Actions
            Section {
                Button(role: .destructive) {
                    notificationService.removeAllNotifications()
                } label: {
                    Label("Clear All Notifications", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Notifications")
        .inlineNavigationBarTitle()
        .task {
            await notificationService.checkAuthorization()
        }
    }
    
    // MARK: - Actions
    
    private func requestPermission() {
        isRequestingPermission = true
        
        Task {
            _ = await notificationService.requestAuthorization()
            isRequestingPermission = false
        }
    }
}

// MARK: - Notification Type Row

struct NotificationTypeRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(title)
        }
    }
}

// MARK: - Threshold Row

struct ThresholdRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(Int(value))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range, step: 1) {
                Text(title)
            }
            .onChange(of: value) { _, _ in
                notificationService.saveSettings()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Floor Management View

struct FloorManagementView: View {
    @ObservedObject var viewModel: LoxoneViewModel
    @StateObject private var floorViewModel = FloorViewModel()
    
    @State private var showingAddFloor = false
    @State private var floorToEdit: Floor?
    
    var body: some View {
        List {
            Section {
                ForEach(floorViewModel.floors.filter { !$0.isUnassigned }) { floor in
                    FloorManagementRow(floor: floor, roomCount: floorViewModel.getRoomCount(for: floor))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            floorToEdit = floor
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                floorViewModel.deleteFloor(floor)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                floorToEdit = floor
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onMove(perform: floorViewModel.moveFloor)
            } header: {
                Text("Floors")
            } footer: {
                Text("Drag to reorder floors. Tap to edit.")
            }
            
            // Unassigned info
            if let unassigned = floorViewModel.floors.first(where: { $0.isUnassigned }) {
                Section {
                    HStack {
                        Image(systemName: unassigned.icon)
                            .foregroundStyle(.secondary)
                        
                        Text("Unassigned Rooms")
                        
                        Spacer()
                        
                        Text("\(floorViewModel.getRoomCount(for: unassigned))")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Rooms not assigned to any floor appear here.")
                }
            }
            
            Section {
                Button {
                    showingAddFloor = true
                } label: {
                    Label("Add Floor", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Manage Floors")
        .inlineNavigationBarTitle()
        .editModeActive()
        .sheet(isPresented: $showingAddFloor) {
            FloorEditView(mode: .add, viewModel: viewModel)
        }
        .sheet(item: $floorToEdit) { floor in
            FloorEditView(mode: .edit(floor), viewModel: viewModel)
        }
        .onAppear {
            if let context = try? viewModel.loxoneService.structure {
                // Floor view model will load from context
            }
        }
    }
}

// MARK: - Floor Management Row

struct FloorManagementRow: View {
    let floor: Floor
    let roomCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: floor.icon)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(floor.name)
                    .font(.body)
                
                Text("\(roomCount) room\(roomCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

