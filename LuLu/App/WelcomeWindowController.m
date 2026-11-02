//
//  file: WelcomeWindowController.m
//  project: lulu (main app)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "Extension.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "WelcomeWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//buttons
#define SHOW_WELCOME 0
#define SHOW_ALLOW_EXT 1
#define SHOW_CONFIGURE 2
#define SHOW_SUPPORT 3
#define SUPPORT_NO 4
#define SUPPORT_YES 5

@implementation WelcomeWindowController

@synthesize preferences;

//welcome!
-(void)windowDidLoad {
    
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //when supported
    // indicate title bar is transparent (too)
    if(YES == [self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //set title
    self.window.title = [NSString stringWithFormat:@"LuLu v%@", getAppVersion()];
    
    //init pages
    // each 'next' button invokes the button handler, w/ the tag of the page to show next
    self.welcomePage = [[WelcomeSplashPage alloc] init];
    [self.welcomePage addNextButton:NSLocalizedString(@"Next", @"Next") tag:SHOW_ALLOW_EXT target:self action:@selector(buttonHandler:)];
    
    self.permissionsPage = [[PermissionsPage alloc] init];
    [self.permissionsPage addNextButton:NSLocalizedString(@"Next", @"Next") tag:SHOW_CONFIGURE target:self action:@selector(permissionsButtonHandler:)];
    [self.permissionsPage updateNextButton];
    
    self.configurePage = [[ConfigurePage alloc] init];
    [self.configurePage addNextButton:NSLocalizedString(@"Next", @"Next") tag:SHOW_SUPPORT target:self action:@selector(buttonHandler:)];
    
    self.supportPage = [[SupportPage alloc] initWithSupportTag:SUPPORT_YES target:self action:@selector(buttonHandler:)];
    [self.supportPage addNextButton:NSLocalizedString(@"Done", @"Done") tag:SUPPORT_NO target:self action:@selector(buttonHandler:)];
    
    //show welcome page
    [self showPage:self.welcomePage];
    
    //make key and front
    [self.window makeKeyAndOrderFront:self];
    
    //activate
    if(@available(macOS 14.0, *)) {
        [NSApp activate];
    }
    else
    {
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    //(re)make front
    [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
    
    return;
}

//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender {
    
    //leaving prefs view?
    // capture prefs/set defaults
    if(SHOW_SUPPORT == ((NSButton*)sender).tag)
    {
        //capture
        self.preferences = @{PREF_ALLOW_APPLE:[NSNumber numberWithBool:(NSControlStateValueOn == self.configurePage.allowApple.state)], PREF_ALLOW_INSTALLED: [NSNumber numberWithBool:(NSControlStateValueOn == self.configurePage.allowInstalled.state)], PREF_ALLOW_DNS: [NSNumber numberWithBool:(NSControlStateValueOn == self.configurePage.allowDNS.state)], PREF_ALLOW_LOCALHOST:@YES, PREF_ALLOW_SIMULATOR:@NO, PREF_PASSIVE_MODE:@NO, PREF_PASSIVE_MODE_ACTION:@0, PREF_BLOCK_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_VT_MODE:@NO, PREF_NO_UPDATE_MODE:@NO, PREF_INSTALL_TIMESTAMP:[NSDate date]};
    }
    
    //set next view
    switch(((NSButton*)sender).tag)
    {
        //show "allow extension" view
        // waits until extension is loaded!
        case SHOW_ALLOW_EXT:
        {
            //skip if extension is already active
            if(YES == [[[Extension alloc] init] isNetworkExtensionEnabled])
            {
                //dbg msg
                os_log_debug(logHandle, "network extension already enabled, jumping to 'configure' view");
                
                //goto to next page!
                [self showPage:self.configurePage];
                
                //done
                break;
            }
            
            //show page
            [self showPage:self.permissionsPage];
            
            //request permissions
            // activates system extension, then the content filter
            [self requestPermissions];
            
            break;
        }
            
        //show configure page
        case SHOW_CONFIGURE:
            
            //show
            [self showPage:self.configurePage];
            
            break;
            
        //show "support us" view
        // + kick off main logic so traffic filtering is started
        case SHOW_SUPPORT:
            
            //show support page
            [self showPage:self.supportPage];
            
            //kick off main (client) logic
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) completeInitialization:self.preferences];
            
            break;
            
        //support, yes!
        case SUPPORT_YES:
            
            //open patreon URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to close/set app state
        
        //support, no :(
        case SUPPORT_NO:
            
            //close window
            [self.window close];
            
            //finally set app's background/foreground state
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
            
            break;
            
        default:
            break;
    }

    return;
}

//'next' / 'retry' button handler (permissions page)
-(IBAction)permissionsButtonHandler:(id)sender
{
    //both granted?
    // show configure page
    if( (PermissionStateGranted == self.permissionsPage.extensionRow.state) &&
        (PermissionStateGranted == self.permissionsPage.filterRow.state) )
    {
        //show
        [self showPage:self.configurePage];
    }
    //otherwise
    // (re)request
    else
    {
        //retry
        [self requestPermissions];
    }
    
    return;
}

//request permissions
// activate the system extension (macOS: approve in System Settings), then the content filter (macOS: 'allow' prompt)
// ...each step updates its row on the permissions page; once both are granted, user can continue
-(void)requestPermissions
{
    //rows
    PermissionRow* extensionRow = self.permissionsPage.extensionRow;
    PermissionRow* filterRow = self.permissionsPage.filterRow;
    
    //init extension object
    self.extension = [[Extension alloc] init];
    
    //(re)set rows
    [extensionRow setState:PermissionStateChecking message:nil];
    [filterRow setState:PermissionStatePending message:nil];
    [self.permissionsPage updateNextButton];
    
    //kick off extension activation request
    [self.extension toggleExtension:ACTION_ACTIVATE reply:^(NSError* error) {
        
        //filter enabled?
        BOOL enabled = NO;
        
        //dbg msg
        os_log_debug(logHandle, "extension 'activate' returned");
        
        //error?
        // includes 'will complete after reboot'
        if(nil != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to activate system extension: %{public}@", error);
            
            //update UI
            dispatch_async(dispatch_get_main_queue(),
            ^{
                //failed
                [extensionRow setState:PermissionStateFailed message:error.localizedDescription];
                [self.permissionsPage updateNextButton];
            });
            
            return;
        }
        
        //dbg msg
        os_log_debug(logHandle, "system extension activated");
        
        //update UI
        dispatch_sync(dispatch_get_main_queue(),
        ^{
            //granted
            [extensionRow setState:PermissionStateGranted message:nil];
            
            //now, the filter
            [filterRow setState:PermissionStateChecking message:nil];
        });
        
        //activate network extension (content filter)
        // macOS prompts the user to allow LuLu to filter network content
        enabled = [self.extension toggleNetworkExtension:ACTION_ACTIVATE];
        if(YES != enabled)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to activate network extension");
        }
        //dbg msg
        else
        {
            //dbg msg
            os_log_debug(logHandle, "network filter approved/enabled");
        }
        
        //update UI
        dispatch_async(dispatch_get_main_queue(),
        ^{
            //granted, or failed
            if(YES == enabled)
            {
                //granted
                [filterRow setState:PermissionStateGranted message:nil];
            }
            else
            {
                //failed
                [filterRow setState:PermissionStateFailed message:NSLocalizedString(@"The content filter wasn't enabled.", @"The content filter wasn't enabled.")];
            }
            
            //update
            [self.permissionsPage updateNextButton];
            
            //make it key window
            // user was likely in System Settings
            [self.window makeKeyAndOrderFront:self];
            
            //activate
            if(@available(macOS 14.0, *)) {
                [NSApp activate];
            }
            else
            {
                [NSApp activateIgnoringOtherApps:YES];
            }
            
            //(re)make front
            [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
        });
    }];
    
    //needs approval? tell the user
    // flag is set (asynchronously) by the request's delegate, so poll for it
    [self pollApproval:self.extension];
    
    return;
}

//poll for 'needs approval'
// updates the extension row (w/ 'Open System Settings…') when the user has to approve the extension
-(void)pollApproval:(Extension*)extension
{
    //check (again) in a bit
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(),
    ^{
        //stale (retried), or no longer checking?
        if( (extension != self.extension) ||
            (PermissionStateChecking != self.permissionsPage.extensionRow.state) )
        {
            //done
            return;
        }
        
        //needs approval?
        if(YES == extension.needsApproval)
        {
            //update
            [self.permissionsPage.extensionRow setState:PermissionStateWaiting message:NSLocalizedString(@"Approve “LuLu” under Network Extensions, then come back.", @"Approve “LuLu” under Network Extensions, then come back.")];
            
            //done
            return;
        }
        
        //poll again
        [self pollApproval:extension];
    });
    
    return;
}

//show a page
// all pages share a size, so the window is only sized/centered once
-(void)showPage:(WelcomePage*)page
{
    //not in dark mode?
    // make page white
    if(YES != isDarkMode())
    {
        //set white
        page.layer.backgroundColor = [NSColor whiteColor].CGColor;
    }
    
    //first page?
    // size & center window
    if(nil == self.window.contentView.subviews.firstObject || YES != [self.window.contentView isKindOfClass:[WelcomePage class]])
    {
        //size
        self.window.contentSize = page.frame.size;
        
        //center
        [self.window center];
    }
    
    //swap in page
    self.window.contentView = page;
    
    //'next' is the default button
    [self.window makeFirstResponder:page.nextButton];
    
    return;
}

@end
