//
//  file: StatusBarMenu.m
//  project: lulu (login item)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "StatusBarMenu.h"
#import "StatusBarPopoverController.h"
#import "UserCommsInterface.h"

//menu items
enum menuItems
{
    status = 100,
    toggle,
    rules,
    prefs,
    end
};

@implementation StatusBarMenu

@synthesize isDisabled;
@synthesize statusItem;

//init method
-(id)init:(NSMenu*)menu preferences:(NSDictionary*)preferences firstTime:(BOOL)firstTime
{
    //load from nib
    self = [super init];
    if(self != nil)
    {
        //init status item
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
        //set image
        self.statusItem.image = [NSImage imageNamed:@"statusIcon"];
        
        //tell OS to handle image
        self.statusItem.image.template = YES;
    
        //set menu
        self.statusItem.menu = menu;
        
        //set action handler for all items
        for(int i=toggle; i<end; i++)
        {
            //set action
            [self.statusItem.menu itemWithTag:i].action = @selector(handler:);
            
            //set state
            [self.statusItem.menu itemWithTag:i].enabled = YES;
            
            //set target
            [self.statusItem.menu itemWithTag:i].target = self;
        }
        
        //first time?
        // show popover
        if(YES == firstTime)
        {
            //show
            [self showPopover];
        }
        
        //set state based on (existing) preferences
        self.isDisabled = [preferences[PREF_IS_DISABLED] boolValue];
    }
    
    return self;
}

//show popver
-(void)showPopover
{
    //alloc popover
    self.popover = [[NSPopover alloc] init];
    
    //don't want highlight for popover
    self.statusItem.highlightMode = NO;
    
    //set action
    // can close popover with click
    self.statusItem.action = @selector(closePopover:);
    
    //set target
    self.statusItem.target = self;
    
    //set view controller
    self.popover.contentViewController = [[StatusBarPopoverController alloc] initWithNibName:@"StatusBarPopover" bundle:nil];
    
    //set behavior
    // auto-close if user clicks button in status bar
    self.popover.behavior = NSPopoverBehaviorTransient;
    
    //set delegate
    self.popover.delegate = self;
    
    //show popover
    // have to wait cuz...
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
       //show
       [self.popover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
    });
    
    //wait a bit
    // then automatically hide popup if user has not closed it
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
       //close
       [self closePopover:nil];
    });
    
    return;
}

//close popover
// also unsets action handler, resets, highlighting, etc
-(void)closePopover:(id)sender
{
    //still visible?
    // close it then...
    if(YES == self.popover.shown)
    {
        //close
        [self.popover performClose:nil];
    }
    
    //remove action handler
    self.statusItem.action = nil;
    
    //reset highlight mode
    self.statusItem.highlightMode = YES;
    
    return;
}

//menu handler
-(void)handler:(id)sender
{
    //path to config (main) app
    NSString* mainApp = nil;
    
    //error
    NSError* error = nil;
    
    //config app's pid
    NSNumber* mainAppID = nil;
    
    //window notification
    NSNumber* windowNotification = nil;
    
    //get path to main app
    mainApp = getMainAppPath();

    //get pid of config app for user
    // if it's already running, sent it a notifcation to show the window (rules, prefs, etc)
    mainAppID = [getProcessIDs([[NSBundle bundleWithPath:mainApp] executablePath], getuid()) firstObject];
    if(nil != mainAppID)
    {
        //which window to show?
        switch ((long)((NSMenuItem*)sender).tag)
        {
            //rules window
            case rules:
                
                //rules
                windowNotification = [NSNumber numberWithInt:WINDOW_RULES];
        
                break;
            
            //prefs window
            case prefs:
                
                //prefs
                windowNotification = [NSNumber numberWithInt:WINDOW_PREFERENCES];
                
                break;
            
            default:
                break;
                
        }
        
        //send notification
        if(nil != windowNotification)
        {
            //send
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SHOW_WINDOW object:nil userInfo:@{@"window":windowNotification} deliverImmediately:YES];
        }
    
        //all done
        goto bail;
    }
    
    //handle action
    switch(((NSMenuItem*)sender).tag)
    {
        //toggle on/off
        case toggle:
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling (%d)", self.isDisabled]);
            
            //going from off to on
            if(YES == self.isDisabled)
            {
                //update status
                [self.statusItem.menu itemWithTag:status].title = @"LULU: enabled";
                
                //change text
                ((NSMenuItem*)sender).title = @"Disable";
                
                //toggle flag
                self.isDisabled = NO;
            }
            
            //going from on to off?
            else
            {
                //update status
                [self.statusItem.menu itemWithTag:status].title = @"LULU: disabled";
                
                //change text
                ((NSMenuItem*)sender).title = @"Enable";
                
                //toggle flag
                self.isDisabled = YES;
            }
            
            //update prefs
            [[[DaemonComms alloc] init] updatePreferences:@{PREF_IS_DISABLED:[NSNumber numberWithBool:self.isDisabled]}];
            
            break;
            
        //launch main app to show rules
        case rules:
            
            //launch main app
            // pass in '-rules'
            if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:mainApp] options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: @[CMDLINE_FLAG_RULES]} error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to launch %@ (%@)", mainApp, error]);
                
                //bail
                goto bail;
            }
            
            break;
            
        //launch main app to show prefs
        case prefs:
            
            //launch main app
            if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:mainApp] options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: @[CMDLINE_FLAG_PREFS]} error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to launch %@ (%@)", mainApp, error]);
                
                //bail
                goto bail;
            }
            
            break;
            
        default:
            break;
    }
    
bail:
    
    return;
}
@end
