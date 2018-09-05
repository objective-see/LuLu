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
@synthesize daemonComms;

//init method
// set some intial flags, init daemon comms, etc.
-(id)init:(NSMenu*)menu firstTime:(BOOL)firstTime
{
    //preferences
    NSDictionary* preferences = nil;
    
    //super
    self = [super init];
    if(self != nil)
    {
        //init daemon comms
        daemonComms = [[DaemonComms alloc] init];
        
        //init status item
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
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
        
        //set notification for when theme toggles
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(interfaceChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
        
        //get prefs via XPC
        preferences = [self.daemonComms getPreferences];
        
        //set state based on (existing) preferences
        self.isDisabled = [preferences[PREF_IS_DISABLED] boolValue];
        
        //set initial menu state
        [self setState];
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
    
    return;
}

//cleanup popover
-(void)popoverDidClose:(NSNotification *)notification
{
    //unset
    self.popover = nil;
    
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
    
    //window notification
    NSNumber* windowNotification = nil;
    
    //commandline args
    NSArray* cmdline = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user clicked status menu item %lu", ((NSMenuItem*)sender).tag]);
    
    //toggle?
    // enable/disable
    if(toggle == ((NSMenuItem*)sender).tag)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling (%d)", self.isDisabled]);
        
        //invert since toggling
        self.isDisabled = !self.isDisabled;
        
        //set menu state
        [self setState];
        
        //update prefs
        [[[DaemonComms alloc] init] updatePreferences:@{PREF_IS_DISABLED:[NSNumber numberWithBool:self.isDisabled]}];
        
        //all done
        goto bail;
    }
    
    //get path to main app
    mainApp = getMainAppPath();
    
    //prefs
    //set window/cmdline flags
    if(prefs == ((NSMenuItem*)sender).tag)
    {
        //set window notification
        windowNotification = [NSNumber numberWithInt:WINDOW_PREFERENCES];
        
        //set cmdline args
        cmdline = @[CMDLINE_FLAG_PREFS];
    }
    
    //default to rules
    // set window/cmdline flags
    else
    {
        //set window notification
        windowNotification = [NSNumber numberWithInt:WINDOW_RULES];
        
        //set cmdline args
        cmdline = @[CMDLINE_FLAG_RULES];
    }
    
    //when main app alread running
    // just tell it to show correct window
    if(nil != [getProcessIDs([[NSBundle bundleWithPath:mainApp] executablePath], getuid()) firstObject])
    {
        //send
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SHOW_WINDOW object:nil userInfo:@{@"window":windowNotification} deliverImmediately:YES];
    }
    //otherwise
    // launch main app w/ cmdline args
    else
    {
        //launch main app
        if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:mainApp] options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: cmdline} error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to launch %@ (%@)", mainApp, error]);
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return;
}

//set menu status
// logic based on 'isEnabled' iVar
-(void)setState
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting state to: %@", (self.isDisabled) ? @"disabled" : @"enabled"]);
    
    //set to disabled
    if(YES == self.isDisabled)
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"LuLu: disabled";
        
        //change text
        [self.statusItem.menu itemWithTag:toggle].title = @"Enable";
    }
    
    //set to enabled
    else
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"LuLu: enabled";
        
        //change text
        [self.statusItem.menu itemWithTag:toggle].title = @"Disable";
    }
    
    //set icon
    [self setIcon];
    
    return;
}

//set status bar icon
// takes into account dark mode
-(void)setIcon
{
    //dark mode
    BOOL darkMode = NO;
    
    //set dark mode
    // !nil if dark mode is enabled
    darkMode = (nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting icon (dark mode: %d)", darkMode]);
    
    //enabled
    if(YES != self.isDisabled)
    {
        //alternate is always white
        self.statusItem.alternateImage = [NSImage imageNamed:@"statusIconWhite"];
        
        //normal (non) dark mode
        if(YES != darkMode)
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIcon"];
        }
        //dark mode
        else
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIconWhite"];
        }
    }
    //disabled
    else
    {
        //alternate is always white
        self.statusItem.alternateImage = [NSImage imageNamed:@"statusIconDisabledWhite"];
        
        //normal (non) dark mode
        if(YES != darkMode)
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIconDisabled"];
        }
        //dark mode
        else
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIconDisabledWhite"];
        }
    }
    
    return;
}

//callback for when theme changes
// just invoke helper method to change icon
-(void)interfaceChanged:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //set icon
    [self setIcon];
    
    return;
}

@end
