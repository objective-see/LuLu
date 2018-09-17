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

//methods for login item
#ifndef MAIN_APP

//show an alert
-(void)alertShow:(NSDictionary*)alert;

#endif

//methods for main app
#ifndef LOGIN_ITEM

//rules changed
-(void)rulesChanged:(NSDictionary*)rules;

#endif

@end

