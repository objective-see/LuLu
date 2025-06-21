//
//  file: main.h
//  project: lulu (launch daemon)
//  description: main (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Rules.h"
#import "Alerts.h"
#import "consts.h"
#import "Profiles.h"
#import "utilities.h"
#import "Preferences.h"
#import "XPCListener.h"
#import "BlockOrAllowList.h"

#ifndef main_h
#define main_h

//GLOBALS

//rules obj
Rules* rules = nil;

//alerts obj
Alerts* alerts = nil;

//allow list
BlockOrAllowList* allowList = nil;

//block list
BlockOrAllowList* blockList = nil;

//XPC listener obj
XPCListener* xpcListener = nil;

//prefs obj
Preferences* preferences = nil;

//profile obj
Profiles* profiles = nil;

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

/* FUNCTIONS */

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown(void);

//launch daemon should only be unloaded if box is shutting down
// so handle things like telling kext to disable & unregister, de-init logging, etc
void goodbye(void);


#endif /* main_h */
