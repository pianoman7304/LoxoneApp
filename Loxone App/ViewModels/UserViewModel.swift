//
//  UserViewModel.swift
//  Loxone App
//
//  View model for user profile management
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class UserViewModel: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Server configuration
    @Published var localServerAddress: String = ""
    @Published var remoteServerAddress: String = ""
    
    private let userManager = UserManager.shared
    private let keychainManager = KeychainManager.shared
    private var modelContext: ModelContext?
    
    init() {
        loadServerAddresses()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        userManager.setModelContext(context)
        loadUsers()
    }
    
    // MARK: - Load
    
    func loadUsers() {
        users = userManager.getAllUsers()
        currentUser = userManager.currentUser
        isAuthenticated = userManager.isAuthenticated
    }
    
    func loadServerAddresses() {
        let addresses = userManager.getServerAddresses()
        localServerAddress = addresses.local ?? ""
        remoteServerAddress = addresses.remote ?? ""
    }
    
    // MARK: - User CRUD
    
    func createUser(
        name: String,
        loxoneUsername: String,
        password: String,
        isExpertMode: Bool = false,
        useBiometrics: Bool = false
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try userManager.createUser(
                name: name,
                loxoneUsername: loxoneUsername,
                password: password,
                isExpertMode: isExpertMode,
                useBiometrics: useBiometrics
            )
            loadUsers()
            isLoading = false
            return true
        } catch {
            showError(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    func updateUser(
        _ user: UserProfile,
        name: String? = nil,
        loxoneUsername: String? = nil,
        password: String? = nil,
        isExpertMode: Bool? = nil,
        useBiometrics: Bool? = nil
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try userManager.updateUser(
                user,
                name: name,
                loxoneUsername: loxoneUsername,
                password: password,
                isExpertMode: isExpertMode,
                useBiometrics: useBiometrics
            )
            loadUsers()
            isLoading = false
            return true
        } catch {
            showError(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    func deleteUser(_ user: UserProfile) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try userManager.deleteUser(user)
            loadUsers()
            isLoading = false
            return true
        } catch {
            showError(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Authentication
    
    func login(user: UserProfile) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await userManager.login(user: user)
            loadUsers()
            isLoading = false
            return true
        } catch {
            showError(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    func logout() {
        userManager.logout()
        loadUsers()
    }
    
    func switchUser(to user: UserProfile) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await userManager.switchUser(to: user)
            loadUsers()
            isLoading = false
            return true
        } catch {
            showError(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Server Configuration
    
    func saveServerAddresses() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try userManager.saveServerAddresses(
                local: localServerAddress.isEmpty ? nil : localServerAddress,
                remote: remoteServerAddress.isEmpty ? nil : remoteServerAddress
            )
            isLoading = false
            return true
        } catch {
            showError(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Validation
    
    var hasServerConfigured: Bool {
        !localServerAddress.isEmpty || !remoteServerAddress.isEmpty
    }
    
    var canCreateUser: Bool {
        hasServerConfigured
    }
    
    func validateUserInput(name: String, username: String, password: String) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Please enter a display name"
        }
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Please enter a Loxone username"
        }
        if password.isEmpty {
            return "Please enter a password"
        }
        return nil
    }
    
    // MARK: - Biometrics
    
    var biometricsAvailable: Bool {
        keychainManager.biometricsAvailable()
    }
    
    var biometricType: String {
        keychainManager.biometricType()
    }
    
    // MARK: - Auto-Login
    
    func getLastSelectedUser() -> UserProfile? {
        userManager.getLastSelectedUser()
    }
    
    func shouldAutoLogin() -> Bool {
        userManager.shouldAutoLogin()
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

