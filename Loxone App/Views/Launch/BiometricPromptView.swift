//
//  BiometricPromptView.swift
//  Loxone App
//
//  Biometric authentication prompt (Face ID / Touch ID)
//

import SwiftUI
import LocalAuthentication

struct BiometricPromptView: View {
    let user: UserProfile
    let onSuccess: () -> Void
    let onCancel: () -> Void
    let onUsePassword: () -> Void
    
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var showError = false
    
    private let keychainManager = KeychainManager.shared
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            biometricIcon
            
            // User info
            VStack(spacing: 8) {
                Text("Welcome back,")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Text(user.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            // Instructions
            Text("Use \(keychainManager.biometricType()) to authenticate")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button {
                    authenticate()
                } label: {
                    Label("Authenticate", systemImage: biometricSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)
                
                HStack(spacing: 20) {
                    Button("Use Password") {
                        onUsePassword()
                    }
                    .foregroundStyle(.secondary)
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again") {
                authenticate()
            }
            Button("Use Password") {
                onUsePassword()
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        } message: {
            if let error = authError {
                Text(error)
            }
        }
        .onAppear {
            // Auto-trigger authentication on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticate()
            }
        }
    }
    
    // MARK: - Biometric Icon
    
    private var biometricIcon: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: biometricSystemImage)
                .font(.system(size: 50))
                .foregroundStyle(.green)
        }
    }
    
    private var biometricSystemImage: String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "lock.shield"
        }
        
        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.shield"
        @unknown default:
            return "lock.shield"
        }
    }
    
    // MARK: - Authentication
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        authError = nil
        
        Task {
            do {
                let success = try await keychainManager.authenticateWithBiometrics(
                    reason: "Authenticate to access \(user.name)'s Loxone account"
                )
                
                await MainActor.run {
                    isAuthenticating = false
                    
                    if success {
                        onSuccess()
                    } else {
                        authError = "Authentication was not successful"
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Standalone Biometric Auth Sheet

struct BiometricAuthSheet: View {
    let user: UserProfile
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    
    var body: some View {
        BiometricPromptView(
            user: user,
            onSuccess: {
                isPresented = false
                onSuccess()
            },
            onCancel: {
                isPresented = false
            },
            onUsePassword: {
                isPresented = false
                // Parent view should handle password fallback
            }
        )
    }
}

#Preview {
    BiometricPromptView(
        user: UserProfile(
            name: "John",
            loxoneUsername: "admin",
            isExpertMode: false,
            useBiometrics: true
        ),
        onSuccess: {},
        onCancel: {},
        onUsePassword: {}
    )
}

