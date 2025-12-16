//
//  FloorListView.swift
//  Loxone App
//
//  Sidebar view showing floor groups
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Selection Type (All Rooms vs Floor)

enum FloorSelection: Hashable {
    case allRooms
    case floor(Floor)
    
    var floor: Floor? {
        if case .floor(let f) = self { return f }
        return nil
    }
    
    var isAllRooms: Bool {
        if case .allRooms = self { return true }
        return false
    }
}

struct FloorListView: View {
    @Binding var selectedFloor: Floor?
    @Binding var showAllRooms: Bool
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var showingEditFloor = false
    @State private var floorToEdit: Floor?
    @State private var showingAddFloor = false
    @State private var isEditingOrder = false
    
    var body: some View {
        List {
            // All Rooms - always at top (not in edit mode)
            if !isEditingOrder {
                Section {
                    AllRoomsRow(
                        roomCount: viewModel.loxoneService.getRooms().count,
                        isSelected: showAllRooms
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAllRooms = true
                        selectedFloor = nil
                    }
                    .dropDestination(for: String.self) { _, _ in
                        return false
                    }
                }
            }
            
            // Editable floors
            Section(isEditingOrder ? "Drag to Reorder" : "Floors") {
                ForEach(editableFloors) { floor in
                    FloorRow(
                        floor: floor,
                        roomCount: viewModel.getRooms(for: floor).count,
                        isSelected: selectedFloor?.id == floor.id && !showAllRooms,
                        isEditing: isEditingOrder
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isEditingOrder {
                            showAllRooms = false
                            selectedFloor = floor
                        }
                    }
                    .contextMenu {
                        if !isEditingOrder {
                            floorContextMenu(for: floor)
                        }
                    }
                    .dropDestination(for: String.self) { roomUUIDs, _ in
                        guard !isEditingOrder else { return false }
                        for uuid in roomUUIDs {
                            viewModel.addRoomToFloor(uuid, floor: floor)
                        }
                        return true
                    }
                }
                .onMove(perform: moveFloors)
            }
            
            // Action buttons at bottom
            Section {
                if !isEditingOrder {
                    // Add floor button
                    Button {
                        showingAddFloor = true
                    } label: {
                        Label("Add Floor", systemImage: "plus")
                    }
                }
                
                // Edit/Done button
                Button {
                    withAnimation {
                        isEditingOrder.toggle()
                    }
                } label: {
                    Label(isEditingOrder ? "Done Reordering" : "Reorder Floors", systemImage: isEditingOrder ? "checkmark" : "arrow.up.arrow.down")
                }
                .foregroundStyle(isEditingOrder ? .green : .primary)
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingAddFloor) {
            FloorEditView(
                mode: .add,
                viewModel: viewModel
            )
        }
        .sheet(item: $floorToEdit) { floor in
            FloorEditView(
                mode: .edit(floor),
                viewModel: viewModel
            )
        }
        .onAppear {
            print("📂 [FloorListView] onAppear - loading floors")
            viewModel.loadFloors()
            
            // Default to All Rooms
            if selectedFloor == nil && !showAllRooms {
                showAllRooms = true
            }
            print("📂 [FloorListView] showAllRooms: \(showAllRooms), selectedFloor: \(selectedFloor?.name ?? "nil")")
        }
    }
    
    // MARK: - Computed Properties
    
    private var editableFloors: [Floor] {
        viewModel.floors.filter { !$0.isUnassigned }
    }
    
    private var unassignedFloor: Floor? {
        viewModel.floors.first { $0.isUnassigned }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func floorContextMenu(for floor: Floor) -> some View {
        Button {
            floorToEdit = floor
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive) {
            viewModel.deleteFloor(floor)
            if selectedFloor?.id == floor.id {
                showAllRooms = true
                selectedFloor = nil
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func moveFloors(from source: IndexSet, to destination: Int) {
        var floors = editableFloors
        floors.move(fromOffsets: source, toOffset: destination)
        
        // Update order for all floors
        for (index, floor) in floors.enumerated() {
            floor.order = index
        }
        
        // Save and reload
        viewModel.saveFloorOrder()
    }
}

// MARK: - All Rooms Row

struct AllRoomsRow: View {
    let roomCount: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .blue)
                .frame(width: 28)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("All Rooms")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text("\(roomCount) room\(roomCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.8) : Color.clear
        )
    }
}

// MARK: - Floor Row

struct FloorRow: View {
    let floor: Floor
    let roomCount: Int
    let isSelected: Bool
    var isEditing: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: floor.icon)
                .font(.title3)
                .foregroundStyle(isSelected && !isEditing ? .white : .primary)
                .frame(width: 28)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(floor.name)
                    .font(.body)
                    .foregroundStyle(isSelected && !isEditing ? .white : .primary)
                
                Text("\(roomCount) room\(roomCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(isSelected && !isEditing ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            // Drag handle when editing
            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            isSelected && !isEditing ? Color.accentColor.opacity(0.8) : Color.clear
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FloorListView(
            selectedFloor: .constant(nil),
            showAllRooms: .constant(true),
            viewModel: LoxoneViewModel()
        )
    }
}

