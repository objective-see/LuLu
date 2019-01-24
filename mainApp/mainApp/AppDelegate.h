//
//  file: AppDelegate.h
//  project: lulu (main app)
//  description: application delegate (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "XPCDaemonClient.h"
#import "AboutWindowController.h"
#import "PrefsWindowController.h"
#import "RulesWindowController.h"
#import "UpdateWindowController.h"
#import "WelcomeWindowController.h"
#import "3rdParty/HyperlinkTextField.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//flag for launch method
@property BOOL urlLaunch;

//main window
@property(weak)IBOutlet NSWindow* window;

//welcome view controller
@property(nonatomic, retain)WelcomeWindowController* welcomeWindowController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//rules window controller
@property(nonatomic, retain)RulesWindowController* rulesWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

//xpc for daemon comms
@property(nonatomic, retain)XPCDaemonClient* xpcDaemonClient;

/* METHODS */

//'rules' menu item handler
-(IBAction)showRules:(id)sender;

//'prefs' menu item handler
-(IBAction)showPreferences:(id)sender;

@end

