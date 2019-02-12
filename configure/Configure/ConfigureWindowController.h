//
//  file: ConfigureWindowController.h
//  project: lulu (config)
//  description: install/uninstall window logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//uninstall button
@property (weak, nonatomic) IBOutlet NSButton *uninstallButton;

//install button
@property (weak, nonatomic) IBOutlet NSButton *installButton;

//status msg
@property (weak, nonatomic) IBOutlet NSTextField *statusMsg;

//more info button
@property (weak, nonatomic) IBOutlet NSButton *moreInfoButton;

//restart button
@property (weak, nonatomic) IBOutlet NSButton *restartButton;

//spinner
@property (weak, nonatomic) IBOutlet NSProgressIndicator *activityIndicator;

//friends view
@property (strong, nonatomic) IBOutlet NSView *friendsView;

//observer for app activation
@property(nonatomic, retain)id appActivationObserver;

/* METHODS */

//install/uninstall button handler
-(IBAction)buttonHandler:(id)sender;

//(more) info button handler
-(IBAction)info:(id)sender;

//configure window/buttons
// also brings to front
-(void)configure:(BOOL)isInstalled;

//display (show) window
-(void)display;

@end
