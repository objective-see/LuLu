//
//  file: AlertWindowController.h
//  project: lulu (login item)
//  description: window controller for main firewall alert (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#import "ParentsWindowController.h"
#import "VirusTotalViewController.h"

#import <Cocoa/Cocoa.h>

@interface AlertWindowController : NSWindowController


//alert info
@property(nonatomic, retain)NSDictionary* alert;

/* TOP */

//process icon
@property (weak) IBOutlet NSImageView *processIcon;

//icon/image for signing info
@property (weak) IBOutlet NSImageView *signedIcon;

//process name
@property (weak) IBOutlet NSTextField *processName;

//general alert message
@property (weak) IBOutlet NSTextField *alertMessage;

//vt button
@property (weak) IBOutlet NSButton *virusTotalButton;

//popover for virus total
@property (strong) IBOutlet NSPopover *virusTotalPopover;

//view controller for ancestry view/popover
@property (weak) IBOutlet ParentsWindowController *ancestryViewController;

//ancestry button
@property (weak) IBOutlet NSButton *ancestryButton;

//popover for ancestry
@property (strong) IBOutlet NSPopover *ancestryPopover;


/* BOTTOM */

//process id
@property (weak) IBOutlet NSTextField *processID;

//process path
@property (weak) IBOutlet NSTextField *processPath;

//ip address
@property (weak) IBOutlet NSTextField *ipAddress;

//port/protocol
@property (weak) IBOutlet NSTextField *portProto;

//ancestry view
@property (strong) IBOutlet NSView *ancestryView;

//outline view in ancestry popover
@property (weak) IBOutlet NSOutlineView *ancestryOutline;

//text cell for ancestry popover
@property (weak) IBOutlet NSTextFieldCell *ancestryTextCell;

/* METHODS */

//automatically invoked when user clicks process ancestry button
// ->depending on state, show/populate the popup, or close it
-(IBAction)vtButtonHandler:(id)sender;

//invoked when user clicks process ancestry button
// ->depending on state, show/populate the popup, or close it
-(IBAction)ancestryButtonHandler:(id)sender;

//button handler
// ->block/allow, and then close
-(IBAction)handleUserResponse:(id)sender;

@end
