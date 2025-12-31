//
//  LuLuApp.swift
//  LuLuIOS
//

import SwiftUI
import NetworkExtension
import UserNotifications

@main
struct LuLuApp: App {
    @StateObject var viewModel = AppViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    viewModel.requestPermissions()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        viewModel.refresh()
                    }
                }
        }
    }
}

class AppViewModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var rules: [Rule] = []
    @Published var unclassifiedConnections: [PendingConnection] = []

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        refresh()
    }

    func refresh() {
        RuleManager.shared.loadRules()
        RuleManager.shared.loadPendingConnections()
        self.rules = RuleManager.shared.getRules()
        self.unclassifiedConnections = RuleManager.shared.getPendingConnections()
    }

    func requestPermissions() {
        // Network Extension
        NEFilterManager.shared().loadFromPreferences { error in
            if let error = error {
                print("Failed to load filter preferences: \(error)")
                return
            }

            if NEFilterManager.shared().providerConfiguration == nil {
                let config = NEFilterProviderConfiguration()
                config.filterSockets = true
                config.filterPackets = false
                NEFilterManager.shared().providerConfiguration = config
                NEFilterManager.shared().appName = "LuLu"
                NEFilterManager.shared().isEnabled = true

                NEFilterManager.shared().saveToPreferences { error in
                    if let error = error {
                        print("Failed to save filter preferences: \(error)")
                    }
                }
            } else {
                NEFilterManager.shared().isEnabled = true
                NEFilterManager.shared().saveToPreferences { _ in }
            }
        }

        // Notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }

    func addRule(connection: PendingConnection, action: RuleAction) {
        let rule = Rule(bundleID: connection.bundleID,
                        endpointAddr: connection.endpoint,
                        endpointPort: connection.port,
                        action: action)
        RuleManager.shared.addRule(rule)

        // Remove from pending
        RuleManager.shared.removePendingConnection(id: connection.id)

        refresh()
    }

    func deleteRule(at offsets: IndexSet) {
        let rulesToDelete = offsets.map { rules[$0] }
        for rule in rulesToDelete {
            RuleManager.shared.removeRule(id: rule.id)
        }
        refresh()
    }

    func deletePending(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { unclassifiedConnections[$0] }
        for item in itemsToDelete {
            RuleManager.shared.removePendingConnection(id: item.id)
        }
        refresh()
    }

    // Handle Notification Tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Refresh when opened from notification
        DispatchQueue.main.async {
            self.refresh()
        }
        completionHandler()
    }

    // Foreground Notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Refresh list if app is open
        DispatchQueue.main.async {
            self.refresh()
        }
        completionHandler([.banner, .sound])
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            // Unclassified / Recent Tab
            NavigationView {
                List {
                    if viewModel.unclassifiedConnections.isEmpty {
                        Text("No recent unclassified connections")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(viewModel.unclassifiedConnections) { conn in
                            VStack(alignment: .leading) {
                                Text(conn.bundleID).font(.headline)
                                Text("\(conn.endpoint):\(conn.port)").font(.subheadline)
                                Text(conn.timestamp, style: .time).font(.caption).foregroundColor(.gray)
                                HStack {
                                    Button("Block") {
                                        viewModel.addRule(connection: conn, action: .block)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)

                                    Button("Allow") {
                                        viewModel.addRule(connection: conn, action: .allow)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: viewModel.deletePending)
                    }
                }
                .navigationTitle("New Connections")
                .refreshable {
                    viewModel.refresh()
                }
            }
            .tabItem {
                Label("Alerts", systemImage: "bell")
            }

            // Rules Tab
            NavigationView {
                List {
                    ForEach(viewModel.rules) { rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.bundleID).font(.headline)
                                Text("\(rule.endpointAddr):\(rule.endpointPort)").font(.caption)
                            }
                            Spacer()
                            Text(rule.action == .allow ? "ALLOW" : "BLOCK")
                                .foregroundColor(rule.action == .allow ? .green : .red)
                                .fontWeight(.bold)
                        }
                    }
                    .onDelete(perform: viewModel.deleteRule)
                }
                .navigationTitle("Rules")
                .refreshable {
                    viewModel.refresh()
                }
            }
            .tabItem {
                Label("Rules", systemImage: "list.bullet")
            }
        }
    }
}
