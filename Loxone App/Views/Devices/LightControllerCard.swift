//
//  LightControllerCard.swift
//  Loxone App
//
//  Device card for light controllers with scene support
//

import SwiftUI

struct LightControllerCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var isToggling = false
    @State private var sliderValue: Double = 0
    @State private var isAdjusting = false
    @State private var debounceTask: Task<Void, Never>?
    
    private var state: DeviceState? {
        // For LightController, we should check the "active" state, not "activeMoods"
        // "activeMoods" is for scene selection, "active" is for on/off state
        if let activeStateUUID = control.states?["active"]?.uuidString {
            let activeState = stateStore.state(for: activeStateUUID)
            print("💡 [LightControllerCard] \(control.name) - active state UUID: \(activeStateUUID), value: \(activeState?.value ?? -1)")
            if activeState != nil {
                return activeState
            }
        }
        
        // Try activeMoods for scene-based controllers
        if let activeMoodsUUID = control.states?["activeMoods"]?.uuidString,
           let activeMoodsState = stateStore.state(for: activeMoodsUUID) {
            print("💡 [LightControllerCard] \(control.name) - activeMoods state UUID: \(activeMoodsUUID), value: \(activeMoodsState.value)")
            return activeMoodsState
        }
        
        if let activeSceneUUID = control.states?["activeScene"]?.uuidString,
           let activeSceneState = stateStore.state(for: activeSceneUUID) {
            print("💡 [LightControllerCard] \(control.name) - activeScene state UUID: \(activeSceneUUID), value: \(activeSceneState.value)")
            return activeSceneState
        }
        
        // Fallback to the control's main UUID
        let mainState = stateStore.state(for: control.uuid)
        print("💡 [LightControllerCard] \(control.name) - main UUID: \(control.uuid), value: \(mainState?.value ?? -1)")
        print("💡 [LightControllerCard] \(control.name) - available states: \(control.states?.keys.joined(separator: ", ") ?? "none")")
        return mainState
    }
    
    private var isOn: Bool {
        // For LightControllerV2, check if ANY circuit is on by looking at activeMoods
        // activeMoods is a bitmask where each bit represents a circuit
        // If activeMoods > 0, at least one circuit is on
        if let activeMoodsUUID = control.states?["activeMoods"]?.uuidString,
           let activeMoodsState = stateStore.state(for: activeMoodsUUID) {
            let result = activeMoodsState.value > 0
            print("💡 [LightControllerCard] \(control.name) - isOn via activeMoods: value=\(activeMoodsState.value), result=\(result)")
            return result
        }
        
        // Fallback to checking master value or main state
        if let masterValueUUID = control.states?["masterValue"]?.uuidString,
           let masterState = stateStore.state(for: masterValueUUID) {
            let result = masterState.value > 0
            print("💡 [LightControllerCard] \(control.name) - isOn via masterValue: value=\(masterState.value), result=\(result)")
            return result
        }
        
        let value = state?.value ?? 0
        let result = value > 0
        print("💡 [LightControllerCard] \(control.name) - isOn via state: value=\(value), result=\(result)")
        return result
    }
    
    private var brightness: Int {
        Int(state?.value ?? 0)
    }
    
    // Check if this light controller supports dimming (via masterValue or individual circuits)
    private var supportsDimming: Bool {
        let hasMasterValue = control.states?["masterValue"] != nil
        let hasCircuits = hasMultipleCircuits
        let result = hasMasterValue || hasCircuits
        print("💡 [LightControllerCard] \(control.name) - supportsDimming: \(result) (hasMasterValue: \(hasMasterValue), hasCircuits: \(hasCircuits))")
        print("💡 [LightControllerCard] \(control.name) - available states: \(control.states?.keys.joined(separator: ", ") ?? "none")")
        return result
    }
    
    private var dimmerValue: Double {
        // For LightControllerV2, use masterValue which controls all circuits
        return masterDimmerValue
    }
    
    private var displayValue: Int {
        Int(isAdjusting ? sliderValue : dimmerValue)
    }
    
    // Get individual light circuits from subControls (these are dimmers, not scenes!)
    private var lightCircuits: [(uuid: String, name: String, control: LoxoneControl)] {
        guard let subControls = control.subControls else { return [] }
        
        // SubControls in LightControllerV2 are individual dimmable circuits
        return subControls.compactMap { (uuid, subControl) in
            let type = subControl.type.lowercased()
            // These are typically Dimmer types
            if type.contains("dimmer") || !type.isEmpty {
                print("💡 [LightControllerCard] Found light circuit: \(subControl.name) (type: \(subControl.type), uuid: \(uuid))")
                return (uuid: uuid, name: subControl.name, control: subControl)
            }
            return nil
        }.sorted { $0.name < $1.name }
    }
    
    private var hasMultipleCircuits: Bool {
        !lightCircuits.isEmpty
    }
    
    // Get the master dimmer value (controls all circuits)
    private var masterDimmerValue: Double {
        if let masterValueUUID = control.states?["masterValue"]?.uuidString,
           let masterState = stateStore.state(for: masterValueUUID) {
            return masterState.value
        }
        return 0
    }
    
    private func isSceneActive(_ sceneUUID: String) -> Bool {
        // Check if this scene is currently active
        if let activeMoodsUUID = control.states?["activeMoods"]?.uuidString,
           let _ = stateStore.state(for: activeMoodsUUID) {
            // The activeMoods value might be a bitmask or specific scene ID
            // For now, we'll check if the value matches
            // TODO: Implement proper scene active detection based on activeMoods value
            return false
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                // Icon with glow effect
                ZStack {
                    if isOn {
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .blur(radius: 8)
                    }
                    
                    Circle()
                        .fill(isOn ? Color.yellow.opacity(0.3) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.title3)
                        .foregroundStyle(isOn ? .yellow : .secondary)
                }
                
                Spacer()
                
                // Status
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isOn ? "ON" : "OFF")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(isOn ? .yellow : .secondary)
                    
                    if isOn && brightness > 0 {
                        Text("\(brightness)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Show dimmer slider if supported, otherwise show name at top
            if supportsDimming {
                // Percentage display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(displayValue)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(isOn ? .primary : .secondary)
                        .monospacedDigit()
                    
                    Text("%")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                // Slider
                Slider(
                    value: Binding(
                        get: { isAdjusting ? sliderValue : dimmerValue },
                        set: { newValue in
                            sliderValue = newValue
                            isAdjusting = true
                            debouncedSetValue(newValue)
                        }
                    ),
                    in: 0...100,
                    step: 1
                ) {
                    Text("Brightness")
                } minimumValueLabel: {
                    Image(systemName: "sun.min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "sun.max")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .tint(.yellow)
                .onAppear {
                    sliderValue = dimmerValue
                }
                .onChange(of: dimmerValue) { _, newValue in
                    if !isAdjusting {
                        sliderValue = newValue
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Name
            Text(control.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Type label
            Text("Lights")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondarySystemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOn ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.3), value: isOn)
        .onTapGesture {
            toggle()
        }
    }
    
    // MARK: - Actions
    
    private func toggle() {
        isToggling = true
        
        Task {
            await viewModel.toggleSwitch(control.uuid)
            
            // Add small delay for UI feedback
            try? await Task.sleep(nanoseconds: 200_000_000)
            isToggling = false
        }
    }
    
    private func allOff() {
        isToggling = true
        
        Task {
            await viewModel.sendCommand(control.uuid, command: "Off")
            
            // Add small delay for UI feedback
            try? await Task.sleep(nanoseconds: 200_000_000)
            isToggling = false
        }
    }
    
    private func debouncedSetValue(_ value: Double) {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            // Set the master value which controls all circuits proportionally
            if let masterValueUUID = control.states?["masterValue"]?.uuidString {
                print("💡 [LightControllerCard] Setting master value to \(Int(value))%")
                await viewModel.setDimmerValue(masterValueUUID, value: Int(value))
            } else {
                await viewModel.setDimmerValue(control.uuid, value: Int(value))
            }
            
            // Reset adjusting state after a short delay
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                isAdjusting = false
            }
        }
    }
}

// MARK: - Light Circuits Sheet

struct LightCircuitsSheet: View {
    let circuits: [(uuid: String, name: String, control: LoxoneControl)]
    let controlName: String
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(circuits, id: \.uuid) { circuit in
                    CircuitDimmerRow(
                        circuit: circuit,
                        stateStore: stateStore,
                        viewModel: viewModel
                    )
                }
            }
            .navigationTitle("Light Circuits")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Circuit Dimmer Row

struct CircuitDimmerRow: View {
    let circuit: (uuid: String, name: String, control: LoxoneControl)
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var sliderValue: Double = 0
    @State private var isAdjusting = false
    @State private var debounceTask: Task<Void, Never>?
    
    private var currentValue: Double {
        stateStore.state(for: circuit.uuid)?.value ?? 0
    }
    
    private var displayValue: Int {
        Int(isAdjusting ? sliderValue : currentValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name and value
            HStack {
                Text(circuit.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(displayValue)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(currentValue > 0 ? .yellow : .secondary)
                    .monospacedDigit()
            }
            
            // Slider
            HStack {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                
                Slider(
                    value: Binding(
                        get: { isAdjusting ? sliderValue : currentValue },
                        set: { newValue in
                            sliderValue = newValue
                            isAdjusting = true
                            debouncedSetValue(newValue)
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(.yellow)
                .onAppear {
                    sliderValue = currentValue
                }
                .onChange(of: currentValue) { _, newValue in
                    if !isAdjusting {
                        sliderValue = newValue
                    }
                }
                
                Image(systemName: "sun.max")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func debouncedSetValue(_ value: Double) {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            print("💡 [CircuitDimmerRow] Setting \(circuit.name) to \(Int(value))%")
            await viewModel.setDimmerValue(circuit.uuid, value: Int(value))
            
            // Reset adjusting state after a short delay
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                isAdjusting = false
            }
        }
    }
}


#Preview {
    HStack {
        LightControllerCard(
            control: LoxoneControl.preview(name: "Living Room Lights", type: "LightController", uuid: "light-1"),
            stateStore: DeviceStateStore(),
            viewModel: LoxoneViewModel()
        )
        
        LightControllerCard(
            control: LoxoneControl.preview(name: "Kitchen Lights On", type: "LightControllerV2", uuid: "light-2"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "light-2", value: 100)
                return store
            }(),
            viewModel: LoxoneViewModel()
        )
    }
    .padding()
}

