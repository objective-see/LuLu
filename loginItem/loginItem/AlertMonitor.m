//
//  file: AlertMonitor.m
//  project: lulu (login item)
//  description: monitor for alerts from daemom
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
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
    
    //passive flag
    __block BOOL inPassiveMode = NO;
    
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
             
             //set flag
             // is client in passive mode?
             inPassiveMode = [[[NSUserDefaults alloc] initWithSuiteName:@"group.com.objective-see.lulu"] boolForKey:PREF_PASSIVE_MODE];
             
             //passive mode?
             // don't show alert, just respond w/ allow
             if(YES == inPassiveMode)
             {
                 //dbg msg
                 // also log to file
                 logMsg(LOG_DEBUG|LOG_TO_FILE, @"client in passive mode, so telling daemon just to 'allow'");
                 
                 //passively allow
                 [self passivelyAllow:daemonComms alert:alert];
                 
                 //signal alert is processed
                 dispatch_semaphore_signal(self.semaphore);
             }

             //show alert
             else
             {
                 //show alert window on main thread
                 dispatch_async(dispatch_get_main_queue(), ^{
                     
                     //dbg msg
                     logMsg(LOG_DEBUG, [NSString stringWithFormat:@"showing window for alert: %@", alert]);
                     
                     //alloc/init
                     if(nil == self.alertWindow)
                     {
                         //alloc/init
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
             }
         }];
        
        //wait for alert to be processed
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        //alert shown?
        // unregister window notification
        if(YES != inPassiveMode)
        {
            //remove notification watch
            dispatch_sync(dispatch_get_main_queue(), ^{

                //remove notification observer
                [[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowWillCloseNotification object:self.alertWindow.window];
                
            });
        }
        
        //pool
        }
            
    }//forevers
    
    return;
}

//when client is in passive mode: allow
-(void)passivelyAllow:(DaemonComms*)daemonComms alert:(NSDictionary*)alert
{
    //response
    NSMutableDictionary* response = nil;
    
    //init response with initial alert
    response = [NSMutableDictionary dictionaryWithDictionary:alert];
    
    //add action, allow
    response[ALERT_ACTION] = [NSNumber numberWithInt:RULE_STATE_ALLOW];
    
    //add current user
    response[ALERT_USER] = [NSNumber numberWithUnsignedInteger:getuid()];
    
    //indicate that it was passively allowed
    response[ALERT_PASSIVELY_ALLOWED] = [NSNumber numberWithBool:YES];
    
    //send response to daemon
    [daemonComms alertResponse:response];
    
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
