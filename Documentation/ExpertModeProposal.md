# Expert Mode Feature Proposal

This document outlines the potential expert configuration features for the Loxone Home app. These features are planned for Phase 2 implementation and will be available only to users with Expert Mode enabled.

## Overview

Expert Mode provides advanced Loxone Miniserver configuration capabilities directly from the mobile app. This allows system integrators and advanced users to make configuration changes without needing access to Loxone Config on a PC.

## 1. Loxone Config API Capabilities

The Loxone Miniserver exposes several APIs that can be used for configuration:

### 1.1 HTTP API Endpoints

| Endpoint | Purpose | Method |
|----------|---------|--------|
| `/jdev/sps/io/{uuid}/{command}` | Send commands to controls | GET |
| `/jdev/sps/status` | Get SPS status | GET |
| `/jdev/cfg/api` | Configuration API (if enabled) | GET/POST |
| `/jdev/sys/getkey` | Get authentication key | GET |
| `/jdev/sys/reboot` | Reboot Miniserver | GET |
| `/jdev/sys/backup` | Create configuration backup | GET |
| `/data/LoxAPP3.json` | Get full structure file | GET |

### 1.2 WebSocket Commands

- `jdev/sps/enablebinstatusupdate` - Enable binary status updates
- `jdev/cfg/*` - Configuration commands (when enabled)
- `jdev/sys/*` - System commands

### 1.3 Configuration API (requires enabling in Loxone Config)

The Configuration API must be explicitly enabled on the Miniserver. When enabled, it provides:

- Read/write access to certain control parameters
- Schedule/timer management
- Scene configuration
- Limited input/output mapping

## 2. Proposed Expert Features

### 2.1 Control Configuration

**Basic Control Settings:**
- Rename controls (display names only)
- Set favorite status
- Configure control-specific parameters (where supported)
- View detailed control information

**Light Controllers:**
- Create, edit, and delete mood/scene assignments
- Configure mood parameters (brightness, color, fade time)
- Set default startup moods
- Configure presence-based automation

**Dimmers:**
- Set min/max brightness limits
- Configure ramp rates (fade time)
- Set default brightness level

**Jalousie/Blinds:**
- Configure position presets
- Set movement times
- Configure automatic sun tracking parameters

**Climate Controls (IRoomController):**
- Set target temperatures for each mode
- Configure heating/cooling curves
- Set comfort/economy schedules
- View historical data

### 2.2 Schedules & Timers

**Timer Management:**
- View all active timers
- Create new timers (within allowed scope)
- Edit existing timer schedules
- Enable/disable timers

**Daytimer Configuration:**
- View daytimer entries
- Modify time values
- Set operating modes per time slot

**Calendar Events:**
- View Loxone calendar
- Add simple calendar entries
- Configure vacation mode

### 2.3 Scene Management

**Lighting Scenes:**
- Create new lighting scenes/moods
- Edit existing scene compositions
- Copy scenes between rooms
- Set scene activation triggers

**Central Functions:**
- Configure "All Off" behaviors
- Set up coming/leaving home scenes
- Configure presence simulation settings

### 2.4 Input/Output Mapping (Limited)

**View Only:**
- Physical input assignments
- Output mappings
- Virtual input connections

**Configurable (where supported):**
- Virtual input values
- Text state values
- User-defined variables

### 2.5 Network & System

**Network Information:**
- View network configuration
- Check connection status
- View connected clients
- Display MAC addresses and IPs

**System Information:**
- Miniserver details (serial, version, etc.)
- CPU and memory usage
- Uptime statistics
- Extension status

**Maintenance:**
- Trigger configuration reload
- Request system reboot (with confirmation)
- Create configuration backup
- View system logs

### 2.6 Logs & Diagnostics

**System Logs:**
- View recent log entries
- Filter by severity level
- Export logs for support

**Control History:**
- View recent commands sent
- State change history
- Error events

**Connection Diagnostics:**
- Test connectivity
- Ping response times
- WebSocket connection status
- API response times

## 3. UI/UX Considerations

### 3.1 Expert Mode Entry

- Require explicit confirmation before entering expert mode
- Show warning about potential system impact
- Log all expert mode sessions for audit

### 3.2 Change Confirmation

All configuration changes should:
- Show a preview of the change
- Require explicit confirmation
- Provide an undo option (where technically possible)
- Show success/failure feedback

### 3.3 Visual Hierarchy

```
Expert Mode Menu
├── Control Configuration
│   ├── Light Controllers
│   ├── Dimmers
│   ├── Blinds/Jalousie
│   └── Climate
├── Schedules & Timers
│   ├── Active Timers
│   ├── Daytimers
│   └── Calendar
├── Scene Management
│   ├── Lighting Scenes
│   └── Central Functions
├── System
│   ├── Network Info
│   ├── System Status
│   └── Maintenance
└── Diagnostics
    ├── Logs
    ├── History
    └── Connection Test
```

### 3.4 Platform Considerations

**iPad/macOS:**
- Use full multi-column layout
- Show more detail simultaneously
- Enable drag-and-drop for reordering

**iPhone:**
- Progressive disclosure
- Collapsible sections
- Modal sheets for editing

## 4. Safety Considerations

### 4.1 Read-Only vs. Read-Write

Categorize features by risk level:

| Risk Level | Features | Safeguards |
|------------|----------|------------|
| Low | View logs, network info | None required |
| Medium | Change moods, timers | Confirmation dialog |
| High | Reboot, modify I/O | Double confirmation + warning |
| Critical | Not implemented | Require Loxone Config |

### 4.2 Required Confirmations

- All writes require user confirmation
- Destructive actions require typing confirmation word
- System-level changes show impact preview

### 4.3 Rollback Options

Where possible:
- Store previous values before changes
- Provide "Undo" for recent changes
- Backup before bulk operations

### 4.4 Audit Trail

- Log all expert mode actions
- Include timestamp, user, and action
- Store locally for troubleshooting

## 5. Implementation Priority

### Phase 2.1 (First Release)

1. **View-only diagnostics**
   - System information
   - Network status
   - Recent logs
   - Connection diagnostics

2. **Basic control configuration**
   - Rename controls
   - Set favorites
   - View detailed info

### Phase 2.2

3. **Scene/Mood management**
   - View existing moods
   - Edit mood brightness/colors
   - Create simple moods

4. **Timer viewing and basic editing**
   - View all timers
   - Enable/disable timers

### Phase 2.3

5. **Advanced control parameters**
   - Light controller moods
   - Climate target temperatures
   - Jalousie presets

6. **System maintenance**
   - Backup creation
   - Reboot (with safeguards)

### Future Phases

7. Schedule creation
8. Advanced scene composition
9. Virtual input management
10. Calendar integration

## 6. Technical Requirements

### 6.1 API Access

- Configuration API must be enabled on Miniserver
- Expert user credentials with appropriate permissions
- Secure connection (HTTPS where possible)

### 6.2 App Capabilities

- SwiftData for storing local configuration cache
- Undo manager for change rollback
- Background task for backup operations
- Keychain for secure credential storage (already implemented)

### 6.3 Testing Requirements

- Test environment with non-production Miniserver
- Comprehensive rollback testing
- Edge case handling (network failures, concurrent changes)
- User acceptance testing with system integrators

## 7. Open Questions

1. **Permission Granularity**: Should expert mode have sub-levels (view-only, limited edit, full edit)?

2. **Multi-user Conflicts**: How to handle concurrent expert mode sessions?

3. **Offline Support**: Cache configuration changes when offline and sync later?

4. **Configuration API Availability**: What percentage of users have Configuration API enabled?

5. **Version Compatibility**: Minimum Miniserver firmware version required?

## 8. References

- Loxone API Documentation (internal)
- Loxone Config Help Files
- Community API Documentation: [Loxone Community Wiki](https://www.loxone.com/enen/kb/)

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Status:** Draft - Pending Review

*This document is a proposal. Features and implementation details are subject to change based on technical feasibility and user feedback.*

