//
//  file: ConfigureWindowController.h
//  project: lulu (config)
//  description: install/uninstall window logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */
@property (weak, nonatomic) IBOutlet NSTextField *statusMsg;
@property (weak, nonatomic) IBOutlet NSButton *installButton;
@property (weak, nonatomic) IBOutlet NSButton *moreInfoButton;
@property (weak, nonatomic) IBOutlet NSButton *uninstallButton;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *activityIndicator;


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
