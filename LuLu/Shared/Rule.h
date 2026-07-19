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

#import "consts.h"

@interface Rule : NSObject <NSSecureCoding>
{
    //cached CIDR/range bounds for endpointAddr
    // lazily parsed on first match; not serialized (endpointAddr is immutable after creation)
    BOOL _cidrParsed;
    BOOL _cidrValid;
    int _cidrFamily;
    int _cidrLength;
    uint8_t _cidrLo[16];
    uint8_t _cidrHi[16];
}

/* PROPERTIES */

//uuid
@property(nonatomic, retain)NSString* uuid;

//key
@property(nonatomic, retain)NSString* key;

// PROCESS/BINARY INFO

//rule pid
// only set if rule's duration is set to process lifetime
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

//user-friendly endpoint display metadata
@property(nonatomic, retain)NSString* endpointAddrDisplay;

//technical endpoint matcher display metadata
@property(nonatomic, retain)NSString* endpointAddrMatcher;

//original endpoint input kind
@property(nonatomic, retain)NSNumber* endpointInputKind;

//normalized original endpoint input
@property(nonatomic, retain)NSString* endpointInputNormalized;

//remote host
@property(nonatomic, retain)NSString* endpointHost;

//endpoint address match type {exact, regex, cidr}
// note: name retained for serialization compatibility (legacy 'isEndpointAddrRegex' bool)
@property EndpointType isEndpointAddrRegex;

//cached compiled regex for endpointAddr
// lazily built on first match; not serialized
@property(nonatomic, retain) NSRegularExpression* endpointRegex;

//remote port
@property(nonatomic, retain)NSString* endpointPort;

//type
// default, user, etc
@property(nonatomic, retain)NSNumber* type;

//protocol
@property(nonatomic, retain)NSNumber* protocol;

//is disabled
@property(nonatomic, retain)NSNumber* isDisabled;

// TIMESTAMPS

//rule creation
@property(nonatomic, retain)NSDate* creation;

//rule expiration
// only set if rule's duration is set to expire
@property(nonatomic, retain)NSDate* expiration;


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

//is rule temp?
-(BOOL)isTemporary;

//is rule user (created)
-(BOOL)isUserCreated;

//lazily compile & cache the endpoint regex (nil if endpointAddr isn't a valid regex)
-(NSRegularExpression*)compiledEndpointRegex;

//check if a numeric IP string falls within this rule's (cached) CIDR/range endpoint
-(BOOL)endpointAddrInRange:(NSString*)address;

//friendly endpoint display value
-(NSString*)friendlyEndpointAddr;

//technical matcher display value
-(NSString*)friendlyEndpointMatcher;

//friendly endpoint type label
-(NSString*)friendlyEndpointType;

//covert to dictionary
-(NSMutableString*)toJSON;

//make a rule obj from a dictioanary
-(id)initFromJSON:(NSDictionary*)info;

@end

#endif /* Rule_h */
