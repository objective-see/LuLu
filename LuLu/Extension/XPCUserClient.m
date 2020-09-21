//
//  file: XPCUserClient.m
//  project: lulu (launch daemon)
//  description: talk to the user, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Rules.h"
#import "Alerts.h"
#import "consts.h"
#import "XPCListener.h"
#import "XPCUserClient.h"

/* GLOBALS */

//xpc connection
extern XPCListener* xpcListener;

//log handle
extern os_log_t logHandle;

@implementation XPCUserClient

//deliver alert to user
-(BOOL)deliverAlert:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply
{
    //flag
    __block BOOL xpcError = NO;
    
    //sanity check
    // no client connection?
    if(nil == xpcListener.client)
    {
        //dbg msg
        os_log_debug(logHandle, "no client is connected, alert will not be delivered");
        
        //set error
        xpcError = YES;
        
        //bail
        //goto bail;
    }
    else
    {
        //dbg msg
        os_log_debug(logHandle, "invoking user XPC method: 'alertShow:reply:'");

        //send to user
        [[xpcListener.client remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
            
            //set error
            xpcError = YES;
            
        }] alertShow:alert reply:^(NSDictionary* userReply)
        {
            //dbg msg
            os_log_debug(logHandle, "reply: %{public}@", alert);
            
            //respond
            reply(userReply);
        }];
    }

bail:

    return !xpcError;
}

//inform user rules have changed
-(void)rulesChanged
{
    //dbg msg
    os_log_debug(logHandle, "invoking user XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //no client?
    // no need to do anything...
    if(nil == xpcListener.client)
    {
        //bail
        goto bail;
    }
    
    //send to user (login item) to display
    [[xpcListener.client remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute 'rulesChanged' method on launch daemon (error: %{public}@)", proxyError);
          
    }] rulesChanged];
    
bail:
    
    return;
}

@end
