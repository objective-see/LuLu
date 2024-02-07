//
//  file: StatusBarMenu.m
//  project: lulu (login item)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "Extension.h"
#import "AppDelegate.h"
#import "StatusBarItem.h"
#import "StatusBarPopoverController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

//menu items
enum menuItems
{
    status = 100,
    toggle,
    rulesShow,
    rulesAdd,
    rulesExport,
    rulesImport,
    rulesCleanup,
    prefs,
    monitor,
    quit,
    uninstall,
    end
};

@implementation StatusBarItem

@synthesize isDisabled;
@synthesize statusItem;
@synthesize rulesMenuController;

//init method
// set some intial flags, init daemon comms, etc.
-(id)init:(NSMenu*)menu preferences:(NSDictionary*)preferences
{
    //token
    static dispatch_once_t onceToken = 0;
    
    //super
    self = [super init];
    if(self != nil)
    {
        //init rules (sub)menu handler
        rulesMenuController = [[RulesMenuController alloc] init];
        
        //create item
        [self createStatusItem:menu];
        
        //set state based on (existing) preferences
        self.isDisabled = [preferences[PREF_IS_DISABLED] boolValue];
        
        //only once
        // show popover
        dispatch_once(&onceToken, ^{
            
            //parent
            NSDictionary* parent = nil;
            
            //get real parent
            parent = getRealParent(getpid());
            
            //dbg msg
            os_log_debug(logHandle, "(real) parent: %{public}@", parent);
            
            //only show popover if we're not autolaunched
            if(YES != [parent[@"CFBundleIdentifier"] isEqualToString:@"com.apple.loginwindow"])
            {
                //dbg msg
                os_log_debug(logHandle, "...user launched, so will show status bar popover");
                
                //show
                [self showPopover];
            }
            
        });
    
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
    
    //set handler for each menu item
    [self setMenuHandler:menu];
    
    return;
}

//set handler for menu item(s)
-(void)setMenuHandler:(NSMenu*)menu
{
    //iterate over all menu items
    // add target, enable, and handler for each
    for(NSMenuItem* menuItem in menu.itemArray)
    {
        //set target
        menuItem.target = self;
        
        //enable
        menuItem.enabled = YES;
        
        //set action, to handler
        menuItem.action = @selector(handler:);
        
        //handle sub-menu(s)
        if(nil != menuItem.submenu)
        {
            // Recursively set actions for submenu items
            [self setMenuHandler:menuItem.submenu];
        }
    }
    
    return;
}

//remove status item
-(void)removeStatusItem
{
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
    self.statusItem.button.cell.highlighted = NO;
    
    //set target
    self.statusItem.button.target = self;
    
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
        //still visible?
        // close it then...
        if(YES == self.popover.shown)
        {
            //close
            [self.popover performClose:nil];
        }
            
        //remove action handler
        self.statusItem.button.action = nil;
        
        //reset highlight mode
        ((NSButtonCell*)self.statusItem.button.cell).highlightsBy = NSContentsCellMask | NSChangeBackgroundCellMask;
    });
    
    return;
}

//cleanup popover
-(void)popoverDidClose:(NSNotification *)notification
{
    //unset
    self.popover = nil;
    
    //reset highlight mode
    ((NSButtonCell*)self.statusItem.button.cell).highlightsBy = NSContentsCellMask | NSChangeBackgroundCellMask;
    
    return;
}

//menu handler
-(void)handler:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "handling button click: %{public}@ (%ld)", ((NSButton*)sender).title, ((NSButton*)sender).tag);
    
    //handle user selection
    switch(((NSMenuItem*)sender).tag)
    {
        //toggle
        case toggle:
        {
            //dbg msg
            os_log_debug(logHandle, "toggling (%d -> %d)", self.isDisabled, !self.isDisabled);
        
            //invert since toggling
            self.isDisabled = !self.isDisabled;
        
            //set menu state
            [self setState];
        
            //update prefs
            [xpcDaemonClient updatePreferences:@{PREF_IS_DISABLED:[NSNumber numberWithBool:self.isDisabled]}];
            
            //toggle network extension based on (new) state
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //toggle
                [[[Extension alloc] init] toggleNetworkExtension:!self.isDisabled];
            });
            
            break;
        }
           
        //rules: show
        case rulesShow:
            
            //show
            [self.rulesMenuController showRules];
            
            break;
            
        //rules: add
        case rulesAdd:
            
            //show first
            [self.rulesMenuController showRules];
            
            //add
            [self.rulesMenuController addRule];
            
            break;
            
        //rules: export
        case rulesExport:
            
            //show first
            [self.rulesMenuController showRules];
            
            //export
            [self.rulesMenuController exportRules];
            
            break;
        
        //rules: import
        case rulesImport:
            
            //import
            if(YES != [self.rulesMenuController importRules])
            {
                //show alert
                showAlert(NSAlertStyleWarning, @"ERROR: Failed to import rules", @"See log for (more) details", @[@"OK"]);
                
                //bail
                goto bail;
            }
            
            //then show rules
            [self.rulesMenuController showRules];
            
            break;
            
        //rules: cleanup
        case rulesCleanup:
            
            //cleanup
            if(YES != [self.rulesMenuController cleanupRules])
            {
                //show alert
                showAlert(NSAlertStyleWarning, @"ERROR: Failed to cleanup rules", @"See log for (more) details", @[@"OK"]);
                
                //bail
                goto bail;
            }
            break;
                
        //prefs
        case prefs:
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showPreferences:sender];
            break;
            
        //monitor
        // launch netiquette (with lulu args)
        case monitor:
        {
            //path
            NSURL* path = nil;
           
            //error
            NSError* error = nil;
           
            //init path
            path = [NSURL fileURLWithPath:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:NETWORK_MONITOR]];
            
            //dbg msg
            os_log_debug(logHandle, "launching network monitor (%{public}@)", path);
            
            //launch
            // with args
            if(nil == [NSWorkspace.sharedWorkspace launchApplicationAtURL:path options:0 configuration:[NSDictionary dictionaryWithObject:@[@"-lulu"] forKey:NSWorkspaceLaunchConfigurationArguments] error:&error])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to launch network monitor, %{public}@, (error: %{public}@)", path, error);
            }
            
            break;
        }
            
        //quit
        case quit:
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) quit:sender];
            break;
            
        //uninstall
        case uninstall:
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) uninstall:sender];
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
    os_log_debug(logHandle, "setting state to: %@", (self.isDisabled) ? @"disabled" : @"enabled");
    
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
