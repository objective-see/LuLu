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

//cs consts
// from: cs_blobs.h
#define CS_VALID 0x00000001
#define CS_RUNTIME 0x00010000

//bundle ID
#define BUNDLE_ID "com.objective-see.lulu"

//main app bundle id
#define MAIN_APP_ID @"com.objective-see.lulu.app"

//helper (login item) ID
#define HELPER_ID @"com.objective-see.lulu.helper"

//installer (app) ID
#define CONFIG_ID @"com.objective-see.lulu.config"

//installer (helper) ID
#define CONFIG_HELPER_ID @"com.objective-see.lulu.configHelper"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/LuLu"

//daemon mach name
#define DAEMON_MACH_SERVICE @"com.objective-see.lulu"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/lulu.html"

//error(s) url
#define ERRORS_URL @"https://objective-see.com/errors.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//install cmd
#define CMD_UPGRADE @"-upgrade"

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

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/LuLu"

//launch daemon name
#define LAUNCH_DAEMON_BINARY @"LuLu"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"com.objective-see.lulu.plist"

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

//flag to install
#define ACTION_UPGRADE_FLAG 1

//cmdline flag to uninstall
#define ACTION_INSTALL @"-install"

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

//path to kext cache
#define KEXT_CACHE @"/usr/sbin/kextcache"

//path to osascript
#define OSASCRIPT @"/usr/bin/osascript"

//app name
#define APP_NAME @"LuLu.app"

#define CMDLINE_FLAG_WELCOME @"-welcome"
#define CMDLINE_FLAG_PREFS @"-prefs"
#define CMDLINE_FLAG_RULES @"-rules"

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

#endif /* const_h */
