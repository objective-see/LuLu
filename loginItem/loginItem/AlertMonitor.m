//
//  file: AlertMonitor.m
//  project: lulu (login item)
//  description: monitor for alerts from daemom
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "AppDelegate.h"
#import "DaemonComms.h"
#import "AlertMonitor.h"

@implementation AlertMonitor

@synthesize semaphore;

//forever,
// ->display alerts
-(void)monitor
{
    //daemon comms object
    DaemonComms* daemonComms = nil;
    
    //alert window
    __block AlertWindowController* alertWindow;
    
    //response
    __block NSModalResponse userResponse = 0;
    
    //response to daemon
    __block NSMutableDictionary* alertResponse = nil;
    
    //init daemon
    // use local var here, as we need to block
    daemonComms = [[DaemonComms alloc] init];

    //init sema
    self.semaphore = dispatch_semaphore_create(0);
    
    //process alerts
    // call daemon and block, then display, and repeat!
    while(YES)
    {
        //pool
        @autoreleasepool
        {
            
        //dbg msg
        logMsg(LOG_DEBUG, @"requesting alert from daemon, will block");
        
        //wait for alert from daemon via XPC
        [daemonComms alertRequest:^(NSDictionary* alert)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got alert from daemon: %@", alert]);
            
            //show alert window on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                 
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"showing window for alert: %@", alert]);
                 
                //alloc/init alert window
                alertWindow = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindow"];
            
                //set alert
                alertWindow.alert = alert;
                
                //show alert window
                [alertWindow showWindow:self];
             
                //make it key window
                [alertWindow.window makeKeyAndOrderFront:self];
                
                //make window front
                [NSApp activateIgnoringOtherApps:YES];
                
                //make modal
                // will block until user responds ('Block' / 'Allow')
                userResponse = [[NSApplication sharedApplication] runModalForWindow:alertWindow.window];
                
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user responded to alert: %ld", (long)userResponse]);
                
                //init alert response dictionary
                alertResponse = [alert mutableCopy];
                
                //add current user
                alertResponse[ALERT_USER] = [NSNumber numberWithUnsignedInteger:getuid()];
                
                //add user response
                alertResponse[ALERT_ACTION] = [NSNumber numberWithLong:userResponse];
                
                //send response to daemon
                [daemonComms alertResponse:alertResponse];
                
                //dbg msg
                logMsg(LOG_DEBUG, @"sent response to daemon");
                
                //signal sema
                dispatch_semaphore_signal(self.semaphore);
                
             });

         }];
        
        //wait for alert to be processed
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        }//pool
            
    }//forevers
    
    return;
}

@end
