//
//  file: UserComms.h
//  project: lulu (launch daemon)
//  description: interface for user componets (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//



@import Foundation;
#import "UserCommsInterface.h"


@interface UserComms : NSObject <UserProtocol>
{
    
}

/* PROPERTIES */

//client status
@property NSInteger currentStatus;

//last alert
@property(nonatomic,retain)NSDictionary* dequeuedAlert;

/* METHODS */


@end
