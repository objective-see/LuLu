//
//  file: XPCUserClient.h
//  project: lulu (launch daemon)
//  description: talk to the user, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

#import "XPCUserProto.h"
@interface XPCUserClient : NSObject
{
    
}

/* PROPERTIES */


/* METHODS */

//deliver alert to user
// note: this is synchronous, so errors can be detected
-(BOOL)deliverAlert:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply;

//inform user rules have changed
-(void)rulesChanged;

@end
