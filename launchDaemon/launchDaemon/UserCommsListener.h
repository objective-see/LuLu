//
//  file: UserCommsListener.h
//  project: lulu (launch daemon)
//  description: XPC listener for connections for user components (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import Foundation;
#import "UserCommsInterface.h"

@interface UserCommsListener : NSObject <NSXPCListenerDelegate>
{
    
}

/* PROPERTIES */

//XPC listener
@property(nonatomic, retain)NSXPCListener* listener;

/* METHODS */

//setup XPC listener
-(BOOL)initListener;

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// note: we only allow binaries signed by Objective-See to talk to this!
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection;

//connection invalidated
// if there is an 'undelivered' alert, (re)enqueue it
-(void)connectionInvalidated:(NSXPCConnection *)connection;

@end
