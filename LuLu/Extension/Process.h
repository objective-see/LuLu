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

//user id
@property uid_t uid;

//type
// used by process mon
@property u_int16_t type;

//exit code
@property u_int32_t exit;

//(self) deleted binary
@property BOOL deleted;

//name
@property(nonatomic, retain)NSString* _Nullable name;

//path
@property(nonatomic, retain)NSString* _Nullable path;

//args
@property(nonatomic, retain)NSMutableArray* _Nullable arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* _Nullable ancestors;

//signing info
@property(nonatomic, retain)NSMutableDictionary* _Nullable csInfo;

//key
@property(nonatomic, retain)NSString* _Nonnull key;

//Binary object
// has path, hash, etc
@property(nonatomic, retain)Binary* _Nonnull binary;

//timestamp
@property(nonatomic, retain)NSDate* _Nonnull timestamp;

/* METHODS */

//init with a audit token
// method will then (try) fill out rest of object
-(id _Nullable)init:(audit_token_t* _Nonnull)token;

//generate list of ancestors
-(void)enumerateAncestors;

@end

#endif /* Process_h */
