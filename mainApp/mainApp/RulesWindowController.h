//
//  file: RulesWindowController.h
//  project: lulu (main app)
//  description: window controller for 'rules' table (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "DaemonComms.h"
#import <Cocoa/Cocoa.h>

#import "AddRuleWindowController.h"

/* CONSTS */

//id (tag) for detailed text in category table
#define TABLE_ROW_NAME_TAG 100

//id (tag) for detailed text in category table
#define TABLE_ROW_SUB_TEXT_TAG 101

//id (tag) for delete button
#define TABLE_ROW_DELETE_TAG 110

/* INTERFACE */

@interface RulesWindowController : NSWindowController <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    
}

/* PROPERTIES */

//daemom comms object
@property (nonatomic, retain)DaemonComms* daemonComms;

//flag
@property BOOL shouldFilter;

//table items
// ->all rules
@property(nonatomic, retain)NSMutableArray* rules;

//table items
// ->filtered rules
@property(nonatomic, retain)NSMutableArray* rulesFiltered;

//search box
@property (weak) IBOutlet NSSearchField *searchBox;

//top level view
@property (weak) IBOutlet NSView *view;

//window toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//table view
@property (weak) IBOutlet NSTableView *tableView;

//overlay
@property (strong) IBOutlet NSView *overlay;

//panel for 'add rule'
@property (weak) IBOutlet NSView *addRulePanel;

//label for add rules button
@property (weak) IBOutlet NSTextField *addRuleLabel;

//button to add rules
@property (weak) IBOutlet NSButton *addRuleButton;

//add rules popup controller
@property (strong) AddRuleWindowController *addRuleWindowController;

/* METHODS */

//process rules dictionary received from daemon
-(void)processRulesDictionary:(NSDictionary*)daemonRules;

-(IBAction)toolbarHandler:(id)sender;

//add a rule
-(IBAction)addRule:(id)sender;

//delete a rule
-(IBAction)deleteRule:(id)sender;

//init array of filtered rules
-(void)filterRules;

@end
