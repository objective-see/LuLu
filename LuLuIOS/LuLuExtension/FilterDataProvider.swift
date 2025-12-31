//
//  FilterDataProvider.swift
//  LuLuExtension
//

import NetworkExtension
import UserNotifications

class FilterDataProvider: NEFilterDataProvider {

    // Throttle rule reloading
    private var lastCheckTime: Date = Date.distantPast

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        RuleManager.shared.loadRules(force: true)

        let networkRule = NENetworkRule(remoteNetwork: nil,
                                        remotePrefix: 0,
                                        localNetwork: nil,
                                        localPrefix: 0,
                                        protocol: .any,
                                        direction: .outbound)

        let filterRule = NEFilterRule(networkRule: networkRule, action: .filterData)
        let settings = NEFilterSettings(rules: [filterRule], defaultAction: .allow)

        self.apply(settings) { error in
            if let error = error {
                NSLog("LuLu: Failed to apply settings: \(error)")
            }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let socketFlow = flow as? NEFilterSocketFlow,
              let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint else {
            return .allow()
        }

        // Reload rules efficiently (checks modification date)
        RuleManager.shared.loadRules()

        // Use standard iOS API for bundle ID
        var bundleID = "unknown"
        if let sourceID = flow.sourceAppIdentifier {
            bundleID = sourceID
        } else if let sourceAppAuditToken = flow.sourceAppAuditToken {
            // Fallback: try to derive from audit token if possible (though restricted)
            // or just log it. For now, we stick to public API or "unknown".
             bundleID = "system/unknown"
        }

        let endpoint = remoteEndpoint.hostname
        let port = remoteEndpoint.port

        if bundleID.contains("objective-see.lulu") {
            return .allow()
        }

        if let rule = RuleManager.shared.findRule(bundleID: bundleID, endpoint: endpoint, port: port) {
            if rule.action == .block {
                return .drop()
            } else {
                return .allow()
            }
        }

        // Unclassified
        let pending = PendingConnection(bundleID: bundleID, endpoint: endpoint, port: port)

        // Only notify if it's a NEW pending connection
        if RuleManager.shared.addPendingConnection(pending) {
            sendNotification(bundleID: bundleID, endpoint: endpoint, port: port)
        }

        return .allow()
    }

    private func sendNotification(bundleID: String, endpoint: String, port: String) {
        let content = UNMutableNotificationContent()
        content.title = "LuLu: New Connection"
        content.body = "\(bundleID) wants to connect to \(endpoint):\(port)"
        content.sound = .default
        content.categoryIdentifier = SharedConstants.unclassifiedNotificationCategory
        content.userInfo = [
            "bundleID": bundleID,
            "endpoint": endpoint,
            "port": port
        ]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("LuLu: Failed to send notification: \(error)")
            }
        }
    }
}
