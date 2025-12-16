//
//  SettingsView.swift
//  Loxone App
//
//  Main settings view
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var userViewModel: UserViewModel
    @ObservedObject var viewModel: LoxoneViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Current user section
                if let currentUser = userViewModel.currentUser {
                    Section {
                        currentUserRow(currentUser)
                    } header: {
                        Text("Current Profile")
                    }
                }
                
                // User management
                Section {
                    NavigationLink {
                        UserManagementView(userViewModel: userViewModel)
                    } label: {
                        Label("Manage Profiles", systemImage: "person.2")
                    }
                    
                    Button(role: .destructive) {
                        userViewModel.logout()
                        dismiss()
                    } label: {
                        Label("Switch Profile", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Profiles")
                }
                
                // Connection settings
                Section {
                    NavigationLink {
                        ConnectionSettingsView(userViewModel: userViewModel)
                    } label: {
                        Label("Server Connection", systemImage: "server.rack")
                    }
                    
                    // Connection status
                    HStack {
                        Label("Status", systemImage: viewModel.loxoneService.connectionState.icon)
                        Spacer()
                        Text(viewModel.loxoneService.connectionState.description)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Network status
                    HStack {
                        Label("Network", systemImage: viewModel.networkMonitor.status.icon)
                        Spacer()
                        Text(viewModel.networkMonitor.status.description)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Connection")
                }
                
                // Floor management
                Section {
                    NavigationLink {
                        FloorManagementView(viewModel: viewModel)
                    } label: {
                        Label("Manage Floors", systemImage: "building.2")
                    }
                } header: {
                    Text("Organization")
                }
                
                // Notifications
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                } header: {
                    Text("Alerts")
                }
                
                // Expert mode (placeholder for Phase 2)
                if userViewModel.currentUser?.isExpertMode == true {
                    Section {
                        NavigationLink {
                            ExpertMenuView()
                        } label: {
                            Label("Expert Configuration", systemImage: "wrench.and.screwdriver")
                        }
                    } header: {
                        Text("Expert Mode")
                    } footer: {
                        Text("Advanced Loxone configuration options")
                    }
                }
                
                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let serverName = viewModel.loxoneService.miniserverName {
                        HStack {
                            Text("Miniserver")
                            Spacer()
                            Text(serverName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Current User Row
    
    private func currentUserRow(_ user: UserProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(user.isExpertMode ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: user.modeIcon)
                    .font(.title2)
                    .foregroundStyle(user.isExpertMode ? .orange : .blue)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(user.loxoneUsername)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if user.isExpertMode {
                        Text("Expert")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            if user.useBiometrics {
                Image(systemName: "faceid")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView(
        userViewModel: UserViewModel(),
        viewModel: LoxoneViewModel()
    )
}

