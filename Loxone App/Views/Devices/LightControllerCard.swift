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
    
    @State private var showScenes = false
    @State private var isToggling = false
    
    private var state: DeviceState? {
        // First try to get state from the control's "activeMoods" or "activeScene" state UUID
        if let activeMoodsUUID = control.states?["activeMoods"]?.uuidString,
           let activeMoodsState = stateStore.state(for: activeMoodsUUID) {
            return activeMoodsState
        }
        
        if let activeSceneUUID = control.states?["activeScene"]?.uuidString,
           let activeSceneState = stateStore.state(for: activeSceneUUID) {
            return activeSceneState
        }
        
        // Fallback to the control's main UUID
        return stateStore.state(for: control.uuid)
    }
    
    private var isOn: Bool {
        (state?.value ?? 0) > 0
    }
    
    private var brightness: Int {
        Int(state?.value ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            Spacer()
            
            // Name
            Text(control.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            // Quick actions
            HStack(spacing: 8) {
                // Toggle button
                Button {
                    toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                        Text(isOn ? "Turn Off" : "Turn On")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isOn ? Color.secondary.opacity(0.15) : Color.yellow.opacity(0.2))
                    )
                    .foregroundStyle(isOn ? Color.secondary : Color.yellow)
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
                .opacity(isToggling ? 0.6 : 1.0)
                
                // All Off button (common for light controllers)
                Button {
                    allOff()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "moon.fill")
                            .font(.caption)
                        Text("All Off")
                            .font(.caption2)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
            }
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
}

// MARK: - Scene Button

struct SceneButton: View {
    let name: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.yellow.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .foregroundStyle(isActive ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
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

