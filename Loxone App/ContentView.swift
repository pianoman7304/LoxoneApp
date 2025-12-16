//
//  ContentView.swift
//  Loxone App
//
//  Root view with adaptive navigation for iOS, iPadOS, and macOS
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = LoxoneViewModel()
    @StateObject private var userViewModel = UserViewModel()
    
    @State private var selectedFloor: Floor?
    @State private var selectedRoom: LoxoneRoom?
    @State private var showAllRooms: Bool = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings = false
    
    var body: some View {
        Group {
            if userViewModel.isAuthenticated {
                mainNavigationView
            } else {
                UserSelectorView()
                    .environmentObject(userViewModel)
            }
        }
        .onAppear {
            print("📱 [ContentView] onAppear - setting model context")
            viewModel.setModelContext(modelContext)
            userViewModel.setModelContext(modelContext)
        }
        .onChange(of: userViewModel.isAuthenticated) { _, isAuth in
            print("📱 [ContentView] isAuthenticated changed to: \(isAuth)")
            if isAuth {
                // Reset selection state when authenticating
                showAllRooms = true
                selectedFloor = nil
                selectedRoom = nil
            }
        }
    }
    
    // MARK: - Main Navigation
    
    private var mainNavigationView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // First column: Floors
            FloorListView(
                selectedFloor: $selectedFloor,
                showAllRooms: $showAllRooms,
                viewModel: viewModel
            )
            .navigationTitle("Floors")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        Divider()
                        
                        Button {
                            Task {
                                await viewModel.refresh()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            userViewModel.logout()
                        } label: {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        } content: {
            // Second column: Rooms
            RoomListView(
                floor: selectedFloor,
                showAllRooms: showAllRooms,
                selectedRoom: $selectedRoom,
                viewModel: viewModel
            )
            .navigationTitle(showAllRooms ? "All Rooms" : (selectedFloor?.name ?? "Rooms"))
        } detail: {
            // Third column: Devices
            if let room = selectedRoom {
                DeviceGridView(room: room, viewModel: viewModel)
                    .navigationTitle(room.name)
            } else {
                ContentUnavailableView(
                    "Select a Room",
                    systemImage: "square.grid.2x2",
                    description: Text("Choose a room to view its devices")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) {
            SettingsView(userViewModel: userViewModel, viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .overlay {
            // Connection status indicator
            connectionStatusOverlay
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                ConnectionStatusBadge(
                    state: viewModel.loxoneService.connectionState,
                    networkStatus: viewModel.networkMonitor.status
                )
                .padding()
            }
        }
    }
}

// MARK: - Connection Status Badge

struct ConnectionStatusBadge: View {
    let state: LoxoneConnectionState
    let networkStatus: NetworkStatus
    
    @State private var isExpanded = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.description)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(networkStatus.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, isExpanded ? 12 : 8)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, Floor.self])
}
