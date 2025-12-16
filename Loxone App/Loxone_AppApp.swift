//
//  Loxone_AppApp.swift
//  Loxone App
//
//  Created by Oliver Wyrsch on 12/16/25.
//

import SwiftUI
import SwiftData

@main
struct Loxone_AppApp: App {
    // SwiftData model container
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                Floor.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Register background tasks
        NotificationService.registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        #endif
        
        #if os(macOS)
        Settings {
            SettingsWindowView()
                .modelContainer(modelContainer)
        }
        #endif
    }
}

// MARK: - macOS Settings Window

#if os(macOS)
struct SettingsWindowView: View {
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var viewModel = LoxoneViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            ConnectionSettingsView(userViewModel: userViewModel)
                .tabItem {
                    Label("Connection", systemImage: "server.rack")
                }
            
            NotificationSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            viewModel.setModelContext(modelContext)
            userViewModel.setModelContext(modelContext)
        }
    }
}
#endif
