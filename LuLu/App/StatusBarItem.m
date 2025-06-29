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
    profile,
    toggle,
    rulesShow,
    rulesAdd,
    rulesExport,
    rulesImport,
    rulesCleanup,
    profilesManage,
    prefs,
    monitor,
    quit,
    uninstall,
    support,
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
    
    //set menu / delegate
    self.statusItem.menu = menu;
    self.statusItem.menu.delegate = self;
    
    //set handler for each menu item
    [self setMenuHandler:menu];
    
    //disable first two menu items
    // as they are purely informative
    [menu.itemArray[0] setEnabled:NO];
    [menu.itemArray[0] setAction:nil];
    [menu.itemArray[1] setEnabled:NO];
    [menu.itemArray[1] setAction:nil];
    
    //init profiles items/sub-menu
    [self setProfile:[xpcDaemonClient getProfiles] current:[xpcDaemonClient getCurrentProfile]];
    
    return;
}

//menu 'will open' delegate
// make sure popover is closed
-(void)menuWillOpen:(NSMenu *)menu
{
    //make sure to close popover first
    if(YES == self.popover.shown)
    {
        //close
        [self.popover performClose:nil];
    }
    
    return;
}

//set handler for menu item(s)
-(void)setMenuHandler:(NSMenu*)menu
{
    //iterate over all menu items
    // add target, enable, and handler for each
    for(NSMenuItem* menuItem in menu.itemArray)
    {
        //handle sub-menu(s)
        if(nil != menuItem.submenu)
        {
            //recursively set actions for submenu items
            [self setMenuHandler:menuItem.submenu];
            
            continue;
        }
        
        //set target
        menuItem.target = self;
        
        //enable
        menuItem.enabled = YES;
        
        //set action, to handler
        menuItem.action = @selector(handler:);
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
    // don't want it close before timeout (unless user clicks '^')
    self.popover.behavior = NSPopoverBehaviorApplicationDefined;
    
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
                showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: Failed to import rules", @"ERROR: Failed to import rules"), NSLocalizedString(@"See log for (more) details",@"See log for (more) details"), @[NSLocalizedString(@"OK", @"OK")]);
                
                //bail
                goto bail;
            }
            
            //then show rules
            [self.rulesMenuController showRules];
            
            break;
            
        //rules: cleanup
        case rulesCleanup:
            
            //cleanup
            if([self.rulesMenuController cleanupRules] < 0)
            {
                //show alert
                showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: Failed to cleanup rules", @"ERROR: Failed to cleanup rules"), NSLocalizedString(@"See log for (more) details",@"See log for (more) details"), @[NSLocalizedString(@"OK",@"OK")]);
                
                //bail
                goto bail;
            }
            break;
        
        //profiles
        case profilesManage:
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showPreferences:TOOLBAR_PROFILES_ID];
            break;
            
        //prefs
        // default to rules
        case prefs:
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showPreferences:TOOLBAR_RULES_ID];
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
            
        //support
        case support:
            
            //open URL
            // invokes user's default browser
            [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:PATREON_URL]];
            break;
        
        default:
            
            break;
    }
    
bail:
    
    return;
}

//TODO: just ask XPC?
//state current profile
-(void)setProfile:(NSArray*)profiles current:(NSString*)current
{
    //grab menu
    NSMenu* menu = [((AppDelegate*)[[NSApplication sharedApplication] delegate]) profilesMenu];
    
    //set current profile
    if(nil != current)
    {
        //(re)set to default
        [self.statusItem.menu itemWithTag:profile].title = current;
    }
    //otherwise (re)set to default
    else
    {
        //set
        [self.statusItem.menu itemWithTag:profile].title = NSLocalizedString(@"Profile: Default", @"Profile: Default");
    }
    
    //reset profiles menu
    [menu removeAllItems];
    
    //have profiles?
    // add each name and enable 'Switch' menu item
    if(0 != profiles.count)
    {
        //enable
        [[((AppDelegate*)[[NSApplication sharedApplication] delegate]) profileSwitchMenuItem] setEnabled:YES];
        
        //add each name
        for(NSString *name in profiles) {
            
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:@selector(switchToProfile:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = name;
        
            //add
            [menu addItem:item];
        }
    }
    //otherwise disable
    else
    {
        //disable
        [[((AppDelegate*)[[NSApplication sharedApplication] delegate]) profileSwitchMenuItem] setEnabled:NO];
    }
}

//switch profile
- (void)switchToProfile:(NSMenuItem *)sender {
    
    //grab profile
    NSString* profile = sender.representedObject;
    
    //set profile via XPC
    [xpcDaemonClient setProfile:profile];
    
    //reload menu states
    [self setProfile:[xpcDaemonClient getProfiles] current:[xpcDaemonClient getCurrentProfile]];
    
    //TODO: tell prefs? (need to reload prefs window, if open).
    //TODO: handle other settings - like if profile is no menu mode?
    
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
        [self.statusItem.menu itemWithTag:status].title = NSLocalizedString(@"LuLu: disabled", @"LuLu: disabled");
        
        //set icon
        self.statusItem.button.image = [NSImage imageNamed:@"StatusInactive"];
        
        //change toggle text
        [self.statusItem.menu itemWithTag:toggle].title = NSLocalizedString(@"Enable", @"Enable");
    }
    
    //set to enabled
    else
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = NSLocalizedString(@"LuLu: enabled", @"LuLu: enabled");
        
        //set icon
        self.statusItem.button.image = [NSImage imageNamed:@"StatusActive"];
        
        //change toggle text
        [self.statusItem.menu itemWithTag:toggle].title = NSLocalizedString(@"Disable", @"Disable");
    }
    
    return;
}

@end
