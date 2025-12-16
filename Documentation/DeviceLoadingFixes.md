# Device Loading Fixes

## Issues Identified

Based on the screenshot provided, there were two main issues:

1. **Only one device showing in the device grid**: The "Music Room" showed "5 devices" in the middle pane but only 1 device (humidity sensor) appeared in the right pane
2. **No device state data loading**: The humidity sensor showed "-- %" instead of actual values

## Root Causes

### 1. UUID Not Being Set Properly
The Loxone API returns controls in a dictionary format where the UUID is the key, not a property of the control object:

```json
{
  "controls": {
    "uuid-1": { "name": "Device 1", "type": "Switch", ... },
    "uuid-2": { "name": "Device 2", "type": "Sensor", ... }
  }
}
```

The decoder was not properly setting the UUID field when creating `LoxoneControl` objects, resulting in empty UUIDs which could cause filtering or identification issues.

### 2. Asynchronous State Loading
The initial state fetching was happening in a background task that didn't block the UI. This meant:
- UI would load immediately with devices but no state data
- States would trickle in slowly over time
- No visual feedback to the user that states were loading

## Fixes Applied

### 1. Fixed UUID Assignment
Modified all methods in `LoxoneService` that return controls to properly construct `LoxoneControl` objects with the UUID from the dictionary key:

- `getControls(for:)` - Get controls for a room
- `getControl(_:)` - Get a single control
- `getAllControls()` - Get all controls

### 2. Added Immediate State Loading
Created a new public method `fetchRoomStatesImmediate(_:)` that:
- Loads all states for a room's devices immediately when the room is selected
- Uses parallel fetching with reasonable batch sizes (10 devices at a time)
- Includes small delays between batches to avoid overwhelming the Miniserver

### 3. Added Loading Indicators
- Added `isLoadingStates` state to `DeviceGridView`
- Shows a loading overlay with progress indicator while states are being fetched
- Provides visual feedback to the user

### 4. Enhanced Logging
Added comprehensive logging throughout the data flow to help debug issues:

- `DeviceGridView`: Logs when rooms are selected and how many devices are found
- `LoxoneService.getControls`: Logs all controls found for a room with their UUIDs
- `LoxoneService.fetchStateValue`: Logs each state fetch attempt and result
- `DeviceStateStore.update`: Logs every state update
- `SensorCard`: Logs when states are missing or not found

## Testing Instructions

1. **Build and run the app** in Xcode
2. **Open the Console** (Cmd+Shift+Y) to see debug logs
3. **Navigate to a room** with multiple devices
4. **Observe the logs** to verify:
   - All devices are being loaded: Look for `🏠 [LoxoneService] getControls for room`
   - States are being fetched: Look for `🔄 [LoxoneService] Fetching states for room`
   - States are being updated: Look for `📊 [DeviceStateStore] Updated state`
   - Devices are appearing in the grid: Look for `🎯 [DeviceGridView] Total devices in room`

## Expected Behavior After Fixes

1. When selecting a room, you should see:
   - A loading indicator briefly appears
   - All devices for that room appear in the grid
   - Device states load and display within 1-2 seconds
   - Sensor values show actual data instead of "--"

2. Console logs should show:
   - Correct number of devices found for each room
   - All device UUIDs being properly set (not empty)
   - State fetch requests for each device
   - State updates being applied to the store

## Additional Improvements Made

1. **Better error handling**: State fetch errors are now logged instead of silently failing
2. **Optimized batching**: Reduced batch sizes and added delays to prevent connection resets
3. **State verification**: Added checks to verify state UUIDs exist before trying to fetch them

## Known Limitations

1. **Initial load time**: The first time you open a room, there may be a 1-2 second delay while states are fetched
2. **Miniserver connection limits**: Very large rooms (50+ devices) may take longer to load all states
3. **WebSocket fallback**: If WebSocket connection fails, the app falls back to HTTP polling which is slower but still functional

## Future Enhancements

1. **State caching**: Cache recently fetched states to reduce load times
2. **Progressive loading**: Show devices immediately and update states as they arrive
3. **Batch state endpoint**: Use a single API call to fetch multiple states at once (if Loxone API supports it)
4. **State subscriptions**: Improve WebSocket handling for real-time updates
