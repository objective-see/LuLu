//
//  file: RulesWindowController.h
//  project: lulu (main app)
//  description: window controller for 'rules' table (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "Rule.h"
#import "XPCDaemonClient.h"
#import "AddRuleWindowController.h"
#import "ItemPathsWindowController.h"

#import "3rd-party/OrderedDictionary.h"

/* CONSTS */

//id (tag) for detailed text in category table
#define TABLE_ROW_NAME_TAG 100

//id (tag) for detailed text in category table
#define TABLE_ROW_SUB_TEXT_TAG 101

//id (tag) for delete button
#define TABLE_ROW_DELETE_TAG 110

//show path(s)
#define MENU_SHOW_PATHS 0

//edit rule(s)
#define MENU_EDIT_RULE 1

//delete rule(s)
#define MENU_DELETE_RULE 2


/* INTERFACE */

@interface RulesWindowController : NSWindowController <NSWindowDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate>

/* PROPERTIES */

//(main) outline view
@property (weak) IBOutlet NSOutlineView *outlineView;

//observer for rules changed
@property(nonatomic, retain)id rulesObserver;

//flag
//@property BOOL shouldFilter;

//loading rules overlay
@property (weak) IBOutlet NSVisualEffectView* loadingRules;

//loading rules spinner
@property (weak) IBOutlet NSProgressIndicator* loadingRulesSpinner;

//table items
@property(nonatomic, retain)OrderedDictionary* rules;

//table items
// ...but filtered
@property(nonatomic, retain)OrderedDictionary* rulesFiltered;

//search box
@property (weak) IBOutlet NSSearchField *filterBox;

//top level view
@property (weak) IBOutlet NSView *view;

//window toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//show item path(s) popup contoller
@property(strong) ItemPathsWindowController *itemPathsWindowController;

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

//configure (UI)
-(void)configure;

//handle tool bar icon clicks
-(IBAction)toolbarHandler:(id)sender;

//add a rule
-(IBAction)addRule:(id)sender;

//delete a rule
-(IBAction)deleteRule:(id)sender;

@end
