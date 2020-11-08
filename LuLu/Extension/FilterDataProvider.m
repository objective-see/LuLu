//
//  FilterDataProvider.m
//  LuLu
//
//  Created by Patrick Wardle on 8/1/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Rules.h"
#import "Alerts.h"
#import "consts.h"
#import "GrayList.h"
#import "BlockList.h"
#import "utilities.h"
#import "Preferences.h"
#import "XPCUserProto.h"
#import "FilterDataProvider.h"

/* GLOBALS */

//alerts
extern Alerts* alerts;

//log handle
extern os_log_t logHandle;

//rules
extern Rules* rules;

//preferences
extern Preferences* preferences;

//block list
extern BlockList* blockList;

@implementation FilterDataProvider

@synthesize cache;
@synthesize grayList;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //init cache
        cache = [[NSCache alloc] init];
        
        //set cache limit
        self.cache.countLimit = 2048;
        
        //init gray list
        grayList = [[GrayList alloc] init];
        
        //alloc related flows
        self.relatedFlows = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//start filter
-(void)startFilterWithCompletionHandler:(void (^)(NSError *error))completionHandler {

    //rule
    NENetworkRule* networkRule = nil;
    
    //filter rule
    NEFilterRule* filterRule = nil;
    
    //filter settings
    NEFilterSettings* filterSettings = nil;
    
    //log msg
    os_log_debug(logHandle, "%s", __PRETTY_FUNCTION__);
    
    //init network rule
    // any/all outbound traffic
    networkRule = [[NENetworkRule alloc] initWithRemoteNetwork:nil remotePrefix:0 localNetwork:nil localPrefix:0 protocol:NENetworkRuleProtocolAny direction:NETrafficDirectionOutbound];
    
    //init filter rule
    // filter traffic, based on network rule
    filterRule = [[NEFilterRule alloc] initWithNetworkRule:networkRule action:NEFilterActionFilterData];
    
    //init filter settings
    filterSettings = [[NEFilterSettings alloc] initWithRules:@[filterRule] defaultAction:NEFilterActionAllow];
    
    //apply rules
    [self applySettings:filterSettings completionHandler:^(NSError * _Nullable error) {
        
        //error?
        if(nil != error) os_log_error(logHandle, "ERROR: failed to apply filter settings: %@", error.localizedDescription);
        
        completionHandler(error);
    }];
    
    return;
    
}

//stop filter
-(void)stopFilterWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    
    //log msg
    os_log_debug(logHandle, "method '%s' invoked with %ld", __PRETTY_FUNCTION__, (long)reason);
    
    //extra dbg info
    if(NEProviderStopReasonUserInitiated == reason)
    {
        //log msg
        os_log_debug(logHandle, "reason: NEProviderStopReasonUserInitiated");
    }
    
    //required
    completionHandler();
    
    return;
}

//handle flow
// a) skip local/inbound traffic
// b) lookup matching rule & then apply
// c) ...or ask user (alert via XPC) if no rule
-(NEFilterNewFlowVerdict *)handleNewFlow:(NEFilterFlow *)flow {
    
    //socket flow
    NEFilterSocketFlow* socketFlow = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //verdict
    NEFilterNewFlowVerdict* verdict = nil;
    
    //log msg
    os_log_debug(logHandle, "%s", __PRETTY_FUNCTION__);
    
    //init verdict to allow
    verdict = [NEFilterNewFlowVerdict allowVerdict];
    
    //typecast
    socketFlow = (NEFilterSocketFlow*)flow;
    
    //log msg
    os_log_debug(logHandle, "flow: %{public}@", flow);

    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)socketFlow.remoteEndpoint;
    
    //ignore non-outbound traffic
    // even though we init'd `NETrafficDirectionOutbound`, sometimes get inbound traffic :|
    if(NETrafficDirectionOutbound != socketFlow.direction)
    {
        //log msg
        os_log_debug(logHandle, "ignoring non-outbound traffic (direction: %ld)", (long)socketFlow.direction);
           
        //bail
        goto bail;
    }
    
    //ignore traffic destined for localhost
    if( (YES == [remoteEndpoint.hostname hasPrefix:@"::1"]) ||
        (YES == [remoteEndpoint.hostname isEqualToString:@"127.0.0.1"]) )
    {
       //log msg
       os_log_debug(logHandle, "ignoring 'localhost' traffic");
          
       //bail
       goto bail;
    }
    
    //process flow
    // determine verdict
    // deliver alert (if necessary)
    verdict = [self processEvent:flow];
    
    //log msg
    os_log_debug(logHandle, "verdict: %{public}@", verdict);
    
bail:
        
    return verdict;
}

//process a network out event from the network extension (OS)
// if there is no matching rule, will tell client to show alert
-(NEFilterNewFlowVerdict*)processEvent:(NEFilterFlow*)flow
{
    //verdict
    // allow/deny
    NEFilterNewFlowVerdict* verdict = nil;
    
    //pool
    @autoreleasepool
    {
    
    //process obj
    Process* process = nil;
    
    //matching rule obj
    Rule* matchingRule = nil;
    
    //console user
    NSString* consoleUser = nil;
    
    //rule info
    NSMutableDictionary* info = nil;
    
    //default to allow (on errors, etc)
    verdict = [NEFilterNewFlowVerdict allowVerdict];
    
    //(ext) install date
    static NSDate* installDate = nil;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //grab console user
    consoleUser = getConsoleUser();
    
    //check cache for process
    process = [self.cache objectForKey:flow.sourceAppAuditToken];
    if(nil == process)
    {
        //dbg msg
        os_log_debug(logHandle, "no process found in cache, will create");
        
        //create
        // also adds to cache
        process = [self createProcess:flow];
    }

    //dbg msg
    else os_log_debug(logHandle, "found process object in cache: %{public}@", process);
    
    //sanity check
    // no process? just allow...
    if(nil == process)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to create process for flow, will allow");
        
        //bail
        goto bail;
    }
        
    //(now), broadcast notification
    // allows anybody to listen to flows
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:LULU_EVENT object:@"new flow" userInfo:[alerts create:(NEFilterSocketFlow*)flow process:process] options:NSNotificationDeliverImmediately|NSNotificationPostToAllSessions];
            
    //dbg msg
    //os_log_debug(logHandle, "process object for flow: %{public}@", process);
        
    //CHECK:
    // different logged in user?
    // just allow flow, as we don't want to block their traffic
    if( (nil != consoleUser) &&
        (YES != [alerts.consoleUser isEqualToString:consoleUser]) )
    {
        //dbg msg
        os_log_debug(logHandle, "current console user '%{public}@', is different than '%{public}@', so allowing flow: %{public}@", consoleUser, alerts.consoleUser, ((NEFilterSocketFlow*)flow).remoteEndpoint);
        
        //all set
        goto bail;
    }
    
    //CHECK:
    // client in (full) block mode? ...block!
    if(YES == [preferences.preferences[PREF_BLOCK_MODE] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "client in block mode, so disallowing %d/%{public}@", process.pid, process.binary.name);
        
        //deny
        verdict = [NEFilterNewFlowVerdict dropVerdict];
        
        //all set
        goto bail;
    }
        
    //CHECK:
    // client using (global) block list
    if(YES == [preferences.preferences[PREF_USE_BLOCK_LIST] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "client in using block list, will check for match");
        
        //match in block list?
        if(YES == [blockList isMatch:(NEFilterSocketFlow*)flow])
        {
            //dbg msg
            os_log_debug(logHandle, "flow matches item in block list, so denying");
            
            //deny
            verdict = [NEFilterNewFlowVerdict dropVerdict];
            
            //all set
            goto bail;
        }
        //dbg msg
        else os_log_debug(logHandle, "remote endpoint/URL not on block list...");
    }
        
    //CHECK:
    // check for existing rule
    
    //existing rule for process?
    matchingRule = [rules find:process flow:(NEFilterSocketFlow*)flow];
    if(nil != matchingRule)
    {
        //dbg msg
        os_log_debug(logHandle, "found matching rule for %d/%{public}@: %{public}@", process.pid, process.binary.name, matchingRule);
        
        //deny?
        // otherwise will default to allow
        if(RULE_STATE_BLOCK == matchingRule.action.intValue)
        {
            //dbg msg
            os_log_debug(logHandle, "setting verdict to: BLOCK");
            
            //deny
            verdict = [NEFilterNewFlowVerdict dropVerdict];
        }
        //allow (msg)
        else os_log_debug(logHandle, "rule says: ALLOW");
    
        //all set
        goto bail;
    }
    
    /* NO MATCHING RULE FOUND */
    
    //dbg msg
    os_log_debug(logHandle, "no (saved) rule found for %d/%{public}@)", process.pid, process.binary.name);
    
    //no client?

    //CHECK:
    // client in passive mode? ...allow
    if(YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "client in passive mode, so allowing %d/%{public}@", process.pid, process.binary.name);
        
        //all set
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "client not in passive mode");
    
    //CHECK:
    // is a related alert shown, and pending reponse?
    // save, but don't send yet (until the user responds)
    if(YES == [alerts isRelated:process])
    {
        //dbg msg
        os_log_debug(logHandle, "an alert is shown for process %d/%{public}@, so holding off delivering for now...", process.pid, process.binary.name);
        
        //add related flow
        [self addRelatedFlow:process flow:(NEFilterSocketFlow*)flow];
        
        //pause
        verdict = [NEFilterNewFlowVerdict pauseVerdict];
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "no related alert, currently shown...");
    
    
    //CHECK:
    // Apple process and 'PREF_ALLOW_APPLE' is set?
    // ...allow!
    
    //if it's an apple process and that preference is set; allow!
    // unless the binary is something like 'curl' which malware could abuse (then, still alert!)
    if( (YES == [preferences.preferences[PREF_ALLOW_APPLE] boolValue]) &&
        (Apple == [process.csInfo[KEY_CS_SIGNER] intValue]) )
    {
        //dbg msg
        os_log_debug(logHandle, "apple binary...");
        
        //though make sure isn't a graylisted binary
        // such binaries, even if signed by apple, should alert user
        if(YES != [self.grayList isGrayListed:process])
        {
            //dbg msg
            os_log_debug(logHandle, "due to preferences, allowing (non-graylisted) apple process %d/%{public}@", process.pid, process.path);
            
            //init for (rule) info
            // type: apple, action: allow
            info = [@{KEY_PATH:process.path, KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_APPLE} mutableCopy];
            
            //add process cs info
            if(nil != process.csInfo) info[KEY_CS_INFO] = process.csInfo;
            
            //add
            if(YES != [rules add:[[Rule alloc] init:info] save:YES])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to add rule");
                
                //bail
                goto bail;
            }
            
            //tell user rules changed
            [alerts.xpcUserClient rulesChanged];
        }
        
        //dbg msg
        else
        {
            //dbg msg
            os_log_debug(logHandle, "while signed by apple, %d/%{public}@ is gray listed, so will alert", process.pid, process.binary.name);
            
            //pause
            verdict = [NEFilterNewFlowVerdict pauseVerdict];
            
            //create/deliver alert
            [self alert:(NEFilterSocketFlow*)flow process:process];
        }
        
        //all set
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "not apple...");
    
    //if it's a prev installed 3rd-party process and that preference is set; allow!
    if( (YES == [preferences.preferences[PREF_ALLOW_INSTALLED] boolValue]) &&
        (Apple != [process.csInfo[KEY_CS_SIGNER] intValue]))
    {
        //app date
        NSDate* date = nil;
        
        //dbg msg
        os_log_debug(logHandle, "3rd-party app, plus 'PREF_ALLOW_INSTALLED' is set...");
        
        //only once
        // get install date
        dispatch_once(&onceToken, ^{
            
            //get LuLu's install date
            installDate = preferences.preferences[PREF_INSTALL_TIMESTAMP];
            
            //dbg msg
            os_log_debug(logHandle, "LuLu's install date: %{public}@", installDate);
            
        });
        
        //get item's date added
        date = dateAdded(process.path);
        if( (nil != date) &&
            (NSOrderedAscending == [date compare:installDate]) )
        {
            //dbg msg
            os_log_debug(logHandle, "3rd-party item was installed prior, allowing & adding rule");
            
            //init info for rule creation
            info = [@{KEY_PATH:process.path, KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_BASELINE} mutableCopy];
            
            //add process cs info
            if(nil != process.csInfo) info[KEY_CS_INFO] = process.csInfo;
            
            //create and add rule
            if(YES != [rules add:[[Rule alloc] init:info] save:YES])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to add rule for %{public}@", info[KEY_PATH]);
                 
                //bail
                goto bail;
            }
            
            //tell user rules changed
            [alerts.xpcUserClient rulesChanged];
            
            //all set
            goto bail;
        }
    }
    
    //no user?
    // allow, but create rule for user to review
    if( (nil == consoleUser) ||
        (nil == alerts.xpcUserClient) )
    {
        //dbg msg
        os_log_debug(logHandle, "no active user or no connect client, will allow (and create rule)...");
        
        //init info for rule creation
        info = [@{KEY_PATH:process.path, KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_UNCLASSIFIED} mutableCopy];

        //add process cs info?
        if(nil != process.csInfo) info[KEY_CS_INFO] = process.csInfo;
        
        //create and add rule
        if(YES != [rules add:[[Rule alloc] init:info] save:YES])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add rule for %{public}@", info[KEY_PATH]);
             
            //bail
            goto bail;
        }
        
        //tell user rules changed
        [alerts.xpcUserClient rulesChanged];
        
        //all set
        goto bail;
    }
        
    //create/deliver alert
    // note: also handles response (rule creation, etc)
    [self alert:(NEFilterSocketFlow*)flow process:process];

    //alert sent to user, so pause!
    verdict = [NEFilterNewFlowVerdict pauseVerdict];
    
bail:
    
    ;} //pool
    
    return verdict;
}

//1. create and deliver alert
//2. handle response (and process other shown alerts, etc.)
-(void)alert:(NEFilterSocketFlow*)flow process:(Process*)process
{
    //alert
    NSMutableDictionary* alert = nil;
    
    //create alert
    alert = [alerts create:(NEFilterSocketFlow*)flow process:process];
    
    //dbg msg
    os_log_debug(logHandle, "created alert...");

    //deliver alert
    // and process user response
    if(YES != [alerts deliver:alert reply:^(NSDictionary* alert)
    {
        //verdict
        NEFilterNewFlowVerdict* verdict = nil;
        
        //dbg msg
        os_log_debug(logHandle, "(user) response: %{public}@", alert);
        
        //init verdict to allow
        verdict = [NEFilterNewFlowVerdict allowVerdict];
        
        //user replied with block?
        if( (nil != alert[KEY_ACTION]) &&
            (RULE_STATE_BLOCK == [alert[KEY_ACTION] unsignedIntValue]) )
        {
            //verdict: block
            verdict = [NEFilterNewFlowVerdict dropVerdict];
        }
        
        //resume flow w/ verdict
        [self resumeFlow:flow withVerdict:verdict];
        
        //add/save rules
        [rules add:[[Rule alloc] init:alert] save:YES];
        
        //remove from 'shown'
        [alerts removeShown:alert];
        
        //tell user rules changed
        [alerts.xpcUserClient rulesChanged];
        
        //process (any) related flows
        [self processRelatedFlow:alert];
    }])
    {
        //failed to deliver
        // just allow flow...
        [self resumeFlow:flow withVerdict:[NEFilterNewFlowVerdict allowVerdict]];
    }
    
    //delivered to user
    else
    {
        //save as shown
        // needed so related (same process!) alerts aren't delivered as well
        [alerts addShown:alert];
    }
    
    return;
}


//add an alert to 'related'
// invoked when there is already an alert shown for process
// once user responds to alert, these will then be processed
-(void)addRelatedFlow:(Process*)process flow:(NEFilterSocketFlow*)flow
{
    //dbg msg
    os_log_debug(logHandle, "adding flow to 'related': %{public}@ / %{public}@", process.key, flow);
    
    //sync/save
    @synchronized(self.relatedFlows)
    {
        //first time
        // init array for item (process) alerts
        if(nil == self.relatedFlows[process.key])
        {
            //create array
            self.relatedFlows[process.key] = [NSMutableArray array];
        }
        
        //add
        [self.relatedFlows[process.key] addObject:flow];
    }
    
    return;
}

//process related flows
-(void)processRelatedFlow:(NSDictionary*)alert
{
    //flows
    NSMutableArray* flows = nil;
    
    //flow
    NEFilterSocketFlow* flow = nil;
    
    //dbg msg
    os_log_debug(logHandle, "processing related flow(s) for %{public}@", alert[KEY_KEY]);
    
    //sync
    @synchronized(self.relatedFlows)
    {
        //grab flows
        flows = self.relatedFlows[alert[KEY_KEY]];
        if(0 == flows.count)
        {
            //dbg msg
            os_log_debug(logHandle, "no related flows");
            
            //bail
            goto bail;
        }
        
        //grab first
        flow = flows.firstObject;
        
        //dbg msg
        os_log_debug(logHandle, "processing related flow: %{public}@", flow);
        
        //remove it
        [flows removeObjectAtIndex:0];
        
        //process it
        [self processEvent:flow];
    }
    
bail:

    return;
}

//create process object
-(Process*)createProcess:(NEFilterFlow*)flow
{
    //audit token
    audit_token_t* token = NULL;
    
    //process obj
    Process* process = nil;
    
    //extract (audit) token
    token = (audit_token_t*)flow.sourceAppAuditToken.bytes;
    
    //init process object, via audit token
    process = [[Process alloc] init:token];
    if(nil == process)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to create process for %d", audit_token_to_pid(*token));
        
        //bail
        goto bail;
    }
    
    //sync to add to cache
    @synchronized(self.cache) {
        
        //add to cache
        [self.cache setObject:process forKey:flow.sourceAppAuditToken];
    }
    
bail:
    
    return process;
}

@end

