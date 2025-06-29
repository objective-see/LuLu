//
//  file: PrefsWindowController.h
//  project: lulu (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize modesView;
@synthesize rulesView;
@synthesize updateView;
@synthesize updateWindowController;

//'allow apple' button
#define BUTTON_ALLOW_APPLE 1

//'allow installed' button
#define BUTTON_ALLOW_INSTALLED 2

//'allow dns' button
#define BUTTON_ALLOW_DNS 3

//'allow iOS simulator apps' mode button
#define BUTTON_ALLOW_SIMULATOR 4

//'passive mode' button
#define BUTTON_PASSIVE_MODE 5

//'block mode' button
#define BUTTON_BLOCK_MODE 6

//'no-icon mode' button
#define BUTTON_NO_ICON_MODE 7

//'no-VT mode' button
#define BUTTON_NO_VT_MODE 8

//'use allow list' button
#define BUTTON_USE_ALLOW_LIST 9

//'use block list' button
#define BUTTON_USE_BLOCK_LIST 10

//'update mode' button
#define BUTTON_NO_UPDATE_MODE 11

//'passive mode' actions
#define BUTTON_PASSIVE_MODE_ACTION_ALLOW 0
#define BUTTON_PASSIVE_MODE_ACTION_BLOCK 1

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //get prefs
    self.preferences = [xpcDaemonClient getPreferences];
    return;
}

//switch to tab
-(void)switchTo:(NSString*)itemID
{
    //predicate
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"itemIdentifier == %@", itemID];
    
    //item
    NSToolbarItem* item = [[self.toolbar.items filteredArrayUsingPredicate:predicate] firstObject];
    
    //dbg msg
    os_log_debug(logHandle, "item '%@' -> %{public}@", itemID, item);
    
    //select
    [self toolbarButtonHandler:item];
    [self.toolbar setSelectedItemIdentifier:itemID];
    
    return;
}


//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;
    
    //dbg msg
    os_log_debug(logHandle, "%s invoked with %{public}@", __PRETTY_FUNCTION__, sender);
    
    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(YES == self.viewWasAdded)
    {
        //dbg msg
        os_log_debug(logHandle, "removing previous view...");
        
        //remove
        [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    }
    
    //assign view
    switch(((NSToolbarItem*)sender).tag)
    {
        //rules
        case TOOLBAR_RULES:
            
            //set view
            view = self.rulesView;
            
            //show
            self.showRulesButton.hidden = NO;
            
            //set 'apple allowed' button state
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_APPLE]).state = [self.preferences[PREF_ALLOW_APPLE] boolValue];
            
            //set 'installed allowed' button state
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_INSTALLED]).state = [self.preferences[PREF_ALLOW_INSTALLED] boolValue];
            
            //set 'allow dns' button state
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_DNS]).state = [self.preferences[PREF_ALLOW_DNS] boolValue];
        
            //set 'allow simulator apps' button
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_SIMULATOR]).state = [self.preferences[PREF_ALLOW_SIMULATOR] boolValue];

            break;
            
        //modes
        case TOOLBAR_MODES:
            
            //set view
            view = self.modesView;
            
            //set 'passive mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_PASSIVE_MODE]).state = [self.preferences[PREF_PASSIVE_MODE] boolValue];
            
            //set 'passive mode' action
            [self.passiveModeAction selectItemAtIndex: [self.preferences[PREF_PASSIVE_MODE_ACTION] integerValue]];
            
            //set 'passive mode' rules
            [self.passiveModeRules selectItemAtIndex: [self.preferences[PREF_PASSIVE_MODE_RULES] integerValue]];
            
            //set 'block mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_BLOCK_MODE]).state = [self.preferences[PREF_BLOCK_MODE] boolValue];
            
            //set 'no icon' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];
            
            //set 'no VT icon' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_VT_MODE]).state = [self.preferences[PREF_NO_VT_MODE] boolValue];
            
            break;
            
        //lists
        case TOOLBAR_LISTS:
            
            //set view
            view = self.listsView;
            
            //set 'allow list' button state
            ((NSButton*)[view viewWithTag:BUTTON_USE_ALLOW_LIST]).state = [self.preferences[PREF_USE_ALLOW_LIST] boolValue];
            
            //is there a allow list? ...set!
            if(0 != [self.preferences[PREF_ALLOW_LIST] length])
            {
                //set
                self.allowList.stringValue = self.preferences[PREF_ALLOW_LIST];
            }
            
            //set 'browse' button state
            self.selectAllowListButton.enabled = [self.preferences[PREF_USE_ALLOW_LIST] boolValue];
            
            //set allow list input state
            self.allowList.enabled = [self.preferences[PREF_USE_ALLOW_LIST] boolValue];
            
            //set 'block list' button state
            ((NSButton*)[view viewWithTag:BUTTON_USE_BLOCK_LIST]).state = [self.preferences[PREF_USE_BLOCK_LIST] boolValue];
            
            //is there a block list? ...set!
            if(0 != [self.preferences[PREF_BLOCK_LIST] length])
            {
                //set
                self.blockList.stringValue = self.preferences[PREF_BLOCK_LIST];
            }
            
            //set 'browse' button state
            self.selectBlockListButton.enabled = [self.preferences[PREF_USE_BLOCK_LIST] boolValue];
            
            //set block list input state
            self.blockList.enabled = [self.preferences[PREF_USE_BLOCK_LIST] boolValue];
            
            break;
            
        //profiles
        case TOOLBAR_PROFILES:
            
            //set view
            view = self.profilesView;
            
            //reload
            [self reloadProfiles];
            
            break;
            
        //update
        case TOOLBAR_UPDATE:
            
            //set view
            view = self.updateView;
    
            //set 'update' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATE_MODE]).state = [self.preferences[PREF_NO_UPDATE_MODE] boolValue];
            
            //show
            self.updateButton.hidden = NO;
            
            break;
            
        default:
            
            //bail
            goto bail;
    }
    
    //set window size to match each pref's view
    [self.window setFrame:NSMakeRect(self.window.frame.origin.x, NSMaxY(self.window.frame) - view.frame.size.height, view.frame.size.width, view.frame.size.height) display:YES];
    
    //add to window
    [self.window.contentView addSubview:view];
    
    //set
    self.viewWasAdded = YES;
    
bail:
    
    return;
}

//invoked when user toggles button
// update preferences for that button/item
-(IBAction)togglePreference:(id)sender
{
    //preferences
    NSMutableDictionary* updatedPreferences = nil;
    
    //button state
    NSNumber* state = nil;
    
    //in "add profile" mode
    // want to capture all the preferences
    if(YES == self.addProfileSheet.isVisible)
    {
        updatedPreferences = self.profilePreferences;
    }
    //otherwise
    // grab (just) updated preferences to send to daemon
    else
    {
        //init
        updatedPreferences = [NSMutableDictionary dictionary];
    }
    
    //get button state
    state = [NSNumber numberWithBool:((NSButton*)sender).state];
    
    //set appropriate preference
    switch(((NSButton*)sender).tag)
    {
        //allow apple
        case BUTTON_ALLOW_APPLE:
            updatedPreferences[PREF_ALLOW_APPLE] = state;
            break;
            
        //allow installed
        case BUTTON_ALLOW_INSTALLED:
            updatedPreferences[PREF_ALLOW_INSTALLED] = state;
            break;
        
        //allow dns traffic
        case BUTTON_ALLOW_DNS:
            updatedPreferences[PREF_ALLOW_DNS] = state;
            break;
            
        //allow simulator apps
        case BUTTON_ALLOW_SIMULATOR:
            updatedPreferences[PREF_ALLOW_SIMULATOR] = state;
            break;
            
        //use block list
        case BUTTON_USE_ALLOW_LIST:
            
            //set state
            updatedPreferences[PREF_USE_ALLOW_LIST] = state;
            
            //disable?
            // remove allow list too
            if(NSControlStateValueOff == state.longValue)
            {
                //unset
                updatedPreferences[PREF_ALLOW_LIST] = @"";
                
                //clear
                self.allowList.stringValue = @"";
            }
            
            //set allow list input state
            self.allowList.enabled = (NSControlStateValueOn == state.longValue);
            
            //set 'browse' button state
            self.selectAllowListButton.enabled = (NSControlStateValueOn == state.longValue);
            
            break;
            
        //use block list
        case BUTTON_USE_BLOCK_LIST:
            
            //set
            updatedPreferences[PREF_USE_BLOCK_LIST] = state;
            
            //disable?
            // remove block list too
            if(NSControlStateValueOff == state.longValue)
            {
                //unset
                updatedPreferences[PREF_BLOCK_LIST] = @"";
                
                //clear
                self.blockList.stringValue = @"";
            }
            
            //set block list input state
            self.blockList.enabled = (NSControlStateValueOn == state.longValue);
            
            //set 'browse' button state
            self.selectBlockListButton.enabled = (NSControlStateValueOn == state.longValue);
            
            break;
            
        //passive mode
        case BUTTON_PASSIVE_MODE:
            
            //grab state
            updatedPreferences[PREF_PASSIVE_MODE] = state;
            
            //grab selected item of action
            updatedPreferences[PREF_PASSIVE_MODE_ACTION] = [NSNumber numberWithInteger:self.passiveModeAction.indexOfSelectedItem];
            
            //grab selected item of rules
            updatedPreferences[PREF_PASSIVE_MODE_RULES] = [NSNumber numberWithInteger:self.passiveModeRules.indexOfSelectedItem];
            
            break;
            
        //block mode
        case BUTTON_BLOCK_MODE:
            updatedPreferences[PREF_BLOCK_MODE] = state;
            
            //enable?
            // show alert
            if(NSControlStateValueOn == state.longValue)
            {
                //show alert
                showAlert(NSAlertStyleInformational, NSLocalizedString(@"Outgoing traffic will now be blocked.",@"Outgoing traffic will now be blocked."), NSLocalizedString(@"Note however:\r\n▪ Existing connections will not be impacted.\r\n▪ OS traffic (not routed thru LuLu) will not be blocked.",@"Note however:\r\n▪ Existing connections will not be impacted.\r\n▪ OS traffic (not routed thru LuLu) will not be blocked."), @[NSLocalizedString(@"OK", @"OK")]);
            }
            
            break;
            
        //no icon mode
        case BUTTON_NO_ICON_MODE:
            updatedPreferences[PREF_NO_ICON_MODE] = state;
            break;
            
        //no icon mode
        case BUTTON_NO_VT_MODE:
            updatedPreferences[PREF_NO_VT_MODE] = state;
            break;
            
        //no update mode
        case BUTTON_NO_UPDATE_MODE:
            updatedPreferences[PREF_NO_UPDATE_MODE] = state;
            break;
            
        default:
            break;
    }
    
    //logic for 'passive mode' action
    if(YES == [sender isEqualTo:self.passiveModeAction])
    {
        //grab selected index
        updatedPreferences[PREF_PASSIVE_MODE_ACTION] = [NSNumber numberWithInteger:self.passiveModeAction.indexOfSelectedItem];
    }
    //logic for 'passive mode' rules
    else if(YES == [sender isEqualTo:self.passiveModeRules])
    {
        //grab selected index
        updatedPreferences[PREF_PASSIVE_MODE_RULES] = [NSNumber numberWithInteger:self.passiveModeRules.indexOfSelectedItem];
    }
    
    //only process here if we're not in "add profile" mode
    if(YES != self.addProfileSheet.isVisible)
    {
        //send XPC msg to daemon to update prefs
        // returns (all/latest) prefs, which is what we want
        self.preferences = [xpcDaemonClient updatePreferences:updatedPreferences];

        //call back into app to process
        // e.g. show/hide status bar icon, etc.
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) preferencesChanged:self.preferences];
    }
    
    return;
}

//browse for select list
-(IBAction)selectBlockOrAllowList:(id)sender
{
    //'browse' panel
    NSOpenPanel *panel = nil;
        
    //init panel
    panel = [NSOpenPanel openPanel];
        
    //allow files
    panel.canChooseFiles = YES;
    
    //start ...at desktop
    panel.directoryURL = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES) firstObject]];
        
    //disable multiple selections
    panel.allowsMultipleSelection = NO;
        
    //show it
    // and wait for response
    if(NSModalResponseOK == [panel runModal])
    {
        //allow list
        if(sender == self.selectAllowListButton)
        {
            //update ui
            self.allowList.stringValue = panel.URL.path;
            
            //dbg msg
            os_log_debug(logHandle, "user selected allow list: %{public}@", self.allowList.stringValue);
            
            //send XPC msg to daemon to update prefs
            self.preferences = [xpcDaemonClient updatePreferences:@{PREF_ALLOW_LIST:panel.URL.path}];
        }
        //block list
        else if(sender == self.selectBlockListButton)
        {
            //update ui
            self.blockList.stringValue = panel.URL.path;
            
            //dbg msg
            os_log_debug(logHandle, "user selected block list: %{public}@", self.blockList.stringValue);
            
            //send XPC msg to daemon to update prefs
            self.preferences = [xpcDaemonClient updatePreferences:@{PREF_BLOCK_LIST:panel.URL.path}];
        }
        //error
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: %{public}@ is an invalid sender", sender);
        }
    }
    
    return;
}

//invoked when block list path is (manually entered)
-(IBAction)updateBlockList:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "got 'update block list event' (value: %{public}@)", self.blockList.stringValue);
    
    //send XPC msg to daemon to update prefs
    // returns (all/latest) prefs, which is what we want
    self.preferences = [xpcDaemonClient updatePreferences:@{PREF_BLOCK_LIST:self.blockList.stringValue}];
    
    return;
}

//reload profiles/UI
-(void)reloadProfiles
{
    //dbg msg
    os_log_debug(logHandle, "%s invoked", __PRETTY_FUNCTION__);
    
    //send XPC msg to daemon get profiles
    self.profiles = [xpcDaemonClient getProfiles];
    
    //manually add default at start
    [self.profiles insertObject:@"Default" atIndex:0];
    
    //dbg msg
    os_log_debug(logHandle, "list of profiles: %{public}@", self.profiles);
    
    //reload table
    [self.profilesTable reloadData];
    
    //tell app profiles changed
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) profilesChanged];

    return;
}

#pragma mark – Profile's table delegates

//number of profiles
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.profiles.count;
}

//view for each column + row
- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    //dequeue a cell
    NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    //first column
    // check button if we're looking at the current profile
    if(YES == [tableColumn.identifier isEqualToString:@"Current"]) {
        
        //current profile
        NSString* currentProfile = [xpcDaemonClient getCurrentProfile];
        
        //select button
        NSButton* selectButton = (NSButton*)[cell viewWithTag:TABLE_ROW_SELECT_BTN_TAG];
        
        //dbg msg
        os_log_debug(logHandle, "current row: %ld, current profile %{public}@, select button: %{public}@", (long)row, currentProfile, selectButton);
        
        //TODO: remove
        os_log_debug(logHandle, "checking %{public}@ with %{public}@", currentProfile, self.profiles[row]);
        
        //TODO: select row too?
        
        //no profile?
        // select row zero (default)
        if( (0 == row) &&
            (nil == currentProfile) )
        {
            //dbg msg
            os_log_debug(logHandle, "enabling default button here...");
            
            //select
            selectButton.state = NSControlStateValueOn;
        }
        //profile matches current?
        else if(YES == [currentProfile isEqualToString:self.profiles[row]])
        {
            //dbg msg
            os_log_debug(logHandle, "match, enabling button here...");
            
            //select
            selectButton.state = NSControlStateValueOn;
        }
        else
        {
            //turn off
            selectButton.state = NSControlStateValueOff;
        }
    }
    
    //add name
    // and customize delete button
    if ([tableColumn.identifier isEqualToString:@"Name"]) {
        
        //delete button
        NSButton* deleteButton = (NSButton*)[cell viewWithTag:TABLE_ROW_DELETE_BTN_TAG];
        
        //add name
        cell.textField.stringValue = self.profiles[row];
        
        //first row?
        // this is 'default' profile, so disable delete button
        if(0 == row) {
            
            //hide
            deleteButton.hidden = YES;
            
        } else {
            
            //show/enable
            deleteButton.hidden = NO;
            deleteButton.enabled = YES;
        }
    }

    return cell;
}

#pragma mark – Profile's button handlers

//get profile name from current/selected row
-(NSString*)profileFromTable:(id)sender
{
    //profile path
    NSString* profile = nil;
    
    //index of row
    // either clicked or selected row
    NSInteger row = 0;

    //dbg msg
    os_log_debug(logHandle, "%s invoked", __PRETTY_FUNCTION__);
    
    //get row
    if(nil != sender)
    {
        //row from sender
        row = [self.profilesTable rowForView:sender];
    }
    //otherwise get selected row
    else
    {
        //selected row
        row = self.profilesTable.selectedRow;
    }
    
    //TODO: sanity check ... -1?
    
    //get item
    // index 0, is zero, and want to leave nil for that, as its not really a profile
    if(0 != row)
    {
        profile = self.profiles[row];
    }
    
    //dbg msg
    os_log_debug(logHandle, "row: %ld, profile: %{public}@", (long)row, profile);
    
    return profile;
}

//'switch profile' button handler
-(IBAction)switchProfile:(id)sender {
    
    //profile
    NSString* profile = nil;
    
    //dbg msg
    os_log_debug(logHandle, "%s invoked", __PRETTY_FUNCTION__);
    
    //get profile
    // can be 'nil' if default profile is selected
    profile = [self profileFromTable:sender];
    
    //dbg msg
    os_log_debug(logHandle, "user wants to change profile to '%{public}@'", profile ? profile : @"default");
    
    //set profile via XPC
    [xpcDaemonClient setProfile:profile];
    
    //reload profiles
    [self reloadProfiles];

    //grab latest (now, new profile) preferences
    self.preferences = [xpcDaemonClient getPreferences];
    
    //tell app all prefs changed
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) preferencesChanged:self.preferences];
    
    return;
}

//add profile button handler
// show sheet for user to specify settings
-(IBAction)addProfile:(id)sender {
    
    //dbg msg
    os_log_debug(logHandle, "%s invoked", __PRETTY_FUNCTION__);
    
    //init dictionary to collect preferences
    self.profilePreferences = [NSMutableDictionary dictionary];
    
    //init/reset
    self.profileName = nil;
    
    //init/reset
    self.continueProfileButton.tag = 0;
    
    //remove any old view
    if(self.currentProfileSubview) {
        
        //remove current view
        [self.currentProfileSubview removeFromSuperview];
    }

    //init current view (with profile name)
    self.currentProfileSubview = self.profileNameView;
    
    //add initial (profile name) view
    [self.addProfileSheet.contentView addSubview:self.currentProfileSubview];
    
    //show sheet for user to specify settings
    [self.window beginSheet:self.addProfileSheet
               completionHandler:^(NSModalResponse returnCode) {
        
            //add profile?
            // and handle UI refreshes, etc
            if (returnCode == NSModalResponseOK) {
            
                //dbg msg
                os_log_debug(logHandle, "user wants to add profile '%{public}@'", self.profileName);
                
                //add profile via XPC
                [xpcDaemonClient addProfile:self.profileName preferences:self.profilePreferences];
                
                //hide profile sheet
                [self.addProfileSheet orderOut:self];
                
                //reload
                [self reloadProfiles];
                
                //show alert
                showAlert(NSAlertStyleInformational, NSLocalizedString(@"Added Profile", @"Added Profile"), [NSString stringWithFormat:NSLocalizedString(@"profile '%@' saved and activated", @"profile '%@' saved and activated"), self.profileName], @[NSLocalizedString(@"OK", @"OK")]);
                
                //dbg msg
                os_log_debug(logHandle, "grabbing (updated) preferences");
            
                //now grab (profile's) preferences
                self.preferences = [xpcDaemonClient getPreferences];
                
                //tell app they changed
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]) preferencesChanged:self.preferences];
                
                
            }
            
            //cancel
            else {
                
                //close sheet
                [self.addProfileSheet orderOut:self];
            }
    }];
    
    return;
}

//cancel creation of profile
- (IBAction)cancelProfileButtonHandler:(id)sender {
    
    //end w/ cancel
    [self.window endSheet:self.addProfileSheet returnCode:NSModalResponseCancel];
    
    return;
}

//show next view
// note: each case is current view, going to next!
- (IBAction)continueProfileButtonHandler:(NSButton*)sender {
    
    //switch on current view
    // last view, will add profile
    switch (sender.tag) {
            
        //current view: name
        // setup next view: rules
        case profileName:
            
            //save name
            self.profileName = self.profileNameLabel.stringValue;
            
            //remove current view
            [self.currentProfileSubview removeFromSuperview];
            
            //update
            self.currentProfileSubview = self.rulesView;
            
            //hide 'show buttons'
            self.showRulesButton.hidden = YES;
            
            //add to rule's view
            [self.addProfileSheet.contentView addSubview:self.currentProfileSubview];
            
            //update tag
            self.continueProfileButton.tag = profileRules;
            
            break;
            
        //current view: rules
        // setup next view: modes
        case profileRules:
            
            //remove current view
            [self.currentProfileSubview removeFromSuperview];
            
            //update
            self.currentProfileSubview = self.modesView;
            
            //add to mode's view
            [self.addProfileSheet.contentView addSubview:self.currentProfileSubview];
            
            //update tag
            self.continueProfileButton.tag = profileModes;
            
            break;
        
        //current view: modes
        // setup next view: lists
        case profileModes:
            
            //remove current view
            [self.currentProfileSubview removeFromSuperview];
            
            //update
            self.currentProfileSubview = self.listsView;
            
            //add to list's view
            [self.addProfileSheet.contentView addSubview:self.currentProfileSubview];
            
            //update tag
            self.continueProfileButton.tag = profileLists;
            
            break;
        
        //current view: lists
        // setup next view: updates
        case profileLists:
            
            //remove current view
            [self.currentProfileSubview removeFromSuperview];
            
            //update
            self.currentProfileSubview = self.updateView;
            
            //hide button
            self.updateButton.hidden = YES;
            
            //add to mode's view
            [self.addProfileSheet.contentView addSubview:self.currentProfileSubview];
            
            //update tag
            self.continueProfileButton.tag = profileUpdates;
            
            //update button name to "Add Profile"
            self.continueProfileButton.title = NSLocalizedString(@"Add Profile", @"Add Profile");
            
            break;
            
        //current view: updates
        // add profile as this is the last one!
        case profileUpdates:
            
            //end with 'ok'
            [self.window endSheet:self.addProfileSheet returnCode:NSModalResponseOK];
            
        default:
            break;
    }
    
    //update view's fame
    NSRect bounds = self.addProfileSheet.contentView.bounds;
    NSRect frame = self.currentProfileSubview.frame;
    frame.origin.x  = 0;
    frame.origin.y  = bounds.size.height - frame.size.height;
    
    //toolbar
    frame.origin.y += 50;
    
    //set frame
    self.currentProfileSubview.frame = frame;

    return;
}

//delete profile button handler
-(IBAction)deleteProfile:(id)sender {
    
    //name
    NSString* profile = nil;

    //get profile
    profile = [self profileFromTable:sender];
    
    //dbg msg
    os_log_debug(logHandle, "user wants to delete profile '%{public}@'", profile ? profile : @"default");
    
    //delete via XPC
    [xpcDaemonClient deleteProfile:profile];
    
    //reload UI
    [self reloadProfiles];
    
bail:
    
    return;
}

//'check for update' button handler
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;
    
    //disable button
    self.updateButton.enabled = NO;
    
    //reset
    self.updateLabel.stringValue = @"";
    
    //show/start spinner
    [self.updateIndicator startAnimation:self];
    
    //init update obj
    update = [[Update alloc] init];
    
    //check
    // but after a delay for UI
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.75 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
        //check for update
        [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
            
            //process response
            [self updateResponse:result newVersion:newVersion];
            
        }];
    });
    
    return;
}

//'view rules' button handler
// call helper method to show rule's window
-(IBAction)viewRules:(id)sender
{
    //call into app delegate to show app rules
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showRules:nil];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch(result)
    {
        //error
        case Update_Error:
            
            //set label
            self.updateLabel.stringValue = NSLocalizedString(@"error: update check failed", @"error: update check failed");
            break;
            
        //no updates
        case Update_None:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
            
            //set label
            self.updateLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Installed version (%@),\r\nis the latest.",@"Installed version (%@),\r\nis the latest."), getAppVersion()];
           
            break;
            
        //update is not compatible
        case Update_NotSupported:
            
            //dbg msg
            os_log_debug(logHandle, "update available, but isn't supported on macOS %ld.%ld", NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, NSProcessInfo.processInfo.operatingSystemVersion.minorVersion);
            
            //set label
            self.updateLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Update available, but isn't supported on macOS %ld.%ld", @"Update available, but isn't supported on macOS %ld.%ld"), NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, NSProcessInfo.processInfo.operatingSystemVersion.minorVersion];
           
            break;
         
        //new version
        case Update_Available:
            
            //dbg msg
            os_log_debug(logHandle, "a new version (%@) is available", newVersion);
            
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:NSLocalizedString(@"a new version (%@) is available!",@"a new version (%@) is available!"), newVersion]];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //make modal
                makeModal(self.updateWindowController);
                
            });
            
            break;
    }
    
    return;
}

//button handler
// open LuLu home page/docs
-(IBAction)openHomePage:(id)sender {
    
    //open
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    
    return;
}

//on window close
// update prefs/set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
    //blank allow list?
    // uncheck 'enabled' and update prefs
    if(0 == self.allowList.stringValue.length)
    {
        //uncheck 'allow list' radio button
        ((NSButton*)[self.listsView viewWithTag:BUTTON_USE_ALLOW_LIST]).state = NSControlStateValueOff;
        
        //disable 'browse' button
        self.selectAllowListButton.enabled = NSControlStateValueOff;
        
        //clear allow list
        self.allowList.stringValue = @"";
        
        //disable allow list input
        self.allowList.enabled = NSControlStateValueOff;
        
        //send XPC msg to daemon to update prefs
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_USE_ALLOW_LIST:@0, PREF_ALLOW_LIST:@""}];
    }
    
    //allow list changed? capture!
    // this logic is needed, as window can be closed when text field still has focus and 'end edit' won't have fired
    else if(YES != [self.preferences[PREF_ALLOW_LIST] isEqualToString:self.allowList.stringValue])
    {
        //send XPC msg to daemon to update prefs
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_ALLOW_LIST:self.allowList.stringValue}];
    }
    
    //blank block list?
    // uncheck 'enabled' and update prefs
    if(0 == self.blockList.stringValue.length)
    {
        //uncheck 'blocklist' radio button
        ((NSButton*)[self.listsView viewWithTag:BUTTON_USE_BLOCK_LIST]).state = NSControlStateValueOff;
        
        //disable 'browse' button
        self.selectBlockListButton.enabled = NSControlStateValueOff;
        
        //clear block list
        self.blockList.stringValue = @"";
        
        //disable block list input
        self.blockList.enabled = NSControlStateValueOff;
        
        //send XPC msg to daemon to update prefs
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_USE_BLOCK_LIST:@0, PREF_BLOCK_LIST:@""}];
    }
        
    //block list changed? capture!
    // this logic is needed, as window can be closed when text field still has focus and 'end edit' won't have fired
    else if(YES != [self.preferences[PREF_BLOCK_LIST] isEqualToString:self.blockList.stringValue])
    {
        //send XPC msg to daemon to update prefs
        // returns (all/latest) prefs, which is what we want
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_BLOCK_LIST:self.blockList.stringValue}];
    }
     
    //wait a bit, then set activation policy
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
    });
    
    return;
}
@end
