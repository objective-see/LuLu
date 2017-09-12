//
//  file: PrefsWindowController.h
//  project: lulu (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "UpdateWindowController.h"

/* CONSTS */

//general view
#define TOOLBAR_GENERAL 101

//update view
#define TOOLBAR_UPDATE 102

//to select, need string ID
#define TOOLBAR_GENERAL_ID @"general"

@interface PrefsWindowController : NSWindowController

/* PROPERTIES */

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//general prefs view
@property (weak) IBOutlet NSView *generalView;

//passive mode button
@property (weak) IBOutlet NSButton *passiveModeButton;

//icon-less (headless) mode button
@property (weak) IBOutlet NSButton *iconModeButton;

//update view
@property (weak) IBOutlet NSView *updateView;

//disable update check button
@property (weak) IBOutlet NSButton *updateModeButton;

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//update label
@property (weak) IBOutlet NSTextField *updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//set button states
// based on preferences
-(void)setButtonStates;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

@end
