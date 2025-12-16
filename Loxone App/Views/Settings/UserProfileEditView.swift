//
//  UserProfileEditView.swift
//  Loxone App
//
//  Edit an existing user profile
//

import SwiftUI

struct UserProfileEditView: View {
    let user: UserProfile
    @ObservedObject var userViewModel: UserViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var loxoneUsername: String = ""
    @State private var password: String = ""
    @State private var isExpertMode: Bool = false
    @State private var useBiometrics: Bool = false
    @State private var showPassword: Bool = false
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile section
                Section("Profile") {
                    TextField("Display Name", text: $name)
                        .textContentType(.name)
                    
                    Toggle("Expert Mode", isOn: $isExpertMode)
                }
                
                // Credentials section
                Section("Loxone Credentials") {
                    TextField("Username", text: $loxoneUsername)
                        .textContentType(.username)
                        .disableAutocapitalization()
                    
                    HStack {
                        if showPassword {
                            TextField("New Password (leave empty to keep)", text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField("New Password (leave empty to keep)", text: $password)
                                .textContentType(.password)
                        }
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Security section
                if userViewModel.biometricsAvailable {
                    Section("Security") {
                        Toggle("Use \(userViewModel.biometricType)", isOn: $useBiometrics)
                    }
                }
                
                // Info section
                Section {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(user.createdAt.dateTimeString)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Last Used")
                        Spacer()
                        Text(user.lastUsedAt.relativeString)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Expert mode info
                if isExpertMode {
                    Section {
                        Label {
                            Text("Expert mode allows advanced Loxone configuration (coming soon)")
                        } icon: {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                loadUserData()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !loxoneUsername.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Actions
    
    private func loadUserData() {
        name = user.name
        loxoneUsername = user.loxoneUsername
        isExpertMode = user.isExpertMode
        useBiometrics = user.useBiometrics
        password = ""
    }
    
    private func saveChanges() {
        isSaving = true
        
        Task {
            let success = await userViewModel.updateUser(
                user,
                name: name.trimmingCharacters(in: .whitespaces),
                loxoneUsername: loxoneUsername.trimmingCharacters(in: .whitespaces),
                password: password.isEmpty ? nil : password,
                isExpertMode: isExpertMode,
                useBiometrics: useBiometrics
            )
            
            isSaving = false
            
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    UserProfileEditView(
        user: UserProfile(
            name: "John",
            loxoneUsername: "admin",
            isExpertMode: false,
            useBiometrics: true
        ),
        userViewModel: UserViewModel()
    )
}

