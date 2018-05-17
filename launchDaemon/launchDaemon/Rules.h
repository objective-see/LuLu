//
//  file: Rules.h
//  project: lulu (launch daemon)
//  description: handles rules & actions such as add/delete (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#ifndef Rules_h
#define Rules_h

#import "procInfo.h"

@import Foundation;

@class Rule;


@interface Rules : NSObject
{
    
}

/* PROPERTIES */

//rules
@property(nonatomic, retain)NSMutableDictionary* rules;


/* METHODS */

//load from disk
-(BOOL)load;

//find
-(Rule*)find:(Process*)process;

//add rule
-(BOOL)add:(NSString*)path signingInfo:(NSDictionary *)signingInfo action:(NSUInteger)action type:(NSUInteger)type user:(NSUInteger)user;

//add to kernel
-(void)addToKernel:(Rule*)rule;

//update rule
-(BOOL)update:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;

//delete rule
-(BOOL)delete:(NSString*)path;

//delete all rules
-(BOOL)deleteAll;

//convert list of rule objects to dictionary
-(NSMutableDictionary*)serialize;

@end


#endif /* Rules_h */
