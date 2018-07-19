//
//  file: Queue.m
//  project: lulu (launch daemon)
//  description: a queue implementation
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Queue.h"
#import "consts.h"
#import "logging.h"

@implementation Queue

@synthesize queue;
@synthesize queueCondition;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init queue
        queue = [NSMutableArray array];
        
        //init empty condition
        queueCondition = [[NSCondition alloc] init];
    }
    
    return self;
}

//add an object to the queue
-(void)enqueue:(id)anObject
{
    //lock
    [self.queueCondition lock];
    
    //add to queue
    [self.queue enqueue:anObject];
    
    //signal
    [self.queueCondition signal];
    
    //unlock
    [self.queueCondition unlock];
    
    return;
}

//wait until queue has item
// ->then pull if off, and return it
-(id)dequeue
{
    //queue item
    id item = nil;
    
    //lock
    [self.queueCondition lock];
    
    //wait while queue is empty
    while(YES == [self.queue isEmpty])
    {
        //wait
        [self.queueCondition wait];
    }
    
    //get item off queue
    item = [self.queue dequeue];
    
    //unlock
    [self.queueCondition unlock];
    
    return item;
}

@end
