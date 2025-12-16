//
//  DimmerCard.swift
//  Loxone App
//
//  Device card for dimmers with slider control
//

import SwiftUI

struct DimmerCard: View {
    let control: LoxoneControl
    @ObservedObject var stateStore: DeviceStateStore
    @ObservedObject var viewModel: LoxoneViewModel
    
    @State private var sliderValue: Double = 0
    @State private var isAdjusting = false
    @State private var debounceTask: Task<Void, Never>?
    
    private var state: DeviceState? {
        // First try to get state from the control's "position" or "value" state UUID
        if let positionStateUUID = control.states?["position"]?.uuidString,
           let positionState = stateStore.state(for: positionStateUUID) {
            return positionState
        }
        
        if let valueStateUUID = control.states?["value"]?.uuidString,
           let valueState = stateStore.state(for: valueStateUUID) {
            return valueState
        }
        
        // Fallback to the control's main UUID
        return stateStore.state(for: control.uuid)
    }
    
    private var currentValue: Double {
        state?.value ?? 0
    }
    
    private var isOn: Bool {
        currentValue > 0
    }
    
    private var displayValue: Int {
        Int(isAdjusting ? sliderValue : currentValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with toggle
            HStack {
                // Icon with brightness indicator
                ZStack {
                    Circle()
                        .fill(isOn ? Color.yellow.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isOn ? "sun.max.fill" : "sun.max")
                        .font(.title3)
                        .foregroundStyle(isOn ? .yellow : .secondary)
                }
                
                Spacer()
                
                // Toggle button
                Button {
                    toggleOnOff()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOn ? Color.yellow : Color.secondary.opacity(0.5))
                            .frame(width: 8, height: 8)
                        
                        Text(isOn ? "ON" : "OFF")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(isOn ? .yellow : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isOn ? Color.yellow.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Percentage display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(displayValue)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .monospacedDigit()
                
                Text("%")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Slider
            VStack(spacing: 4) {
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
                .disabled(!isOn && currentValue == 0)
                .onAppear {
                    sliderValue = currentValue
                }
                .onChange(of: currentValue) { _, newValue in
                    if !isAdjusting {
                        sliderValue = newValue
                    }
                }
            }
            
            Spacer()
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(control.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Dimmer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(height: 200)
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
    
    private func debouncedSetValue(_ value: Double) {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await viewModel.setDimmerValue(control.uuid, value: Int(value))
            
            // Reset adjusting state after a short delay
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                isAdjusting = false
            }
        }
    }
    
    private func toggleOnOff() {
        Task {
            if isOn {
                await viewModel.setDimmerValue(control.uuid, value: 0)
            } else {
                await viewModel.setDimmerValue(control.uuid, value: 100)
            }
        }
    }
}

#Preview {
    HStack {
        DimmerCard(
            control: LoxoneControl.preview(name: "Dining Light", type: "Dimmer"),
            stateStore: DeviceStateStore(),
            viewModel: LoxoneViewModel()
        )
        
        DimmerCard(
            control: LoxoneControl.preview(name: "Reading Light", type: "Dimmer", uuid: "dimmer-on"),
            stateStore: {
                let store = DeviceStateStore()
                store.update(uuid: "dimmer-on", value: 75)
                return store
            }(),
            viewModel: LoxoneViewModel()
        )
    }
    .padding()
}

