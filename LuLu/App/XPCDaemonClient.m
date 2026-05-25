//
//  file: XPCDaemonClient.m
//  project: lulu (shared)
//  description: talk to daemon via XPC (asynchronous, non-blocking)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert (windows)
extern NSMutableDictionary* alerts;

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

#pragma mark - Preferences

//get preferences (async)
-(void)getPreferences:(void (^)(NSDictionary* _Nullable))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        //fail-safe: still invoke completion so callers don't hang
        if(completion) completion(nil);

    }] getPreferences:^(NSDictionary* preferencesFromDaemon)
    {
        //dbg msg
        os_log_debug(logHandle, "got preferences: %{public}@", preferencesFromDaemon);

        if(completion) completion(preferencesFromDaemon);
    }];
}

//update (save) preferences (async)
// note: daemon merges into current ones, returns merged result
-(void)updatePreferences:(NSDictionary*)preferences completion:(void (^)(NSDictionary* _Nullable))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(nil);

    }] updatePreferences:preferences reply:^(NSDictionary* updatedPreferences)
    {
        //dbg msg
        os_log_debug(logHandle, "got updated preferences: %{public}@", updatedPreferences);

        if(completion) completion(updatedPreferences);
    }];
}

#pragma mark - Rules

//get rules (async)
-(void)getRules:(void (^)(NSDictionary* _Nullable))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(nil);

    }] getRules:^(NSData* archivedRules)
    {
        NSError* error = nil;

        //unarchive
        NSMutableDictionary* rules = [NSKeyedUnarchiver unarchivedObjectOfClasses:
                 [NSSet setWithArray: @[[NSMutableDictionary class], [NSMutableArray class], [NSString class], [NSNumber class], [NSMutableSet class], [NSDate class], [Rule class]]] fromData:archivedRules error:&error];

        if(nil != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to unarchive rules: %{public}@", error);
        }

        if(completion) completion(rules);
    }];
}

//add rule (fire-and-forget)
-(void)addRule:(NSDictionary*)info
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s' with info: %{public}@", __PRETTY_FUNCTION__, info);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

    }] addRule:info];
}

//disable (or re-enable) rule (fire-and-forget)
-(void)toggleRule:(NSString*)key rule:(NSString*)uuid state:(NSNumber*)state
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s' with key: %{public}@, rule id: %{public}@", __PRETTY_FUNCTION__, key, uuid);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

    }] toggleRule:key rule:uuid state:state];
}

//delete rule (fire-and-forget)
-(void)deleteRule:(NSString*)key rule:(NSString*)uuid
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s' with key: %{public}@, rule id: %{public}@", __PRETTY_FUNCTION__, key, uuid);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

    }] deleteRule:key rule:uuid];
}

//cleanup rules (async)
-(void)cleanupRules:(BOOL)full completion:(void (^)(NSInteger))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        //signal failure to caller
        if(completion) completion(-1);

    }] cleanupRules:full reply:^(NSInteger result)
    {
        //dbg msg
        os_log_debug(logHandle, "daemon XPC method, '%s', done! (returned %ld)", __PRETTY_FUNCTION__, (long)result);

        if(completion) completion(result);
    }];
}

//import rules (async)
-(void)importRules:(NSData*)newRules userOnly:(BOOL)userOnly completion:(void (^)(BOOL))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(NO);

    }] importRules:newRules userOnly:userOnly result:^(BOOL result)
    {
        //dbg msg
        os_log_debug(logHandle, "daemon XPC method, '%s', done! (result: %d)", __PRETTY_FUNCTION__, result);

        if(completion) completion(result);
    }];
}

#pragma mark - Profiles

//get current profile (async)
-(void)getCurrentProfile:(void (^)(NSString* _Nullable))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(nil);

    }] getCurrentProfile:^(NSString* currentProfileFromDaemon)
    {
        //dbg msg
        os_log_debug(logHandle, "current profile from daemon: '%{public}@'", currentProfileFromDaemon);

        if(completion) completion(currentProfileFromDaemon);
    }];
}

//get list of profiles (async)
-(void)getProfiles:(void (^)(NSMutableArray* _Nullable))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(nil);

    }] getProfiles:^(NSArray* profilesFromDaemon)
    {
        if(completion) completion([profilesFromDaemon mutableCopy]);
    }];
}

//set profile (async)
-(void)setProfile:(NSString*)name completion:(void (^)(BOOL))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s' with name: %{public}@", __PRETTY_FUNCTION__, name);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(NO);

    }] setProfile:name reply:^(BOOL reply)
    {
        //dbg msg
        os_log_debug(logHandle, "daemon XPC method, '%s', done! (result: %d)", __PRETTY_FUNCTION__, reply);

        if(completion) completion(reply);
    }];
}

//add profile (async)
-(void)addProfile:(NSString*)name preferences:(NSDictionary*)preferences completion:(void (^)(BOOL))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s' with %{public}@", __PRETTY_FUNCTION__, name);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(NO);

    }] addProfile:name preferences:preferences reply:^(BOOL reply)
    {
        //dbg msg
        os_log_debug(logHandle, "daemon XPC method, '%s', done! (result: %d)", __PRETTY_FUNCTION__, reply);

        if(completion) completion(reply);
    }];
}

//delete profile (async)
-(void)deleteProfile:(NSString*)name completion:(void (^)(BOOL))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s' with name: %{public}@", __PRETTY_FUNCTION__, name);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(NO);

    }] deleteProfile:name reply:^(BOOL reply)
    {
        //dbg msg
        os_log_debug(logHandle, "daemon XPC method, '%s', done! (result: %d)", __PRETTY_FUNCTION__, reply);

        if(completion) completion(reply);
    }];
}

#pragma mark - Uninstall

//uninstall (async)
-(void)uninstall:(void (^)(BOOL))completion
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);

    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);

        if(completion) completion(NO);

    }] uninstall:^(BOOL result)
    {
        //dbg msg
        os_log_debug(logHandle, "daemon XPC method, '%s', done! (result: %d)", __PRETTY_FUNCTION__, result);

        if(completion) completion(result);
    }];
}

@end
