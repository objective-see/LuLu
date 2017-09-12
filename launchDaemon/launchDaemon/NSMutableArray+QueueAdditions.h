//
//  file: NSMutableArray+QueueAdditions.h
//  project: lulu (launch daemon)
//  description: queue implementation via NSMutableArray (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//
//  note: based on https://github.com/esromneb/ios-queue-object/blob/master/NSMutableArray%2BQueueAdditions.m

#import <Foundation/Foundation.h>

@interface NSMutableArray (QueueAdditions)
{
    
}

/* METHODS */

//add object to end of queue
-(void)enqueue:(id)item;

//grab item from front of queue
-(id)dequeue;

//determine if queue is empty
-(BOOL)isEmpty;

@end
