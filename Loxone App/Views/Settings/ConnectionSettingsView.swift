//
//  ConnectionSettingsView.swift
//  Loxone App
//
//  Server connection configuration
//

import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var userViewModel: UserViewModel
    
    @State private var localAddress: String = ""
    @State private var remoteAddress: String = ""
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    
    var body: some View {
        Form {
            // Local connection
            Section {
                TextField("Local Server Address", text: $localAddress)
                    .textContentType(.URL)
                    .disableAutocapitalization()
                    .urlKeyboardType()
            } header: {
                Text("Local Connection")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used when connected to your home network.")
                    Text("Example: 192.168.1.100 or loxone.local")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Remote connection
            Section {
                TextField("Remote Server Address", text: $remoteAddress)
                    .textContentType(.URL)
                    .disableAutocapitalization()
                    .urlKeyboardType()
            } header: {
                Text("Remote Connection")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used when away from home.")
                    Text("Example: dns.loxonecloud.com/504F94D0DAAD")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Auto-switching info
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Switching")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("The app automatically switches between local and remote based on your network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Current status
            Section {
                HStack {
                    Text("Network")
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: NetworkMonitor.shared.status.icon)
                        Text(NetworkMonitor.shared.status.description)
                    }
                    .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Connection Mode")
                    Spacer()
                    Text(NetworkMonitor.shared.localServerReachable ? "Local" : "Remote")
                        .foregroundStyle(.secondary)
                }
                
                if NetworkMonitor.shared.localServerReachable {
                    HStack {
                        Text("Local Server")
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Reachable")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Status")
            }
            
            // Save button
            Section {
                Button {
                    saveSettings()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Changes")
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving || !hasChanges)
            }
        }
        .navigationTitle("Connection")
        .inlineNavigationBarTitle()
        .onAppear {
            localAddress = userViewModel.localServerAddress
            remoteAddress = userViewModel.remoteServerAddress
        }
        .alert("Settings Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your connection settings have been saved.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasChanges: Bool {
        localAddress != userViewModel.localServerAddress ||
        remoteAddress != userViewModel.remoteServerAddress
    }
    
    // MARK: - Actions
    
    private func saveSettings() {
        isSaving = true
        
        userViewModel.localServerAddress = localAddress.trimmingCharacters(in: .whitespaces)
        userViewModel.remoteServerAddress = remoteAddress.trimmingCharacters(in: .whitespaces)
        
        Task {
            let success = await userViewModel.saveServerAddresses()
            isSaving = false
            
            if success {
                showSaveConfirmation = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionSettingsView(userViewModel: UserViewModel())
    }
}

