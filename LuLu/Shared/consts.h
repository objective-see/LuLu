//
//  file: consts.h
//  project: lulu (shared)
//  description: #defines and what not
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef consts_h
#define consts_h

//signers
enum Signer{None, Apple, AppStore, DevID, AdHoc};

//patreon url
#define PATREON_URL @"https://www.patreon.com/join/objective_see"

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objectiveSee"

//bundle ID
#define BUNDLE_ID "com.objective-see.lulu"

//extension bundle ID
#define EXT_BUNDLE_ID @"com.objective-see.lulu.extension"

//main app bundle id
#define APP_ID @"com.objective-see.lulu.app"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//firewall event: new flow
#define LULU_EVENT @"com.objective-see.lulu.event"

//lulu service
#define LULU_SERVICE_NAME "com_objective_see_firewall"

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/LuLu"

//preferences file
#define PREFS_FILE @"preferences.plist"

//rules file
#define RULES_FILE @"rules.plist"

//(old) rules file
#define RULES_FILE_V1 @"rules_v1.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"VBG97UB4TA.com.objective-see.lulu"

//rule state; not found
#define RULE_STATE_NOT_FOUND -1

//rule state; block
#define RULE_STATE_BLOCK 0

//rule state; allow
#define RULE_STATE_ALLOW 1

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.org/products.json"

//product key
#define PRODUCT_KEY @"LuLu"

//product url
#define PRODUCT_URL @"https://objective-see.org/products/lulu.html"

//error(s) url
#define ERRORS_URL @"https://objective-see.org/errors.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//install cmd
#define CMD_INSTALL @"-install"

//uninstall cmd
#define CMD_UNINSTALL @"-uninstall"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag for partial uninstall
// leave preferences file, etc.
#define UNINSTALL_PARTIAL 0

//flag for full uninstall
#define UNINSTALL_FULL 1

//add rule, block
#define BUTTON_BLOCK 0

//add rule, allow
#define BUTTON_ALLOW 1

//login item name
#define LOGIN_ITEM_NAME @"LuLu Helper"

//prefs
// disabled status
#define PREF_IS_DISABLED @"disabled"

//prefs
// passive mode, & rules/action
#define PREF_PASSIVE_MODE @"passiveMode"
#define PREF_PASSIVE_MODE_RULES @"passiveModeRules"
#define PREF_PASSIVE_MODE_ACTION @"passiveModeAction"

//index of allow/block in passive mode action
#define PREF_PASSIVE_MODE_ALLOW 0
#define PREF_PASSIVE_MODE_BLOCK 1

//index of no/yes in passive mode action
#define PREF_PASSIVE_MODE_RULES_NO 0
#define PREF_PASSIVE_MODE_RULES_YES 1

//prefs
// block mode
#define PREF_BLOCK_MODE @"blockMode"

//prefs
// icon mode
#define PREF_NO_ICON_MODE @"noIconMode"

//prefs
// no VT mode
#define PREF_NO_VT_MODE @"noVTMode"

//prefs
// update mode
#define PREF_NO_UPDATE_MODE @"noupdateMode"

//prefs
// allow all apple binaries
#define PREF_ALLOW_APPLE @"allowApple"

//prefs
// allow all installed
#define PREF_ALLOW_INSTALLED @"allowInstalled"

//prefs
// allow dns traffic
#define PREF_ALLOW_DNS @"allowDNS"

//prefs
// allow simulator apps
#define PREF_ALLOW_SIMULATOR @"allowSimulatorApps"

//use global block list
#define PREF_USE_BLOCK_LIST @"useBlockList"

//use global allow list
#define PREF_USE_ALLOW_LIST @"useAllowList"

//global allow list
#define PREF_ALLOW_LIST @"allowList"

//global block list
#define PREF_BLOCK_LIST @"blockList"

//install time
// not really a 'pref' but need to save it
#define PREF_INSTALL_TIMESTAMP @"installTime"

//show alert options
// not really a 'pref' but need to save it
#define PREF_ALERT_SHOW_OPTIONS @"alertShowOptions"

//show alert options
// not really a 'pref' but need to save it
#define PREF_ALERT_LAST_ACTION_SCOPE @"alertLastActionScope"

//log file
#define LOG_FILE_NAME @"LuLu.log"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//key for exit code
#define EXIT_CODE @"exitCode"

//key for error msg
#define KEY_ERROR_MSG @"errorMsg"

//key for error sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//rules changed
#define RULES_CHANGED @"com.objective-see.lulu.rulesChanged"

//extension event
#define EXTENSION_EVENT @"com.objective-see.lulu.extensionEvent"

/* INSTALLER */

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/LuLu"

//launch daemon name
#define LAUNCH_DAEMON_BINARY @"LuLu"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"com.objective-see.lulu.plist"

//installed apps file
#define INSTALLED_APPS @"installedApps"

//DON'T need/cleanup
//finder
#define FINDER_APP @"/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"

//frame shift
// for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//button title: restart
#define ACTION_RESTART @"Restart"

//flag to reboot
#define ACTION_RESTART_FLAG -1

//cmdline flag to uninstall
#define ACTION_UNINSTALL @"-uninstall"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//cmdline flag to uninstall
#define ACTION_INSTALL @"-install"

//flag to install
#define ACTION_INSTALL_FLAG 1

//button title: upgrade
#define ACTION_UPGRADE @"Upgrade"

//button title: close
#define ACTION_CLOSE @"Close"

//flag to close
#define ACTION_CLOSE_FLAG 2

//button title: next
#define ACTION_NEXT @"Next »"

//next
#define ACTION_NEXT_FLAG 3

//app name
#define APP_NAME @"LuLu.app"

#define CMDLINE_FLAG_WELCOME @"-welcome"
#define CMDLINE_FLAG_PREFS @"-prefs"
#define CMDLINE_FLAG_RULES @"-rules"

#define KEY_PATHS @"paths"
#define KEY_RULES @"rules"

#define KEY_ID @"id"
#define KEY_PATH @"path"
#define KEY_KEY @"key"

#define KEY_CS_ID @"signatureIdentifier"
#define KEY_CS_INFO @"signingInfo"
#define KEY_CS_AUTHS @"signatureAuthorities"
#define KEY_CS_SIGNER @"signatureSigner"
#define KEY_CS_STATUS @"signatureStatus"
#define KEY_CS_ENTITLEMENTS @"signatureEntitlements"

#define KEY_TYPE @"type"

#define KEY_SCOPE @"scope"
#define KEY_ACTION @"action"
#define KEY_DURATION_PROCESS @"durationProcess"
#define KEY_DURATION_EXPIRATION @"durationExpiration"

#define KEY_ENDPOINT_ADDR @"endpointAddr"
#define KEY_ENDPOINT_PORT @"endpointPort"

#define KEY_ENDPOINT_ADDR_IS_REGEX @"endpointAddrIsRegex"

#define KEY_CS_CHANGE @"csChange"

#define KEY_UUID @"uuid"
#define KEY_PROCESS_ID @"pid"
#define KEY_PROCESS_ARGS @"args"
#define KEY_PROCESS_NAME @"name"
#define KEY_PROCESS_PATH @"path"

#define KEY_PROCESS_DELETED @"deleted"

#define KEY_PROCESS_ANCESTORS @"ancestors"

#define KEY_HOST @"host"
#define KEY_URL @"url"
#define KEY_PROTOCOL @"protocol"
#define KEY_ENDPOINT @"endpoint"

#define KEY_INDEX @"index"

#define KEY_USER_ID @"userID"

#define VALUE_ANY @"*"


//keys for rule dictionary
#define RULE_ID @"id"
#define RULE_PATH @"path"
#define RULE_HASH @"hash"
#define RULE_TYPE @"type"
#define RULE_USER @"user"
#define RULE_ACTION @"action"
#define RULE_SIGNING_INFO @"signingInfo"

//rules types
#define RULE_TYPE_ALL     -1
#define RULE_TYPE_DEFAULT  0
#define RULE_TYPE_APPLE    1
#define RULE_TYPE_BASELINE 2
#define RULE_TYPE_USER     3
#define RULE_TYPE_RECENT   4

//search (filter) field
#define RULE_SEARCH_FIELD 5

//network monitor
#define NETWORK_MONITOR @"Netiquette.app"

//scope for action
// from dropdown in alert window
#define ACTION_SCOPE_UNSELECTED -1
#define ACTION_SCOPE_PROCESS 0
#define ACTION_SCOPE_ENDPOINT 1

//signing info (from ESF)
#define CS_FLAGS @"csFlags"
#define PLATFORM_BINARY @"platformBinary"
#define TEAM_ID @"teamID"
#define SIGNING_ID @"signingID"

//rules window
#define WINDOW_RULES 0

//preferences window
#define WINDOW_PREFERENCES 1

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

/* MAIN APP */

//1st welcome view
#define WELCOME_VIEW_ONE 1

//2nd welcome view
#define WELCOME_VIEW_TWO 2

//3rd welcome view
#define WELCOME_VIEW_THREE 3

//cs consts
// from: cs_blobs.h
#define CS_VALID 0x00000001
#define CS_RUNTIME 0x00010000

//deactivate
#define ACTION_DEACTIVATE 0

//activate
#define ACTION_ACTIVATE 1

//rules menu
#define MENU_RULES_VIEW    1
#define MENU_RULES_ADD     2
#define MENU_RULES_IMPORT  3
#define MENU_RULES_EXPORT  4
#define MENU_RULES_CLEANUP 5

//update error
#define UPDATE_ERROR -1

//update no new version
#define UPDATE_NOTHING_NEW 0

//update new version
#define UPDATE_NEW_VERSION 1

#endif /* const_h */
