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
        
        //log msg
        os_log_debug(logHandle, "'applySettings' completed");
        
        //error?
        if(nil != error) os_log_error(logHandle, "ERROR: failed to apply filter settings: %@", error.localizedDescription);
        
        //call completion handler
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
    
    //flow uuid
    __block NSString *flowUUID = flow.identifier.UUIDString;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //log msg
    os_log_debug(logHandle, "FLOW_ID=%{public}@ method '%s' invoked", flowUUID, __PRETTY_FUNCTION__);
    
    //init verdict to allow
    verdict = [NEFilterNewFlowVerdict allowVerdict];
    
    //no prefs (yet) or disabled
    // just allow the flow (don't block)
    if( (0 == preferences.preferences.count) ||
        (YES == [preferences.preferences[PREF_IS_DISABLED] boolValue]) )
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ no prefs (yet) || disabled, so allowing flow", flowUUID);
        
        //bail
        goto bail;
    }
    
    //typecast
    socketFlow = (NEFilterSocketFlow*)flow;

    //log msg
    // os_log_info(logHandle, "flow: %{public}@", flow);
    
    //only once
    // load init block list
    // ...early it may fail for remote lists, as network isn't up
    dispatch_once(&onceToken, ^{
        
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ init'ing block list", flowUUID);
        
        //alloc/init/load block list
        blockList = [[BlockList alloc] init];
        
    });

    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)socketFlow.remoteEndpoint;
    
    //log msg
    os_log_debug(logHandle, "FLOW_ID=%{public}@ remote endpoint: %{public}@ / url: %{public}@", flowUUID, remoteEndpoint, flow.URL);
    
    //ignore non-outbound traffic
    // even though we init'd `NETrafficDirectionOutbound`, sometimes get inbound traffic :|
    if(NETrafficDirectionOutbound != socketFlow.direction)
    {
        //log msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ ignoring non-outbound traffic (direction: %ld)", flowUUID, (long)socketFlow.direction);
           
        //bail
        goto bail;
    }
    
    //process flow
    // determine verdict
    // deliver alert (if necessary)
    verdict = [self processEvent:flow];
    
    //log msg
    os_log_debug(logHandle, "FLOW_ID=%{public}@ verdict: %{public}@", flowUUID, verdict);
    
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
    //@autoreleasepool
    //{
    
    //process obj
    Process* process = nil;
    
    //flag
    BOOL csChange = NO;
    
    //matching rule obj
    Rule* matchingRule = nil;
    
    //flow uuid
    NSString *flowUUID = flow.identifier.UUIDString;
    
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
        os_log_debug(logHandle, "FLOW_ID=%{public}@ no process found in cache, will create", flowUUID);
        
        //create
        // also adds to cache
        process = [self createProcess:flow];
    }

    //dbg msg
    else os_log_debug(logHandle, "FLOW_ID=%{public}@ found process object in cache: %{public}@ (pid: %d)", flowUUID, process.path, process.pid);
    
    //sanity check
    // no process? just allow...
    if(nil == process)
    {
        //err msg
        os_log_error(logHandle, "FLOW_ID=%{public}@ ERROR: failed to create process for flow, will allow", flowUUID);
        
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
        os_log_debug(logHandle, "FLOW_ID=%{public}@ current console user '%{public}@', is different than '%{public}@', so allowing flow: %{public}@", flowUUID, consoleUser, alerts.consoleUser, ((NEFilterSocketFlow*)flow).remoteEndpoint);
        
        //all set
        goto bail;
    }
    
    //CHECK:
    // client in (full) block mode? ...block!
    if(YES == [preferences.preferences[PREF_BLOCK_MODE] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ client in block mode, so disallowing %d/%{public}@", flowUUID, process.pid, process.binary.name);
        
        //deny
        verdict = [NEFilterNewFlowVerdict dropVerdict];
        
        //all set
        goto bail;
    }
        
    //CHECK:
    // client using (global) block list
    if( (YES == [preferences.preferences[PREF_USE_BLOCK_LIST] boolValue]) &&
        (0 != [preferences.preferences[PREF_BLOCK_LIST] length]) )
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ client is using block list '%{public}@' (%lu items) ...will check for match", flowUUID, preferences.preferences[PREF_BLOCK_LIST], (unsigned long)blockList.items.count);
        
        //match in block list?
        if(YES == [blockList isMatch:(NEFilterSocketFlow*)flow])
        {
            //dbg msg
            os_log_debug(logHandle, "FLOW_ID=%{public}@ flow matches item in block list, so denying", flowUUID);
            
            //deny
            verdict = [NEFilterNewFlowVerdict dropVerdict];
            
            //all set
            goto bail;
        }
        //dbg msg
        else os_log_debug(logHandle, "FLOW_ID=%{public}@ remote endpoint/URL not on block list...", flowUUID);
    }
        
    //CHECK:
    // check for existing rule
    
    //existing rule for process?
    matchingRule = [rules find:process flow:(NEFilterSocketFlow*)flow csChange:&csChange];
    
    if(nil != matchingRule)
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ RULE_ID=%{public}@ found matching rule for %d/%{public}@: %{public}@", flowUUID, matchingRule.uuid, process.pid, process.binary.name, matchingRule);
        
        //deny?
        // otherwise will default to allow
        if(RULE_STATE_BLOCK == matchingRule.action.intValue)
        {
            //dbg msg
            os_log_debug(logHandle, "FLOW_ID=%{public}@ RULE_ID=%{public}@ setting verdict to: BLOCK", flowUUID, matchingRule.uuid);
            
            //deny
            verdict = [NEFilterNewFlowVerdict dropVerdict];
        }
        //allow (msg)
        else os_log_debug(logHandle, "FLOW_ID=%{public}@ RULE_ID=%{public}@ rule says: ALLOW", flowUUID, matchingRule.uuid);
    
        //all set
        goto bail;
    }

    /* NO MATCHING RULE FOUND */
    
    //cs change?
    // update item's rules with new code signing info
    // note: user will be informed about this, if/when alert is delivered
    if(YES == csChange)
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ found rule set for %d/%{public}@: %{public}@, but code signing info has changed", flowUUID, process.pid, process.binary.name, matchingRule);
        
        //update cs info
        [rules updateCSInfo:process];
    }
    //no matching rule found?
    else
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ no (saved) rule found for %d/%{public}@", flowUUID, process.pid, process.binary.name);
    }

    //no client?

    //CHECK:
    // client in passive mode? ...allow
    if(YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "FLOW_ID=%{public}@ client in passive mode, so allowing %d/%{public}@", flowUUID, process.pid, process.binary.name);
        
        //all set
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "client not in passive mode");
    
    //CHECK:
    // there a related alert shown (i.e. for same process)
    // save this flow, as only want to process once user responds to first alert
    if(YES == [alerts isRelated:process])
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ an alert is shown for process %d/%{public}@, so holding off delivering for now...", flowUUID, process.pid, process.binary.name);
        
        //add related flow
        [self addRelatedFlow:process.key flow:(NEFilterSocketFlow*)flow];
        
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
    
    //if it's an apple process and that preference is set; allow
    // unless the binary is something like 'curl' which malware could abuse (then, still alert)
    if(YES == [preferences.preferences[PREF_ALLOW_APPLE] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "'Allow Apple' preference is set, will check if is an Apple binary");
        
        //signed by Apple?
        if(Apple == [process.csInfo[KEY_CS_SIGNER] intValue])
        {
            //dbg msg
            os_log_debug(logHandle, "is an Apple binary...");
            
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
                if(nil != process.csInfo)
                {
                    //add
                    info[KEY_CS_INFO] = process.csInfo;
                }
                
                //add key
                info[KEY_KEY] = process.key;
                
                Rule *newRule = [[Rule alloc] init:info];
                
                //add/save
                if(YES != [rules add:newRule save:YES])
                {
                    //err msg
                    os_log_error(logHandle, "FLOW_ID=%{public}@ RULE_ID=%{public}@ ERROR: failed to add rule", flowUUID, newRule.uuid);
                    
                    //bail
                    goto bail;
                }
                
                //tell user rules changed
                [alerts.xpcUserClient rulesChanged];
            }
            
            //graylisted item
            // pause and alert user
            else
            {
                //dbg msg
                os_log_debug(logHandle, "while signed by apple, %d/%{public}@ is gray listed, so will alert", process.pid, process.binary.name);
                
                //pause
                verdict = [NEFilterNewFlowVerdict pauseVerdict];
                
                //create/deliver alert
                [self alert:(NEFilterSocketFlow*)flow process:process csChange:NO];
            }
            
            //all set
            goto bail;
            
        } //signed by apple
    }
    //dbg msg
    else
    {
        //dbg msg
        os_log_debug(logHandle, "'Allow Apple' preference not set, so skipped 'Is Apple' check");
    }
    
    //if it's a prev installed 3rd-party process (w/ no CS change) and that preference is set; allow!
    if( (YES == [preferences.preferences[PREF_ALLOW_INSTALLED] boolValue]) &&
        (Apple != [process.csInfo[KEY_CS_SIGNER] intValue]) &&
        (YES != csChange) )
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
            
            Rule *newRule = [[Rule alloc] init:info];
                
            //create and add rule
            if(YES != [rules add:newRule save:YES])
            {
                //err msg
                os_log_error(logHandle, "FLOW_ID=%{public}@ RULE_ID=%{public}@ ERROR: failed to add rule for %{public}@", flowUUID, newRule.uuid, info[KEY_PATH]);
                 
                //bail
                goto bail;
            }
            
            //tell user rules changed
            [alerts.xpcUserClient rulesChanged];
            
            //all set
            goto bail;
        }
    }
    
    //allow dns traffic pref set?
    // really, just any UDP traffic over port 53
    if(YES == [preferences.preferences[PREF_ALLOW_DNS] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ 'allow DNS traffic' is enabled, so checking port/protocol", flowUUID);
        
        //check proto (UDP) and port (53)
        if( (IPPROTO_UDP == ((NEFilterSocketFlow*)flow).socketProtocol) &&
            (YES == [((NWHostEndpoint*)((NEFilterSocketFlow*)flow).remoteEndpoint).port isEqualToString:@"53"]) )
        {
            //dbg msg
            os_log_debug(logHandle, "%{public}@ protocol is 'UDP' and port is '53', (so likely DNS traffic) ...will allow", flowUUID);
            
            //allow
            verdict = [NEFilterNewFlowVerdict allowVerdict];
            
            //done
            goto bail;
        }
    }
    
    //allow simulator apps?
    if(YES == [preferences.preferences[PREF_ALLOW_SIMULATOR] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "'allow simulator apps' is enabled, so checking process");
        
        //is simulator app?
        if(YES == isSimulatorApp(process.path))
        {
            //dbg msg
            os_log_debug(logHandle, "%{public}@, is an simulator app, so will allow", process.path);
            
            //allow
            verdict = [NEFilterNewFlowVerdict allowVerdict];
            
            //done
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
        
        Rule *newRule = [[Rule alloc] init:info];
        
        //create and add rule
        if(YES != [rules add:newRule save:YES])
        {
            //err msg
            os_log_error(logHandle, "FLOW_ID=%{public}@ RULE_ID=%{public}@ ERROR: failed to add rule for %{public}@", flowUUID, newRule.uuid, info[KEY_PATH]);
             
            //bail
            goto bail;
        }
        
        //tell user rules changed
        [alerts.xpcUserClient rulesChanged];
        
        //all set
        goto bail;
    }
    
    //sending to user, so pause!
    verdict = [NEFilterNewFlowVerdict pauseVerdict];
        
    //create/deliver alert
    // note: handles response + next/any related flow
    [self alert:(NEFilterSocketFlow*)flow process:process csChange:csChange];
    
bail:
    
    
    //;} //pool
    
    return verdict;
}

//1. create and deliver alert
//2. handle response (and process other shown alerts, etc.)
-(void)alert:(NEFilterSocketFlow*)flow process:(Process*)process csChange:(BOOL)csChange
{
    //alert
    NSMutableDictionary* alert = nil;
    
    //create alert
    alert = [alerts create:(NEFilterSocketFlow*)flow process:process];
    
    //add cs change
    alert[KEY_CS_CHANGE] = [NSNumber numberWithBool:csChange];
    
    //dbg msg
    os_log_debug(logHandle, "created alert...");

    //deliver alert
    // and process user response
    if(YES != [alerts deliver:alert reply:^(NSDictionary* alert)
    {
        //flag
        BOOL shouldSave = YES;
        
        //verdict
        NEFilterNewFlowVerdict* verdict = nil;
        
        //log msg
        // note, this msg persists in log
        os_log(logHandle, "(user) response: \"%@\" for %{public}@, that was trying to connect to %{public}@:%{public}@", (RULE_STATE_BLOCK == [alert[KEY_ACTION] unsignedIntValue]) ? @"block" : @"allow", alert[KEY_PATH], alert[KEY_ENDPOINT_ADDR], alert[KEY_ENDPOINT_PORT]);
        
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
        
        //save ...if not temporary
        shouldSave = ![alert[KEY_TEMPORARY] boolValue];
        
        //add/save rules
        [rules add:[[Rule alloc] init:alert] save:shouldSave];
        
        //remove from 'shown'
        [alerts removeShown:alert];
        
        //tell user rules changed
        [alerts.xpcUserClient rulesChanged];
        
        //process (any) related flows
        [self processRelatedFlow:alert[KEY_KEY]];
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
-(void)addRelatedFlow:(NSString*)key flow:(NEFilterSocketFlow*)flow
{
    //dbg msg
    os_log_debug(logHandle, "%{public}@ adding flow to 'related': %{public}@ / %{public}@", flow.identifier.UUIDString, key, flow);
    
    //sync/save
    @synchronized(self.relatedFlows)
    {
        //first time
        // init array for item (process) alerts
        if(nil == self.relatedFlows[key])
        {
            //create array
            self.relatedFlows[key] = [NSMutableArray array];
        }
        
        //add
        [self.relatedFlows[key] addObject:flow];
    }
    
    return;
}

//process related flows
-(void)processRelatedFlow:(NSString*)key
{
    //flows
    NSMutableArray* flows = nil;
    
    //flow
    NEFilterSocketFlow* flow = nil;
    
    //dbg msg
    os_log_debug(logHandle, "processing %lu related flow(s) for %{public}@", (unsigned long)[self.relatedFlows[key] count], key);
    
    //sync
    @synchronized(self.relatedFlows)
    {
        //grab flows for process
        flows = self.relatedFlows[key];
        for(NSInteger i = flows.count - 1; i >= 0; i--)
        {
            //grab flow
            flow = flows[i];
            
            //remove
            [flows removeObjectAtIndex:i];
           
            //process
            // pause means alert is/was shown
            // ...so stop, and wait for user response (which will retrigger processing)
            if([NEFilterNewFlowVerdict pauseVerdict] == [self processEvent:flow])
            {
                //stop
                break;
            }
        }
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
        os_log_error(logHandle, "%{public}@ ERROR: failed to create process for %d", flow.identifier.UUIDString, audit_token_to_pid(*token));
        
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

