//
//  file: XPCUser.m
//  project: lulu (login item)
//  description: user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "AlertWindowController.h"

@implementation XPCUser

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert (windows)
extern NSMutableDictionary* alerts;

//show an alert window
-(void)alertShow:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply
{
    //dbg msg
    os_log_debug(logHandle, "daemon invoked user XPC method, '%s', with %{public}@", __PRETTY_FUNCTION__, alert);
    
    //on main (ui) thread
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        //alert window
        AlertWindowController* alertWindow = nil;
        
        //alloc/init alert window
        alertWindow = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindow"];
                
        //sync to save alert
        // ensures there is a (memory) reference to the window
        @synchronized(alerts)
        {
            //save
            alerts[alert[KEY_UUID]] = alertWindow;
        }
        
        //set reply
        alertWindow.reply = reply;
        
        //set alert
        alertWindow.alert = alert;
        
        //show in all spaces
        alertWindow.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
        
        //show alert window
        [alertWindow showWindow:self];
    
        //make alert window key
        [alertWindow.window makeKeyAndOrderFront:self];
        
        //set app's background/foreground state
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
        
        //request user attention
        // bounces icon on the dock
        [NSApp requestUserAttention:NSCriticalRequest];
        
        //delay, then make the alert window front
        // note: this will stop the dock bouncing...
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            //make window front
            [NSApp activateIgnoringOtherApps:YES];
            
        });
        
    });
    
    //reverse dns resolve ip
    // background resolve, then update alert window
    if(nil != alert[KEY_HOST])
    {
        //async
        // resolve ip -> host
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //responses
            NSArray* responses = nil;
            
            //address
            NSString* address = nil;
            
            //capture
            address = alert[KEY_HOST];
            
            //resolve
            responses = resolveAddress(address);
            
            //dbg msg
            os_log_debug(logHandle, "resolved %{public}@ to %{public}@", address, responses);
         
            //sync to add to alert window(s)
            @synchronized(alerts)
            {
                //find any who's ip matches
                [alerts enumerateKeysAndObjectsUsingBlock:^(id key, AlertWindowController* alertWindow, BOOL* stop) {
                  
                    //match?
                    // update alert window
                    if(YES == [alertWindow.alert[KEY_HOST] isEqualToString:address])
                    {
                        //update window on main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            //update
                            alertWindow.reverseDNS.stringValue = (0 != [responses.firstObject length]) ? responses.firstObject : @"unknown";
                            
                        });
                    }
                    
                }];
            }
            
        });
    }
    
    return;
}

//rule changed
// broadcast new rules, so any (relevant) windows can be updated
-(void)rulesChanged
{
    //dbg msg
    os_log_debug(logHandle, "daemon invoked user XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //broadcast
    [[NSNotificationCenter defaultCenter] postNotificationName:RULES_CHANGED object:nil userInfo:nil];
    
    return;
}

@end
