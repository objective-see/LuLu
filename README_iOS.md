# LuLu for iOS (TrollStore Edition)

This directory contains the source code to convert LuLu (macOS Firewall) into an iOS App compatible with TrollStore (iOS 15+ Rootless).

## Architecture

*   **LuLuApp**: The main iOS Application (SwiftUI). It manages rules and displays alerts for new connections.
*   **LuLuExtension**: A Network Extension (`NEFilterDataProvider`) that intercepts network traffic, checks against rules, and notifies the user.
*   **Shared**: Logic shared between the App and Extension (Data Models, Persistence).

## Installation Instructions

Since this project requires specific entitlements and a complex setup, follow these steps to compile it:

### 1. Create Xcode Project
1.  Open Xcode and create a new Project -> **App**.
2.  Name it `LuLu`.
3.  Interface: **SwiftUI**.
4.  Language: **Swift**.

### 2. Add Network Extension Target
1.  In Xcode, go to File -> New -> Target.
2.  Select **Network Extension**.
3.  Name it `LuLuExtension`.
4.  Choose "Filter Data" (Content Filter) as the provider type if asked, or just ensure the `Info.plist` matches the one provided.

### 3. Setup App Groups
*   **Crucial Step**: Both the App and the Extension must share data.
1.  Select the `LuLu` target -> **Signing & Capabilities**.
2.  Click `+ Capability` -> **App Groups**.
3.  Add a new group: `group.com.objective-see.lulu.ios`.
4.  Repeat this for the `LuLuExtension` target. Ensure both have the *exact same* App Group checked.

### 4. Add Source Files
Copy the files from this repository into your Xcode project structure:

*   **Shared Files** (Add to **BOTH** `LuLu` and `LuLuExtension` targets):
    *   `LuLuIOS/Shared/Rule.swift`
    *   `LuLuIOS/Shared/RuleManager.swift`
    *   `LuLuIOS/Shared/SharedConstants.swift`

*   **App Files** (Add to `LuLu` target):
    *   `LuLuIOS/LuLuApp/ContentView.swift` (Replace the default one)
    *   `LuLuIOS/LuLuApp/LuLuApp.swift` (Replace the default one)

*   **Extension Files** (Add to `LuLuExtension` target):
    *   `LuLuIOS/LuLuExtension/FilterDataProvider.swift` (Replace the default one)

### 5. Configure Entitlements & Info.plist
*   Ensure your `Info.plist` and `.entitlements` files contain the keys found in `LuLuIOS/LuLuApp/LuLuApp.entitlements` and `LuLuIOS/LuLuExtension/LuLuExtension.entitlements`.
*   Specifically, `com.apple.developer.networking.networkextension` is required.

### 6. Build & Install
1.  Build the project.
2.  Export the `.ipa`.
3.  **Important**: Install using **TrollStore**. Standard installation methods (AltStore/Sideloadly) might not grant the necessary entitlements for the Network Extension to function fully in the background without a VPN profile, or might restrict the Content Filter capability.

## Usage
1.  Open LuLu on iOS.
2.  Grant **Notification** and **Network Extension** permissions when prompted.
3.  The app will default to **Allow & Notify** mode.
4.  When an app connects to the internet, you will receive a notification.
5.  Open LuLu to see the "New Connections" list and decide to **Block** or **Allow** them permanently.
