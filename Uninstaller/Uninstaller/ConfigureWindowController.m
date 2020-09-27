//
//  file: ConfigureWindowController.m
//  project: lulu (config)
//  description: install/uninstall window logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "ConfigureWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize moreInfoButton;
@synthesize appActivationObserver;

//automatically called when nib is loaded
// just center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //set delegate
    self.window.delegate = self;
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set transparency
    self.window.titlebarAppearsTransparent = YES;
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.upgradeButton];
        
    });

    //init config obj
    if(nil == self.configure) self.configure = [[Configure alloc] init];
    
    return;
}

//button handler
-(IBAction)buttonHandler:(id)sender
{
    //action
    NSInteger action = 0;
    
    //grab tag
    action = ((NSButton*)sender).tag;
    
    //dbg msg
    os_log_debug(logHandle, "handling button click: %{public}@ (%ld)", ((NSButton*)sender).title, (long)action);
    
    //process button
    switch(action)
    {
        //uninstall
        case ACTION_UPGRADE_FLAG:
        case ACTION_UNINSTALL_FLAG:
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
               //uninstall/upgrade
               [self lifeCycleEvent:action];
            });
            
            break;
        }
        //restart
        case ACTION_RESTART_FLAG:
            
            //disable button
            self.restartButton.enabled = NO;
            
            //cleanup
            [self cleanup];
            
            //disable re-launch
            [NSApplication.sharedApplication disableRelaunchOnLogin];
            
            //restart after a bit (allow cleanup to completee)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //bye!
                restart();
                
            });
            
            break;
            
        //close
        // triggers cleanup logic
        case ACTION_CLOSE_FLAG:
            [self.window close];
            break;
            
        //default
        default:
            break;
    }
    
    return;
}

//button handler for '?' button (on an error)
// load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    #pragma unused(sender)
    
    //open URL
    // invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:ERRORS_URL]];
    
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
    
    //perform action (uninstall/upgrade)
    if(YES == [self.configure uninstall:event])
    {
        //dbg msg
        os_log_debug(logHandle, "XPC uninstall logic completed");
        
        //set flag
        status = YES;
        
        //update status msg
        dispatch_async(dispatch_get_main_queue(),
        ^{
            //set status msg
            [self.statusMsg setStringValue:@"Rebuilding kernel cache\n\t\t ...please wait!"];
        });
        
        //wait until 'kextcache' has exited
        while(YES)
        {
            //dbg msg
            os_log_debug(logHandle, "waiting for '%@' to complete", KEXT_CACHE);
            
            //nap
            [NSThread sleepForTimeInterval:1.0];
            
            //exit'd?
            if(0 == [getProcessIDs(KEXT_CACHE, -1) count])
            {
                //bye
                break;
            }
        }
        
        //dbg msg
        os_log_debug(logHandle, "'%@' completed", KEXT_CACHE);
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
    CGRect statusMsgFrame;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    self.statusMsg.alignment = NSTextAlignmentLeft;
    
    //observe app activation
    // allows workaround where process indicator stops
    self.appActivationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSWorkspaceDidActivateApplicationNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        #pragma unused(notification)
        
        //show spinner
        self.activityIndicator.hidden = NO;
        
        //start spinner
        [self.activityIndicator startAnimation:nil];
        
    }];
    
    //set status msg
    (ACTION_UPGRADE_FLAG == event) ? [self.statusMsg setStringValue:@"Upgrading..."] : [self.statusMsg setStringValue:@"Uninstalling..."];
    
    //disable upgrade button
    self.upgradeButton.enabled = NO;
    
    //disable uninstall button
    self.uninstallButton.enabled = NO;
    
    //show spinner
    self.activityIndicator.hidden = NO;
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame;
    
    //action
    NSString* action = nil;
    
    //result msg
    NSMutableString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //remove app activation observer
    if(nil != self.appActivationObserver)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.appActivationObserver];
        
        //unset
        self.appActivationObserver = nil;
    }
    
    //success
    if(YES == success)
    {
        //set action
        action = (ACTION_UPGRADE_FLAG == event) ? @"upgrad" : @"uninstall";
        
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"LuLu %@ed!\nSystem restart required to complete.", action];
    }
    //failure
    else
    {
        //set action
        action = (ACTION_UPGRADE_FLAG == event) ? @"upgrade" : @"uninstall";
        
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"Error: %@ failed", action];
        
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
    // set button title and tag for 'restart'
    if(YES == success)
    {
        //restart
        self.upgradeButton.title = ACTION_RESTART;
        
        //update it's tag
        // will allow button handler method process
        self.upgradeButton.tag = ACTION_RESTART_FLAG;
    }
    
    //failed
    // set button and tag for close/exit
    else
    {
        //close
        self.upgradeButton.title = ACTION_CLOSE;
        
        //update it's tag
        // will allow button handler method process
        self.upgradeButton.tag = ACTION_CLOSE_FLAG;
    }
    
    //enable
    self.upgradeButton.enabled = YES;

    //...and highlighted
    [self.window makeFirstResponder:self.upgradeButton];
   
    //ok to re-enable 'x' button
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//perform any cleanup/termination
// for now, just call into Config obj to remove helper
-(BOOL)cleanup
{
    //flag
    BOOL cleanedUp = NO;
    
    //dbg msg
    os_log_debug(logHandle, "cleaning up...");
    
    //remove helper
    if(YES != [self.configure removeHelper])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to remove config helper");
        
        //bail
        goto bail;
    }
    
    //happy
    cleanedUp = YES;
    
bail:

    return cleanedUp;
}

//automatically invoked when window is closing
// perform cleanup logic, then manually terminate app
-(void)windowWillClose:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //cleanup in background
    // then exit application
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //cleanup
        [self cleanup];
        
        //exit
        // on main thread...
        dispatch_sync(dispatch_get_main_queue(),
        ^{
            //exit
            [NSApp terminate:self];
        });
    });

    return;
}

@end
