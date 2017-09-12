//
//  file: Queue.h
//  project: lulu (launch daemon)
//  description: a queue implementation (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;
#import "NSMutableArray+QueueAdditions.h"

@interface Queue : NSObject
{
    
}

/* PROPERTIES */

//event queue
@property(retain, atomic)NSMutableArray* eventQueue;

//queue condition
@property (nonatomic, retain)NSCondition* queueCondition;


/* METHODS */

//add an object to the queue
-(void)enqueue:(id)anObject;

//wait until queue has item
// ->then pull if off, and return it
-(id)dequeue;

@end
