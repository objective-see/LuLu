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
#import "logging.h"
#import "Baseline.h"
#import "KextComms.h"
#import "utilities.h"
#import "Preferences.h"
#import "KextListener.h"
#import "ProcListener.h"
#import "XPCListener.h"

#ifndef main_h
#define main_h

//GLOBALS

//prefs obj
Preferences* preferences = nil;

//kext comms obj
KextComms* kextComms = nil;

//rules obj
Rules* rules = nil;

//alerts obj
Alerts* alerts = nil;

//process listener obj
ProcessListener* processListener = nil;

//kext listener obj
KextListener* kextListener = nil;

//base line object
Baseline* baseline;

//XPC listener obj
XPCListener* xpcListener = nil;

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
