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
@synthesize welcomeViewController;

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
    if ([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //set title
    self.window.title = [NSString stringWithFormat:@"LuLu (version: %@)", getAppVersion()];
    
    //show welcome view
    [self showView:self.welcomeView firstResponder:SHOW_ALLOW_EXT];
    
    //make key and front
    [self.window makeKeyAndOrderFront:self];
    
    //make app active
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender {
    
    //leaving prefs view?
    // capture prefs
    if( (SHOW_CONFIGURE+1) == ((NSToolbarItem*)sender).tag)
    {
        //capture
        self.preferences = @{PREF_ALLOW_APPLE:[NSNumber numberWithBool:self.allowApple.state], PREF_ALLOW_INSTALLED: [NSNumber numberWithBool:self.allowInstalled.state], PREF_PASSIVE_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_UPDATE_MODE:@NO, PREF_INSTALL_TIMESTAMP:[NSDate date]};
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
                
                //goto to next view!
                [self showView:self.configureView firstResponder:SHOW_SUPPORT];
                
                //done
                break;
            }
            
            //show view
            [self showView:self.allowExtensionView firstResponder:-1];
            
            //show message
            self.allowExtMessage.hidden = NO;
            
            //show spinner
            self.allowExtActivityIndicator.hidden = NO;
            
            //start spinner
            [self.allowExtActivityIndicator startAnimation:nil];
            
            //in background
            // activate and wait for extension to be approved
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //extension
                Extension* extension = nil;
                
                //wait semaphore
                dispatch_semaphore_t semaphore = 0;
                
                //init extension object
                extension = [[Extension alloc] init];
                
                //init wait semaphore
                semaphore = dispatch_semaphore_create(0);
                
                //kick off extension activation request
                [extension toggleExtension:ACTION_ACTIVATE reply:^(BOOL toggled) {
                    
                    //dbg msg
                    os_log_debug(logHandle, "extension 'activate' returned");
                    
                    //signal semaphore
                    dispatch_semaphore_signal(semaphore);
                    
                    //error
                    if(YES != toggled)
                    {
                        //err msg
                        os_log_error(logHandle, "ERROR: failed to activate extension");
                        
                        //show alert
                        showAlert(@"ERROR: activation failed", @"failed to activate system/network extension");
                        
                        //bye
                        [NSApplication.sharedApplication terminate:self];
                    }
                    //happy
                    else
                    {
                        //dbg msg
                        os_log_debug(logHandle, "extension + network filtering approved");
                        
                        //wait till it's up and running
                        while(YES != [extension isExtensionRunning])
                        {
                            //nap
                            [NSThread sleepForTimeInterval:0.25];
                        }
                        
                        //dbg msg
                        os_log_debug(logHandle, "extension now up and running");
                        
                        //update UI
                        dispatch_sync(dispatch_get_main_queue(),
                        ^{
                            //hide spinner
                            self.allowExtActivityIndicator.hidden = YES;
                            
                            //hide message
                            self.allowExtMessage.hidden = YES;
                            
                            //goto to next view!
                            [self showView:self.configureView firstResponder:SHOW_SUPPORT];
                            
                            //make it key window
                            [self.window makeKeyAndOrderFront:self];
                            
                            //make window front
                            [NSApp activateIgnoringOtherApps:YES];
                            
                        });
                    }
                }];
                
                //wait for extension semaphore
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

            });
            
            break;
        }
            
        //show configure view
        case SHOW_CONFIGURE:
            [self showView:self.configureView firstResponder:SHOW_SUPPORT];
            break;
            
        //show configure view
        case SHOW_SUPPORT:
            [self showView:self.supportView firstResponder:SUPPORT_YES];
            break;
            
        //support, yes!
        case SUPPORT_YES:
            
            //open URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to kick off main logic / close
        
        //support, no :(
        case SUPPORT_NO:
            
            //kick off main client logic
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) completeInitialization:self.preferences];
            
            //close window
            [self.window close];
            
            //finally set app's background/foreground state
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
            
        default:
            break;
    }

    return;
}

//show a view
// note: replaces old view and highlights specified responder
-(void)showView:(NSView*)view firstResponder:(NSInteger)firstResponder
{
    //x position
    CGFloat xPos = 0;
    
    //y position
    CGFloat yPos = 0;
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //set white
        view.layer.backgroundColor = [NSColor whiteColor].CGColor;
    }
    
    //set content view size
    self.window.contentSize = view.frame.size;
    
    //update config view
    self.window.contentView = view;
    
    //center x
    xPos = NSWidth(self.window.screen.frame)/2 - NSWidth(self.window.frame)/2;
    
    //center y
    yPos = NSHeight(self.window.screen.frame)/2 - NSHeight(self.window.frame)/2;
    
    //center window
    [self.window setFrame:NSMakeRect(xPos, yPos, NSWidth(self.window.frame), NSHeight(self.window.frame)) display:YES];

    //make 'next' button first responder
    // calling this without a timeout, sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        if(-1 != firstResponder)
        {
            //first responder
            [self.window makeFirstResponder:[view viewWithTag:firstResponder]];
        }
        
    });

    return;
}

@end
