//
//  KeychainManager.swift
//  Loxone App
//
//  Secure credential storage using iOS/macOS Keychain
//

import Foundation
import Security
import LocalAuthentication
import Combine

// MARK: - Keychain Error

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidItemFormat
    case unexpectedStatus(OSStatus)
    case biometricsFailed
    case biometricsNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .invalidItemFormat:
            return "Invalid data format"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .biometricsNotAvailable:
            return "Biometric authentication not available"
        }
    }
}

// MARK: - Keychain Manager

@MainActor
final class KeychainManager: ObservableObject {
    static let shared = KeychainManager()
    
    private let service = AppConstants.keychainService
    
    private init() {}
    
    // MARK: - Basic Operations
    
    /// Save data to keychain
    func save(_ data: Data, for key: String, requireBiometrics: Bool = false) throws {
        print("🔐 [Keychain] Saving data for key: \(key), size: \(data.count) bytes, biometrics: \(requireBiometrics)")
        
        // Delete existing item first
        try? delete(key: key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Add biometric protection if requested
        if requireBiometrics {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            )
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("🔐 [Keychain] ❌ Save FAILED with status: \(status)")
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
        print("🔐 [Keychain] ✅ Save SUCCESS for key: \(key)")
    }
    
    /// Load data from keychain
    func load(key: String) throws -> Data {
        print("🔐 [Keychain] Loading data for key: \(key)")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            print("🔐 [Keychain] ❌ Load FAILED for key: \(key), status: \(status)")
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data else {
            print("🔐 [Keychain] ❌ Invalid data format for key: \(key)")
            throw KeychainError.invalidItemFormat
        }
        
        print("🔐 [Keychain] ✅ Load SUCCESS for key: \(key), size: \(data.count) bytes")
        return data
    }
    
    /// Delete item from keychain
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Check if item exists
    func exists(key: String) -> Bool {
        do {
            _ = try load(key: key)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - String Convenience Methods
    
    /// Save string to keychain
    func saveString(_ string: String, for key: String, requireBiometrics: Bool = false) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        try save(data, for: key, requireBiometrics: requireBiometrics)
    }
    
    /// Load string from keychain
    func loadString(key: String) throws -> String {
        let data = try load(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        return string
    }
    
    /// Load string or return nil if not found
    func loadStringOrNil(key: String) -> String? {
        try? loadString(key: key)
    }
    
    // MARK: - User Password Methods
    
    /// Save password for a user profile
    func saveUserPassword(_ password: String, for userId: UUID, requireBiometrics: Bool = false) throws {
        let key = KeychainKeys.userPassword(userId)
        try saveString(password, for: key, requireBiometrics: requireBiometrics)
    }
    
    /// Load password for a user profile
    func loadUserPassword(for userId: UUID) throws -> String {
        let key = KeychainKeys.userPassword(userId)
        return try loadString(key: key)
    }
    
    /// Delete password for a user profile
    func deleteUserPassword(for userId: UUID) throws {
        let key = KeychainKeys.userPassword(userId)
        try delete(key: key)
    }
    
    /// Check if user has saved password
    func hasUserPassword(for userId: UUID) -> Bool {
        let key = KeychainKeys.userPassword(userId)
        return exists(key: key)
    }
    
    // MARK: - Server Address Methods
    
    /// Save local server address
    func saveLocalServerAddress(_ address: String) throws {
        try saveString(address, for: KeychainKeys.localServerAddress)
    }
    
    /// Load local server address
    func loadLocalServerAddress() -> String? {
        loadStringOrNil(key: KeychainKeys.localServerAddress)
    }
    
    /// Save remote server address
    func saveRemoteServerAddress(_ address: String) throws {
        try saveString(address, for: KeychainKeys.remoteServerAddress)
    }
    
    /// Load remote server address
    func loadRemoteServerAddress() -> String? {
        loadStringOrNil(key: KeychainKeys.remoteServerAddress)
    }
    
    // MARK: - Biometric Authentication
    
    /// Check if biometrics are available
    func biometricsAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get biometric type description
    func biometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "None"
        }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }
    
    /// Authenticate with biometrics
    func authenticateWithBiometrics(reason: String = "Authenticate to access your Loxone account") async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw KeychainError.biometricsNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            throw KeychainError.biometricsFailed
        }
    }
    
    // MARK: - Clear All
    
    /// Clear all keychain items for this app
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

