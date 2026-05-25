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

//
// NOTE: All methods are now asynchronous and non-blocking.
// Callers MUST dispatch any UI work performed inside the completion block
// back to the main queue (dispatch_get_main_queue()).
// Completion blocks are invoked on an arbitrary XPC queue.
//

//get preferences
-(void)getPreferences:(void (^)(NSDictionary* _Nullable preferences))completion;

//update (save) preferences
// note: returns merged preferences (from daemon) via the completion block
-(void)updatePreferences:(NSDictionary*)preferences completion:(void (^)(NSDictionary* _Nullable updatedPreferences))completion;

//get rules
-(void)getRules:(void (^)(NSDictionary* _Nullable rules))completion;

//add rule (fire-and-forget)
-(void)addRule:(NSDictionary*)info;

//disable (or re-enable) rule (fire-and-forget)
-(void)toggleRule:(NSString*)key rule:(NSString*)uuid state:(NSNumber*)state;

//delete rule (fire-and-forget)
-(void)deleteRule:(NSString*)key rule:(NSString*)uuid;

//import rules
-(void)importRules:(NSData*)newRules userOnly:(BOOL)userOnly completion:(void (^)(BOOL imported))completion;

//cleanup rules
// note: NSInteger result is -1 on error (e.g. XPC failure)
-(void)cleanupRules:(BOOL)full completion:(void (^)(NSInteger deletedRules))completion;

//get current profile
-(void)getCurrentProfile:(void (^)(NSString* _Nullable currentProfile))completion;

//get list of profiles
-(void)getProfiles:(void (^)(NSMutableArray* _Nullable profiles))completion;

//set profile
-(void)setProfile:(NSString*)name completion:(void (^)(BOOL wasSet))completion;

//add profile
-(void)addProfile:(NSString*)name preferences:(NSDictionary*)preferences completion:(void (^)(BOOL wasAdded))completion;

//delete profile
-(void)deleteProfile:(NSString*)name completion:(void (^)(BOOL wasDeleted))completion;

//uninstall
-(void)uninstall:(void (^)(BOOL wasUninstalled))completion;

@end
