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

@import Foundation;

@class Rule;

@interface Rules : NSObject
{
    
}

/* PROPERTIES */

//rules
@property(nonatomic, retain)NSMutableDictionary* rules;

//query for baselining rules
@property(nonatomic, retain)NSMetadataQuery* appQuery;

/* METHODS */

//load from disk
-(BOOL)load;

//start query for all installed apps
-(void)startBaselining;

//find
// for now, just by path
-(Rule*)find:(NSString*)path;

//add rule
-(BOOL)add:(NSString*)path action:(NSUInteger)action type:(NSUInteger)type user:(NSUInteger)user;

//add to kernel
-(void)addToKernel:(Rule*)rule;

//delete rule
-(BOOL)delete:(NSString*)path;

//delete all rules
-(BOOL)deleteAll;

//convert list of rule objects to dictionary
-(NSMutableDictionary*)serialize;

@end


#endif /* Rules_h */
