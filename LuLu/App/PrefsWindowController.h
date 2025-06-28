//
//  file: PrefsWindowController.h
//  project: lulu (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "XPCDaemonClient.h"
#import "UpdateWindowController.h"

/* CONSTS */

//rules view
#define TOOLBAR_RULES 0

//modes view
#define TOOLBAR_MODES 1

//update view
#define TOOLBAR_LISTS 2

//profiles view
#define TOOLBAR_PROFILES 3

//update view
#define TOOLBAR_UPDATE 4

//to select, need string ID
#define TOOLBAR_RULES_ID @"Rules"
#define TOOLBAR_PROFILES_ID @"Profiles"

//id (tag) for delete button
#define TABLE_ROW_DELETE_TAG 110

@interface PrefsWindowController : NSWindowController <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource>

/* PROPERTIES */

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar* toolbar;

/* RULES */

//rules prefs view
@property (weak) IBOutlet NSView* rulesView;

//show rules button
@property (weak) IBOutlet NSButton* showRulesButton;

/* MODES */

//modes view
@property (strong) IBOutlet NSView* modesView;

//passive mode action ...allow or block?
@property (weak) IBOutlet NSPopUpButton* passiveModeAction;

//passive mode rules ...create, or not?
@property (weak) IBOutlet NSPopUpButton* passiveModeRules;

//(block/allow) lists view
@property (strong) IBOutlet NSView *listsView;

//allow list
@property (weak) IBOutlet NSTextField *allowList;

//select allow list button
@property (weak) IBOutlet NSButton *selectAllowListButton;

//block list
@property (weak) IBOutlet NSTextField* blockList;

//select block list button
@property (weak) IBOutlet NSButton* selectBlockListButton;

//profiles table
@property (weak) IBOutlet NSTableView *profilesTable;

/* PROFILES VIEW */

//profiles view
@property (strong) IBOutlet NSView* profilesView;

//profiles
@property(nonatomic, retain)NSMutableArray* profiles;

//selected profile
@property(nonatomic, retain)NSString* selectedProfile;

//add profile sheet
@property (strong) IBOutlet NSPanel* addProfileSheet;

//continue/next button
@property (weak) IBOutlet NSButton* continueProfileButton;

//current view
@property (strong) NSView* currentProfileSubview;

//profile name label
@property (weak) IBOutlet NSTextField* profileNameLabel;

//profile name view
@property (strong) IBOutlet NSView* profileNameView;

//new profile name
@property(nonatomic, retain)NSString* profileName;

//profile preferences
@property(nonatomic, retain)NSMutableDictionary* profilePreferences;

//profile views
enum profileViews
{
    profileName = 0,
    profileRules,
    profileModes,
    profileLists,
    profileUpdates,
};

/* UPDATE VIEW */

//update view
@property (weak) IBOutlet NSView* updateView;

//update button
@property (weak) IBOutlet NSButton* updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator* updateIndicator;

//update label
@property (weak) IBOutlet NSTextField* updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

//added view
@property (nonatomic) BOOL viewWasAdded;



/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//switch to tab
-(void)switchTo:(NSString*)itemID;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

@end
