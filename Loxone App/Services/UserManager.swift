//
//  UserManager.swift
//  Loxone App
//
//  Manages user profiles and authentication
//

import Foundation
import SwiftData
import Combine

// MARK: - User Manager

@MainActor
final class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isAuthenticated: Bool = false
    @Published var showUserSelector: Bool = true
    
    private let keychainManager = KeychainManager.shared
    private let loxoneService = LoxoneService.shared
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    // MARK: - Setup
    
    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Check if we have any users, create defaults if not
        setupDefaultUsersIfNeeded()
    }
    
    // MARK: - User Operations
    
    /// Get all user profiles
    func getAllUsers() -> [UserProfile] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Create a new user profile
    func createUser(
        name: String,
        loxoneUsername: String,
        password: String,
        isExpertMode: Bool = false,
        useBiometrics: Bool = false
    ) throws -> UserProfile {
        print("👤 [UserManager] Creating user: \(name), loxoneUsername: \(loxoneUsername), passwordLength: \(password.count)")
        
        guard let context = modelContext else {
            print("👤 [UserManager] ❌ Context not available!")
            throw UserManagerError.contextNotAvailable
        }
        
        let user = UserProfile(
            name: name,
            loxoneUsername: loxoneUsername,
            isExpertMode: isExpertMode,
            useBiometrics: useBiometrics
        )
        
        print("👤 [UserManager] User created with ID: \(user.id)")
        
        context.insert(user)
        try context.save()
        print("👤 [UserManager] ✅ User saved to database")
        
        // Save password to keychain (no biometrics required)
        print("👤 [UserManager] Saving password to keychain for user ID: \(user.id)")
        try keychainManager.saveUserPassword(password, for: user.id, requireBiometrics: false)
        print("👤 [UserManager] ✅ Password saved to keychain")
        
        return user
    }
    
    /// Update an existing user profile
    func updateUser(
        _ user: UserProfile,
        name: String? = nil,
        loxoneUsername: String? = nil,
        password: String? = nil,
        isExpertMode: Bool? = nil,
        useBiometrics: Bool? = nil
    ) throws {
        guard let context = modelContext else {
            throw UserManagerError.contextNotAvailable
        }
        
        if let name = name {
            user.name = name
        }
        if let loxoneUsername = loxoneUsername {
            user.loxoneUsername = loxoneUsername
        }
        if let isExpertMode = isExpertMode {
            user.isExpertMode = isExpertMode
        }
        if let useBiometrics = useBiometrics {
            user.useBiometrics = useBiometrics
        }
        
        try context.save()
        
        // Update password if provided
        if let password = password {
            try keychainManager.saveUserPassword(
                password,
                for: user.id,
                requireBiometrics: false
            )
        }
        
        // Update current user if this is them
        if currentUser?.id == user.id {
            currentUser = user
        }
    }
    
    /// Delete a user profile
    func deleteUser(_ user: UserProfile) throws {
        guard let context = modelContext else {
            throw UserManagerError.contextNotAvailable
        }
        
        // Delete password from keychain
        try? keychainManager.deleteUserPassword(for: user.id)
        
        // Delete user
        context.delete(user)
        try context.save()
        
        // If deleting current user, logout
        if currentUser?.id == user.id {
            logout()
        }
    }
    
    // MARK: - Authentication
    
    /// Login with a user profile
    func login(user: UserProfile) async throws {
        print("👤 [UserManager] Login attempt for user: \(user.name), ID: \(user.id)")
        
        // Load password from keychain
        print("👤 [UserManager] Loading password from keychain for user ID: \(user.id)")
        let password: String
        do {
            password = try keychainManager.loadUserPassword(for: user.id)
            print("👤 [UserManager] ✅ Password loaded, length: \(password.count)")
        } catch {
            print("👤 [UserManager] ❌ Failed to load password: \(error)")
            throw error
        }
        
        // Load server addresses
        let localAddress = keychainManager.loadLocalServerAddress()
        let remoteAddress = keychainManager.loadRemoteServerAddress()
        print("👤 [UserManager] Server addresses - local: \(localAddress ?? "nil"), remote: \(remoteAddress ?? "nil")")
        
        guard localAddress != nil || remoteAddress != nil else {
            print("👤 [UserManager] ❌ No server configured")
            throw UserManagerError.serverNotConfigured
        }
        
        // Configure Loxone service
        print("👤 [UserManager] Configuring LoxoneService with username: \(user.loxoneUsername)")
        loxoneService.configure(
            localAddress: localAddress,
            remoteAddress: remoteAddress,
            username: user.loxoneUsername,
            password: password
        )
        
        // Connect to Loxone
        print("👤 [UserManager] Connecting to Loxone...")
        do {
            try await loxoneService.connect()
            print("👤 [UserManager] ✅ Connected to Loxone")
        } catch {
            print("👤 [UserManager] ❌ Connection failed: \(error.localizedDescription)")
            throw error
        }
        
        // Update user's last used timestamp
        user.markAsUsed()
        try? modelContext?.save()
        
        // Save as last selected user
        UserDefaults.standard.set(user.id.uuidString, forKey: UserDefaultsKeys.lastSelectedUserProfileId)
        
        currentUser = user
        isAuthenticated = true
        showUserSelector = false
        print("👤 [UserManager] ✅ Login complete!")
    }
    
    /// Logout current user
    func logout() {
        loxoneService.disconnect()
        currentUser = nil
        isAuthenticated = false
        showUserSelector = true
    }
    
    /// Switch to a different user
    func switchUser(to user: UserProfile) async throws {
        logout()
        try await login(user: user)
    }
    
    /// Login with a user profile (legacy signature for compatibility)
    func login(user: UserProfile, skipBiometrics: Bool) async throws {
        try await login(user: user)
    }
    
    // MARK: - Last Selected User
    
    /// Get the last selected user
    func getLastSelectedUser() -> UserProfile? {
        guard let uuidString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastSelectedUserProfileId),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        
        return getAllUsers().first { $0.id == uuid }
    }
    
    /// Check if we should show auto-login for last user
    func shouldAutoLogin() -> Bool {
        guard let lastUser = getLastSelectedUser() else { return false }
        // Auto-login if user has biometrics enabled (they'll still need to authenticate)
        return lastUser.useBiometrics
    }
    
    // MARK: - Server Configuration
    
    /// Save server addresses
    func saveServerAddresses(local: String?, remote: String?) throws {
        if let local = local, !local.isEmpty {
            try keychainManager.saveLocalServerAddress(local)
        }
        if let remote = remote, !remote.isEmpty {
            try keychainManager.saveRemoteServerAddress(remote)
        }
    }
    
    /// Get server addresses
    func getServerAddresses() -> (local: String?, remote: String?) {
        (
            keychainManager.loadLocalServerAddress(),
            keychainManager.loadRemoteServerAddress()
        )
    }
    
    // MARK: - Default Users Setup
    
    private func setupDefaultUsersIfNeeded() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<UserProfile>()
        let existingUsers = (try? context.fetch(descriptor)) ?? []
        
        // If no users exist, the user will create them through settings
        // We don't pre-create users since we need credentials
        
        if existingUsers.isEmpty {
            // Just show the user selector which will prompt for setup
            showUserSelector = true
        }
    }
}

// MARK: - User Manager Error

enum UserManagerError: Error, LocalizedError {
    case contextNotAvailable
    case userNotFound
    case biometricsFailed
    case serverNotConfigured
    case passwordNotFound
    
    var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "Database not available"
        case .userNotFound:
            return "User not found"
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .serverNotConfigured:
            return "Server not configured. Please add a server address in settings."
        case .passwordNotFound:
            return "Password not found for this user"
        }
    }
}

