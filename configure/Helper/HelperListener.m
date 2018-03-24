//
//  file: HelperListener.m
//  project: (open-source) installer
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "consts.h"
#import "logging.h"
#import "XPCProtocol.h"
#import "HelperListener.h"
#import "HelperInterface.h"

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
        syslog(LOG_ERR, "failed to create mach service %s", CONFIG_HELPER_ID.UTF8String);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created mach service %@", CONFIG_HELPER_ID]);
    
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
// note: we only allow binaries signed by Objective-See to talk to this to be extra safe :)
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //pragma
    #pragma unused(listener)
    
    //flag
    BOOL shouldAccept = NO;
    
    //task ref
    SecTaskRef taskRef = 0;
    
    //signing req string
    NSString *requirementString = nil;
    
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
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[HelperInterface alloc] init];

    //resume
    [newConnection resume];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowed XPC connection: %@", newConnection]);
    
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
