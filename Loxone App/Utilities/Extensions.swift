//
//  Extensions.swift
//  Loxone App
//
//  Helper extensions for common functionality
//

import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// Check if string is a valid IP address
    var isValidIPAddress: Bool {
        let ipPattern = #"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        return self.range(of: ipPattern, options: .regularExpression) != nil
    }
    
    /// Check if string is a local IP address
    var isLocalIP: Bool {
        let localPatterns = [
            "^192\\.168\\.",
            "^10\\.",
            "^172\\.(1[6-9]|2[0-9]|3[01])\\.",
            "^localhost$",
            "^127\\."
        ]
        return localPatterns.contains { pattern in
            self.range(of: pattern, options: .regularExpression, range: nil, locale: nil) != nil
        }
    }
    
    /// Remove protocol prefix from URL string
    var withoutProtocol: String {
        self.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
    
    /// Add protocol if missing
    func withProtocol(secure: Bool = true) -> String {
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return self
        }
        return (secure ? "https://" : "http://") + self
    }
    
    /// Trim trailing slashes
    var trimmedTrailingSlash: String {
        var result = self
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
    
    /// Base64 encode
    var base64Encoded: String? {
        data(using: .utf8)?.base64EncodedString()
    }
    
    /// Base64 decode
    var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - URL Extensions

extension URL {
    /// Create URL with basic auth credentials in the format user:pass@host
    func withBasicAuth(username: String, password: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.user = username
        components.password = password
        return components.url
    }
}

// MARK: - Data Extensions

extension Data {
    /// Create Basic Auth header value from username and password
    static func basicAuthHeader(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        let credentialsData = credentials.data(using: .utf8)!
        return "Basic \(credentialsData.base64EncodedString())"
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format as time string (HH:mm:ss)
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }
    
    /// Format as date/time string
    var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
    
    /// Relative time description (e.g., "2 minutes ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format as temperature string
    var temperatureString: String {
        String(format: "%.1f°C", self)
    }
    
    /// Format as percentage string
    var percentageString: String {
        String(format: "%.0f%%", self)
    }
    
    /// Format with specific decimal places
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Hide view conditionally
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
    
    /// Apply card style
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.systemBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    /// Apply standard padding with background
    func sectionBackground() -> some View {
        self
            .padding()
            .background(Color.secondarySystemBackground)
            .cornerRadius(10)
    }
    
    /// Cross-platform inline navigation bar title display mode
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
    
    /// Cross-platform text input autocapitalization
    @ViewBuilder
    func disableAutocapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
    
    /// Cross-platform URL keyboard type
    @ViewBuilder
    func urlKeyboardType() -> some View {
        #if os(iOS)
        self.keyboardType(.URL)
        #else
        self
        #endif
    }
    
    /// Cross-platform edit mode
    @ViewBuilder
    func editModeActive() -> some View {
        #if os(iOS)
        self.environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }
    
    /// Cross-platform inset grouped list style
    @ViewBuilder
    func insetGroupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }
}

// MARK: - Cross-Platform Toolbar Placement

extension ToolbarItemPlacement {
    /// Cross-platform trailing placement
    static var topBarTrailingCompat: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }
}

// MARK: - Color Extensions

extension Color {
    /// Loxone brand green
    static let loxoneGreen = Color(red: 0.4, green: 0.75, blue: 0.4)
    
    /// Status colors
    static let statusOn = Color.green
    static let statusOff = Color.gray
    static let statusWarning = Color.orange
    static let statusError = Color.red
    
    /// Sensor type colors
    static let temperatureColor = Color.orange
    static let humidityColor = Color.blue
    static let powerColor = Color.yellow
    static let securityColor = Color.red
    
    /// Cross-platform background colors
    #if os(iOS)
    static let systemBackground = Color(uiColor: .systemBackground)
    static let secondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    static let systemGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let tertiarySystemBackground = Color(uiColor: .tertiarySystemBackground)
    #elseif os(macOS)
    static let systemBackground = Color(nsColor: .windowBackgroundColor)
    static let secondarySystemBackground = Color(nsColor: .controlBackgroundColor)
    static let systemGroupedBackground = Color(nsColor: .windowBackgroundColor)
    static let tertiarySystemBackground = Color(nsColor: .underPageBackgroundColor)
    #endif
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    /// Return empty string if nil
    var orEmpty: String {
        self ?? ""
    }
    
    /// Check if nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - Array Extensions

extension Array where Element: Identifiable {
    /// Find element by ID
    func first(withId id: Element.ID) -> Element? {
        first { $0.id == id }
    }
    
    /// Get index of element by ID
    func index(withId id: Element.ID) -> Int? {
        firstIndex { $0.id == id }
    }
}

// MARK: - Dictionary Extensions

extension Dictionary where Key == String {
    /// Case-insensitive key lookup
    func value(forKeyIgnoringCase key: String) -> Value? {
        let lowercasedKey = key.lowercased()
        return first { $0.key.lowercased() == lowercasedKey }?.value
    }
}

// MARK: - UserDefaults Extension for App Group

extension UserDefaults {
    /// Shared UserDefaults for app group (widgets)
    static var shared: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    }
}

// MARK: - Binding Extensions

extension Binding {
    /// Create a binding that performs an action on change
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

// MARK: - Task Extension for Debouncing

extension Task where Success == Never, Failure == Never {
    /// Sleep for specified seconds
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

