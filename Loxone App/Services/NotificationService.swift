//
//  NotificationService.swift
//  Loxone App
//
//  Local notification service for security and climate alerts
//

import Foundation
import UserNotifications
import Combine
import BackgroundTasks

// MARK: - Notification Service

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published private(set) var isAuthorized: Bool = false
    @Published var securityNotificationsEnabled: Bool = true
    @Published var climateNotificationsEnabled: Bool = true
    
    // Climate thresholds
    @Published var temperatureHighThreshold: Double = DefaultValues.temperatureHighThreshold
    @Published var temperatureLowThreshold: Double = DefaultValues.temperatureLowThreshold
    @Published var humidityHighThreshold: Double = DefaultValues.humidityHighThreshold
    @Published var humidityLowThreshold: Double = DefaultValues.humidityLowThreshold
    
    private let loxoneService = LoxoneService.shared
    private var cancellables = Set<AnyCancellable>()
    private var monitoredDevices: Set<String> = []
    
    private init() {
        loadSettings()
        setupStateMonitoring()
    }
    
    // MARK: - Authorization
    
    /// Request notification authorization
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            
            if granted {
                await registerCategories()
            }
            
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    /// Register notification categories
    private func registerCategories() async {
        let center = UNUserNotificationCenter.current()
        
        // Acknowledge action
        let acknowledgeAction = UNNotificationAction(
            identifier: NotificationIdentifiers.acknowledgeAction,
            title: "Acknowledge",
            options: []
        )
        
        // View action
        let viewAction = UNNotificationAction(
            identifier: NotificationIdentifiers.viewAction,
            title: "View in App",
            options: [.foreground]
        )
        
        // Security category
        let securityCategory = UNNotificationCategory(
            identifier: NotificationIdentifiers.securityCategory,
            actions: [viewAction, acknowledgeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Climate category
        let climateCategory = UNNotificationCategory(
            identifier: NotificationIdentifiers.climateCategory,
            actions: [viewAction, acknowledgeAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([securityCategory, climateCategory])
    }
    
    // MARK: - State Monitoring
    
    private func setupStateMonitoring() {
        // Monitor state changes from Loxone service
        // This would be connected to WebSocket state updates
    }
    
    /// Register a device for monitoring
    func registerDevice(_ uuid: String, eventTypes: [NotificationEventType]) {
        monitoredDevices.insert(uuid)
    }
    
    /// Unregister a device from monitoring
    func unregisterDevice(_ uuid: String) {
        monitoredDevices.remove(uuid)
    }
    
    /// Process a state change and trigger notifications if needed
    func processStateChange(controlUUID: String, controlName: String, controlType: String, value: Double) {
        guard isAuthorized else { return }
        
        let type = controlType.lowercased()
        
        // Check for security events
        if securityNotificationsEnabled {
            if type.contains("alarm") && value > 0 {
                sendNotification(
                    title: "⚠️ Alarm Triggered",
                    body: "\(controlName) has been triggered",
                    eventType: .alarmTriggered,
                    controlUUID: controlUUID
                )
            }
            
            if type.contains("door") && value > 0 {
                sendNotification(
                    title: "🚪 Door Opened",
                    body: "\(controlName) has been opened",
                    eventType: .doorOpened,
                    controlUUID: controlUUID
                )
            }
            
            if type.contains("window") && value > 0 {
                sendNotification(
                    title: "🪟 Window Opened",
                    body: "\(controlName) has been opened",
                    eventType: .windowOpened,
                    controlUUID: controlUUID
                )
            }
            
            if type.contains("smoke") && value > 0 {
                sendNotification(
                    title: "🔥 Smoke Detected",
                    body: "Smoke alarm triggered at \(controlName)",
                    eventType: .smokeDetected,
                    controlUUID: controlUUID,
                    critical: true
                )
            }
        }
        
        // Check for climate events
        if climateNotificationsEnabled {
            let name = controlName.lowercased()
            
            if name.contains("temp") || type.contains("temp") {
                if value > temperatureHighThreshold {
                    sendNotification(
                        title: "🌡️ Temperature High",
                        body: "\(controlName): \(value.temperatureString) exceeds \(temperatureHighThreshold.temperatureString)",
                        eventType: .temperatureHigh,
                        controlUUID: controlUUID
                    )
                } else if value < temperatureLowThreshold {
                    sendNotification(
                        title: "🌡️ Temperature Low",
                        body: "\(controlName): \(value.temperatureString) below \(temperatureLowThreshold.temperatureString)",
                        eventType: .temperatureLow,
                        controlUUID: controlUUID
                    )
                }
            }
            
            if name.contains("humid") || name.contains("feucht") {
                if value > humidityHighThreshold {
                    sendNotification(
                        title: "💧 Humidity High",
                        body: "\(controlName): \(value.percentageString) exceeds \(humidityHighThreshold.percentageString)",
                        eventType: .humidityHigh,
                        controlUUID: controlUUID
                    )
                } else if value < humidityLowThreshold {
                    sendNotification(
                        title: "💧 Humidity Low",
                        body: "\(controlName): \(value.percentageString) below \(humidityLowThreshold.percentageString)",
                        eventType: .humidityLow,
                        controlUUID: controlUUID
                    )
                }
            }
        }
    }
    
    // MARK: - Send Notifications
    
    /// Send a local notification
    func sendNotification(
        title: String,
        body: String,
        eventType: NotificationEventType,
        controlUUID: String,
        critical: Bool = false
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = critical ? .defaultCritical : .default
        content.categoryIdentifier = eventType.isSecurityEvent
            ? NotificationIdentifiers.securityCategory
            : NotificationIdentifiers.climateCategory
        content.userInfo = [
            "eventType": eventType.rawValue,
            "controlUUID": controlUUID
        ]
        
        // Use UUID to allow multiple notifications
        let request = UNNotificationRequest(
            identifier: "\(eventType.rawValue)-\(controlUUID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        securityNotificationsEnabled = defaults.bool(forKey: UserDefaultsKeys.securityNotificationsEnabled)
        climateNotificationsEnabled = defaults.bool(forKey: UserDefaultsKeys.climateNotificationsEnabled)
        
        if let tempHigh = defaults.object(forKey: UserDefaultsKeys.temperatureHighThreshold) as? Double {
            temperatureHighThreshold = tempHigh
        }
        if let tempLow = defaults.object(forKey: UserDefaultsKeys.temperatureLowThreshold) as? Double {
            temperatureLowThreshold = tempLow
        }
        if let humidHigh = defaults.object(forKey: UserDefaultsKeys.humidityHighThreshold) as? Double {
            humidityHighThreshold = humidHigh
        }
        if let humidLow = defaults.object(forKey: UserDefaultsKeys.humidityLowThreshold) as? Double {
            humidityLowThreshold = humidLow
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(securityNotificationsEnabled, forKey: UserDefaultsKeys.securityNotificationsEnabled)
        defaults.set(climateNotificationsEnabled, forKey: UserDefaultsKeys.climateNotificationsEnabled)
        defaults.set(temperatureHighThreshold, forKey: UserDefaultsKeys.temperatureHighThreshold)
        defaults.set(temperatureLowThreshold, forKey: UserDefaultsKeys.temperatureLowThreshold)
        defaults.set(humidityHighThreshold, forKey: UserDefaultsKeys.humidityHighThreshold)
        defaults.set(humidityLowThreshold, forKey: UserDefaultsKeys.humidityLowThreshold)
    }
    
    // MARK: - Badge Management
    
    /// Clear notification badge
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    /// Remove all delivered notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - Background Task Registration

#if os(iOS)
extension NotificationService {
    /// Register background tasks (call from AppDelegate)
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.langmuriweg.loxone.refresh",
            using: nil
        ) { task in
            handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    /// Schedule background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.langmuriweg.loxone.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
    
    private static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        Task { @MainActor in
            NotificationService.shared.scheduleBackgroundRefresh()
        }
        
        // Create a task to fetch latest states
        let refreshTask = Task {
            // Fetch states and check for alerts
            // This would reconnect and check states
        }
        
        task.expirationHandler = {
            refreshTask.cancel()
        }
        
        Task {
            _ = await refreshTask.result
            task.setTaskCompleted(success: true)
        }
    }
}
#else
extension NotificationService {
    /// Background tasks not available on macOS - no-op
    static func registerBackgroundTasks() {
        // Background tasks use different APIs on macOS
    }
    
    /// Background refresh not available on macOS - no-op
    func scheduleBackgroundRefresh() {
        // Background refresh not available on macOS
    }
}
#endif

