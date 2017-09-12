//
//  file: AddRuleWindowController.h
//  project: lulu (main app)
//  description: 'add rule' window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AddRuleWindowController : NSWindowController <NSTextFieldDelegate>

/* PROPERTIES */

//app/binary icon
@property (weak) IBOutlet NSImageView *icon;

//path to app/binary
@property (weak) IBOutlet NSTextField *processPath;

//'add' button handler
@property (weak) IBOutlet NSButton *addButton;

//action (block/allow) button
@property (weak) IBOutlet NSButton *actionButton;

//action
// ->block/allow
@property NSUInteger action;

/* METHODS */

//'block'/'allow' button handler
// ->set state into iVar, so can accessed when sheet closes
-(IBAction)radioButtonsHandler:(id)sender;

//'browse' button handler
// open a panel for user to select file
-(IBAction)browseButtonHandler:(id)sender;

//'cancel' button handler
// close sheet, returning NSModalResponseCancel
-(IBAction)cancelButtonHandler:(id)sender;

//'add' button handler
// close sheet, returning NSModalResponseOK
-(IBAction)addButtonHandler:(id)sender;

@end
