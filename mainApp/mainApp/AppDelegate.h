//
//  file: AppDelegate.h
//  project: lulu (main app)
//  description: application delegate (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DaemonComms.h"
#import "AboutWindowController.h"
#import "PrefsWindowController.h"
#import "RulesWindowController.h"
#import "UpdateWindowController.h"
#import "3rdParty/HyperlinkTextField.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//rules window controller
@property(nonatomic, retain)RulesWindowController* rulesWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

/* METHODS */

//start the (helper) login item
-(BOOL)startLoginItem:(BOOL)shouldRestart;


@end

