//
//  file: XPCListener
//  project: lulu (launch daemon)
//  description: XPC listener for connections for user components (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import OSLog;
@import Foundation;

#import "XPCDaemonProto.h"

//function def
OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@interface XPCListener : NSObject <NSXPCListenerDelegate>
{
    
}

/* PROPERTIES */

//XPC listener
@property(nonatomic, retain)NSXPCListener* listener;

//XPC connection for login item
@property(weak)NSXPCConnection* client;

@end
