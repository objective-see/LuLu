//
//  file: Rule.h
//  project: LuLu (shared)
//  description: Rule object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Rule_h
#define Rule_h

@import OSLog;
@import Foundation;

@interface Rule : NSObject <NSSecureCoding>
{
    
}

/* PROPERTIES */

//uuid
@property(nonatomic, retain)NSString* uuid;

//key
@property(nonatomic, retain)NSString* key;

// PROCESS/BINARY INFO

//rule pid
// only set if rule is temporary
@property(nonatomic, retain)NSNumber* pid;

//path
@property(nonatomic, retain)NSString* path;

//flag for global rule
@property(nonatomic, retain)NSNumber* isGlobal;

//flag for directory rule
@property(nonatomic, retain)NSNumber* isDirectory;

//name
@property(nonatomic, retain)NSString* name;

//signing info
@property(nonatomic, retain)NSDictionary* csInfo;

//remote ip or url
@property(nonatomic, retain)NSString* endpointAddr;

//flag for endpoint addr
@property BOOL isEndpointAddrRegex;

//remote port
@property(nonatomic, retain)NSString* endpointPort;

//type
// default, user, etc
@property(nonatomic, retain)NSNumber* type;

//protocol
@property(nonatomic, retain)NSNumber* protocol;


// ACTION

//action
// allow / deny
@property(nonatomic, retain)NSNumber* action;

//action scope
// process, endpoint, etc
@property(nonatomic, retain)NSNumber* scope;


/* METHODS */

//init method
-(id)init:(NSDictionary*)info;

//matches a string?
-(BOOL)matchesString:(NSString*)match;

//matches a(nother) rule?
-(BOOL)isEqualToRule:(Rule *)rule;

@end


#endif /* Rule_h */
