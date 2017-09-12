//
//  file: StatusBarMenu.m
//  project: lulu (login item)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#import "const.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "UserCommsInterface.h"
#import "StatusBarMenu.h"


//menu item
enum menuItems
{
    status = 100,
    toggle,
    rules,
    prefs,
    end
};


@implementation StatusBarMenu

@synthesize isEnabled;
@synthesize statusItem;
@synthesize daemonComms;

//init method
// set some intial flags, etc.
-(id)init:(NSMenu*)menu;
{
    //load from nib
    self = [super init];
    if(self != nil)
    {
        //init status item
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
        //set image
        self.statusItem.image = [NSImage imageNamed:@"statusIcon"];
        
        //tell OS to handle image
        self.statusItem.image.template = YES;
    
        //set menu
        self.statusItem.menu = menu;
        
        //set action handler for all items
        for(int i=toggle; i<end; i++)
        {
            //set action
            [self.statusItem.menu itemWithTag:i].action = @selector(handler:);
            
            //set state
            [self.statusItem.menu itemWithTag:i].enabled = YES;
            
            //set target
            [self.statusItem.menu itemWithTag:i].target = self;
        }
        
        //set flag
        self.isEnabled = YES;
        
        //init daemon comms obj
        daemonComms = [[DaemonComms alloc] init];
        
        //tell daemon, client is enabled
        [self.daemonComms setClientStatus:STATUS_CLIENT_ENABLED];
    }
    
    return self;
}

//menu handler
-(void)handler:(id)sender
{
    //path components
    NSArray *pathComponents = nil;
    
    //path to config (main) app
    NSString* mainApp = nil;
    
    //error
    NSError* error = nil;
    
    //config app's pid
    NSNumber* mainAppID = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user clicked %ld", (long)((NSMenuItem*)sender).tag]);
    #endif
    
    //get path components
    pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
    if(pathComponents.count > 4)
    {
        //init path to full (main) app
        mainApp = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 4)]];
    }

    //get pid of config app for user
    // kill running instance to make sure correct window is shown
    // TODO: do this better (send msg to running instance so don't have to kill/restart?)
    mainAppID = [getProcessIDs([[NSBundle bundleWithPath:mainApp] executablePath], getuid()) firstObject];
    if(nil != mainAppID)
    {
        //kill
        kill(mainAppID.unsignedShortValue, SIGTERM);
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killed %@ (%@)", mainApp, mainAppID]);
        #endif
        
        //nap
        [NSThread sleepForTimeInterval:0.5];
    }
    
    //handle action
    switch ((long)((NSMenuItem*)sender).tag)
    {
        //toggle on/off
        case toggle:
            
            //going from on to off?
            if(YES == self.isEnabled)
            {
                //update status
                [self.statusItem.menu itemWithTag:status].title = @"LULU: disabled";

                //change text
                ((NSMenuItem*)sender).title = @"Enable";
                
                //tell daemon, client is disabled
                [self.daemonComms setClientStatus:STATUS_CLIENT_DISABLED];
                
                //toggle flag
                self.isEnabled = NO;
            }
            
            //going from off to on?
            else
            {
                //update status
                [self.statusItem.menu itemWithTag:status].title = @"LULU: enabled";
                
                //change text
                ((NSMenuItem*)sender).title = @"Disable";
                
                //tell daemon, client is enabled
                [self.daemonComms setClientStatus:STATUS_CLIENT_ENABLED];
                
                //toggle flag
                self.isEnabled = YES;
            }
            
            break;
         
            
        //launch main app to show rules
        case rules:
            
            //launch main app
            // pass in '-rules'
            if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:mainApp] options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: @[CMDLINE_FLAG_RULES]} error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to launch %@ (%@)", mainApp, error]);
                
                //bail
                goto bail;
            }
            
            break;
            
        //launch main app to show prefs
        case prefs:
            
            //launch main app
            if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:mainApp] options:0 configuration:@{NSWorkspaceLaunchConfigurationArguments: @[CMDLINE_FLAG_PREFS]} error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to launch %@ (%@)", mainApp, error]);
                
                //bail
                goto bail;
            }
            
            break;
            
        default:
            break;
    }
    
bail:
    
    return;
}
@end
