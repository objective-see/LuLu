//
//  file: userCommsInterface.h
//  project: lulu (shared)
//  description: protocol for talking to the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef userCommsInterface_h
#define userCommsInterface_h

@import Foundation;

@protocol UserProtocol

//set status
// ->enabled/disabled
-(void)setClientStatus:(NSInteger)status;

//get rules
// ->optionally waits (blocks) for change
-(void)getRules:(BOOL)wait4Change reply:(void (^)(NSDictionary*))reply;

//add rule
-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;

//delete rule
-(void)deleteRule:(NSString*)path;

//import rules
-(void)importRules:(NSString*)rulesFile reply:(void (^)(BOOL))reply;

//process alert request from client
-(void)alertRequest:(void (^)(NSDictionary* alert))reply;

//process client response to alert
-(void)alertResponse:(NSDictionary*)alert;

@end


#endif /* userCommsInterface_h */
