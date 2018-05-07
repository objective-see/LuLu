//
//  file: Rule.h
//  project: lulu (shared)
//  description: Rule object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Rule_h
#define Rule_h

#import <Foundation/Foundation.h>


@interface Rule : NSObject
{
    
}


/* PROPERTIES */

//path of binary
@property(nonatomic, retain)NSString* path;

//signing info
@property(nonatomic, retain)NSDictionary* signingInfo;

//hash
@property(nonatomic, retain)NSString* sha256;

//name
@property(nonatomic, retain)NSString* name;


//action
// allow, deny, etc
@property(nonatomic, retain)NSNumber* action;

//type
// default, baseline, user
@property(nonatomic, retain)NSNumber* type;

//user
// what user created this
@property(nonatomic, retain)NSNumber* user;

/* METHODS */

//init method
-(id)init:(NSString*)path info:(NSDictionary*)info;

//make sure rule dictionary has all the required memebers
-(BOOL)validate:(NSString*)path rule:(NSDictionary*)rule;

//covert rule obj to dictionary
-(NSMutableDictionary*)serialize;

@end


#endif /* Rule_h */
