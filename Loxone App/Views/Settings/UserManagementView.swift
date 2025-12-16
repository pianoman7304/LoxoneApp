//
//  UserManagementView.swift
//  Loxone App
//
//  Manage user profiles
//

import SwiftUI

struct UserManagementView: View {
    @ObservedObject var userViewModel: UserViewModel
    
    @State private var showingAddUser = false
    @State private var userToEdit: UserProfile?
    @State private var userToDelete: UserProfile?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        List {
            Section {
                ForEach(userViewModel.users) { user in
                    UserManagementRow(
                        user: user,
                        isCurrentUser: user.id == userViewModel.currentUser?.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        userToEdit = user
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if user.id != userViewModel.currentUser?.id {
                            Button(role: .destructive) {
                                userToDelete = user
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        Button {
                            userToEdit = user
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("Tap a profile to edit. Swipe left for more options.")
            }
            
            Section {
                Button {
                    showingAddUser = true
                } label: {
                    Label("Add Profile", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Manage Profiles")
        .inlineNavigationBarTitle()
        .sheet(isPresented: $showingAddUser) {
            AddUserSheet(userViewModel: userViewModel)
        }
        .sheet(item: $userToEdit) { user in
            UserProfileEditView(user: user, userViewModel: userViewModel)
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                userToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let user = userToDelete {
                    deleteUser(user)
                }
            }
        } message: {
            if let user = userToDelete {
                Text("Are you sure you want to delete \"\(user.name)\"? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteUser(_ user: UserProfile) {
        Task {
            _ = await userViewModel.deleteUser(user)
        }
        userToDelete = nil
    }
}

// MARK: - User Management Row

struct UserManagementRow: View {
    let user: UserProfile
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(user.isExpertMode ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: user.modeIcon)
                    .font(.title3)
                    .foregroundStyle(user.isExpertMode ? .orange : .blue)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("Current")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    Text(user.loxoneUsername)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if user.isExpertMode {
                        Text("Expert")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Indicators
            HStack(spacing: 8) {
                if user.useBiometrics {
                    Image(systemName: "faceid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        UserManagementView(userViewModel: UserViewModel())
    }
}

