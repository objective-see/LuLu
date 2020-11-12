//
//  file: HelperListener.m
//  project: (open-source) installer
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "XPCProtocol.h"
#import "HelperListener.h"
#import "HelperInterface.h"

#import <bsm/libbsm.h>
#import <Security/AuthSession.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//interface for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection

//private iVar
@property (nonatomic) audit_token_t auditToken;

@end

//implementation for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@implementation ExtendedNSXPCConnection

//private iVar
@synthesize auditToken;

@end

@implementation HelperListener

@synthesize listener;

//init
// create XPC listener
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //setup XPC listener
        if(YES != [self initListener])
        {
            //unset
            self =  nil;
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return self;
}

//setup XPC listener
-(BOOL)initListener
{
    //result
    BOOL result = NO;
    
    //init listener
    listener = [[NSXPCListener alloc] initWithMachServiceName:CONFIG_HELPER_ID];
    if(nil == self.listener)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to create mach service %{public}@", CONFIG_HELPER_ID);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "created mach service %{public}@", CONFIG_HELPER_ID);
    
    //set delegate
    self.listener.delegate = self;
    
    //ready to accept connections
    [self.listener resume];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

#pragma mark -
#pragma mark NSXPCConnection method overrides

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// shoutout to: https://blog.obdev.at/what-we-have-learned-from-a-vulnerability/
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //pragma
    #pragma unused(listener)

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
    os_log_debug(logHandle, "received request to connect to XPC interface");
        
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
    
    //extract flags
    csFlags = [((__bridge NSDictionary *)csInfo)[(__bridge NSString *)kSecCodeInfoStatus] unsignedIntValue];
    
    //dbg msg
    os_log_debug(logHandle, "code signing flags: %#x", csFlags);
                    
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
    os_log_debug(logHandle, "code signing flags, ok (`CS_RUNTIME` is set)");
    
    //init signing req
    requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\"", CONFIG_ID, SIGNING_AUTH];
    
    //step 1: create task ref
    // uses NSXPCConnection's (private) 'auditToken' iVar
    taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
    if(NULL == taskRef)
    {
        //bail
        goto bail;
    }
    
    //step 2: validate
    // check that client is signed with Objective-See's dev cert and it's the BB's installer
    if(0 != SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(requirement)))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to validated against %{public}@", requirement);
        
        //bail
        goto bail;
    }

    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[HelperInterface alloc] init];

    //resume
    [newConnection resume];
    
    //dbg msg
    os_log_debug(logHandle, "allowed XPC connection: %{public}@", newConnection);
    
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
