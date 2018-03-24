//
//  LinkWindowController.h
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/message.h>

#import "DaemonComms.h"

@interface WelcomeWindowController : NSWindowController

/* PROPERTIES */

//sync view controller
@property(nonatomic, retain)NSViewController* welcomeViewController;

//welcome view
@property (strong) IBOutlet NSView *welcomeView;

//config view
@property (strong) IBOutlet NSView *configureView;

//allow apple bins/apps
@property (weak) IBOutlet NSButton *allowApple;

//allow 3rd-party installed apps
@property (weak) IBOutlet NSButton *allowInstalled;

//kext view
@property (strong) IBOutlet NSView *kextView;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//support view
@property (strong) IBOutlet NSView *supportView;

/* METHODS */

@end
