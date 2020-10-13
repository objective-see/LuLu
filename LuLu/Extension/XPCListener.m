//
//  file: XPCListener.m
//  project: lulu (launch daemon)
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"

#import "Rule.h"
#import "Rules.h"
#import "Alerts.h"
#import "utilities.h"
#import "XPCListener.h"

#import "XPCDaemon.h"

#import "XPCUserProto.h"
#import "XPCDaemonProto.h"

@import OSLog;
#import <bsm/libbsm.h>


/* GLOBALS */

//alerts
extern Alerts* alerts;

//interface for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection
{
    //private iVar
    audit_token_t auditToken;
}
//private iVar
@property audit_token_t auditToken;

@end

//implementation for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@implementation ExtendedNSXPCConnection

//private iVar
@synthesize auditToken;

@end

//global logging handle
extern os_log_t logHandle;

@implementation XPCListener

@synthesize client;
@synthesize listener;

//init
// create XPC listener
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init listener
        listener = [[NSXPCListener alloc] initWithMachServiceName:DAEMON_MACH_SERVICE];
        
        //dbg msg
        os_log_debug(logHandle, "created mach service %@", DAEMON_MACH_SERVICE);
        
        //set delegate
        self.listener.delegate = self;
        
        //ready to accept connections
        [self.listener resume];
    }
    
    return self;
}

#pragma mark -
#pragma mark NSXPCConnection method overrides

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// shoutout to writeup: https://blog.obdev.at/what-we-have-learned-from-a-vulnerability
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //flag
    BOOL shouldAccept = NO;
    
    //status
    OSStatus status = !errSecSuccess;
    
    //audit token
    audit_token_t auditToken = {0};
    
    //task ref
    SecTaskRef taskRef = 0;
    
    //code ref
    SecCodeRef codeRef = NULL;
    
    //code signing info
    CFDictionaryRef csInfo = NULL;
    
    //cs flags
    uint32_t csFlags = 0;
    
    //signing req string (main app)
    NSString* requirement = nil;

    //extract audit token
    auditToken = ((ExtendedNSXPCConnection*)newConnection).auditToken;
    
    //dbg msg
    os_log_debug(logHandle, "received request to connect to XPC interface from: (%d)%{public}@", audit_token_to_pid(auditToken), getProcessPath(audit_token_to_pid(auditToken)));
    
    //obtain dynamic code ref
    status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit : [NSData dataWithBytes:&auditToken length:sizeof(audit_token_t)]}), kSecCSDefaultFlags, &codeRef);
    if(errSecSuccess != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'SecCodeCopyGuestWithAttributes' failed with': %#x", status);
        
        //bail
        goto bail;
    }
    
    //validate code
    status = SecCodeCheckValidity(codeRef, kSecCSDefaultFlags, NULL);
    if(errSecSuccess != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'SecCodeCheckValidity' failed with': %#x", status);
       
        //bail
        goto bail;
    }
    
    //get code signing info
    status = SecCodeCopySigningInformation(codeRef, kSecCSDynamicInformation, &csInfo);
    if(errSecSuccess != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'SecCodeCopySigningInformation' failed with': %#x", status);
       
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "client's code signing info: %{public}@", csInfo);
    
    //extract flags
    csFlags = [((__bridge NSDictionary *)csInfo)[(__bridge NSString *)kSecCodeInfoStatus] unsignedIntValue];
    
    //dbg msg
    os_log_debug(logHandle, "client code signing flags: %#x", csFlags);
    
    //gotta have hardened runtime
    if( !(CS_VALID & csFlags) &&
        !(CS_RUNTIME & csFlags) )
    {
        //err msg
        os_log_error(logHandle, "ERROR: invalid code signing flags: %#x", csFlags);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "client code signing flags, ok (includes 'CS_RUNTIME')");
    
    //init signing req
    requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\"", APP_ID, SIGNING_AUTH];
    
    //step 1: create task ref
    // uses NSXPCConnection's (private) 'auditToken' iVar
    taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
    if(NULL == taskRef)
    {
        //bail
        goto bail;
    }
    
    //step 2: validate
    // check that client is signed with Objective-See's and it's LuLu
    if(errSecSuccess != (status = SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(requirement))))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed with validate client (error: %#x/%d)", status, status);
    
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "client code signing information, ok");
    
    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[XPCDaemon alloc] init];
    
    //set type of remote object
    // user (login item/main app) will set this object
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol: @protocol(XPCUserProtocol)];
    
    //set interruption handler
    [newConnection setInterruptionHandler:^{
        
        //dbg msg
        os_log_debug(logHandle, "XPC 'interruptionHandler' method invoked");
        
        //unset user
        alerts.consoleUser = nil;
        
    }];

    //set invalidation handler
    [newConnection setInvalidationHandler:^{
        
        //dbg msg
        os_log_debug(logHandle, "XPC 'invalidationHandler' method invoked");
        
        //unset user
        alerts.consoleUser = nil;
        
    }];
    
    //save
    self.client = newConnection;
    
    //and set user
    alerts.consoleUser = getConsoleUser();
    
    //resume
    [newConnection resume];
    
    //dbg msg
    os_log_debug(logHandle, "allowing XPC connection from client (pid: %d)", audit_token_to_pid(auditToken));
    
    //happy
    shouldAccept = YES;
    
bail:
    
    //release task ref object
    if(NULL != taskRef)
    {
        //release
        CFRelease(taskRef);
        taskRef = NULL;
    }
    
    //free cs info
    if(NULL != csInfo)
    {
        //free
        CFRelease(csInfo);
        csInfo = NULL;
    }
    
    //free code ref
    if(NULL != codeRef)
    {
        //free
        CFRelease(codeRef);
        codeRef = NULL;
    }
    
    return shouldAccept;
}

@end
