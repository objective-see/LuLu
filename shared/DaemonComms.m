//
//  file: DaemonComms.m
//  project: lulu (shared)
//  description: talk to daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "logging.h"
#import "DaemonComms.h"

@implementation DaemonComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// ->create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UserProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//set client status
-(void)setClientStatus:(NSInteger)status
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending request to set client status (to %lu) via XPC", (unsigned long)status]);
    
    //set status
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'setClientStatus' method on launch daemon (error: %@)", proxyError]);
          
    }] setClientStatus:status];
    
    return;
}

//get rules
// ->optionally waits (blocks) for change
-(void)getRules:(BOOL)wait4Change reply:(void (^)(NSDictionary*))reply;
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending request to get RULES from Daemon via XPC (wait: %d)", wait4Change]);
    
    
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'getRules' method on launch daemon (error: %@)", proxyError]);
        
    }] getRules:wait4Change reply:^(NSDictionary* rules)
    {
         //respond with rules
         dispatch_async(dispatch_get_main_queue(), ^
         {
                //respond
                reply(rules);
         });
    }];
    
    return;
}

//add rule
-(void)addRule:(NSString*)processPath action:(NSUInteger)action
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request to add rule from Daemon via XPC");
    
    //add rule
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'addRule' method on launch daemon (error: %@)", proxyError]);
        
    }] addRule:processPath action:action user:getuid()];
    
    return;
}

//delete rule
-(void)deleteRule:(NSString*)processPath
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request to delete rule from Daemon via XPC");
    
    //add rule
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'deleteRule' method on launch daemon (error: %@)", proxyError]);
        
    }] deleteRule:processPath];
    
    return;
}

//ask (and then block) for an alert
-(void)alertRequest:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request to daemon (via xpc) for alert");
    
    //request alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertRequest' method on launch daemon (error: %@)", proxyError]);
        
    }] alertRequest:^(NSDictionary* alert)
    {
        //respond with alert
        reply(alert);
    }];
    
    return;
}

//send alert response back to the user
-(void)alertResponse:(NSDictionary *)alert
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request to daemon (via xpc) for alert response");
    
    //respond to alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
      {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertResponse' method on launch daemon (error: %@)", proxyError]);
          
      }] alertResponse:alert];
    
    return;
}

@end
