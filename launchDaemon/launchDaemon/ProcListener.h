//
//  file: ProcListener.h
//  project: lulu (launch daemon)
//  description: interface with process monitor library (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import Foundation;

#import "procInfo.h"

@interface ProcessListener : NSObject
{
    
}

/* PROPERTIES */

//process info (monitor) object
@property(nonatomic, retain)ProcInfo* procMon;

//list of active processes
@property(nonatomic, retain)NSMutableDictionary* processes;


/* METHODS */

//init
-(id)init;

//setup/start process monitoring
-(void)monitor;


@end
