//
//  file: XPCDaemon.h
//  project: lulu (launch daemon)
//  description: interface for XPC methods, invoked by user (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

//#import "XPCUserClient.h"
#import "XPCDaemonProto.h"

@interface XPCDaemon : NSObject <XPCDaemonProtocol>
{
    
}

/* PROPERTIES */

//xpc client for talking to user
//@property(nonatomic, retain)XPCUserClient* xpcUserClient;



//last alert
//@property(nonatomic,retain)NSDictionary* dequeuedAlert;

@end
