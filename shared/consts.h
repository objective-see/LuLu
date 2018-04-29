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

//patreon url
#define PATREON_URL @"https://www.patreon.com/bePatron?c=701171"

//sentry crash reporting URL
#define CRASH_REPORTING_URL @"https://639e824c5bc14eaca06c55f52aee1946:77fa2885950642288a52b1773e5375b3@sentry.io/1195655"

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objectiveSee"

//bundle ID
#define BUNDLE_ID "com.objective-see.lulu"

//main app bundle id
#define MAIN_APP_ID @"com.objective-see.lulu"

//helper ID
#define HELPER_ID @"com.objective-see.lulu.helper"

//installer (app) ID
#define INSTALLER_ID @"com.objective-see.lulu.installer"

//installer (helper) ID
#define CONFIG_HELPER_ID @"com.objective-see.lulu.configHelper"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//firewall event: network out
#define EVENT_NETWORK_OUT 0x0

//firewall event: dns response
#define EVENT_DNS_RESPONSE 0x1

//connect out (TCP)
#define EVENT_CONNECT_OUT 0x1

//data out (UDP)
#define EVENT_DATA_OUT 0x2

//log to file flag
#define LOG_TO_FILE 0x10

//max size of msg
#define MAX_KEV_MSG 254

//max Q items
#define MAX_FIREWALL_EVENTS 512

#define LULU_SERVICE_NAME "com_objective_see_firewall"

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/LuLu"

//preferences file
#define PREFS_FILE @"preferences.plist"

//name of user client class
#define LULU_USER_CLIENT_CLASS "com_objectivesee_driver_LuLu"

//rules file
#define RULES_FILE @"rules.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"com.objective-see.lulu"

//rule state; not found
#define RULE_STATE_NOT_FOUND -1

//rule state; block
#define RULE_STATE_BLOCK 0

//rule state; allow
#define RULE_STATE_ALLOW 1

//product url
#define PRODUCT_URL @"https://objective-see.com/products/lulu.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

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
// passive mode
#define PREF_PASSIVE_MODE @"passiveMode"

//prefs
// icon mode
#define PREF_NO_ICON_MODE @"noIconMode"

//prefs
// update mode
#define PREF_NO_UPDATE_MODE @"noupdateMode"

//allow all apple binaries
#define PREF_ALLOW_APPLE @"allowApple"

//allow all installed
#define PREF_ALLOW_INSTALLED @"allowInstalled"

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

/* INSTALLER */

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/LuLu"

//launch daemon name
#define LAUNCH_DAEMON_BINARY @"LuLu"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"com.objective-see.lulu.plist"

//installed apps file
#define INSTALLED_APPS @"installedApps"

//frame shift
// for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//flag to reboot
#define ACTION_RESTART_FLAG -1

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag to close
#define ACTION_CLOSE_FLAG 2

//button title: restart
#define ACTION_RESTART @"Restart"

//button title: close
#define ACTION_CLOSE @"Close"

/* LAUNCH DAEMON */

//path to system profiler
#define SYSTEM_PROFILER @"/usr/sbin/system_profiler"

//path to kext cache
#define KEXT_CACHE @"/usr/sbin/kextcache"

/* LOGIN ITEM */

//path to osascript
#define OSASCRIPT @"/usr/bin/osascript"

//path to open
#define OPEN @"/usr/bin/open"


//log activity button
#define PREF_LOG_ACTIVITY @"logActivity"

//app name
#define APP_NAME @"LuLu.app"

//show window notification
#define NOTIFICATION_SHOW_WINDOW @"com.objective-see.lulu.showWindow"

#define CMDLINE_FLAG_WELCOME @"-welcome"
#define CMDLINE_FLAG_PREFS @"-prefs"
#define CMDLINE_FLAG_RULES @"-rules"

//keys for rule dictionary
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

//keys for alert dictionary
#define ALERT_PATH @"path"
#define ALERT_PID @"pid"
#define ALERT_USER @"user"
#define ALERT_IPADDR @"ipAddr"
#define ALERT_HOSTNAME @"hostName"
#define ALERT_PORT @"port"
#define ALERT_PROTOCOL @"protocol"
#define ALERT_ACTION @"action"
#define ALERT_SIGNINGINFO @"signingInfo"

//keys for (pre)install apps
#define KEY_NAME @"name"
#define KEY_HASH @"hash"

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signing auths
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

//file belongs to apple?
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//file signed with apple dev id
#define KEY_SIGNING_IS_APPLE_DEV_ID @"signedWithDevID"

//from app store
#define KEY_SIGNING_IS_APP_STORE @"fromAppStore"

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

#endif /* const_h */
