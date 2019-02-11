//
//  file: XPCDaemonClient.m
//  project: lulu (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

@implementation XPCDaemonClient

@synthesize daemon;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        daemon = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.daemon.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
        
        //set exported object interface (protocol)
        self.daemon.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
        
        //set exported object
        // this will allow daemon to invoke user methods!
        self.daemon.exportedObject = [[XPCUser alloc] init];
    
        //resume
        [self.daemon resume];
    }
    
    return self;
}

//tell daemon to load kext
// on 10.13+ might need to re-try to allow user to allow via UI
-(void)loadKext
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //ask daemon to load kext
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
      {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
          
      }] loadKext];
    
    return;
}

//get preferences
// note: synchronous, will block until daemon responds
-(NSDictionary*)getPreferences
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //request preferences
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
     }] getPreferences:^(NSDictionary* preferencesFromDaemon)
     {
         //dbg msg
         logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got preferences: %@", preferencesFromDaemon]);
         
         //save
         preferences = preferencesFromDaemon;
         
     }];
    
    return preferences;
}

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //update prefs
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
          
    }] updatePreferences:preferences];
    
    return;
}

//get rules
-(void)getRules:(void (^)(NSDictionary*))reply;
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //make XPC request to get rules
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] getRules:^(NSDictionary* rules)
    {
         //respond
         reply(rules);
    }];
    
    return;
}

//add rule
-(void)addRule:(NSString*)processPath action:(NSUInteger)action
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //make XPC request to add rule
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] addRule:processPath action:action user:getuid()];
    
    return;
}

//update rule
// for now, just action (block/allow)
-(void)updateRule:(NSString*)processPath action:(NSUInteger)action
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //make XPC request to add rule
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
          
    }] updateRule:processPath action:action user:getuid()];
    
    return;
}

//delete rule
-(void)deleteRule:(NSString*)processPath
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //delete rule
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] deleteRule:processPath];
    
    return;
}

//import rules
// note: synchronous
-(BOOL)importRules:(NSString*)rulesFile
{
    //flag
    __block BOOL importedRules = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //import rules
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] importRules:rulesFile reply:^(BOOL result)
    {
        //set flag
        importedRules = YES;
        
    }];
    
    return importedRules;
}


#ifndef MAIN_APP

//send alert response back to the deamon
-(void)alertReply:(NSDictionary*)alert
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__]);
    
    //respond to alert
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute daemon XPC method '%s' (error: %@)", __PRETTY_FUNCTION__, proxyError]);
        
    }] alertReply:alert];
    
    //sync to remove alert (window)
    @synchronized(((AppDelegate*)[[NSApplication sharedApplication] delegate]).alerts)
    {
        //remove
        ((AppDelegate*)[[NSApplication sharedApplication] delegate]).alerts[alert[ALERT_PATH]] = nil;
    }
    
    //no more visible alerts?
    // send app back to background
    if(0 == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).alerts.count)
    {
        //background
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }

    return;
}

#endif

@end
