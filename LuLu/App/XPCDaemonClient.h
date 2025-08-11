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
{
    
}

//xpc connection to daemon
@property (atomic, strong, readwrite)NSXPCConnection* daemon;

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences;

//update (save) preferences
// note: synchronous, as then returns latest preferences
-(NSDictionary*)updatePreferences:(NSDictionary*)preferences;

//get rules
// note: synchronous
-(NSDictionary*)getRules;

//add rule
-(void)addRule:(NSDictionary*)info;

//disable (or re-enable) rule
-(void)toggleRule:(NSString*)key rule:(NSString*)uuid;

//delete rule
-(void)deleteRule:(NSString*)key rule:(NSString*)uuid;

//import rules
-(BOOL)importRules:(NSData*)newRules;

//cleanup rules
-(NSInteger)cleanupRules;

//get current profile
-(NSString*)getCurrentProfile;

//get list of profiles
-(NSMutableArray*)getProfiles;

//set profile
-(BOOL)setProfile:(NSString*)name;

//add profile
-(BOOL)addProfile:(NSString*)name preferences:(NSDictionary*)preferences;

//delete profile
-(BOOL)deleteProfile:(NSString*)name;

//uninstall
-(BOOL)uninstall;

@end
