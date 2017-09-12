//
//  file: UserComms.m
//  project: lulu (launch daemon)
//  description: interface for user componets
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "Rule.h"
#import "Rules.h"
#import "Queue.h"
#import "logging.h"
#import "KextComms.h"
#import "UserComms.h"
#import "UserClientShared.h"
#import "UserCommsInterface.h"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global kext comms obj
extern KextComms* kextComms;

//global rules obj
extern Rules* rules;

//global queue object
extern Queue* eventQueue;

//global 'rules changed' semaphore
extern dispatch_semaphore_t rulesChanged;

//global client status
extern NSInteger clientStatus;

@implementation UserComms

@synthesize currentStatus;
@synthesize dequeuedAlert;

//init
// set connection to unknown
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //set status
        self.currentStatus = STATUS_CLIENT_UNKNOWN;
        
    }
    
    return self;
}

//set status
// enabled/disabled
// TODO: assumes single client/user
-(void)setClientStatus:(NSInteger)status
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: set client status (%ld)", (long)status]);
    
    //save into iVar
    self.currentStatus = status;
    
    //save into global
    // TODO: change, if multiple clients
    clientStatus = status;
    
    //enable?
    // ->tell kext to enable firewall
    if(STATUS_CLIENT_ENABLED == status)
    {
        //enable firewall
        [kextComms enable];
    }
    //disable?
    // ->tell kext to disable firewall
    else if(STATUS_CLIENT_DISABLED == status)
    {
        //disable firewall
        [kextComms disable];
    }
    
    return;
}

//get rules
// optionally wait (blocks) for change
-(void)getRules:(BOOL)wait4Change reply:(void (^)(NSDictionary*))reply;
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: GET RULES");
    
    //block for change?
    if(YES == wait4Change)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"waiting (blocking) for rule change...%p\n", self]);
        
        //wait for rules change
        // add/remove/alerts methods will trigger
        dispatch_semaphore_wait(rulesChanged, DISPATCH_TIME_FOREVER);
    }
    
    //return rules
    reply([rules serialize]);
    
    return;
}

//add rule
-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: ADD RULE (%@/%lu)", path, action]);

    //add
    // ->type is 'user'
    if(YES != [rules add:path action:action type:RULE_TYPE_USER user:user])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to add rule for %@", path]);
    }

    //signal all threads that rules changed
    while(0 != dispatch_semaphore_signal(rulesChanged));
    
    return;
}

//delete rule
-(void)deleteRule:(NSString*)path
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: DELETE RULE (%@)", path]);
    
    //remove
    if(YES != [rules delete:path])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete rule for %@", path]);
    }
    
    //signal all threads that rules changed
    while(0 != dispatch_semaphore_signal(rulesChanged));
    
    return;
}

//process alert request from client
// ->blocks for queue item, then sends to client
-(void)alertRequest:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: alert request");
    
    //reset
    self.dequeuedAlert = nil;
    
    //read off queue
    // ->will block
    self.dequeuedAlert = [eventQueue dequeue];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"dequeued alert: %@", self.dequeuedAlert]);
    
    //return alert
    reply(self.dequeuedAlert);
    
    return;
}

//process client response to alert
// ->tells kext/update rules/etc...
-(void)alertResponse:(NSMutableDictionary*)alert
{
    //path
    NSString* path = nil;
    
    //pid
    uint32_t pid = 0;
    
    //action
    uint32_t action = 0;
    
    //user
    uint32 user = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: alert response: %@", alert]);
    
    //sanity check
    if( (nil == alert[ALERT_PID]) ||
        (nil == alert[ALERT_PATH]) ||
        (nil == alert[ALERT_USER]) ||
        (nil == alert[ALERT_ACTION]) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"received invalid alert response: %@", alert]);
        
        //bail
        goto bail;
    }
    
    //extract path
    path = alert[ALERT_PATH];
    
    //extract pid
    pid = [alert[ALERT_PID] unsignedIntValue];
    
    //extact user
    user = [alert[ALERT_USER] unsignedIntValue];
    
    //extract action
    action = [alert[ALERT_ACTION] unsignedIntValue];
    
    //tell kext
    // TODO: add support for 'user'
    [kextComms addRule:pid action:action];
    
    //update rules
    // ->type is 'user'
    [rules add:path action:action type:RULE_TYPE_USER user:user];
    
    //signal all threads that rules changed
    while(0 != dispatch_semaphore_signal(rulesChanged));
    
bail:
    
    return;
}


@end
