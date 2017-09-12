//
//  file: PrefsWindowController.h
//  project: lulu (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "Update.h"
#import "logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize updateView;
@synthesize generalView;
@synthesize updateModeButton;
@synthesize passiveModeButton;
@synthesize iconModeButton;

@synthesize updateWindowController;

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //init w/ 'general' view
    [self.window.contentView addSubview:self.generalView];
    
    //set title
    self.window.title = [NSString stringWithFormat:@"LuLu (v. %@)", getAppVersion()];
    
    //set frame rect
    self.generalView.frame = CGRectMake(0, 100, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-100);
    
    //make 'general' selected
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL_ID];
    
    //set pref buttons
    [self setButtonStates];
    
    return;

}

//toolbar view handler
// ->toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;
    
    //remove prev. subview
    [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    
    //assign view
    switch(((NSToolbarItem*)sender).tag)
    {
        //general
        case TOOLBAR_GENERAL:
            view = self.generalView;
            break;
            
        //update
        case TOOLBAR_UPDATE:
            view = self.updateView;
            break;
            
        default:
            break;
    }
    
    //set frame rect
    view.frame = CGRectMake(0, 100, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-100);
    
    //add to window
    [self.window.contentView addSubview:view];
    
    //make sure preference button states are selected
    [self setButtonStates];
    
    return;
}

//set button states
// based on preferences
-(void)setButtonStates
{
    //app preferences
    NSUserDefaults* appPreferences = nil;
    
    //alloc/init
    appPreferences = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.objective-see.lulu"];
    
    //passive mode
    self.passiveModeButton.state = [appPreferences boolForKey:PREF_PASSIVE_MODE];
    
    //icon-less (headless) mode
    self.iconModeButton.state = [appPreferences boolForKey:PREF_ICONLESS_MODE];
    
    //update mode
    self.updateModeButton.state = [appPreferences boolForKey:PREF_NOUPDATES_MODE];
    
    return;
}

//invoked when user toggles button
// update preferences for that button
-(IBAction)togglePreference:(id)sender
{
    //app preferences
    NSUserDefaults* appPreferences = nil;
    
    //alloc/init
    appPreferences = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.objective-see.lulu"];
    
    //passive mode?
    if(sender == self.passiveModeButton)
    {
        //save
        [appPreferences setBool:self.passiveModeButton.state forKey:PREF_PASSIVE_MODE];
    }
    
    //icon mode?
    // restart login item too
    else if(sender == self.iconModeButton)
    {
        //save
        [appPreferences setBool:self.iconModeButton.state forKey:PREF_ICONLESS_MODE];
        
        //restart the login item
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:YES];
    }
    
    //update mode?
    else if(sender == self.updateModeButton)
    {
        //save
        [appPreferences setBool:self.updateModeButton.state forKey:PREF_NOUPDATES_MODE];
    }
    
    //sync
    [appPreferences synchronize];
    
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
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"no updates available");
            #endif
            
            //set lable
            self.updateLabel.stringValue = @"no new versions";
            
            break;
         
            
        //new version
        case 1:
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);
            #endif
            
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
