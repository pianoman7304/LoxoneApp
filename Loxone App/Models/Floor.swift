//
//  Floor.swift
//  Loxone App
//
//  SwiftData model for floor groups that organize rooms
//

import Foundation
import SwiftData

@Model
final class Floor {
    var id: UUID
    var name: String
    var order: Int
    var icon: String
    var roomUUIDs: [String]
    
    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        icon: String,
        roomUUIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.icon = icon
        self.roomUUIDs = roomUUIDs
    }
    
    /// Check if this floor contains a specific room
    func containsRoom(_ roomUUID: String) -> Bool {
        roomUUIDs.contains(roomUUID)
    }
    
    /// Add a room to this floor
    func addRoom(_ roomUUID: String) {
        if !roomUUIDs.contains(roomUUID) {
            roomUUIDs.append(roomUUID)
        }
    }
    
    /// Remove a room from this floor
    func removeRoom(_ roomUUID: String) {
        roomUUIDs.removeAll { $0 == roomUUID }
    }
}

// MARK: - Default Floors

extension Floor {
    /// Create default floor groups
    static func createDefaultFloors() -> [Floor] {
        [
            Floor(name: "Ground Floor", order: 0, icon: "house"),
            Floor(name: "First Floor", order: 1, icon: "stairs"),
            Floor(name: "Basement", order: 2, icon: "square.stack.3d.down.right"),
            Floor(name: "Outside", order: 3, icon: "leaf"),
            Floor(name: "Unassigned", order: 999, icon: "questionmark.folder")
        ]
    }
    
    /// Check if this is the unassigned floor
    var isUnassigned: Bool {
        order == 999
    }
}

