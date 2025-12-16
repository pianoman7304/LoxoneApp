//
//  RoomListView.swift
//  Loxone App
//
//  List of rooms within a floor
//

import SwiftUI

struct RoomListView: View {
    let floor: Floor?
    let showAllRooms: Bool
    @Binding var selectedRoom: LoxoneRoom?
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var searchText = ""
    
    var body: some View {
        List(selection: $selectedRoom) {
            ForEach(filteredRooms) { room in
                DraggableRoomRow(
                    room: room,
                    deviceCount: viewModel.loxoneService.getControls(for: room.uuid).count,
                    isSelected: selectedRoom?.uuid == room.uuid,
                    floors: viewModel.getFloors(for: room.uuid),
                    showAllRooms: showAllRooms
                )
                .tag(room)
            }
            
            if filteredRooms.isEmpty {
                emptyStateView
            }
        }
        .insetGroupedListStyle()
        .safeAreaInset(edge: .top) {
            if !rooms.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search rooms", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var rooms: [LoxoneRoom] {
        if showAllRooms {
            return viewModel.loxoneService.getRooms()
        } else if let floor = floor {
            return viewModel.getRooms(for: floor)
        }
        return []
    }
    
    private var filteredRooms: [LoxoneRoom] {
        if searchText.isEmpty {
            return rooms
        }
        return rooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No Rooms")
                .font(.headline)
            
            if showAllRooms {
                Text("Connect to your Loxone server to see rooms")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let floor = floor {
                Text(floor.isUnassigned
                     ? "All rooms have been assigned to floors"
                     : "Drag rooms from \"All Rooms\" to add them here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Draggable Room Row

struct DraggableRoomRow: View {
    let room: LoxoneRoom
    let deviceCount: Int
    let isSelected: Bool
    let floors: [Floor]
    let showAllRooms: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.secondarySystemBackground)
                    .frame(width: 44, height: 44)
                
                Image(systemName: room.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Show floor badges when viewing All Rooms
                    if showAllRooms && !floors.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        ForEach(floors.prefix(2)) { floor in
                            Text(floor.name)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        
                        if floors.count > 2 {
                            Text("+\(floors.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Drag indicator when in All Rooms
            if showAllRooms {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .draggable(room.uuid) // Enable drag with room UUID
    }
}

// MARK: - Simple Room Row (for backwards compatibility)

struct RoomRow: View {
    let room: LoxoneRoom
    let deviceCount: Int
    let isSelected: Bool
    
    var body: some View {
        DraggableRoomRow(
            room: room,
            deviceCount: deviceCount,
            isSelected: isSelected,
            floors: [],
            showAllRooms: false
        )
    }
}

#Preview {
    NavigationStack {
        RoomListView(
            floor: Floor(name: "Ground Floor", order: 0, icon: "house"),
            showAllRooms: false,
            selectedRoom: .constant(nil),
            viewModel: LoxoneViewModel()
        )
    }
}

