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
@synthesize friendsView;
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
    //set window title
    [self window].title = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //init status msg
    [self.statusMsg setStringValue:@"the free, open, firewall 🔥🛡️"];
    
    //app already installed?
    // enable 'uninstall' button
    // change 'install' button to say 'upgrade'
    if(YES == isInstalled)
    {
        //enable 'uninstall'
        self.uninstallButton.enabled = YES;
        
        //set to 'upgrade'
        self.installButton.title = ACTION_UPGRADE;
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
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //action
    NSInteger action = 0;
    
    //frame
    NSRect frame = {0};

    //'beta installed' alert
    NSAlert* betaInstalled = nil;
    
    //grab tag
    action = ((NSButton*)sender).tag;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@ (%ld)", ((NSButton*)sender).title, (long)action]);
    
    //process button
    switch(action)
    {
        //restart
        case ACTION_RESTART_FLAG:
            
            //disable button
            self.restartButton.enabled = NO;
            
            //bye!
            restart();
        
            break;
            
        //close
        case ACTION_CLOSE_FLAG:
            
            //close window to trigger cleanup logic
            [self.window close];
            
            break;
            
        //install/uninstall
        case ACTION_INSTALL_FLAG:
        case ACTION_UNINSTALL_FLAG:
        {
            //upgrade/uninstall
            // warn if beta is installed
            if( (action != ACTION_UNINSTALL_FLAG) &&
                (YES == [((AppDelegate*)[[NSApplication sharedApplication] delegate]).configureObj isBetaInstalled]) )
            {
                //init alert
                betaInstalled = [[NSAlert alloc] init];
                
                //set style
                betaInstalled.alertStyle = NSAlertStyleInformational;
                
                //set main text
                betaInstalled.messageText = @"Beta Version Already Installed";
                
                //set detailed text
                betaInstalled.informativeText = @"Please note, it will be fully uninstalled first!";
                
                //add button
                [betaInstalled addButtonWithTitle:@"Ok"];
                
                //show
                // will block until user
                [betaInstalled runModal];
            }
            
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
            
            break;
        }
            
        //next
        // show 'friends' view
        case ACTION_NEXT_FLAG:
        {
            //unset window title
            self.window.title = @"";
            
            //get main window's frame
            frame = self.window.contentView.frame;
            
            //set origin to 0/0
            frame.origin = CGPointZero;
            
            //increase y offset
            frame.origin.y += 5;
            
            //reduce height
            frame.size.height -= 5;
            
            //pre-req
            [self.friendsView setWantsLayer:YES];
            
            //update view to take up entire window
            self.friendsView.frame = frame;
            
            //not in dark mode?
            // make window white
            if(YES != isDarkMode())
            {
                //set white
                self.friendsView.layer.backgroundColor = [NSColor whiteColor].CGColor;
            }
            
            //update config view
            self.window.contentView = self.friendsView;
            
            //make 'restart' button first responder
            // calling this without a timeout sometimes fails :/
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                
                //set first responder
                [self.window makeFirstResponder:self.restartButton];
                
            });
            
            //show
            self.friendsView.hidden = NO;
        }
        
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
        
        //for fresh install
        // wait until enum'ing of installed apps is done
        if( (ACTION_INSTALL_FLAG == event) &&
            (YES != [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", INSTALLED_APPS]]]) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"enumerating (pre)installed applications");
            
            //nap
            // give time for 'system_profiler' to start....
            [NSThread sleepForTimeInterval:1.0];
            
            //update status msg
            dispatch_async(dispatch_get_main_queue(),
            ^{
               //set status msg
               [self.statusMsg setStringValue:@"Enum'ing installed apps\n\t\t ...please wait!"];
            });
            
            //wait until 'system_profiler' has exited
            while(YES)
            {
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"waiting for '%@' to complete", SYSTEM_PROFILER]);
                
                //nap
                [NSThread sleepForTimeInterval:1.0];
                
                //exit'd?
                if(0 == [getProcessIDs(SYSTEM_PROFILER, -1) count])
                {
                    //bye
                    break;
                }
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%@' completed", SYSTEM_PROFILER]);
        }
    
        //update status msg
        dispatch_async(dispatch_get_main_queue(),
        ^{
            //set status msg
            [self.statusMsg setStringValue:@"Rebuilding kernel cache\n\t\t ...please wait!"];
        });
        
        //for both install and uninstall
        //wait until 'kextcache' has exited
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
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'%@' completed", KEXT_CACHE]);
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
    CGRect statusMsgFrame;
    
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
        
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"error: %@ failed", action];
        
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
    // set button title and tag for 'next'
    if(YES == success)
    {
        //restart
        self.installButton.title = ACTION_NEXT;
        
        //update it's tag
        // will allow button handler method process
        self.installButton.tag = ACTION_NEXT_FLAG;
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

//perform any cleanup/termination
// for now, just call into Config obj to remove helper
-(BOOL)cleanup
{
    //flag
    BOOL cleanedUp = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"cleaning up...");
    
    //remove helper
    if(YES != [((AppDelegate*)[[NSApplication sharedApplication] delegate]).configureObj removeHelper])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to remove config helper");
        
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
        //install/uninstall
        [self cleanup];
        
        //exit
        [NSApp terminate:self];
    });

    return;
}

@end
