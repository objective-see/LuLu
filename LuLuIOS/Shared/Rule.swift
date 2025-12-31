//
//  Rule.swift
//  LuLuIOS
//

import Foundation

enum RuleAction: Int, Codable {
    case allow = 0
    case block = 1
}

struct Rule: Codable, Identifiable {
    var id: String // UUID
    var bundleID: String // "com.apple.shortcuts" or "ANY"
    var endpointAddr: String // "google.com", "192.168.1.1", or "ANY"
    var endpointPort: String // "80", "443" or "ANY"
    var action: RuleAction
    var isRegex: Bool
    var isGlobal: Bool

    // For specific process matching if possible (optional)
    var teamID: String?

    init(id: String = UUID().uuidString,
         bundleID: String,
         endpointAddr: String = "ANY",
         endpointPort: String = "ANY",
         action: RuleAction,
         isRegex: Bool = false,
         isGlobal: Bool = false,
         teamID: String? = nil) {
        self.id = id
        self.bundleID = bundleID
        self.endpointAddr = endpointAddr
        self.endpointPort = endpointPort
        self.action = action
        self.isRegex = isRegex
        self.isGlobal = isGlobal
        self.teamID = teamID
    }
}
