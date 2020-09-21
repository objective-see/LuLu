//
//  file: XPCUserProtocol
//  project: LuLu (shared)
//  description: protocol for talking to the user (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@protocol XPCUserProtocol

//rules changed
-(void)rulesChanged;

//show an alert
-(void)alertShow:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply;

@end

