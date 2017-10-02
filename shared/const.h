//
//  file: const.h
//  project: lulu (shared)
//  description: #defines and what not
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef const_h
#define const_h

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objectiveSee"

//bundle ID
#define BUNDLE_ID "com.objective-see.lulu"

//print macros
#ifdef DEBUG
# define DEBUG_PRINT(x) printf x
#else
# define DEBUG_PRINT(x) do {} while (0)
#endif

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

//name of user client class
#define LULU_USER_CLIENT_CLASS "com_objectivesee_driver_LuLu"

//rules file
#define RULES_FILE @"/Library/Objective-See/LuLu/rules.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"com.objective-see.luluDaemon"

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

//patreon url
#define PATREON_URL @"https://www.patreon.com/objective_see"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//add rule, block
#define BUTTON_BLOCK 0

//add rule, allow
#define BUTTON_ALLOW 1

//login item name
#define LOGIN_ITEM_NAME @"LuLu Helper"

//prefs
// passive mode
#define PREF_PASSIVE_MODE @"passiveMode"

//prefs
// icon mode
#define PREF_ICONLESS_MODE @"iconlessMode"

//prefs
// update mode
#define PREF_NOUPDATES_MODE @"noupdatesMode"

//log file
#define LOG_FILE_NAME @"LuLu.log"

/* LOGIN ITEM */

//path to preferences
#define APP_PREFERENCES @"~/Library/Preferences/com.objective-see.lulu.plist"

//log activity button
#define PREF_LOG_ACTIVITY @"logActivity"

//app name
#define APP_NAME @"LuLu.app"

//show window notification
#define NOTIFICATION_SHOW_WINDOW @"com.objective-see.lulu.showWindow"

#define CMDLINE_FLAG_PREFS @"-prefs"
#define CMDLINE_FLAG_RULES @"-rules"
#define CMDLINE_FLAG_INSTALL @"-install"
#define CMDLINE_FLAG_UNINSTALL @"-uninstall"

//keys for rule dictionary
#define RULE_PATH @"path"
#define RULE_ACTION @"action"
#define RULE_TYPE @"type"
#define RULE_USER @"user"

//rules types
#define RULE_TYPE_ALL     -1
#define RULE_TYPE_DEFAULT  0
#define RULE_TYPE_BASELINE 1
#define RULE_TYPE_USER     2

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
#define ALERT_PASSIVELY_ALLOWED @"passivelyAllowed"

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

#endif /* const_h */
