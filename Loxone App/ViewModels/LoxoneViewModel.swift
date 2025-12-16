//
//  LoxoneViewModel.swift
//  Loxone App
//
//  Main view model for app state management
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class LoxoneViewModel: ObservableObject {
    // Services
    let loxoneService = LoxoneService.shared
    let userManager = UserManager.shared
    let networkMonitor = NetworkMonitor.shared
    let notificationService = NotificationService.shared
    
    // State
    @Published var selectedFloor: Floor?
    @Published var selectedRoom: LoxoneRoom?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Floor management
    @Published var floors: [Floor] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        userManager.setModelContext(context)
        loadFloors()
    }
    
    private func setupBindings() {
        // Monitor connection state changes
        // Note: We don't show errors here because WebSocket failures
        // are non-critical if HTTP fetches succeed
        loxoneService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .error(let message) = state {
                    // Only log, don't show error dialog
                    // The structure might still have loaded via HTTP
                    print("⚠️ [LoxoneViewModel] Connection state error (non-critical): \(message)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Connection
    
    func connect() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await loxoneService.connect()
        } catch {
            showError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func disconnect() {
        loxoneService.disconnect()
    }
    
    func refresh() async {
        isLoading = true
        
        do {
            try await loxoneService.fetchStructure()
        } catch {
            showError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Room Selection
    
    func selectRoom(_ room: LoxoneRoom?) {
        selectedRoom = room
        if let roomUUID = room?.uuid {
            loxoneService.setCurrentRoom(roomUUID)
        }
    }
    
    // MARK: - Floor Management
    
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
    
    private func createDefaultFloors() {
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
        
        let maxOrder = floors.filter { !$0.isUnassigned }.map(\.order).max() ?? -1
        let floor = Floor(name: name, order: maxOrder + 1, icon: icon)
        context.insert(floor)
        
        try? context.save()
        loadFloors()
    }
    
    func updateFloor(_ floor: Floor, name: String, icon: String) {
        floor.name = name
        floor.icon = icon
        try? modelContext?.save()
        loadFloors()
    }
    
    func deleteFloor(_ floor: Floor) {
        guard !floor.isUnassigned else { return } // Can't delete unassigned
        
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
    
    func assignRoom(_ roomUUID: String, to floor: Floor) {
        // Remove from other floors first (exclusive assignment)
        for f in floors {
            f.removeRoom(roomUUID)
        }
        
        // Add to new floor
        floor.addRoom(roomUUID)
        try? modelContext?.save()
    }
    
    /// Add room to a floor without removing from others (allows multiple floor membership)
    func addRoomToFloor(_ roomUUID: String, floor: Floor) {
        floor.addRoom(roomUUID)
        try? modelContext?.save()
        loadFloors()
    }
    
    /// Remove room from a specific floor
    func removeRoomFromFloor(_ roomUUID: String, floor: Floor) {
        floor.removeRoom(roomUUID)
        try? modelContext?.save()
        loadFloors()
    }
    
    /// Get all floors that contain a room
    func getFloors(for roomUUID: String) -> [Floor] {
        floors.filter { $0.containsRoom(roomUUID) && !$0.isUnassigned }
    }
    
    func moveFloor(_ floor: Floor, to newOrder: Int) {
        guard !floor.isUnassigned else { return }
        
        var editableFloors = floors.filter { !$0.isUnassigned }
        editableFloors.removeAll { $0.id == floor.id }
        editableFloors.insert(floor, at: min(newOrder, editableFloors.count))
        
        for (index, f) in editableFloors.enumerated() {
            f.order = index
        }
        
        try? modelContext?.save()
        loadFloors()
    }
    
    /// Save floor order after reordering
    func saveFloorOrder() {
        try? modelContext?.save()
        loadFloors()
    }
    
    // MARK: - Room Helpers
    
    func getRooms(for floor: Floor) -> [LoxoneRoom] {
        let allRooms = loxoneService.getRooms()
        
        if floor.isUnassigned {
            // Return rooms not in any other floor
            let assignedRooms = Set(floors.filter { !$0.isUnassigned }.flatMap { $0.roomUUIDs })
            return allRooms.filter { !assignedRooms.contains($0.uuid) }
        }
        
        return allRooms.filter { floor.containsRoom($0.uuid) }
    }
    
    func getFloor(for room: LoxoneRoom) -> Floor? {
        floors.first { $0.containsRoom(room.uuid) }
    }
    
    // MARK: - Device Control
    
    func toggleSwitch(_ uuid: String) async {
        do {
            try await loxoneService.toggleSwitch(uuid)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func setDimmerValue(_ uuid: String, value: Int) async {
        do {
            try await loxoneService.setDimmerValue(uuid, value: value)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func sendJalousieCommand(_ uuid: String, command: JalousieCommand) async {
        do {
            try await loxoneService.sendJalousieCommand(uuid, command: command)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func sendCommand(_ uuid: String, command: String) async {
        do {
            try await loxoneService.sendCommand(uuid, command: command)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Error Handling
    
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
}

