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

//checkin
-(void)clientCheckin;

//get preferences
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//get rules
// ->optionally waits (blocks) for change
-(void)getRules:(BOOL)wait4Change reply:(void (^)(NSDictionary*))reply;

//add rule
-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;

//update
-(void)updateRule:(NSString*)processPath action:(NSUInteger)action user:(NSUInteger)user;

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
