//
//  file: AlertMonitor.m
//  project: lulu (login item)
//  description: monitor for alerts from daemom
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "logging.h"
#import "AppDelegate.h"
#import "DaemonComms.h"
#import "AlertMonitor.h"

@implementation AlertMonitor

@synthesize semaphore;
@synthesize alertWindow;

//forever,
// ->display alerts
-(void)monitor
{
    //daemon comms object
    DaemonComms* daemonComms = nil;
    
    //init daemon
    // use local var here, as we need to block
    daemonComms = [[DaemonComms alloc] init];
    
    //init sema
    self.semaphore = dispatch_semaphore_create(0);
    
    //process alerts
    // ->call daemon and block, then display, and repeat!
    while(YES)
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
             
                 //alloc
                 if(nil == self.alertWindow)
                 {
                     alertWindow = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindow"];
                 }
                 
                 //configure alert window with data from daemon
                 self.alertWindow.alert = alert;
                 
                 //show (now configured), alert
                 [self.alertWindow showWindow:self];
                 
                 //make it key window
                 [self.alertWindow.window makeKeyAndOrderFront:self];
                 
                 //make window front
                 [NSApp activateIgnoringOtherApps:YES];

                 //register for close event
                 // callback will signal semaphore
                 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(alertWindowClosed:) name:NSWindowWillCloseNotification object:self.alertWindow.window];
             
             });
            
         }];
        
        //wait for alert window to close
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        //show alert window on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{

            //remove notification observer
            [[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowWillCloseNotification object:self.alertWindow.window];
            
        });
    }
    
    return;
}

//callback handler
// ->invoked when window closes
-(void)alertWindowClosed:(id)object
{
    //dbg msg
    logMsg(LOG_DEBUG, @"alert window closed, will signal semaphore");
    
    //signal
    dispatch_semaphore_signal(self.semaphore);
    
    return;
}

@end
