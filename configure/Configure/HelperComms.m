//
//  file: HelperComms.h
//  project: lulu (config)
//  description: interface to talk to blessed installer (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "consts.h"
#import "logging.h"
#import "AppDelegate.h"
#import "HelperComms.h"

@implementation HelperComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:CONFIG_HELPER_ID options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//install
// note: XPC is async, so return logic handled in callback block
-(void)install:(void (^)(NSNumber*))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"invoking 'install' XPC method");
    
    //install
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'install' method on helper tool (error: %@)", proxyError]);
        
        //invoke block
        reply([NSNumber numberWithInt:-1]);
          
    }] install:[[NSBundle mainBundle] bundlePath] reply:^(NSNumber* result)
    {
        //invoke block
        reply(result);
    }];
    
    return;
}

//uninstall
// note: XPC is async, so return logic handled in callback block
-(void)uninstall:(BOOL)full reply:(void (^)(NSNumber*))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"invoking 'uninstall' XPC method");
    
    //uninstall
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'uninstall' method on helper tool (error: %@)", proxyError]);
          
          //invoke block
          reply([NSNumber numberWithInt:-1]);
          
    }] uninstall:[[NSBundle mainBundle] bundlePath] full:full reply:^(NSNumber* result)
    {
         //invoke block
         reply(result);
    }];
    
    return;
}

//cleanup
-(void)cleanup:(void (^)(NSNumber*))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"invoking 'cleanup' XPC method");
    
    //remove
    [[(NSXPCConnection*)self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'remove' method on helper tool (error: %@)", proxyError]);
          
    }] cleanup:^(NSNumber* result)
    {
        //invoke block
        reply(result);
    }];
    
    return;
}

@end
