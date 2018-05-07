//
//  file: ProcListener.m
//  project: lulu (launch daemon)
//  description: interface with process monitor library
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#import "ProcListener.h"
#import "consts.h"
#import "logging.h"

#import "Rule.h"
#import "Rules.h"
#import "KextComms.h"
#import "KextListener.h"
#import "UserClientShared.h"

//global kext comms obj
extern KextComms* kextComms;

//global kext listen obj
extern KextListener* kextListener

//global rules obj
extern Rules* rules;

@implementation ProcessListener

@synthesize procMon;
@synthesize processes;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc
        self.processes = [NSMutableDictionary dictionary];
        
        //init proc info (monitor)
        // invoke with 'YES' for less CPU
        procMon = [[ProcInfo alloc] init:YES];
        
        //start thread enumerate existing processes
        [NSThread detachNewThreadSelector:@selector(enumerateCurrent) toTarget:self withObject:nil];
    }
    
    return self;
}

//enumerate existing processes
-(void)enumerateCurrent
{
    //current procs
    NSMutableArray* currentProcesses = nil;
    
    //matching rule
    Rule* matchingRule = nil;
    
    //get current processes
    currentProcesses = [procMon currentProcesses];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"enumerated %lu current processes\n", (unsigned long)currentProcesses.count]);
    
    //get signing info for each
    // then add to list of proceses
    for(Process* currentProcess in currentProcesses)
    {
        //sync to add
        @synchronized (self.processes)
        {
            //add
            self.processes[[NSNumber numberWithUnsignedShort:currentProcess.pid]] = currentProcess;
        }
        
        //existing rule for process
        // tell kernel to add them already
        matchingRule = [rules find:currentProcess];
        if(nil != matchingRule)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found matching rule: %@\n", matchingRule]);
            
            //tell kernel to add rule for this process
            [kextComms addRule:currentProcess.pid action:matchingRule.action.unsignedIntValue];
        }
    }
    
    return;    
}

//setup/start process monitoring
-(void)monitor
{
    //callback block
    ProcessCallbackBlock block = ^(Process* process)
    {
        //process start?
        if(process.type != EVENT_EXIT)
        {
            //start
            [self processStart:process];
        }
        
        //process end?
        else
        {
            //end
            [self processEnd:process];
        }
    };
    
    //start
    [self.procMon start:block];

    return;
}

//process start
//  add to list of procs
//  ...and if rule exists, tell kernel
-(void)processStart:(Process*)process
{
    //matching rule
    Rule* matchingRule = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process start: %@ (%d)\n", process.path, process.pid]);
    
    //sync to add
    @synchronized(self.processes)
    {
        //add
        self.processes[[NSNumber numberWithUnsignedShort:process.pid]] = process;
    }
    
    //existing rule for process (path)
    matchingRule = [rules find:process];
    if(nil != matchingRule)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found matching rule: %@\n", matchingRule]);
        
        //tell kernel to add rule for this process
        [kextComms addRule:process.pid action:matchingRule.action.unsignedIntValue];
    }

    return;
}

//process end
// remove from list of procs
// ...also tell kernel to invalidate rule for that pid
-(void)processEnd:(Process*)process
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process exit: %d\n", process.pid]);
    
    //sync to remove
    @synchronized(self.processes)
    {
        //remove
        [self.processes removeObjectForKey:[NSNumber numberWithUnsignedShort:process.pid]];
    }
    
    //remove from list of passive process
    [kextListener.passiveProcesses removeObject:[NSNumber numberWithInt:process.pid]];
    
    //tell kernel to remove rule for this process
    [kextComms removeRule:process.pid];
    
    return;
}

@end
