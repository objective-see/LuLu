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
#import "StatusBarItem.h"
#import "StatusBarPopoverController.h"

//menu items
enum menuItems
{
    status = 100,
    toggle,
    rules,
    prefs,
    end
};

@implementation StatusBarItem

@synthesize isDisabled;
@synthesize statusItem;

//init method
// set some intial flags, init daemon comms, etc.
-(id)init:(NSMenu*)menu preferences:(NSDictionary*)preferences firstTime:(BOOL)firstTime
{
    //super
    self = [super init];
    if(self != nil)
    {
        //create item
        [self createStatusItem:menu];
        
        //first time?
        // show popover
        if(YES == firstTime)
        {
            //show
            [self showPopover];
        }
        
        //set state based on (existing) preferences
        self.isDisabled = [preferences[PREF_IS_DISABLED] boolValue];
        
        //set initial menu state
        [self setState];
    }
    
    return self;
}

//create status item
-(void)createStatusItem:(NSMenu*)menu
{
    //init status item
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    //set menu
    self.statusItem.menu = menu;
    
    //set action handler for all menu items
    for(int i=toggle; i<end; i++)
    {
        //set action
        [self.statusItem.menu itemWithTag:i].action = @selector(handler:);
        
        //set state
        [self.statusItem.menu itemWithTag:i].enabled = YES;
        
        //set target
        [self.statusItem.menu itemWithTag:i].target = self;
    }
    
    return;
}

//remove status item
-(void)removeStatusItem
{
    //unset
    self.statusItem.view = nil;
    
    //remove item
    [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    
    //unset
    self.statusItem = nil;
    
    return;
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
    
    //wait a bit
    // then automatically hide popup if user has not closed it
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
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
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user clicked status menu item %lu", ((NSMenuItem*)sender).tag]);
    
    //handle user selection
    switch(((NSMenuItem*)sender).tag)
    {
        //toggle
        case toggle:
        
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling (%d)", self.isDisabled]);
        
            //invert since toggling
            self.isDisabled = !self.isDisabled;
        
            //set menu state
            [self setState];
        
            //update prefs
            [[[XPCDaemonClient alloc] init] updatePreferences:@{PREF_IS_DISABLED:[NSNumber numberWithBool:self.isDisabled]}];
        
            break;
            
        //rules
        case rules:
            
            //launch main app with 'rules' parameter
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"lulu://rules"]];
            
            break;
            
        //prefs
        case prefs:
            
            //launch main app with 'preferences' parameter
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"lulu://preferences"]];
            
            break;
            
        default:
            
            break;
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
        
        //set icon
        self.statusItem.button.image = [NSImage imageNamed:@"LoginItemStatusInactive"];
        
        //change toggle text
        [self.statusItem.menu itemWithTag:toggle].title = @"Enable";
    }
    
    //set to enabled
    else
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"LuLu: enabled";
        
        //set icon
        self.statusItem.button.image = [NSImage imageNamed:@"LoginItemStatusActive"];
        
        //change toggle text
        [self.statusItem.menu itemWithTag:toggle].title = @"Disable";
    }
    
    return;
}

@end
