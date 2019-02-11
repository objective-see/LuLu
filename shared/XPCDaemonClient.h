//
//  file: XPCDaemonClient.h
//  project: lulu (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCDaemonProto.h"

@interface XPCDaemonClient : NSObject

//xpc connection to daemon
@property (atomic, strong, readwrite)NSXPCConnection* daemon;

//tell daemon to load kext
// on 10.13+ might need to re-try to allow user to allow via UI
-(void)loadKext;

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences;

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//ask daemon for rules
-(void)getRules:(void (^)(NSDictionary*))reply;

//add rule
-(void)addRule:(NSString*)processPath action:(NSUInteger)action;

//update rule
-(void)updateRule:(NSString*)processPath action:(NSUInteger)action;

//delete rule
-(void)deleteRule:(NSString*)processPath;

//import rules
-(BOOL)importRules:(NSString*)rulesFile;

//login item methods
#ifndef MAIN_APP

//respond to alert
-(void)alertReply:(NSDictionary*)alert;

#endif

@end
