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
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize modesView;
@synthesize rulesView;
@synthesize updateView;
@synthesize daemonComms;
@synthesize updateWindowController;

//'allow apple' button
#define BUTTON_ALLOW_APPLE 1

//'allow installed' button
#define BUTTON_ALLOW_INSTALLED 2

//'allow globally' button
#define BUTTON_ALLOW_GLOBALLY 3

//'passive mode' button
#define BUTTON_PASSIVE_MODE 4

//'lockdown mode' button
#define BUTTON_LOCKDOWN_MODE 5

//'no-icon mode' button
#define BUTTON_NO_ICON_MODE 6

//'update mode' button
#define BUTTON_NO_UPDATE_MODE 7

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //set title
    self.window.title = [NSString stringWithFormat:@"LuLu (v. %@)", getAppVersion()];
    
    //init daemon comms
    daemonComms = [[DaemonComms alloc] init];
    
    //get prefs
    self.preferences = [self.daemonComms getPreferences];
    
    //set rules prefs as default
    [self toolbarButtonHandler:nil];
    
    //set rules prefs as default
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_RULES_ID];
    
    return;
}

//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;
    
    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(nil != sender)
    {
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
            
            //set 'apple allowed' button state
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_APPLE]).state = [self.preferences[PREF_ALLOW_APPLE] boolValue];
            
            //set 'installed allowed' button state
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_INSTALLED]).state = [self.preferences[PREF_ALLOW_INSTALLED] boolValue];
            
            //set 'allowed globally' button state
            ((NSButton*)[view viewWithTag:BUTTON_ALLOW_GLOBALLY]).state = [self.preferences[PREF_ALLOW_GLOBALLY] boolValue];
            
            break;
            
        //modes
        case TOOLBAR_MODES:
            
            //set view
            view = self.modesView;
            
            //set 'passive mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_PASSIVE_MODE]).state = [self.preferences[PREF_PASSIVE_MODE] boolValue];
            
            //set 'lockdown mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_LOCKDOWN_MODE]).state = [self.preferences[PREF_LOCKDOWN_MODE] boolValue];
            
            //set 'no icon' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];
            
            break;
            
        //update
        case TOOLBAR_UPDATE:
            
            //set view
            view = self.updateView;
    
            //set 'update' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATE_MODE]).state = [self.preferences[PREF_NO_UPDATE_MODE] boolValue];
            
            break;
            
        default:
            
            //bail
            goto bail;
    }
    
    //set frame rect
    view.frame = CGRectMake(0, 75, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-75);
    
    //add to window
    [self.window.contentView addSubview:view];
    
bail:
    
    return;
}

//invoked when user toggles button
// update preferences for that button
-(IBAction)togglePreference:(id)sender
{
    //preferences
    NSMutableDictionary* preferences = nil;
    
    //button state
    NSNumber* state = nil;
    
    //init
    preferences = [NSMutableDictionary dictionary];
    
    //get button state
    state = [NSNumber numberWithBool:((NSButton*)sender).state];
    
    //passive mode
    // lockdown mode can't be on too...
    if( (BUTTON_PASSIVE_MODE == ((NSButton*)sender).tag) &&
        (NSOnState == state.intValue) )
    {
        //unset lockdown mode button
        ((NSButton*)[self.modesView viewWithTag:BUTTON_LOCKDOWN_MODE]).state = NSOffState;
    }
    
    //lockdown mode
    // passive mode can't be on too...
    else if( (BUTTON_LOCKDOWN_MODE == ((NSButton*)sender).tag) &&
             (NSOnState == state.intValue) )
    {
        //unset passive mode button
        ((NSButton*)[self.modesView viewWithTag:BUTTON_PASSIVE_MODE]).state = NSOffState;
    }
    
    //set appropriate preference
    switch(((NSButton*)sender).tag)
    {
        //allow apple
        case BUTTON_ALLOW_APPLE:
            preferences[PREF_ALLOW_APPLE] = state;
            break;
            
        //allow installed
        case BUTTON_ALLOW_INSTALLED:
            preferences[PREF_ALLOW_INSTALLED] = state;
            break;
            
        //allow globally
        case BUTTON_ALLOW_GLOBALLY:
            preferences[PREF_ALLOW_GLOBALLY] = state;
            break;
            
        //passive mode
        // when on, unset lockdown mode
        case BUTTON_PASSIVE_MODE:
        {
            
            //save mode
            preferences[PREF_PASSIVE_MODE] = state;
            
            //unset lockdown mode
            if(NSOnState == state.intValue)
            {
                //unset
                preferences[PREF_LOCKDOWN_MODE] = [NSNumber numberWithBool:NSOffState];
            }
            
            break;
        }
            
        //lockdown mode
        // when on, also unset passive mode
        case BUTTON_LOCKDOWN_MODE:
        {
            
            //save mode
            preferences[PREF_LOCKDOWN_MODE] = state;
            
            //unset passive mode
            if(NSOnState == state.intValue)
            {
                //unset
                preferences[PREF_PASSIVE_MODE] = [NSNumber numberWithBool:NSOffState];
            }
        }
            
        //no icon mode
        case BUTTON_NO_ICON_MODE:
            preferences[PREF_NO_ICON_MODE] = state;
            break;
            
        //no update mode
        case BUTTON_NO_UPDATE_MODE:
            preferences[PREF_NO_UPDATE_MODE] = state;
            break;
            
        default:
            break;
    }

    //update prefs
    [self.daemonComms updatePreferences:preferences];

    //get prefs
    // these should obv. match...
    self.preferences = [self.daemonComms getPreferences];
    
    //restart login item if user toggle'd icon state
    // note: this has to be done after the prefs are written out by the daemon
    if(((NSButton*)sender).tag == BUTTON_NO_ICON_MODE)
    {
        //restart login item
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
           //restart
           if(YES != [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:TRUE])
           {
               //err msg
               logMsg(LOG_ERR, @"failed to (re)start login item");
           }
        });
    }
    
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
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response
        [self updateResponse:result newVersion:newVersion];
        
    }];
    
    return;
}

//process update response
// ->error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch (result)
    {
        //error
        case -1:
            
            //set label
            self.updateLabel.stringValue = @"error: update check failed";
            
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no updates available");
            
            //set lable
            self.updateLabel.stringValue = @"no new versions";
            
            break;
         
            
        //new version
        case 1:
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);
            
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //make modal
                makeModal(self.updateWindowController);
                
            });
            
            //set label
            //self.updateLabel.stringValue = [NSString stringWithFormat:@"a new version (%@) is available", newVersion];
            
            break;
    }
    
    
    return;
}

@end
