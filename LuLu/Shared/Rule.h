//
//  file: Rule.h
//  project: BlockBlock (shared)
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
@property (nonatomic, retain)NSString* uuid;

// PROCESS/BINARY INFO

//path
@property(nonatomic, retain)NSString* path;

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

//temporary rule?
@property(nonatomic, retain)NSNumber* temporary;

/* METHODS */

//init method
-(id)init:(NSDictionary*)info;

//matches a string?
-(BOOL)matchesString:(NSString*)match;

//matches a(nother) rule?
-(BOOL)isEqualToRule:(Rule *)rule;

@end


#endif /* Rule_h */
