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

#define VIEW_WELCOME 0
#define VIEW_CONFIGURE 1
#define VIEW_KEXT 2
#define OPEN_SYSTEM_PREFS 3
#define SUPPORT_NO 4
#define SUPPORT_YES 5

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
    
    //show first view
    [self buttonHandler:nil];

    return;
}

//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender {
    
    //high sierra version struct
    NSOperatingSystemVersion highSierra = {10,13,0};
    
    //apple script object
    __block NSAppleScript* scriptObject = nil;
    
    //prev view was config?
    // send prefs to daemon to save
    if( (VIEW_CONFIGURE+1) == ((NSToolbarItem*)sender).tag)
    {
        //update prefs
        // pass in values from UI, plus some defaults
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).xpcDaemonClient updatePreferences:@{PREF_ALLOW_APPLE: [NSNumber numberWithBool:self.allowApple.state], PREF_ALLOW_INSTALLED: [NSNumber numberWithBool:self.allowInstalled.state], PREF_PASSIVE_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_UPDATE_MODE:@NO}];
    }
    
    //set next view
    switch(((NSButton*)sender).tag)
    {
        //welcome
        case VIEW_WELCOME:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.welcomeView];
            
            //make 'next' button first responder
            [self.window makeFirstResponder:[self.welcomeView viewWithTag:VIEW_CONFIGURE]];
        
            break;
        }
            
        //configure
        case VIEW_CONFIGURE:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.configureView];
            
            //make 'next' button first responder
            [self.window makeFirstResponder:[self.configureView viewWithTag:VIEW_KEXT]];
            
            break;
        }
            
        //kext
        // only show on macOS 10.13+ if kext isn't loaded
        case VIEW_KEXT:
            
            //10.13+ and kext not yet loaded?
            if( (YES == [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:highSierra]) &&
                (YES != kextIsLoaded([NSString stringWithUTF8String:LULU_SERVICE_NAME])) )
            {
                //remove prev. subview
                [[[self.window.contentView subviews] lastObject] removeFromSuperview];
                
                //set view
                [self.window.contentView addSubview:self.kextView];
                
                //make 'show system prefs' button first responder
                [self.window makeFirstResponder:[self.kextView viewWithTag:OPEN_SYSTEM_PREFS]];
            }
            
            //older os || kext loaded
            // can skip, so just show support view
            else
            {
                //remove prev. subview
                [[[self.window.contentView subviews] lastObject] removeFromSuperview];
                
                //set view
                [self.window.contentView addSubview:self.supportView];
                
                //make 'yes' button first responder
                [self.window makeFirstResponder:[self.supportView viewWithTag:SUPPORT_YES]];
            }
            
            break;
            
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
                //init apple script
                // have it show 'General' tab of 'Security Pane'
                scriptObject = [[NSAppleScript alloc] initWithSource:
                                @"tell application \"System Preferences\"\n" \
                                "activate\n" \
                                "reveal anchor \"General\" of pane id \"com.apple.preference.security\"\n" \
                                "end tell\n"];
                
                //execute to open prefs
                [scriptObject executeAndReturnError:nil];
                
                //wait for kext
                // will block...
                wait4kext([NSString stringWithUTF8String:LULU_SERVICE_NAME]);
                
                //init apple script
                // have it tell 'System Preferences' to quit
                scriptObject = [[NSAppleScript alloc] initWithSource:@"tell application \"System Preferences\" to quit"];
                
                //execute to quit 'System Preferences'
                [scriptObject executeAndReturnError:nil];
                
                //ok loaded!
                // show next view
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    //remove prev. subview
                    [[[self.window.contentView subviews] lastObject] removeFromSuperview];
                    
                    //set view
                    [self.window.contentView addSubview:self.supportView];
                    
                    //make 'yes' button first responder
                    [self.window makeFirstResponder:[self.supportView viewWithTag:SUPPORT_YES]];
                    
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

@end
