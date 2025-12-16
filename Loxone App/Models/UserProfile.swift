//
//  UserProfile.swift
//  Loxone App
//
//  SwiftData model for user profiles with expert/normal mode support
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var loxoneUsername: String
    var isExpertMode: Bool
    var useBiometrics: Bool
    var createdAt: Date
    var lastUsedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        loxoneUsername: String,
        isExpertMode: Bool = false,
        useBiometrics: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.loxoneUsername = loxoneUsername
        self.isExpertMode = isExpertMode
        self.useBiometrics = useBiometrics
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
    
    /// Update the last used timestamp
    func markAsUsed() {
        self.lastUsedAt = Date()
    }
}

// MARK: - Convenience Extensions

extension UserProfile {
    /// Display name with mode indicator
    var displayNameWithMode: String {
        isExpertMode ? "\(name) (Expert)" : name
    }
    
    /// Icon name based on mode
    var modeIcon: String {
        isExpertMode ? "wrench.and.screwdriver" : "person"
    }
}

