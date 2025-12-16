//
//  ExpertMenuView.swift
//  Loxone App
//
//  Placeholder for expert configuration features (Phase 2)
//

import SwiftUI

struct ExpertMenuView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    
                    Text("Expert Configuration")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Coming Soon")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Description
                VStack(alignment: .leading, spacing: 16) {
                    Text("Advanced Loxone configuration options will be available here in a future update.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Planned Features")
                        .font(.headline)
                    
                    // Feature list
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "slider.horizontal.3", title: "Control Configuration", description: "Customize device settings and behaviors")
                        
                        FeatureRow(icon: "clock.arrow.circlepath", title: "Schedules & Timers", description: "Create and manage automation schedules")
                        
                        FeatureRow(icon: "theatermasks", title: "Scene Management", description: "Create and edit lighting scenes")
                        
                        FeatureRow(icon: "link", title: "Input/Output Mapping", description: "Configure physical I/O connections")
                        
                        FeatureRow(icon: "network", title: "Network Settings", description: "View and configure network parameters")
                        
                        FeatureRow(icon: "doc.text", title: "Logs & Diagnostics", description: "View system logs and run diagnostics")
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Expert Mode")
        .inlineNavigationBarTitle()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ExpertMenuView()
    }
}

