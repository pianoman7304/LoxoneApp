//
//  SwitchCard.swift
//  Loxone App
//
//  Device card for switches and pushbuttons
//

import SwiftUI

struct SwitchCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var isToggling = false
    
    private var state: DeviceState? {
        // First try to get state from the control's "active" state UUID
        if let activeStateUUID = control.states?["active"]?.uuidString,
           let activeState = stateStore.state(for: activeStateUUID) {
            return activeState
        }
        
        // Fallback to the control's main UUID
        return stateStore.state(for: control.uuid)
    }
    
    private var isOn: Bool {
        state?.isOn ?? false
    }
    
    var body: some View {
        Button {
            toggle()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .opacity(isToggling ? 0.6 : 1.0)
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Icon with glow effect when on
                ZStack {
                    if isOn {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .blur(radius: 8)
                    }
                    
                    Circle()
                        .fill(isOn ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isOn ? "power.circle.fill" : "power.circle")
                        .font(.title2)
                        .foregroundStyle(isOn ? .green : .secondary)
                }
                
                Spacer()
                
                // Status indicator
                statusBadge
            }
            
            Spacer()
            
            // Large ON/OFF indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(isOn ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .shadow(color: isOn ? .green.opacity(0.5) : .clear, radius: 4)
                
                Text(isOn ? "ON" : "OFF")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            
            // Name
            Text(control.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // Type
            Text("Switch")
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
                .stroke(isOn ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.3), value: isOn)
        .animation(.easeInOut(duration: 0.2), value: isToggling)
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOn ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            
            Text(isOn ? "ON" : "OFF")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(isOn ? .green : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isOn ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
        )
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
}

#Preview {
    HStack {
        SwitchCard(
            control: LoxoneControl.preview(name: "Living Room Light", type: "Switch"),
            stateStore: DeviceStateStore(),
            viewModel: LoxoneViewModel()
        )
        
        SwitchCard(
            control: LoxoneControl.preview(name: "Kitchen Light On", type: "Switch"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "preview-on", value: 1)
                return store
            }(),
            viewModel: LoxoneViewModel()
        )
    }
    .padding()
}

// MARK: - Preview Helpers

extension LoxoneControl {
    static func preview(name: String, type: String, uuid: String = "preview") -> LoxoneControl {
        // Create a mock control for previews
        let jsonString = """
        {
            "uuid": "\(uuid)",
            "name": "\(name)",
            "type": "\(type)"
        }
        """
        let data = jsonString.data(using: .utf8)!
        return try! JSONDecoder().decode(LoxoneControl.self, from: data)
    }
}

