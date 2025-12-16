# Expert Mode Implementation Plan

## Overview

This document outlines a practical, phased approach to implementing Expert Mode features in the Loxone Home app. Each phase builds on the previous one, starting with safe, high-value features and progressing to more advanced capabilities.

---

## Phase 1: Foundation & Safe Configuration (MVP)
**Timeline**: 2-3 weeks  
**Risk Level**: Low  
**Goal**: Provide immediate value with zero risk of system damage

### 1.1 Room Management
**Priority**: HIGH - Users frequently need this

#### Features:
- ✅ **Rename Rooms**
  - Edit room display names
  - Update room icons (from predefined set)
  - Changes stored locally (doesn't modify Miniserver config)
  - Sync with structure file on reload

- ✅ **Room Organization**
  - Reorder rooms within floors
  - Hide/show rooms from main view
  - Mark rooms as favorites
  - Set room colors/themes

#### Implementation:
```swift
// Extend LoxoneRoom model
struct RoomCustomization {
    let roomUUID: String
    var customName: String?
    var customIcon: String?
    var isHidden: Bool
    var isFavorite: Bool
    var sortOrder: Int
    var themeColor: Color?
}
```

#### UI:
- Long-press room → "Edit Room" sheet
- Fields: Name, Icon picker, Color picker, Favorite toggle
- "Reset to Default" button

---

### 1.2 Control Customization
**Priority**: HIGH - Improves daily usability

#### Features:
- ✅ **Rename Controls** (Display names only)
  - Custom names stored locally
  - Fallback to original name from Miniserver
  - Search by custom names

- ✅ **Control Organization**
  - Mark controls as favorites
  - Hide controls from view
  - Custom icons (from predefined set)
  - Add custom notes/descriptions

- ✅ **Control Grouping**
  - Create custom control groups
  - "Living Room Lights" group with multiple controls
  - Quick actions for groups

#### Implementation:
```swift
struct ControlCustomization {
    let controlUUID: String
    var customName: String?
    var customIcon: String?
    var isHidden: Bool
    var isFavorite: Bool
    var notes: String?
    var groupIDs: [UUID]
}

struct ControlGroup {
    let id: UUID
    var name: String
    var icon: String
    var controlUUIDs: [String]
    var color: Color
}
```

#### UI:
- Long-press control card → "Edit Control" sheet
- Swipe actions: Favorite, Hide, Edit
- New "Groups" tab in settings

---

### 1.3 Statistics Management
**Priority**: MEDIUM - Requested feature

#### Features:
- ✅ **Toggle Statistics Collection**
  - Enable/disable per sensor
  - View current statistics status
  - Estimate storage impact

- ✅ **View Statistics Settings**
  - See which controls have statistics enabled
  - View data retention period
  - See storage usage

- ✅ **Bulk Operations**
  - Enable statistics for all sensors in a room
  - Disable statistics for all hidden controls
  - Category-based bulk enable/disable

#### Implementation:
```swift
// Send command to Miniserver
func setStatistics(controlUUID: String, enabled: Bool) async throws {
    // Loxone command: /jdev/sps/io/{uuid}/setStatistics/{0|1}
    try await sendCommand(controlUUID, command: "setStatistics/\(enabled ? 1 : 0)")
}
```

#### UI:
- Toggle switch on sensor cards (when in Expert Mode)
- "Statistics" section in control edit sheet
- Bulk operations in room settings

---

### 1.4 System Information (Read-Only)
**Priority**: HIGH - Essential for troubleshooting

#### Features:
- ✅ **Miniserver Info**
  - Serial number
  - Firmware version
  - Project name
  - Last modified date
  - Uptime

- ✅ **Network Status**
  - Local IP address
  - Remote URL status
  - Current connection type (local/remote)
  - WebSocket status
  - Connection quality metrics

- ✅ **Extension Status**
  - List all extensions (Tree, Air)
  - Online/offline status
  - Signal strength (for wireless)
  - Last seen timestamp

- ✅ **App Diagnostics**
  - App version
  - Last sync time
  - Cache size
  - Number of controls loaded
  - State update count

#### Implementation:
```swift
// Fetch from existing structure + new endpoints
struct SystemInfo {
    let miniserver: MiniserverInfo
    let extensions: [ExtensionInfo]
    let network: NetworkInfo
    let app: AppDiagnostics
}

// New endpoint: /jdev/sys/status
func fetchSystemStatus() async throws -> SystemStatus
```

#### UI:
- New "System Info" screen in Expert Mode menu
- Collapsible sections for each category
- "Copy to Clipboard" for support
- "Export Diagnostics" button

---

### 1.5 Connection Diagnostics
**Priority**: MEDIUM - Helps users troubleshoot

#### Features:
- ✅ **Connection Test**
  - Test local connection
  - Test remote connection
  - Measure response times
  - Check certificate validity

- ✅ **Network Quality**
  - Ping times
  - Packet loss
  - Bandwidth estimate
  - Connection stability score

- ✅ **Troubleshooting Tips**
  - Suggest fixes based on detected issues
  - "Switch to Remote" button if local fails
  - "Retry Connection" with different settings

#### Implementation:
```swift
struct ConnectionDiagnostics {
    var localPing: TimeInterval?
    var remotePing: TimeInterval?
    var packetLoss: Double
    var lastError: String?
    var recommendations: [String]
}

func runDiagnostics() async -> ConnectionDiagnostics
```

#### UI:
- "Run Diagnostics" button in settings
- Progress indicator during test
- Results with color-coded status
- Action buttons for fixes

---

## Phase 2: Advanced Configuration (Power Users)
**Timeline**: 3-4 weeks  
**Risk Level**: Medium  
**Goal**: Enable common configuration tasks without Loxone Config

### 2.1 Lighting Scene Management
**Priority**: HIGH - Frequently requested

#### Features:
- ✅ **View Existing Scenes**
  - List all scenes/moods for a light controller
  - Show scene composition (which lights, brightness, colors)
  - Preview scene (visual representation)

- ✅ **Edit Scene Parameters**
  - Adjust brightness per light in scene
  - Change colors (for RGB lights)
  - Modify fade time
  - Rename scenes (display name)

- ✅ **Create Simple Scenes**
  - "Save Current State as Scene"
  - Set lights to desired state → Save as new scene
  - Limited to light controllers only (safe)

- ✅ **Scene Templates**
  - Pre-built scenes: "Reading", "Movie", "Dinner", "Party"
  - One-tap apply to any light controller
  - Customize template defaults

#### Implementation:
```swift
struct LightingScene {
    let uuid: String
    var name: String
    var lights: [LightState]
    var fadeTime: TimeInterval
    var icon: String
}

struct LightState {
    let controlUUID: String
    var brightness: Int // 0-100
    var color: Color?
    var isOn: Bool
}

// Loxone API
func updateScene(_ sceneUUID: String, parameters: SceneParameters) async throws
func createScene(name: String, lightStates: [LightState]) async throws -> String
```

#### UI:
- Enhanced scene sheet (already have basic version)
- "Edit" button on each scene
- "Create Scene" button
- Scene preview with light icons

---

### 2.2 Timer & Schedule Viewing
**Priority**: MEDIUM - Useful for understanding automation

#### Features:
- ✅ **View Active Timers**
  - List all timers in the system
  - Show next trigger time
  - Display associated controls
  - Filter by room/category

- ✅ **Timer Details**
  - View schedule (daily, weekly, etc.)
  - See enabled/disabled status
  - View last execution time
  - Show timer logic (if available)

- ✅ **Enable/Disable Timers**
  - Toggle timer on/off
  - Temporary disable (e.g., "Disable for 1 day")
  - Bulk enable/disable by room

- ✅ **Calendar View**
  - Visual timeline of all timers
  - See what happens when
  - Identify conflicts/overlaps

#### Implementation:
```swift
struct LoxoneTimer {
    let uuid: String
    let name: String
    var isEnabled: Bool
    let schedule: TimerSchedule
    let associatedControls: [String]
    let nextTrigger: Date?
}

// Endpoint: /jdev/sps/io/{timerUUID}/enable or /disable
func setTimerEnabled(_ uuid: String, enabled: Bool) async throws
```

#### UI:
- New "Timers" tab in Expert Mode
- List view with toggle switches
- Calendar view (day/week)
- Filter by room/category

---

### 2.3 Climate Control Configuration
**Priority**: MEDIUM - Comfort optimization

#### Features:
- ✅ **Temperature Targets**
  - Set target temperatures per mode
  - Comfort mode target
  - Economy mode target
  - Night mode target
  - Building protection mode target

- ✅ **Operating Mode Schedule**
  - View when each mode is active
  - Temporary mode override
  - "Away" mode quick toggle

- ✅ **Temperature Curves**
  - View heating/cooling curves
  - Adjust curve parameters (if supported)
  - See current outdoor temp influence

- ✅ **Historical Data**
  - Temperature history graph
  - Energy consumption
  - Mode changes over time

#### Implementation:
```swift
struct ClimateConfiguration {
    var comfortTemp: Double
    var economyTemp: Double
    var nightTemp: Double
    var buildingProtectionTemp: Double
    var currentMode: ClimateMode
}

// Commands
func setTargetTemperature(_ controlUUID: String, mode: ClimateMode, temp: Double) async throws
func setOperatingMode(_ controlUUID: String, mode: ClimateMode) async throws
```

#### UI:
- Enhanced climate control card
- Temperature target editor
- Mode schedule viewer
- History graph

---

### 2.4 Blind/Jalousie Presets
**Priority**: LOW-MEDIUM - Nice to have

#### Features:
- ✅ **Position Presets**
  - Save favorite positions
  - "Morning" preset (50% open)
  - "Privacy" preset (closed, slats angled)
  - "Sun Protection" preset

- ✅ **Automatic Positioning**
  - View sun tracking settings
  - Enable/disable automatic control
  - Set time-based positions

- ✅ **Movement Settings**
  - View movement times
  - Calibration status
  - Manual calibration trigger

#### Implementation:
```swift
struct JalousiePreset {
    let name: String
    let position: Int // 0-100
    let slatsPosition: Int? // 0-100 (if supported)
    let icon: String
}

func saveJalousiePreset(_ controlUUID: String, preset: JalousiePreset) async throws
func applyJalousiePreset(_ controlUUID: String, presetName: String) async throws
```

#### UI:
- Preset buttons on jalousie card
- "Save Current Position" button
- Preset editor sheet

---

### 2.5 Backup & Restore
**Priority**: HIGH - Safety net for changes

#### Features:
- ✅ **Create Backup**
  - Download current configuration
  - Store locally in app
  - iCloud sync option
  - Automatic backup before changes

- ✅ **View Backups**
  - List all backups with dates
  - Show backup size
  - Preview backup info (version, date, etc.)

- ✅ **Restore Backup**
  - Upload backup to Miniserver
  - Requires confirmation
  - Show diff of changes (if possible)

- ✅ **Scheduled Backups**
  - Auto-backup daily/weekly
  - Keep last N backups
  - Backup before any expert mode change

#### Implementation:
```swift
// Endpoint: /jdev/sys/backup
func createBackup() async throws -> Data

// Store locally
struct ConfigBackup {
    let id: UUID
    let date: Date
    let data: Data
    let miniserverSerial: String
    let version: String
}

func restoreBackup(_ backup: ConfigBackup) async throws
```

#### UI:
- "Backups" section in Expert Mode
- "Create Backup Now" button
- List of backups with restore/delete
- Settings for auto-backup

---

## Phase 3: Advanced Features (System Integrators)
**Timeline**: 4-6 weeks  
**Risk Level**: Medium-High  
**Goal**: Replace common Loxone Config tasks

### 3.1 Control Parameter Editing
**Priority**: MEDIUM - For fine-tuning

#### Features:
- ✅ **Dimmer Settings**
  - Min/max brightness limits
  - Ramp rate (fade time)
  - Default startup brightness
  - Soft start/stop

- ✅ **Switch Settings**
  - Pulse duration (for pushbuttons)
  - Double-click behavior
  - Staircase timer duration

- ✅ **Sensor Calibration**
  - Offset adjustment
  - Scaling factor
  - Averaging period
  - Alarm thresholds

#### Implementation:
```swift
struct ControlParameters {
    let controlUUID: String
    var parameters: [String: Any] // Dynamic based on control type
}

// Requires Configuration API enabled on Miniserver
func updateControlParameter(_ uuid: String, key: String, value: Any) async throws
```

#### UI:
- "Advanced Settings" section in control edit
- Parameter-specific UI (sliders, toggles, etc.)
- "Reset to Default" option
- Warning about advanced settings

---

### 3.2 Scene Composition & Automation
**Priority**: MEDIUM - Creative control

#### Features:
- ✅ **Multi-Room Scenes**
  - Create scenes spanning multiple rooms
  - "Good Night" scene (all lights off, lock doors, etc.)
  - "Welcome Home" scene

- ✅ **Scene Triggers**
  - Time-based triggers
  - Sensor-based triggers (e.g., motion detected)
  - Manual triggers (button, app)

- ✅ **Scene Sequences**
  - Chain multiple scenes
  - Delays between scenes
  - "Movie Mode": Dim lights → Close blinds → Turn on TV

- ✅ **Conditional Scenes**
  - "If temperature > 25°C, activate cooling scene"
  - "If dark outside, activate evening lighting"

#### Implementation:
```swift
struct MultiRoomScene {
    let id: UUID
    var name: String
    var actions: [SceneAction]
    var triggers: [SceneTrigger]
    var conditions: [SceneCondition]
}

struct SceneAction {
    let controlUUID: String
    let command: String
    let delay: TimeInterval
}
```

#### UI:
- Scene builder interface
- Drag-and-drop controls
- Trigger configuration
- Test scene button

---

### 3.3 Virtual Inputs & Variables
**Priority**: LOW-MEDIUM - Advanced users

#### Features:
- ✅ **View Virtual Inputs**
  - List all virtual inputs
  - Show current values
  - See what they control

- ✅ **Set Virtual Input Values**
  - Manual value entry
  - Toggle digital inputs
  - Set analog values

- ✅ **User Variables**
  - Create custom variables
  - Use in scenes/automation
  - View/edit values

#### Implementation:
```swift
struct VirtualInput {
    let uuid: String
    let name: String
    let type: InputType // digital, analog, text
    var currentValue: Any
}

func setVirtualInput(_ uuid: String, value: Any) async throws
```

#### UI:
- "Virtual Inputs" section
- List with current values
- Edit sheet per input
- "What uses this?" info

---

### 3.4 System Maintenance
**Priority**: MEDIUM - Operational needs

#### Features:
- ✅ **Reboot Miniserver**
  - Requires double confirmation
  - Shows uptime before reboot
  - Countdown timer
  - "Cancel" option

- ✅ **Reload Configuration**
  - Refresh structure file
  - Clear caches
  - Re-establish connections

- ✅ **Update Firmware** (View Only)
  - Check for updates
  - Show current version
  - Link to update instructions
  - (Actual update via Loxone Config only)

- ✅ **Network Configuration** (View Only)
  - IP settings
  - DNS settings
  - Port configuration
  - (Changes via Loxone Config only)

#### Implementation:
```swift
// Endpoint: /jdev/sys/reboot
func rebootMiniserver() async throws

// Confirmation flow
struct RebootConfirmation {
    var step: Int // 1: Warning, 2: Type "REBOOT", 3: Countdown
    var countdown: Int // 10 seconds
    var canCancel: Bool
}
```

#### UI:
- "System Maintenance" section
- Big red "Reboot" button
- Multi-step confirmation
- Progress indicator

---

### 3.5 Log Viewer & Diagnostics
**Priority**: MEDIUM - Troubleshooting

#### Features:
- ✅ **System Logs**
  - View recent log entries
  - Filter by severity (Error, Warning, Info)
  - Filter by source (Miniserver, Extension, etc.)
  - Search logs

- ✅ **Event History**
  - Recent commands sent
  - State changes
  - User actions
  - Automation triggers

- ✅ **Error Tracking**
  - List of recent errors
  - Error frequency
  - Affected controls
  - Suggested fixes

- ✅ **Export Logs**
  - Export to file
  - Share via email
  - Include diagnostics bundle

#### Implementation:
```swift
// Endpoint: /jdev/sys/log (if available)
struct LogEntry {
    let timestamp: Date
    let severity: LogSeverity
    let source: String
    let message: String
}

func fetchLogs(since: Date, severity: LogSeverity?) async throws -> [LogEntry]
```

#### UI:
- "Logs" tab in Expert Mode
- Filter toolbar
- Search bar
- Export button
- Auto-refresh toggle

---

## Implementation Priorities Summary

### Must Have (Phase 1)
1. ✅ Room renaming & organization
2. ✅ Control renaming & customization
3. ✅ Statistics toggle
4. ✅ System information viewer
5. ✅ Connection diagnostics

### Should Have (Phase 2)
6. ✅ Lighting scene management
7. ✅ Timer viewing & enable/disable
8. ✅ Climate target temperatures
9. ✅ Backup & restore
10. ✅ Blind presets

### Nice to Have (Phase 3)
11. ⚠️ Control parameter editing (requires Config API)
12. ⚠️ Multi-room scenes
13. ⚠️ Virtual inputs
14. ⚠️ System maintenance (reboot)
15. ⚠️ Log viewer

---

## Technical Requirements

### Phase 1 Requirements
- ✅ SwiftData for local storage (already implemented)
- ✅ Basic HTTP API access (already implemented)
- ✅ No Miniserver configuration changes needed
- ✅ All changes stored locally in app

### Phase 2 Requirements
- ⚠️ Miniserver firmware 10.0+ recommended
- ⚠️ Some features may require Configuration API enabled
- ✅ Backup/restore uses standard endpoints
- ✅ Timer control uses standard commands

### Phase 3 Requirements
- ❌ Configuration API MUST be enabled on Miniserver
- ❌ Expert user credentials required
- ❌ Miniserver firmware 11.0+ recommended
- ⚠️ Some features may not work on older firmware

---

## Safety & Permissions

### Permission Levels

```swift
enum ExpertModeLevel {
    case viewer      // Phase 1: View-only + local customization
    case editor      // Phase 2: Safe configuration changes
    case advanced    // Phase 3: System-level changes
}
```

### Safety Checks

```swift
struct SafetyCheck {
    // Before any write operation
    static func canPerformAction(_ action: ExpertAction) -> Bool {
        // Check user permission level
        // Check Miniserver capabilities
        // Check if Configuration API is enabled
        // Check if backup exists
    }
    
    // Confirmation requirements
    static func confirmationLevel(_ action: ExpertAction) -> ConfirmationLevel {
        switch action.risk {
        case .low: return .simple        // OK button
        case .medium: return .dialog     // Yes/No
        case .high: return .typeWord     // Type "CONFIRM"
        case .critical: return .delayed  // Type word + 10s countdown
        }
    }
}
```

---

## UI/UX Guidelines

### Expert Mode Entry

```
Settings → Expert Mode → [Biometric Auth] → Expert Menu
```

### Expert Mode Menu Structure

```
Expert Mode
├── 📝 Customization
│   ├── Rooms
│   ├── Controls
│   └── Groups
├── 📊 Statistics
│   ├── Manage Statistics
│   └── View Usage
├── 🎬 Scenes & Automation
│   ├── Lighting Scenes
│   ├── Timers
│   └── Multi-Room Scenes (Phase 3)
├── 🌡️ Climate
│   ├── Temperature Targets
│   ├── Mode Schedule
│   └── History
├── 🔧 System
│   ├── Information
│   ├── Diagnostics
│   ├── Backups
│   ├── Maintenance (Phase 3)
│   └── Logs (Phase 3)
└── ⚙️ Advanced (Phase 3)
    ├── Control Parameters
    ├── Virtual Inputs
    └── Network Settings
```

### Visual Design

- **Badge**: Show "Expert" badge when in expert mode
- **Colors**: Use orange/yellow for expert mode UI elements
- **Icons**: Use wrench/gear icons consistently
- **Warnings**: Show warning icons for risky actions
- **Confirmations**: Use modal sheets with clear action buttons

---

## Testing Strategy

### Phase 1 Testing
- ✅ All features work offline (local storage)
- ✅ No impact on Miniserver
- ✅ Data persists across app restarts
- ✅ Sync with structure file updates

### Phase 2 Testing
- ⚠️ Test on non-production Miniserver first
- ⚠️ Verify backup/restore works
- ⚠️ Test rollback of changes
- ⚠️ Verify no impact on automation

### Phase 3 Testing
- ❌ Requires test environment
- ❌ Test all failure scenarios
- ❌ Verify concurrent user handling
- ❌ Load testing for bulk operations

---

## Open Questions

### For Phase 1:
1. ❓ Should room/control customizations sync across devices via iCloud?
2. ❓ Should we allow exporting customizations for sharing?
3. ❓ How to handle customizations when structure file changes?

### For Phase 2:
4. ❓ Should scene creation be limited to certain control types?
5. ❓ How to handle timer conflicts (overlapping schedules)?
6. ❓ Should backups be encrypted?

### For Phase 3:
7. ❓ How to detect if Configuration API is enabled?
8. ❓ Should we limit concurrent expert mode sessions?
9. ❓ How to handle firmware compatibility issues?
10. ❓ Should we implement a "safe mode" to revert all changes?

---

## Success Metrics

### Phase 1 Metrics
- % of users who enable Expert Mode
- Average number of customizations per user
- Time saved vs. using Loxone Config
- User satisfaction score

### Phase 2 Metrics
- Number of scenes created
- Timer modifications per week
- Backup frequency
- Feature adoption rate

### Phase 3 Metrics
- Advanced feature usage
- System integrator adoption
- Support ticket reduction
- Time saved vs. Loxone Config

---

## Timeline Summary

| Phase | Duration | Features | Risk | User Value |
|-------|----------|----------|------|------------|
| 1 | 2-3 weeks | 5 core features | Low | High |
| 2 | 3-4 weeks | 5 advanced features | Medium | High |
| 3 | 4-6 weeks | 5 expert features | High | Medium |

**Total**: 9-13 weeks for complete implementation

---

## Recommendations

### Start with Phase 1
- ✅ Immediate user value
- ✅ Zero risk to Miniserver
- ✅ Builds foundation for later phases
- ✅ Can ship to production quickly

### Phase 2 After User Feedback
- ⚠️ Gather feedback from Phase 1 users
- ⚠️ Prioritize most-requested features
- ⚠️ Test thoroughly on test Miniserver

### Phase 3 Only If Needed
- ❌ Requires Configuration API (not all users have this)
- ❌ Higher risk of issues
- ❌ Consider if user demand justifies effort

### Alternative Approach
Instead of Phase 3, consider:
- Better integration with Loxone Config (open Config from app)
- More visualization features (energy dashboards, etc.)
- Better automation insights (what's happening when)

---

**Document Version:** 2.0  
**Last Updated:** December 2025  
**Status:** Ready for Implementation  
**Next Step:** Begin Phase 1 implementation

