//
//  FloorViewModel.swift
//  Loxone App
//
//  View model for floor management
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class FloorViewModel: ObservableObject {
    @Published var floors: [Floor] = []
    @Published var isEditing: Bool = false
    @Published var selectedFloor: Floor?
    
    private var modelContext: ModelContext?
    private let loxoneService = LoxoneService.shared
    
    // Available icons for floors
    let availableIcons = [
        "house", "house.fill",
        "stairs", "arrow.up.to.line",
        "square.stack.3d.down.right", "archivebox",
        "leaf", "tree",
        "sun.max", "cloud.sun",
        "car", "car.fill",
        "figure.walk", "person.2",
        "bed.double", "sofa",
        "fork.knife", "cup.and.saucer",
        "shower", "drop",
        "wrench", "gearshape",
        "questionmark.folder"
    ]
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadFloors()
    }
    
    // MARK: - Load
    
    func loadFloors() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Floor>(
            sortBy: [SortDescriptor(\.order)]
        )
        
        floors = (try? context.fetch(descriptor)) ?? []
        
        // Create default floors if none exist
        if floors.isEmpty {
            createDefaultFloors()
        }
    }
    
    // MARK: - Create
    
    func createDefaultFloors() {
        guard let context = modelContext else { return }
        
        let defaultFloors = Floor.createDefaultFloors()
        for floor in defaultFloors {
            context.insert(floor)
        }
        
        try? context.save()
        loadFloors()
    }
    
    func createFloor(name: String, icon: String) {
        guard let context = modelContext else { return }
        
        // Find max order (excluding unassigned which is 999)
        let maxOrder = floors.filter { $0.order < 999 }.map(\.order).max() ?? -1
        
        let floor = Floor(name: name, order: maxOrder + 1, icon: icon)
        context.insert(floor)
        
        try? context.save()
        loadFloors()
    }
    
    // MARK: - Update
    
    func updateFloor(_ floor: Floor, name: String, icon: String) {
        floor.name = name
        floor.icon = icon
        try? modelContext?.save()
        loadFloors()
    }
    
    // MARK: - Delete
    
    func deleteFloor(_ floor: Floor) {
        guard !floor.isUnassigned else { return }
        
        // Move rooms to unassigned
        if let unassigned = floors.first(where: { $0.isUnassigned }) {
            for roomUUID in floor.roomUUIDs {
                unassigned.addRoom(roomUUID)
            }
        }
        
        modelContext?.delete(floor)
        try? modelContext?.save()
        loadFloors()
    }
    
    // MARK: - Room Assignment
    
    func assignRoom(_ roomUUID: String, to floor: Floor) {
        // Remove from all floors first
        for f in floors {
            f.removeRoom(roomUUID)
        }
        
        // Add to target floor
        floor.addRoom(roomUUID)
        try? modelContext?.save()
        loadFloors()
    }
    
    func unassignRoom(_ roomUUID: String, from floor: Floor) {
        floor.removeRoom(roomUUID)
        
        // Add to unassigned
        if let unassigned = floors.first(where: { $0.isUnassigned }) {
            unassigned.addRoom(roomUUID)
        }
        
        try? modelContext?.save()
        loadFloors()
    }
    
    // MARK: - Reordering
    
    func moveFloor(from source: IndexSet, to destination: Int) {
        var editableFloors = floors.filter { !$0.isUnassigned }
        editableFloors.move(fromOffsets: source, toOffset: destination)
        
        for (index, floor) in editableFloors.enumerated() {
            floor.order = index
        }
        
        try? modelContext?.save()
        loadFloors()
    }
    
    // MARK: - Room Helpers
    
    func getRooms(for floor: Floor) -> [LoxoneRoom] {
        let allRooms = loxoneService.getRooms()
        
        if floor.isUnassigned {
            // Return rooms not assigned to any floor
            let assignedRooms = Set(floors.filter { !$0.isUnassigned }.flatMap { $0.roomUUIDs })
            return allRooms.filter { !assignedRooms.contains($0.uuid) }
        }
        
        return allRooms.filter { floor.containsRoom($0.uuid) }
    }
    
    func getUnassignedRooms() -> [LoxoneRoom] {
        let allRooms = loxoneService.getRooms()
        let assignedRooms = Set(floors.filter { !$0.isUnassigned }.flatMap { $0.roomUUIDs })
        return allRooms.filter { !assignedRooms.contains($0.uuid) }
    }
    
    func getRoomCount(for floor: Floor) -> Int {
        if floor.isUnassigned {
            return getUnassignedRooms().count
        }
        return floor.roomUUIDs.count
    }
}

