//
//  file: ProcListener.m
//  project: lulu (launch daemon)
//  description: interface with process monitor library
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Rules.h"
#import "consts.h"
#import "logging.h"
#import "KextComms.h"
#import "KextListener.h"
#import "ProcListener.h"
#import "UserClientShared.h"

//global kext comms obj
extern KextComms* kextComms;

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
    }
    
    return self;
}

//enumerate existing processes
// get signing info and add to kernel
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
            self.processes[[NSNumber numberWithUnsignedInt:currentProcess.pid]] = currentProcess;
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
//  add to list of procs and broadcast event
-(void)processStart:(Process*)process
{
    //existing proc
    Process* existingProcess = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process start: %@ (%d)\n", process.path, process.pid]);
    
    //sync
    // when invoking 'process remove' logic, want that to complete
    @synchronized(self)
    {
        //see if there is an existing process
        // fork/exec doesn't trigger an exit event
        existingProcess = self.processes[[NSNumber numberWithUnsignedInt:process.pid]];
        if(nil != existingProcess)
        {
            //manually remove
            // will trigger logic to remove rule (in kext)
            [self processEnd:existingProcess];
        }
    }

    //sync to add
    @synchronized(self.processes)
    {
        //add
        self.processes[[NSNumber numberWithUnsignedInt:process.pid]] = process;
    }
    
    //broadcast event
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PROCESS_START object:nil userInfo:@{NOTIFICATION_PROCESS_START:process}];

    return;
}

//process end
// remove from list of procs and broadcast event
-(void)processEnd:(Process*)process
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process exit: %d\n", process.pid]);
    
    //sync to remove
    @synchronized(self.processes)
    {
        //remove
        [self.processes removeObjectForKey:[NSNumber numberWithUnsignedInt:process.pid]];
    }
    
    //broadcast event
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PROCESS_END object:nil userInfo:@{NOTIFICATION_PROCESS_END:process}];
    
    return;
}

@end
