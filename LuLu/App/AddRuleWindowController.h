//
//  file: AddRuleWindowController.h
//  project: lulu
//  description: 'add/edit rule' window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "Rule.h"

@interface AddRuleWindowController : NSWindowController <NSTextFieldDelegate>

/* PROPERTIES */

//app/binary icon
@property (weak) IBOutlet NSImageView *icon;

//path to app/binary
@property (weak) IBOutlet NSTextField *path;

//endpoint address
@property (weak) IBOutlet NSTextField *endpointAddr;

//but indicating endpoint addr is a regex
@property (weak) IBOutlet NSButton *isEndpointAddrRegex;

//endpoint port
@property (weak) IBOutlet NSTextField *endpointPort;

//'add' button
@property (weak) IBOutlet NSButton *addButton;

//block button
@property (weak) IBOutlet NSButton *blockButton;

//allow button
@property (weak) IBOutlet NSButton *allowButton;

//(existing) rule
@property (nonatomic, retain)Rule* rule;

//info (to create/update rule)
@property(nonatomic, retain) NSDictionary* info;


/* METHODS */

//'block'/'allow' button handler
// just needed so buttons will toggle
-(IBAction)radioButtonsHandler:(id)sender;

//'browse' button handler
// open a panel for user to select file
-(IBAction)browseButtonHandler:(id)sender;

//'cancel' button handler
// returns NSModalResponseCancel
-(IBAction)cancelButtonHandler:(id)sender;

//'add' button handler
// returns NSModalResponseOK
-(IBAction)addButtonHandler:(id)sender;

@end
