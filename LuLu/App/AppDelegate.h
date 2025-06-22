//
//  AppDelegate.h
//  LuLu
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;
@import NetworkExtension;
@import SystemExtensions;

#import "StatusBarItem.h"
#import "XPCDaemonClient.h"
#import "AboutWindowController.h"
#import "PrefsWindowController.h"
#import "RulesWindowController.h"
#import "UpdateWindowController.h"
#import "StartupWindowController.h"
#import "WelcomeWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>


/* PROPERTIES */

//configure window controller
@property(nonatomic, retain)StartupWindowController* startupWindowController;

//uninstall (deactivation) request
@property(nonatomic, retain)OSSystemExtensionRequest *uninstallRequest;

//welcome view controller
@property(nonatomic, retain)WelcomeWindowController* welcomeWindowController;

//status bar menu/sub-menus
@property(strong) IBOutlet NSMenu* statusMenu;
@property(strong) IBOutlet NSMenuItem *profilesMenu;
@property (weak) IBOutlet NSMenuItem *profileSwitchMenu;

//status bar menu controller
@property(nonatomic, retain)StatusBarItem* statusBarItemController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

//rules window controller
@property(nonatomic, retain)RulesWindowController* rulesWindowController;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//first launch?
// check for install time(stamp)
-(BOOL)isFirstTime;

//finish up initializations
-(void)completeInitialization:(NSDictionary*)initialPreferenes;

//set app foreground/background
// determined by the app's window count
-(void)setActivationPolicy;

//'rules' menu item handler
// alloc and show rules window
-(IBAction)showRules:(id)sender;

//'preferences' menu item handler
// alloc and show preferences window
-(void)showPreferences:(NSString*)itemID;

//preferences changed
// for now, just check status bar icon setting
-(void)preferencesChanged:(NSDictionary*)preferences;

//toggle (status) bar icon
-(void)toggleIcon:(NSDictionary*)preferences;

//quit
-(IBAction)quit:(id)sender;

//uninstall
-(IBAction)uninstall:(id)sender;

@end

