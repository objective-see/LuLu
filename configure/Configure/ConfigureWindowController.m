//
//  file: ConfigureWindowController.m
//  project: lulu (config)
//  description: install/uninstall window logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize moreInfoButton;

//automatically called when nib is loaded
// just center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //when supported
    // indicate title bar is transparent (too)
    if ([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.installButton];
        
    });

    return;
}

//configure window/buttons
// also brings window to front
-(void)configure:(BOOL)isInstalled
{
    //yosemite
    // 10.10.0
    NSOperatingSystemVersion yosemite = {10,10,0};
    
    //set window title
    [self window].title = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //yosemite doesn't support emojis :|
    if(YES != [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:yosemite])
    {
        //init status msg
        [self.statusMsg setStringValue:@"signing info via the UI"];
    }
    //el capitan+ supports emojis
    else
    {
        //init status msg
        [self.statusMsg setStringValue:@"monitor network connections 🔥🛡️"];
    }
    
    //enable 'uninstall' button when app is installed already
    if(YES == isInstalled)
    {
        //enable
        self.uninstallButton.enabled = YES;
    }
    //otherwise disable
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// center, make front, set bg to white, etc
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //action
    NSInteger action = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@", ((NSButton*)sender).title]);
    
    //grab tag
    action = ((NSButton*)sender).tag;
    
    //restart?
    if(action == ACTION_RESTART_FLAG)
    {
        //bye!
        restart();
    }
    
    //close?
    else if(action == ACTION_CLOSE_FLAG)
    {
        //exit
        [NSApp terminate:self];
        
    }
    
    //install || uninstall
    else
    {
        //disable 'x' button
        // don't want user killing app during install/upgrade
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
        
        //clear status msg
        self.statusMsg.stringValue = @"";
        
        //force redraw of status msg
        // sometime doesn't refresh (e.g. slow VM)
        self.statusMsg.needsDisplay = YES;

        //invoke logic to install/uninstall
        // do in background so UI doesn't block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //install/uninstall
            [self lifeCycleEvent:action];
        });
    }
    
    return;
}

//button handler for '?' button (on an error)
// load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    #pragma unused(sender)
    
    //url
    NSURL *helpURL = nil;
    
    //build help URL
    helpURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#errors", PRODUCT_URL]];
    
    //open URL
    // invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:helpURL];
    
    return;
}

//perform install | uninstall via Control obj
// invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent:(NSInteger)event
{
    //status var
    BOOL status = NO;
    
    //begin event
    // updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //complete
        [self beginEvent:event];
    });
    
    //sleep
    // allow 'install' || 'uninstall' msg to show up
    [NSThread sleepForTimeInterval:0.5];
  
    //perform action (install | uninstall)
    // perform background actions
    if(YES == [((AppDelegate*)[[NSApplication sharedApplication] delegate]).configureObj configure:event])
    {
        //set flag
        status = YES;
        
        //for install
        // wait until kext cache rebuild is done
        if(ACTION_INSTALL_FLAG == event)
        {
            //update status msg
            dispatch_async(dispatch_get_main_queue(),
            ^{
                //set status msg
                [self.statusMsg setStringValue:@"Rebuilding kernel cache\n\t\t ...please wait!"];
            });
            
            //nap
            // give time for kext cache to start....
            [NSThread sleepForTimeInterval:5.0];
            
            //wait until kextcache has exited
            while(YES)
            {
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"waiting for '%@' to complete", KEXT_CACHE]);
                
                //nap
                [NSThread sleepForTimeInterval:1.0];
                
                //exit'd?
                if(0 == [getProcessIDs(KEXT_CACHE, -1) count])
                {
                    //bye
                    break;
                }
            }
        }
    }
    
    //error occurred
    else
    {
        //set flag
        status = NO;
    }
    
    //complete event
    // updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// basically just update UI
-(void)beginEvent:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {{0,0}, {0,0}};
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    self.statusMsg.alignment = NSLeftTextAlignment;
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        [self.statusMsg setStringValue:@"Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        [self.statusMsg setStringValue:@"Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {{0,0}, {0,0}};
    
    //action
    NSString* action = nil;
    
    //result msg
    NSMutableString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //set action msg for install
    if(ACTION_INSTALL_FLAG == event)
    {
        //set msg
        action = @"install";
    }
    //set action msg for uninstall
    else
    {
        //set msg
        action = @"uninstall";
    }
    
    //success
    if(YES == success)
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"LuLu %@ed!\nRestart required to complete.", action];
        
        //set font to black
        resultMsgColor = [NSColor blackColor];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"error: %@ failed", action];
        
        //set font to red
        resultMsgColor = [NSColor redColor];
        
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    self.activityIndicator.hidden = YES;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //shift back since activity indicator is gone
    statusMsgFrame.origin.x -= FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //set font to bold
    self.statusMsg.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
    
    //set msg color
    self.statusMsg.textColor = resultMsgColor;
    
    //set status msg
    self.statusMsg.stringValue = resultMsg;
    
    //success
    // set button title and tag for restart
    if(YES == success)
    {
        //restart
        self.installButton.title = ACTION_RESTART;
        
        //update it's tag
        // will allow button handler method process
        self.installButton.tag = ACTION_RESTART_FLAG;
    }
    
    //failed
    // set button and tag for close/exit
    else
    {
        //close
        self.installButton.title = ACTION_CLOSE;
        
        //update it's tag
        // will allow button handler method process
        self.installButton.tag = ACTION_CLOSE_FLAG;
    }
    
    //enable
    self.installButton.enabled = YES;

    //...and highlighted
    [self.window makeFirstResponder:self.installButton];
   
    //ok to re-enable 'x' button
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically invoked when window is closing
// just exit application
-(void)windowWillClose:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //exit
    [NSApp terminate:self];
    
    return;
}

@end
