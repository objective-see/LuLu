//
//  file: ConfigureWindowController.h
//  project: lulu (config)
//  description: install/uninstall window logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "Configure.h"

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//config object
@property(nonatomic, retain) Configure* configure;

//uninstall button
@property (weak, nonatomic) IBOutlet NSButton *uninstallButton;

@property (weak, nonatomic) IBOutlet NSButton *upgradeButton;

//status msg
@property (weak, nonatomic) IBOutlet NSTextField *statusMsg;

//more info button
@property (weak, nonatomic) IBOutlet NSButton *moreInfoButton;

//restart button
@property (weak, nonatomic) IBOutlet NSButton *restartButton;

//spinner
@property (weak, nonatomic) IBOutlet NSProgressIndicator *activityIndicator;

//observer for app activation
@property(nonatomic, retain)id appActivationObserver;

/* METHODS */

//install/uninstall button handler
-(IBAction)buttonHandler:(id)sender;

//(more) info button handler
-(IBAction)info:(id)sender;

@end
