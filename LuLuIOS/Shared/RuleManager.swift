//
//  RuleManager.swift
//  LuLuIOS
//

import Foundation

struct PendingConnection: Codable, Identifiable {
    var id: String
    var bundleID: String
    var endpoint: String
    var port: String
    var timestamp: Date

    init(bundleID: String, endpoint: String, port: String) {
        self.id = UUID().uuidString
        self.bundleID = bundleID
        self.endpoint = endpoint
        self.port = port
        self.timestamp = Date()
    }
}

class RuleManager {
    static let shared = RuleManager()

    // Shared container URL (App Group)
    private let appGroupIdentifier = "group.com.objective-see.lulu.ios"

    private var containerURL: URL? {
        let fileManager = FileManager.default
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) ??
               fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private var rulesFileURL: URL? { containerURL?.appendingPathComponent("rules.json") }
    private var pendingFileURL: URL? { containerURL?.appendingPathComponent("pending.json") }

    private var rules: [Rule] = []
    private var pendingConnections: [PendingConnection] = []

    private var lastRulesLoadTime: Date = Date.distantPast
    private var lastRulesModificationDate: Date?

    init() {
        loadRules()
        loadPendingConnections()
    }

    // MARK: - Rules
    func loadRules(force: Bool = false) {
        guard let url = rulesFileURL else { return }

        // Throttling / Attribute Check
        if !force {
            // Check file modification date
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let modificationDate = attributes?[.modificationDate] as? Date

            if let modificationDate = modificationDate,
               let lastMod = lastRulesModificationDate,
               modificationDate <= lastMod {
                // File hasn't changed
                return
            }
            lastRulesModificationDate = modificationDate
        }

        guard let data = try? Data(contentsOf: url),
              let loadedRules = try? JSONDecoder().decode([Rule].self, from: data) else {
            return
        }
        self.rules = loadedRules
        self.lastRulesLoadTime = Date()
    }

    func saveRules() {
        guard let url = rulesFileURL,
              let data = try? JSONEncoder().encode(rules) else {
            return
        }
        try? data.write(to: url)
        // Update local modification date to avoid reload loop
        lastRulesModificationDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    func addRule(_ rule: Rule) {
        rules.append(rule)
        saveRules()
    }

    func getRules() -> [Rule] {
        return rules
    }

    func removeRule(id: String) {
        rules.removeAll { $0.id == id }
        saveRules()
    }

    // MARK: - Pending Connections
    func loadPendingConnections() {
        guard let url = pendingFileURL,
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([PendingConnection].self, from: data) else {
            return
        }
        self.pendingConnections = loaded
    }

    func savePendingConnections() {
        guard let url = pendingFileURL,
              let data = try? JSONEncoder().encode(pendingConnections) else {
            return
        }
        try? data.write(to: url)
    }

    /// Adds a pending connection. Returns true if it was new, false if it already existed.
    func addPendingConnection(_ conn: PendingConnection) -> Bool {
        // Avoid duplicates for same bundle+endpoint
        if !pendingConnections.contains(where: { $0.bundleID == conn.bundleID && $0.endpoint == conn.endpoint && $0.port == conn.port }) {
            pendingConnections.insert(conn, at: 0)
            // Limit size
            if pendingConnections.count > 100 {
                pendingConnections.removeLast()
            }
            savePendingConnections()
            return true
        }
        return false
    }

    func removePendingConnection(id: String) {
        pendingConnections.removeAll { $0.id == id }
        savePendingConnections()
    }

    func getPendingConnections() -> [PendingConnection] {
        return pendingConnections
    }

    // MARK: - Logic
    func findRule(bundleID: String, endpoint: String, port: String) -> Rule? {
        let candidates = rules.filter { rule in
            let bundleMatch = (rule.bundleID == bundleID) || (rule.bundleID == "ANY") || rule.isGlobal
            return bundleMatch
        }

        var bestMatch: Rule?
        var bestScore = -1

        for rule in candidates {
            var score = 0

            if rule.bundleID == bundleID { score += 10 }
            else if rule.bundleID == "ANY" { score += 1 }

            if rule.endpointAddr == endpoint { score += 5 }
            else if rule.endpointAddr == "ANY" { score += 0 }
            else if rule.isRegex {
                if endpoint.range(of: rule.endpointAddr, options: .regularExpression) != nil {
                    score += 4
                } else {
                    continue
                }
            } else {
                continue
            }

            if rule.endpointPort == port { score += 3 }
            else if rule.endpointPort == "ANY" { score += 0 }
            else {
                continue
            }

            if score > bestScore {
                bestScore = score
                bestMatch = rule
            }
        }

        return bestMatch
    }
}
