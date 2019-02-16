//
//  file: WelcomeWindowController.m
//  project: lulu (main app)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "WelcomeWindowController.h"

//buttons
#define SHOW_WELCOME 0
#define SHOW_CONFIGURE 1
#define SHOW_KEXT 2
#define SHOW_SUPPORT 3
#define OPEN_SYSTEM_PREFS 4
#define SUPPORT_NO 5
#define SUPPORT_YES 6

@implementation WelcomeWindowController

@synthesize welcomeViewController;

//welcome!
-(void)windowDidLoad {
    
    //super
    [super windowDidLoad];
    
    //center
    [self.window center];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //when supported
    // indicate title bar is transparent (too)
    if ([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //set title
    self.window.title = [NSString stringWithFormat:@"LuLu (version: %@)", getAppVersion()];
    
    //show welcome view
    [self showView:self.welcomeView firstResponder:SHOW_CONFIGURE];

    return;
}

//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender {
    
    //high sierra version struct
    NSOperatingSystemVersion highSierra = {10,13,0};
    
    //prev view was config?
    // send prefs to daemon to save
    if( (SHOW_CONFIGURE+1) == ((NSToolbarItem*)sender).tag)
    {
        //update prefs
        // pass in values from UI, plus some defaults
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient updatePreferences:@{PREF_ALLOW_APPLE: [NSNumber numberWithBool:self.allowApple.state], PREF_ALLOW_INSTALLED: [NSNumber numberWithBool:self.allowInstalled.state], PREF_PASSIVE_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_UPDATE_MODE:@NO}];
    }
    
    //set next view
    switch(((NSButton*)sender).tag)
    {
        //show configure view
        case SHOW_CONFIGURE:
            [self showView:self.configureView firstResponder:SHOW_KEXT];
            break;
            
        //show kext view
        // only show on macOS 10.13+ if kext isn't loaded
        case SHOW_KEXT:
        {
            //ask daemon to load kext
            // 'allow' button in system prefs ui times out, so this is really just to re-trigger
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient loadKext];
            
            //10.13+
            // show kext view
            if( (YES == [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:highSierra]) &&
                (YES != kextIsLoaded([NSString stringWithUTF8String:LULU_SERVICE_NAME])) )
            {
                //show kext view
                [self showView:self.kextView firstResponder:OPEN_SYSTEM_PREFS];
            }
            
            //kext already running,
            // show support view
            else
            {
                //show support view
                [self showView:self.supportView firstResponder:SUPPORT_YES];
            }
            
            break;
        }
            
        //support
        case OPEN_SYSTEM_PREFS:
        {
            //start spinner
            [self.activityIndicator startAnimation:nil];
            
            //disable button
            [(NSButton*)[self.kextView viewWithTag:OPEN_SYSTEM_PREFS] setEnabled:NO];
            
            //show system prefs & wait for kext to load
            // this will block so invoke in background to keep UI responsive 
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //launch system prefs and show 'privacy'
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?General"]];
                
                //wait for kext
                // will block...
                wait4kext([NSString stringWithUTF8String:LULU_SERVICE_NAME]);
                
                //quit 'System Preferences'
                [[[NSAppleScript alloc] initWithSource:@"tell application \"System Preferences\" to quit"] executeAndReturnError:nil];
                
                //ok loaded!
                // show support view now...
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    //show support view
                    [self showView:self.supportView firstResponder:SUPPORT_YES];
                    
                });
            });
            
            break;
        }
            
        //support, yes!
        case SUPPORT_YES:
            
            //open URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to terminate app
        
        //support, no :(
        case SUPPORT_NO:
            
            //exit
            [NSApp terminate:nil];
            
        default:
            break;
    }

    return;
}

//show a view
// note: replaces old view and highlights specified responder
-(void)showView:(NSView*)view firstResponder:(NSInteger)firstResponder
{
    //remove prev. subview
    [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    
    //set view
    [self.window.contentView addSubview:view];
    
    //make 'next' button first responder
    [self.window makeFirstResponder:[view viewWithTag:firstResponder]];

    return;
}
                

@end
