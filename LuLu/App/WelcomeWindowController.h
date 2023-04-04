//
//  LinkWindowController.h
//  LuLu
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "XPCDaemonClient.h"

@interface WelcomeWindowController : NSWindowController

/* PROPERTIES */

//main view controller
@property(nonatomic, retain)NSViewController* welcomeViewController;

//welcome view
@property (strong) IBOutlet NSView *welcomeView;

//allow extension view
@property (strong) IBOutlet NSView *allowExtensionView;

//allow extension spinner
@property (weak) IBOutlet NSProgressIndicator *allowExtActivityIndicator;

//allow extension message
@property (weak) IBOutlet NSTextField *allowExtMessage;

//config view
@property (strong) IBOutlet NSView *configureView;

//allow apple bins/apps
@property (weak) IBOutlet NSButton *allowApple;

//allow 3rd-party installed apps
@property (weak) IBOutlet NSButton *allowInstalled;

//support view
@property (strong) IBOutlet NSView *supportView;

//preferences
@property (nonatomic, retain)NSDictionary* preferences;

/* METHODS */

//show a view
// note: replaces old view and highlights specified responder
-(void)showView:(NSView*)view firstResponder:(NSInteger)firstResponder;

@end
