//
//  ProcessTreeTracker.h
//  LuLu
//
//  Copyright (c) Objective-See. All rights reserved.
//

#ifndef ProcessTreeTracker_h
#define ProcessTreeTracker_h

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface ProcessTreeTracker : NSObject

@property(nonatomic, readonly)BOOL available;
@property(nonatomic, readonly)BOOL healthy;
@property(nonatomic, readonly, copy, nullable)NSString* failureReason;

-(BOOL)start;
-(void)stop;
+(nullable NSString*)identityForAuditToken:(NSData*)auditToken;

//Observed oldest ancestors through the current executable; nil means unknown identity.
//Snapshots contain path, auditToken, identity and available ES signing information.
//A new tracker cannot recover exited ancestors; monitoring gaps cannot be rebuilt.
//In-process restarts retain captured identities. AUTH_EXEC precedes execution,
//but fork-only children and default-muted AUTH paths can precede notification delivery.
-(nullable NSArray<NSDictionary*>*)ancestorsForAuditToken:(NSData*)auditToken;
-(BOOL)lineageCompleteForAuditToken:(NSData*)auditToken;

//Snapshots must originate from kernel process events, never PID-only parent lookups.
//These mutations also support deterministic policy tests without an ES client.
-(void)recordSnapshot:(NSDictionary*)snapshot;
-(void)recordForkParent:(NSDictionary*)parent child:(NSDictionary*)child;
-(void)recordExecSource:(NSDictionary*)source target:(NSDictionary*)target;
-(void)recordExitAuditToken:(NSData*)auditToken;

@end

NS_ASSUME_NONNULL_END

#endif /* ProcessTreeTracker_h */
