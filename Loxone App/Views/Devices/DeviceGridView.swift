//
//  DeviceGridView.swift
//  Loxone App
//
//  Grid view showing all devices in a room
//

import SwiftUI

struct DeviceGridView: View {
    let room: LoxoneRoom
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var filter: DeviceFilter = .all
    @State private var searchText = ""
    @State private var isLoadingStates = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Filter pills
                    filterView
                    
                    // Device grid
                    if filteredDevices.isEmpty {
                        emptyStateView
                    } else {
                        deviceGrid
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
            
            // Loading overlay
            if isLoadingStates {
                VStack {
                    Spacer()
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Loading device states...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    Spacer()
                }
            }
        }
        .onAppear {
            print("🎯 [DeviceGridView] onAppear - room: \(room.name) (\(room.uuid))")
            print("🎯 [DeviceGridView] Total devices in room: \(allDevices.count)")
            print("🎯 [DeviceGridView] Filtered devices: \(filteredDevices.count)")
            for device in allDevices {
                print("🎯 [DeviceGridView]   - \(device.name) (\(device.type)) - UUID: \(device.uuid)")
            }
            viewModel.selectRoom(room)
            
            // Load states for this room immediately
            Task {
                isLoadingStates = true
                await viewModel.loxoneService.fetchRoomStatesImmediate(room.uuid)
                isLoadingStates = false
            }
        }
        .onChange(of: room) { _, newRoom in
            print("🎯 [DeviceGridView] Room changed to: \(newRoom.name)")
            viewModel.selectRoom(newRoom)
            
            // Load states for the new room
            Task {
                isLoadingStates = true
                await viewModel.loxoneService.fetchRoomStatesImmediate(newRoom.uuid)
                isLoadingStates = false
            }
        }
    }
    
    // MARK: - Filter View
    
    private var filterView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search devices", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DeviceFilter.allCases) { filterOption in
                        FilterPill(
                            title: filterOption.title,
                            icon: filterOption.icon,
                            isSelected: filter == filterOption
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                filter = filterOption
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Device Grid
    
    private var deviceGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredDevices, id: \.uuid) { control in
                DeviceCardFactory.makeCard(
                    for: control,
                    stateStore: viewModel.loxoneService.stateStore,
                    viewModel: viewModel
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: filter == .all ? "square.grid.2x2" : filter.icon)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text(filter == .all ? "No Devices" : "No \(filter.title)")
                .font(.headline)
            
            Text(filter == .all
                 ? "This room doesn't have any devices"
                 : "This room doesn't have any \(filter.title.lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Computed Properties
    
    private var allDevices: [LoxoneControl] {
        viewModel.loxoneService.getControls(for: room.uuid)
    }
    
    private var filteredDevices: [LoxoneControl] {
        var devices = allDevices
        
        // Remove duplicates by UUID (Loxone can return same control multiple times)
        var seenUUIDs = Set<String>()
        devices = devices.filter { control in
            if seenUUIDs.contains(control.uuid) {
                return false
            }
            seenUUIDs.insert(control.uuid)
            return true
        }
        
        // Apply type filter
        if filter != .all {
            devices = devices.filter { filter.matches($0) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            devices = devices.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return devices
    }
}

// MARK: - Device Filter

enum DeviceFilter: String, CaseIterable, Identifiable {
    case all
    case lights
    case switches
    case sensors
    case climate
    case blinds
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all: return "All"
        case .lights: return "Lights"
        case .switches: return "Switches"
        case .sensors: return "Sensors"
        case .climate: return "Climate"
        case .blinds: return "Blinds"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .lights: return "lightbulb"
        case .switches: return "power"
        case .sensors: return "chart.line.uptrend.xyaxis"
        case .climate: return "thermometer"
        case .blinds: return "blinds.horizontal.closed"
        }
    }
    
    func matches(_ control: LoxoneControl) -> Bool {
        let type = control.type.lowercased()
        let name = control.name.lowercased()
        
        switch self {
        case .all:
            return true
        case .lights:
            return type.contains("light") || type.contains("dimmer") || type.contains("color")
        case .switches:
            return type.contains("switch") || type.contains("pushbutton")
        case .sensors:
            // All sensors including temperature and humidity
            return type.contains("sensor") || type.contains("analog") || 
                   type.contains("meter") || type.contains("infoonly") ||
                   name.contains("temp") || name.contains("humid") ||
                   name.contains("feuchte") || name.contains("temperature") ||
                   name.contains("humidity")
        case .climate:
            // Only actual climate CONTROLLERS (thermostats, HVAC), not sensors
            return type.contains("iroomcontroller") || type.contains("i-roomcontroller") ||
                   type.contains("heating") || type.contains("ventilation") ||
                   type.contains("climate") || type.contains("thermostat")
        case .blinds:
            return type.contains("jalousie") || type.contains("blind") ||
                   type.contains("gate") || type.contains("window")
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color.secondarySystemBackground
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Card Factory

struct DeviceCardFactory {
    @MainActor
    static func makeCard(
        for control: LoxoneControl,
        stateStore: DeviceStateStore,
        viewModel: LoxoneViewModel
    ) -> some View {
        let controlType = LoxoneControlType(rawValue: control.type)
        
        return Group {
            switch controlType {
            case .switch_, .pushbutton, .timedSwitch:
                SwitchCard(control: control, stateStore: stateStore, viewModel: viewModel)
                
            case .dimmer, .eibDimmer:
                DimmerCard(control: control, stateStore: stateStore, viewModel: viewModel)
                
            case .lightController, .lightControllerV2, .centralLightController:
                LightControllerCard(control: control, stateStore: stateStore, viewModel: viewModel)
                
            case .jalousie, .centralJalousie, .gate, .window:
                JalousieCard(control: control, stateStore: stateStore, viewModel: viewModel)
                
            case .infoOnlyAnalog, .infoOnlyDigital, .textState, .meter:
                SensorCard(control: control, stateStore: stateStore)
                
            case .iRoomController, .iRoomControllerV2:
                SensorCard(control: control, stateStore: stateStore)
                
            default:
                // Generic card for unknown types
                GenericDeviceCard(control: control, stateStore: stateStore, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Generic Device Card

struct GenericDeviceCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    private var state: DeviceState? {
        // Try common state UUID names
        let stateNames = ["value", "active", "state", "position"]
        
        for stateName in stateNames {
            if let stateUUID = control.states?[stateName]?.uuidString,
               let state = stateStore.state(for: stateUUID) {
                return state
            }
        }
        
        // Fallback to the control's main UUID
        return stateStore.state(for: control.uuid)
    }
    
    private var isOn: Bool {
        state?.isOn ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: LoxoneControlType(rawValue: control.type)?.icon ?? "gear")
                    .font(.title2)
                    .foregroundStyle(isOn ? .green : .secondary)
                
                Spacer()
                
                Text(isOn ? "ON" : "OFF")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOn ? .green : .secondary)
            }
            
            // Name
            Text(control.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            // Type
            Text(control.type)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Value if available
            if let value = state?.value {
                Text(String(format: "%.1f", value))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(height: 160)
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOn ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    DeviceGridView(
        room: LoxoneRoom(uuid: "test", name: "Living Room"),
        viewModel: LoxoneViewModel()
    )
}

