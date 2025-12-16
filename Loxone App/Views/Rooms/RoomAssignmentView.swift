//
//  RoomAssignmentView.swift
//  Loxone App
//
//  View for assigning rooms to floors
//

import SwiftUI

struct RoomAssignmentView: View {
    let floor: Floor
    @ObservedObject var viewModel: LoxoneViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRooms: Set<String> = []
    @State private var searchText = ""
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isRefreshing {
                    // Show loading indicator during refresh
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading rooms...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.loxoneService.structure == nil {
                    // Show loading state if structure not loaded
                    ContentUnavailableView(
                        "Not Connected",
                        systemImage: "network.slash",
                        description: Text("Connect to your Loxone Miniserver to see rooms.")
                    )
                } else if allRooms.isEmpty {
                    // No rooms in structure
                    ContentUnavailableView(
                        "No Rooms Found",
                        systemImage: "square.dashed",
                        description: Text("Your Loxone configuration doesn't contain any rooms.")
                    )
                } else {
                    // Show room list
                    List {
                        // Currently assigned rooms
                        if !assignedRooms.isEmpty {
                            Section("Assigned to \(floor.name)") {
                                ForEach(assignedRooms) { room in
                                    RoomAssignmentRow(
                                        room: room,
                                        isAssigned: true
                                    ) {
                                        viewModel.assignRoom(room.uuid, to: unassignedFloor!)
                                    }
                                }
                            }
                        }
                        
                        // Available rooms (from unassigned or other floors)
                        if !filteredAvailableRooms.isEmpty {
                            Section("Available Rooms") {
                                ForEach(filteredAvailableRooms) { room in
                                    RoomAssignmentRow(
                                        room: room,
                                        isAssigned: false,
                                        currentFloorName: currentFloorName(for: room)
                                    ) {
                                        viewModel.assignRoom(room.uuid, to: floor)
                                    }
                                }
                            }
                        }
                        
                        // Show message if search returns no results
                        if !searchText.isEmpty && filteredAvailableRooms.isEmpty && assignedRooms.isEmpty {
                            Section {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                        Text("No rooms match '\(searchText)'")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 40)
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search rooms")
                }
            }
            .navigationTitle("Assign Rooms")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.loxoneService.structure == nil {
                        Button {
                            Task {
                                isRefreshing = true
                                await viewModel.refresh()
                                isRefreshing = false
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                isRefreshing = true
                await viewModel.refresh()
                isRefreshing = false
            }
        }
        .onAppear {
            print("🏠 [RoomAssignment] View appeared")
            print("🏠 [RoomAssignment] Structure loaded: \(viewModel.loxoneService.structure != nil)")
            print("🏠 [RoomAssignment] Total rooms: \(allRooms.count)")
            
            if !allRooms.isEmpty {
                print("🏠 [RoomAssignment] Room names:")
                for room in allRooms.prefix(5) {
                    print("  - \(room.name) (UUID: \(room.uuid))")
                }
                if allRooms.count > 5 {
                    print("  ... and \(allRooms.count - 5) more")
                }
            }
            
            print("🏠 [RoomAssignment] Assigned to \(floor.name): \(assignedRooms.count)")
            print("🏠 [RoomAssignment] Available rooms: \(availableRooms.count)")
            
            if let structure = viewModel.loxoneService.structure {
                print("🏠 [RoomAssignment] Structure rooms dictionary count: \(structure.rooms?.count ?? 0)")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var allRooms: [LoxoneRoom] {
        viewModel.loxoneService.getRooms()
    }
    
    private var assignedRooms: [LoxoneRoom] {
        let rooms = viewModel.getRooms(for: floor)
        
        // Apply search filter to assigned rooms too
        if searchText.isEmpty {
            return rooms
        }
        return rooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var availableRooms: [LoxoneRoom] {
        let allRooms = viewModel.loxoneService.getRooms()
        let assignedUUIDs = Set(floor.roomUUIDs)
        return allRooms.filter { !assignedUUIDs.contains($0.uuid) }
    }
    
    private var filteredAvailableRooms: [LoxoneRoom] {
        if searchText.isEmpty {
            return availableRooms
        }
        
        let filtered = availableRooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        print("🔍 [RoomAssignment] Search: '\(searchText)' - Found \(filtered.count) rooms")
        return filtered
    }
    
    private var unassignedFloor: Floor? {
        viewModel.floors.first { $0.isUnassigned }
    }
    
    private func currentFloorName(for room: LoxoneRoom) -> String? {
        let otherFloor = viewModel.floors.first { 
            !$0.isUnassigned && $0.containsRoom(room.uuid)
        }
        return otherFloor?.name
    }
}

// MARK: - Room Assignment Row

struct RoomAssignmentRow: View {
    let room: LoxoneRoom
    let isAssigned: Bool
    var currentFloorName: String? = nil
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: room.icon)
                .font(.title3)
                .foregroundStyle(isAssigned ? .green : .secondary)
                .frame(width: 28)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.body)
                
                if let floorName = currentFloorName {
                    Text("Currently in: \(floorName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: action) {
                Image(systemName: isAssigned ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isAssigned ? .red : .green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RoomAssignmentView(
        floor: Floor(name: "Ground Floor", order: 0, icon: "house"),
        viewModel: LoxoneViewModel()
    )
}

