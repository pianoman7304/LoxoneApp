//
//  JalousieCard.swift
//  Loxone App
//
//  Device card for blinds/jalousie controls with up/stop/down buttons
//

import SwiftUI

struct JalousieCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var isAnimating = false
    
    private var state: DeviceState? {
        // First try to get state from the control's "position" or "up" state UUID
        if let positionStateUUID = control.states?["position"]?.uuidString,
           let positionState = stateStore.state(for: positionStateUUID) {
            return positionState
        }
        
        if let upStateUUID = control.states?["up"]?.uuidString,
           let upState = stateStore.state(for: upStateUUID) {
            return upState
        }
        
        // Fallback to the control's main UUID
        return stateStore.state(for: control.uuid)
    }
    
    private var position: Int {
        Int(state?.value ?? 0)
    }
    
    private var isFullyOpen: Bool {
        position == 0
    }
    
    private var isFullyClosed: Bool {
        position >= 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Animated blind icon
                blindIcon
                
                Spacer()
                
                // Position indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(position)%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text(positionLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Visual position indicator
            positionBar
            
            Spacer()
            
            // Control buttons
            controlButtons
            
            // Name
            Text(control.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding()
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondarySystemBackground)
        )
    }
    
    // MARK: - Blind Icon
    
    private var blindIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 44, height: 44)
            
            VStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(slotColor(for: index))
                        .frame(width: 28, height: 6)
                }
            }
        }
    }
    
    private func slotColor(for index: Int) -> Color {
        let threshold = Double(index + 1) / 4.0 * 100
        return position >= Int(threshold) ? .primary : .secondary.opacity(0.3)
    }
    
    // MARK: - Position Label
    
    private var positionLabel: String {
        if isFullyOpen {
            return "Open"
        } else if isFullyClosed {
            return "Closed"
        } else {
            return "Partial"
        }
    }
    
    // MARK: - Position Bar
    
    private var positionBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                
                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(position) / 100)
            }
        }
        .frame(height: 8)
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Up button
            ControlButton(
                icon: "chevron.up",
                label: "Up",
                isDisabled: isFullyOpen,
                color: .blue
            ) {
                sendCommand(.fullUp)
            }
            
            // Stop button
            ControlButton(
                icon: "stop.fill",
                label: "Stop",
                isDisabled: false,
                color: .orange
            ) {
                sendCommand(.stop)
            }
            
            // Down button
            ControlButton(
                icon: "chevron.down",
                label: "Down",
                isDisabled: isFullyClosed,
                color: .blue
            ) {
                sendCommand(.fullDown)
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendCommand(_ command: JalousieCommand) {
        Task {
            await viewModel.sendJalousieCommand(control.uuid, command: command)
        }
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let label: String
    let isDisabled: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.headline)
                
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDisabled ? Color.secondary.opacity(0.1) : color.opacity(0.15))
            )
            .foregroundStyle(isDisabled ? .secondary : color)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    HStack {
        JalousieCard(
            control: LoxoneControl.preview(name: "Living Room Blinds", type: "Jalousie", uuid: "blind-1"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "blind-1", value: 0)
                return store
            }(),
            viewModel: LoxoneViewModel()
        )
        
        JalousieCard(
            control: LoxoneControl.preview(name: "Bedroom Blinds", type: "Jalousie", uuid: "blind-2"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "blind-2", value: 50)
                return store
            }(),
            viewModel: LoxoneViewModel()
        )
    }
    .padding()
}

