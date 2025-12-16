//
//  FloorEditView.swift
//  Loxone App
//
//  View for adding/editing floor groups
//

import SwiftUI

enum FloorEditMode: Identifiable {
    case add
    case edit(Floor)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let floor):
            return floor.id.uuidString
        }
    }
    
    var title: String {
        switch self {
        case .add:
            return "New Floor"
        case .edit:
            return "Edit Floor"
        }
    }
}

struct FloorEditView: View {
    let mode: FloorEditMode
    @ObservedObject var viewModel: LoxoneViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "house"
    
    private let iconOptions = [
        "house", "house.fill",
        "stairs", "arrow.up.to.line",
        "square.stack.3d.down.right", "archivebox",
        "leaf", "tree",
        "sun.max", "cloud.sun",
        "car", "car.fill",
        "figure.walk", "person.2",
        "bed.double", "sofa",
        "fork.knife", "cup.and.saucer",
        "shower", "drop",
        "wrench", "gearshape"
    ]
    
    private let columns = Array(repeating: GridItem(.adaptive(minimum: 44)), count: 6)
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon
                            ) {
                                selectedIcon = icon
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(mode.title)
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadExistingData() {
        switch mode {
        case .add:
            name = ""
            selectedIcon = "house"
        case .edit(let floor):
            name = floor.name
            selectedIcon = floor.icon
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        switch mode {
        case .add:
            viewModel.createFloor(name: trimmedName, icon: selectedIcon)
        case .edit(let floor):
            viewModel.updateFloor(floor, name: trimmedName, icon: selectedIcon)
        }
        
        dismiss()
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? Color.accentColor : Color.secondarySystemBackground
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Add") {
    FloorEditView(mode: .add, viewModel: LoxoneViewModel())
}

