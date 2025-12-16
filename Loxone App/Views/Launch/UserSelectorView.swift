//
//  UserSelectorView.swift
//  Loxone App
//
//  User profile selection screen shown at app launch
//  Adaptive design: Full-screen on iPhone, centered on iPad/Mac
//

import SwiftUI
import SwiftData

struct UserSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var showingAddUser = false
    @State private var showingServerSettings = false
    @State private var isAuthenticating = false
    @State private var userToDelete: UserProfile?
    @State private var showDeleteConfirmation = false
    @State private var userToEdit: UserProfile?
    
    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    var body: some View {
        Group {
            if isCompact {
                // iPhone: Full-screen native design
                iPhoneLayout
            } else {
                // iPad/Mac: Centered design
                desktopLayout
            }
        }
        .onAppear {
            userViewModel.setModelContext(modelContext)
        }
        .sheet(isPresented: $showingAddUser) {
            AddUserSheet(userViewModel: userViewModel)
        }
        .sheet(isPresented: $showingServerSettings) {
            ServerSettingsSheet(userViewModel: userViewModel)
        }
        .sheet(item: $userToEdit) { user in
            EditUserSheet(user: user, userViewModel: userViewModel)
        }
        .alert("Error", isPresented: $userViewModel.showError) {
            Button("OK", role: .cancel) {
                userViewModel.clearError()
            }
        } message: {
            if let error = userViewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
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
        .overlay {
            if isAuthenticating {
                authenticationOverlay
            }
        }
    }
    
    // MARK: - iPhone Layout (Full Screen)
    
    @ViewBuilder
    private var iPhoneLayout: some View {
        #if os(iOS)
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    iPhoneHeader
                        .padding(.top, 20)
                    
                    // Content
                    if userViewModel.users.isEmpty {
                        emptyStateContent
                    } else {
                        userListContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingServerSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        #else
        // This code path won't be reached on macOS but needed for compilation
        EmptyView()
        #endif
    }
    
    private var iPhoneHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            
            Text("Loxone Home")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Choose your profile")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Desktop/iPad Layout (Centered)
    
    private var desktopLayout: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.1, blue: 0.14),
                    Color(red: 0.04, green: 0.05, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Settings button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingServerSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(10)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                Spacer()
            }
            
            // Main content
            VStack(spacing: 32) {
                // Header
                desktopHeader
                
                // Content area with scroll
                ScrollView {
                    VStack(spacing: 16) {
                        if userViewModel.users.isEmpty {
                            emptyStateContent
                        } else {
                            userListContent
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 400)
                
                // Footer
                footerView
            }
            .padding(40)
            .frame(width: 420)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            )
        }
    }
    
    private var desktopHeader: some View {
        VStack(spacing: 16) {
            // Logo with subtle glow
            ZStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .blur(radius: 15)
                    .opacity(0.4)
                
                Image(systemName: "house.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 6) {
                Text("Loxone Home")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Choose your profile")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Shared Content
    
    private var emptyStateContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(isCompact ? Color.secondary : Color.white.opacity(0.4))
            
            VStack(spacing: 6) {
                Text("No Profiles Yet")
                    .font(.headline)
                    .foregroundStyle(isCompact ? Color.primary : Color.white)
                
                Text("Create a profile to start controlling your Loxone smart home.")
                    .font(.callout)
                    .foregroundStyle(isCompact ? Color.secondary : Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            if !userViewModel.hasServerConfigured {
                VStack(spacing: 12) {
                    Label("Server not configured", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    
                    Button {
                        showingServerSettings = true
                    } label: {
                        Label("Configure Server", systemImage: "server.rack")
                            .frame(maxWidth: isCompact ? .infinity : 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            } else {
                Button {
                    showingAddUser = true
                } label: {
                    Label("Create Profile", systemImage: "plus")
                        .frame(maxWidth: isCompact ? .infinity : 200)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.vertical, 30)
    }
    
    private var userListContent: some View {
        VStack(spacing: 10) {
            ForEach(userViewModel.users) { user in
                ProfileRow(
                    user: user,
                    isCompact: isCompact,
                    onSelect: { selectUser(user) },
                    onEdit: { userToEdit = user },
                    onDelete: { confirmDelete(user) }
                )
            }
            
            // Add profile button
            Button {
                showingAddUser = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isCompact ? .green : .white.opacity(0.5))
                    
                    Text("Add Profile")
                        .font(.body)
                        .foregroundStyle(isCompact ? Color.primary : Color.white.opacity(0.6))
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var footerView: some View {
        HStack(spacing: 6) {
            Image(systemName: NetworkMonitor.shared.status.icon)
            Text(NetworkMonitor.shared.status.description)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.4))
    }
    
    // MARK: - Authentication Overlay
    
    private var authenticationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(isCompact ? Color.primary : Color.white)
                
                Text("Connecting...")
                    .font(.headline)
                    .foregroundStyle(isCompact ? Color.primary : Color.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Actions
    
    private func selectUser(_ user: UserProfile) {
        // Prevent multiple simultaneous login attempts
        guard !isAuthenticating else {
            print("⚠️ [UserSelector] Login already in progress, ignoring")
            return
        }
        
        print("🔑 [UserSelector] Starting login for: \(user.name)")
        isAuthenticating = true
        
        Task {
            let success = await userViewModel.login(user: user)
            print("🔑 [UserSelector] Login completed, success: \(success)")
            await MainActor.run {
                isAuthenticating = false
            }
        }
    }
    
    private func confirmDelete(_ user: UserProfile) {
        userToDelete = user
        showDeleteConfirmation = true
    }
    
    private func deleteUser(_ user: UserProfile) {
        Task {
            _ = await userViewModel.deleteUser(user)
            userToDelete = nil
        }
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let user: UserProfile
    let isCompact: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main button area
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: user.isExpertMode
                                        ? [.orange, .orange.opacity(0.7)]
                                        : [.green, .green.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: user.modeIcon)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(user.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(isCompact ? Color.primary : Color.white)
                            
                            if user.isExpertMode {
                                Text("Expert")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(user.loxoneUsername)
                            .font(.subheadline)
                            .foregroundStyle(isCompact ? Color.secondary : Color.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isCompact ? Color.gray : Color.white.opacity(0.3))
                }
                .padding(.vertical, 12)
                .padding(.leading, 12)
                .padding(.trailing, 4)
            }
            .buttonStyle(.plain)
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(isCompact ? Color.secondary : Color.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompact
                    ? Color.systemBackground
                    : Color.white.opacity(isHovered ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCompact ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: isCompact ? .black.opacity(0.05) : .clear, radius: 2, y: 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var biometricIcon: String {
        #if os(macOS)
        return "touchid"
        #else
        return "faceid"
        #endif
    }
}

// MARK: - Add User Sheet

struct AddUserSheet: View {
    @ObservedObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var loxoneUsername = ""
    @State private var password = ""
    @State private var isExpertMode = false
    @State private var showPassword = false
    @State private var isCreating = false
    
    private let fieldWidth: CGFloat = 220
    private let labelWidth: CGFloat = 100
    
    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }
    
    // MARK: - macOS Layout
    
    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 0) {
            // Title
            Text("New Profile")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 24)
            
            // Form content
            VStack(alignment: .leading, spacing: 20) {
                // Profile Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    formRow(label: "Display Name") {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                    }
                    
                    formRow(label: "Expert Mode") {
                        Toggle("", isOn: $isExpertMode)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Credentials Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Loxone Credentials")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    formRow(label: "Username") {
                        TextField("", text: $loxoneUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                    }
                    
                    formRow(label: "Password") {
                        HStack(spacing: 8) {
                            if showPassword {
                                TextField("", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth - 32)
                            } else {
                                SecureField("", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth - 32)
                            }
                            
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Expert mode note
                if isExpertMode {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundStyle(.orange)
                        Text("Expert mode allows advanced configuration (coming soon)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Divider()
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isCreating)
                
                Button("Create") {
                    createUser()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isCreating)
            }
            .padding(16)
        }
        .frame(width: 400, height: 480)
        .onAppear {
            userViewModel.setModelContext(modelContext)
        }
        .alert("Error", isPresented: $userViewModel.showError) {
            Button("OK", role: .cancel) {
                userViewModel.clearError()
            }
        } message: {
            if let error = userViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .frame(width: labelWidth, alignment: .trailing)
            content()
            Spacer()
        }
    }
    #endif
    
    // MARK: - iOS Layout
    
    #if os(iOS)
    private var iOSLayout: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display Name", text: $name)
                        .textContentType(.name)
                    
                    Toggle("Expert Mode", isOn: $isExpertMode)
                }
                
                Section("Loxone Credentials") {
                    TextField("Username", text: $loxoneUsername)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                    
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                        }
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
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
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createUser()
                    }
                    .disabled(!isValid || isCreating)
                }
            }
            .onAppear {
                userViewModel.setModelContext(modelContext)
            }
            .alert("Error", isPresented: $userViewModel.showError) {
                Button("OK", role: .cancel) {
                    userViewModel.clearError()
                }
            } message: {
                if let error = userViewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    #endif
    
    // MARK: - Shared
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !loxoneUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }
    
    private func createUser() {
        isCreating = true
        
        Task {
            let success = await userViewModel.createUser(
                name: name.trimmingCharacters(in: .whitespaces),
                loxoneUsername: loxoneUsername.trimmingCharacters(in: .whitespaces),
                password: password,
                isExpertMode: isExpertMode,
                useBiometrics: false
            )
            
            isCreating = false
            
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Edit User Sheet

struct EditUserSheet: View {
    let user: UserProfile
    @ObservedObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String
    @State private var loxoneUsername: String
    @State private var password = ""
    @State private var isExpertMode: Bool
    @State private var showPassword = false
    @State private var isSaving = false
    
    private let fieldWidth: CGFloat = 220
    private let labelWidth: CGFloat = 100
    
    init(user: UserProfile, userViewModel: UserViewModel) {
        self.user = user
        self.userViewModel = userViewModel
        _name = State(initialValue: user.name)
        _loxoneUsername = State(initialValue: user.loxoneUsername)
        _isExpertMode = State(initialValue: user.isExpertMode)
    }
    
    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }
    
    // MARK: - macOS Layout
    
    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 0) {
            // Title
            Text("Edit Profile")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 24)
            
            // Form content
            VStack(alignment: .leading, spacing: 20) {
                // Profile Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    formRow(label: "Display Name") {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                    }
                    
                    formRow(label: "Expert Mode") {
                        Toggle("", isOn: $isExpertMode)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Credentials Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Loxone Credentials")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    formRow(label: "Username") {
                        TextField("", text: $loxoneUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                    }
                    
                    formRow(label: "Password") {
                        HStack(spacing: 8) {
                            if showPassword {
                                TextField("Leave blank to keep current", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth - 32)
                            } else {
                                SecureField("Leave blank to keep current", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth - 32)
                            }
                            
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Leave password blank to keep the current password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, labelWidth)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Divider()
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isSaving)
                
                Button("Save") {
                    saveUser()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isSaving)
            }
            .padding(16)
        }
        .frame(width: 420, height: 520)
        .onAppear {
            userViewModel.setModelContext(modelContext)
        }
        .alert("Error", isPresented: $userViewModel.showError) {
            Button("OK", role: .cancel) {
                userViewModel.clearError()
            }
        } message: {
            if let error = userViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .frame(width: labelWidth, alignment: .trailing)
            content()
            Spacer()
        }
    }
    #endif
    
    // MARK: - iOS Layout
    
    #if os(iOS)
    private var iOSLayout: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display Name", text: $name)
                        .textContentType(.name)
                    
                    Toggle("Expert Mode", isOn: $isExpertMode)
                }
                
                Section {
                    TextField("Username", text: $loxoneUsername)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                    
                    HStack {
                        if showPassword {
                            TextField("Leave blank to keep current", text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField("Leave blank to keep current", text: $password)
                                .textContentType(.password)
                        }
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Loxone Credentials")
                } footer: {
                    Text("Leave password blank to keep the current password")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveUser()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                userViewModel.setModelContext(modelContext)
            }
            .alert("Error", isPresented: $userViewModel.showError) {
                Button("OK", role: .cancel) {
                    userViewModel.clearError()
                }
            } message: {
                if let error = userViewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    #endif
    
    // MARK: - Shared
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !loxoneUsername.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveUser() {
        isSaving = true
        
        Task {
            let success = await userViewModel.updateUser(
                user,
                name: name.trimmingCharacters(in: .whitespaces),
                loxoneUsername: loxoneUsername.trimmingCharacters(in: .whitespaces),
                password: password.isEmpty ? nil : password,
                isExpertMode: isExpertMode,
                useBiometrics: false
            )
            
            isSaving = false
            
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Server Settings Sheet

struct ServerSettingsSheet: View {
    @ObservedObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var localAddress: String = ""
    @State private var remoteAddress: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Local Server
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Server Address")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    TextField("192.168.1.100", text: $localAddress)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .disableAutocapitalization()
                        .urlKeyboardType()
                    
                    Text("Used when connected to your home network")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                // Remote Server
                VStack(alignment: .leading, spacing: 6) {
                    Text("Remote Server Address")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    TextField("dns.loxonecloud.com/504F94D0DAAD", text: $remoteAddress)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .disableAutocapitalization()
                        .urlKeyboardType()
                    
                    Text("Used when away from home")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                // Info
                Label {
                    Text("Automatic switching between local and remote based on network")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Server Settings")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(!hasValidAddress || isSaving)
                }
            }
            .onAppear {
                localAddress = userViewModel.localServerAddress
                remoteAddress = userViewModel.remoteServerAddress
            }
            .alert("Error", isPresented: $userViewModel.showError) {
                Button("OK", role: .cancel) {
                    userViewModel.clearError()
                }
            } message: {
                if let error = userViewModel.errorMessage {
                    Text(error)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 320)
        #endif
    }
    
    private var hasValidAddress: Bool {
        !localAddress.trimmingCharacters(in: .whitespaces).isEmpty ||
        !remoteAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveSettings() {
        isSaving = true
        userViewModel.localServerAddress = localAddress.trimmingCharacters(in: .whitespaces)
        userViewModel.remoteServerAddress = remoteAddress.trimmingCharacters(in: .whitespaces)
        
        Task {
            let success = await userViewModel.saveServerAddresses()
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    UserSelectorView()
        .environmentObject(UserViewModel())
}

