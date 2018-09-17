//
//  file: XPCListener.m
//  project: lulu (launch daemon)
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//



#import "consts.h"
#import "logging.h"

#import "Rule.h"
#import "Rules.h"
#import "KextComms.h"
#import "utilities.h"
#import "UserClientShared.h"
#import "XPCListener.h"

#import "XPCDaemon.h"

#import "XPCUserProto.h"
#import "XPCDaemonProto.h"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//interface for 'extension' to NSXPCConnection
// ->allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection
{
    //private iVar
    audit_token_t auditToken;
}
//private iVar
@property audit_token_t auditToken;

@end

//implementation for 'extension' to NSXPCConnection
// ->allows us to access the 'private' auditToken iVar
@implementation ExtendedNSXPCConnection

//private iVar
@synthesize auditToken;

@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

//global kext comms obj
extern KextComms* kextComms;

//global rules obj
extern Rules* rules;

@implementation XPCListener

@synthesize listener;
@synthesize loginItem;

//init
// ->create XPC listener
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
    listener = [[NSXPCListener alloc] initWithMachServiceName:DAEMON_MACH_SERVICE];
    if(nil == self.listener)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create mach service %@", DAEMON_MACH_SERVICE]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created mach service %@", DAEMON_MACH_SERVICE]);
    
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
// note: we only allow binaries signed by Objective-See to talk to this!
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //flag
    BOOL shouldAccept = NO;
    
    //task ref
    SecTaskRef taskRef = 0;
    
    //signing req string
    NSString* requirementString = nil;
    
    //path of connecting app
    NSString* path = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"received request to connect to XPC interface");
    
    //init signing req string
    requirementString = [NSString stringWithFormat:@"anchor trusted and certificate leaf [subject.CN] = \"%@\"", SIGNING_AUTH];
    
    //step 1: create task ref
    // uses NSXPCConnection's (private) 'auditToken' iVar
    taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
    if(NULL == taskRef)
    {
        //bail
        goto bail;
    }
    
    //step 2: validate
    // check that client is signed with Objective-See's dev cert
    if(0 != SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(requirementString)))
    {
        //bail
        goto bail;
    }
    
    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[XPCDaemon alloc] init];
    
    //set type of remote object
    // user (login item/main app) will set this object
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol: @protocol(XPCUserProtocol)];
    
    //get path
    path = getProcessPath(newConnection.processIdentifier);
    
    //login item
    // save connection and notify that new client has connected
    if(YES == [path hasSuffix:@"LuLu Helper"])
    {
        //save
        self.loginItem = newConnection;
    
        //in background
        // notify that a new client connected
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
           //notify
           [[NSNotificationCenter defaultCenter] postNotificationName:USER_NOTIFICATION object:nil userInfo:nil];
        });
    }
    //main app
    else
    {
        //save
        self.mainApp = newConnection;
    }
    
    //resume
    [newConnection resume];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowed XPC connection from %@", path]);
    
    //happy
    shouldAccept = YES;
    
bail:
    
    //release task ref object
    if(NULL != taskRef)
    {
        //release
        CFRelease(taskRef);
        
        //unset
        taskRef = NULL;
    }
    
    return shouldAccept;
}

@end
