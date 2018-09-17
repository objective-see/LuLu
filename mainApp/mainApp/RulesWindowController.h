//
//  file: RulesWindowController.h
//  project: lulu (main app)
//  description: window controller for 'rules' table (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Rule.h"
#import "XPCDaemonClient.h"
#import "AddRuleWindowController.h"

/* CONSTS */

//id (tag) for detailed text in category table
#define TABLE_ROW_NAME_TAG 100

//id (tag) for detailed text in category table
#define TABLE_ROW_SUB_TEXT_TAG 101

//id (tag) for delete button
#define TABLE_ROW_DELETE_TAG 110

//menu item for block
#define MENU_ITEM_BLOCK 0

//menu item for allow
#define MENU_ITEM_ALLOW 1

//menu item for delete
#define MENU_ITEM_DELETE 2

/* INTERFACE */

@interface RulesWindowController : NSWindowController <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
{
    
}

/* PROPERTIES */

//observer for rules changed
@property(nonatomic, retain)id rulesObserver;

//flag
@property BOOL shouldFilter;

//loading rules overlay
@property (weak) IBOutlet NSVisualEffectView *loadingRules;

//loading rules spinner
@property (weak) IBOutlet NSProgressIndicator *loadingRulesSpinner;

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

//panel for 'add rule'
@property (weak) IBOutlet NSView *addRulePanel;

//label for add rules button
@property (weak) IBOutlet NSTextField *addRuleLabel;

//button to add rules
@property (weak) IBOutlet NSButton *addRuleButton;

//add rules popup controller
@property (strong) AddRuleWindowController *addRuleWindowController;

//(last) added rule
@property(nonatomic,retain)NSString* addedRule;

//status message for import/export rules
@property (weak) IBOutlet NSTextField *rulesStatusMsg;

/* METHODS */

//process rules dictionary received from daemon
-(void)processRulesDictionary:(NSDictionary*)daemonRules;

//handle tool bar icon clicks
-(IBAction)toolbarHandler:(id)sender;

//import rules
-(IBAction)importRules:(id)sender;

//export rules
-(IBAction)exportRules:(id)sender;

//add a rule
-(IBAction)addRule:(id)sender;

//delete a rule
-(IBAction)deleteRule:(id)sender;

//init array of filtered rules
-(void)filterRules;

//given a path
// find the row/index of rule
-(NSInteger)findRowForRule:(NSString*)path;

//given a table row
// find/return the corresponding rule
-(Rule*)ruleForRow:(NSInteger)row;

@end
