//
//  Process.h
//  LuLu
//
//  Created by Patrick Wardle on 8/27/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#ifndef Process_h
#define Process_h

@import OSLog;

#import "Binary.h"

@interface Process : NSObject

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//user id
@property uid_t uid;

//type
// used by process mon
@property u_int16_t type;

//exit code
@property u_int32_t exit;

//path
@property(nonatomic, retain)NSString* _Nullable path;

//args
@property(nonatomic, retain)NSMutableArray* _Nonnull arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* _Nonnull ancestors;

//signing info
@property(nonatomic, retain)NSMutableDictionary* _Nonnull csInfo;

//Binary object
// has path, hash, etc
@property(nonatomic, retain)Binary* _Nonnull binary;

//timestamp
@property(nonatomic, retain)NSDate* _Nonnull timestamp;

/* METHODS */

//init with a pid
// method will then (try) fill out rest of object
-(id _Nullable)init:(pid_t)processID;

//generate signing info
// also classifies if Apple/from App Store/etc.
-(void)generateSigningInfo:(SecCSFlags)flags;

//set process's path
-(void)pathFromPid;

//generate list of ancestors
-(void)enumerateAncestors;

@end

#endif /* Process_h */
