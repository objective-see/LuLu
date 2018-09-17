//
//  file: XPCDaemonProtocol.h
//  project: LuLu (shared)
//  description: methods exported by the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@protocol XPCDaemonProtocol

//get preferences
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//get rules
// optionally waits (blocks) for change
-(void)getRules:(void (^)(NSDictionary*))reply;

//add rule
-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;

//update
-(void)updateRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;

//delete rule
-(void)deleteRule:(NSString*)path;

//import rules
-(void)importRules:(NSString*)rulesFile reply:(void (^)(BOOL))reply;

//login item methods
#ifndef MAIN_APP

//respond to an alert
-(void)alertReply:(NSDictionary*)alert;

#endif 

@end
