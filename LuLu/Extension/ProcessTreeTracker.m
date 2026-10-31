//
//  ProcessTreeTracker.m
//  LuLu
//
//  Copyright (c) Objective-See. All rights reserved.
//

#import "ProcessTreeTracker.h"

#import <EndpointSecurity/EndpointSecurity.h>
#import <bsm/libbsm.h>

//Kernel code-signing flags (the SDK does not export kern/cs_blobs.h).
static const uint32_t PROCESS_CS_VALID = 0x00000001;
static const uint32_t PROCESS_CS_ADHOC = 0x00000002;

//Never discard live lineage to make room: a full table invalidates strict coverage.
static const NSUInteger MAX_TRACKED_PROCESSES = 32768;
static const NSUInteger MAX_LINEAGE_SNAPSHOTS = 262144;

@interface ProcessTreeTracker ()
{
    es_client_t* client;
    NSLock* lifecycleLock;
    NSMutableDictionary<NSString*, NSDictionary*>* processes;
    NSMutableDictionary<NSNumber*, NSNumber*>* sequenceNumbers;
    NSMutableDictionary<NSString*, NSString*>* pendingExecTargets;
    NSUInteger snapshotCount;
    BOOL available;
    BOOL healthy;
    BOOL stopping;
    NSString* failureReason;
}

-(void)handleMessage:(const es_message_t*)message client:(es_client_t*)eventClient;
-(void)degrade:(NSString*)reason;
-(nullable NSDictionary*)normalizedSnapshot:(NSDictionary*)snapshot;
-(NSDictionary*)entryForSnapshot:(NSDictionary*)snapshot;
-(BOOL)storeEntry:(NSDictionary*)entry identity:(NSString*)identity;
-(void)recordExecSource:(NSDictionary*)source target:(NSDictionary*)target retireSource:(BOOL)retireSource;
-(void)clearPendingExecForIdentity:(NSString*)identity keepingTarget:(nullable NSString*)targetIdentity;

@end

@implementation ProcessTreeTracker

-(id)init
{
    self = [super init];
    if(nil != self)
    {
        lifecycleLock = [[NSLock alloc] init];
        processes = [NSMutableDictionary dictionary];
        sequenceNumbers = [NSMutableDictionary dictionary];
        pendingExecTargets = [NSMutableDictionary dictionary];
        failureReason = @"Process lineage monitoring has not started.";
    }
    return self;
}

-(void)dealloc
{
    //The final reference can be released on the ES callback itself.
    //Delete off that callback without capturing this deallocating object.
    es_client_t* oldClient = client;
    if(NULL != oldClient)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ es_delete_client(oldClient); });
}

-(BOOL)available
{
    @synchronized(self) { return available; }
}

-(BOOL)healthy
{
    @synchronized(self) { return healthy; }
}

-(NSString*)failureReason
{
    @synchronized(self) { return [failureReason copy]; }
}

-(void)degrade:(NSString*)reason
{
    @synchronized(self)
    {
        healthy = NO;
        if(nil == failureReason) failureReason = [reason copy];
    }
}

-(BOOL)start
{
    es_client_t* newClient = NULL;
    __weak ProcessTreeTracker* weakSelf = self;
    [lifecycleLock lock];

    @synchronized(self)
    {
        if(NULL != client)
        {
            BOOL ready = available && healthy;
            [lifecycleLock unlock];
            return ready;
        }
        [sequenceNumbers removeAllObjects];
        [pendingExecTargets removeAllObjects];
        available = NO;
        healthy = YES;
        stopping = NO;
        failureReason = nil;
    }

    es_new_client_result_t result = es_new_client(&newClient, ^(es_client_t* eventClient, const es_message_t* message)
    {
        ProcessTreeTracker* tracker = weakSelf;
        if(nil != tracker) [tracker handleMessage:message client:eventClient];
    });

    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        [self degrade:[NSString stringWithFormat:@"Endpoint Security client creation failed (%u).", result]];
        [lifecycleLock unlock];
        return NO;
    }

    //AUTH_EXEC establishes the new audit identity before its executable resumes.
    //Always allow, without caching; network rules remain the enforcement point.
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_FORK, ES_EVENT_TYPE_AUTH_EXEC,
                               ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT};
    if(ES_RETURN_SUCCESS != es_subscribe(newClient, events, sizeof(events)/sizeof(events[0])))
    {
        [self degrade:@"Endpoint Security process-event subscription failed."];
        @synchronized(self) { stopping = YES; }
        es_delete_client(newClient);
        [lifecycleLock unlock];
        return NO;
    }

    @synchronized(self)
    {
        client = newClient;
        available = YES;
    }
    BOOL ready = self.healthy;
    [lifecycleLock unlock];
    return ready;
}

-(void)stop
{
    es_client_t* oldClient = NULL;
    [lifecycleLock lock];
    @synchronized(self)
    {
        oldClient = client;
        client = NULL;
        available = NO;
        healthy = NO;
        stopping = YES;
        if(nil == failureReason) failureReason = @"Process lineage monitoring is stopped.";
    }

    //Do not hold the state lock while deletion drains the ES handler.
    if(NULL != oldClient) es_delete_client(oldClient);
    @synchronized(self)
    {
        //Keep known owners available to fail closed while monitoring is stopped.
        //An in-process restart retains this history; deallocation releases it normally.
        [sequenceNumbers removeAllObjects];
        [pendingExecTargets removeAllObjects];
    }
    [lifecycleLock unlock];
}

static NSString* identityForToken(NSData* data)
{
    audit_token_t token = {0};
    if(NO == [data isKindOfClass:NSData.class] || sizeof(token) != data.length) return nil;
    memcpy(&token, data.bytes, sizeof(token));
    if(audit_token_to_pid(token) <= 0) return nil;
    //Credentials can change while the kernel execution identity remains the same.
    return [NSString stringWithFormat:@"%d:%u", audit_token_to_pid(token), audit_token_to_pidversion(token)];
}

+(NSString*)identityForAuditToken:(NSData*)auditToken
{
    return identityForToken(auditToken);
}

static NSString* stringForToken(es_string_token_t token)
{
    if(NULL == token.data || 0 == token.length) return nil;
    return [[NSString alloc] initWithBytes:token.data length:token.length encoding:NSUTF8StringEncoding];
}

static NSDictionary* snapshotForProcess(const es_process_t* process, uint32_t version)
{
    if(NULL == process || NULL == process->executable || process->executable->path_truncated) return nil;
    NSString* path = stringForToken(process->executable->path);
    if(NO == path.isAbsolutePath) return nil;

    NSMutableDictionary* snapshot = [NSMutableDictionary dictionary];
    snapshot[@"path"] = [path stringByStandardizingPath];
    snapshot[@"auditToken"] = [NSData dataWithBytes:&process->audit_token length:sizeof(audit_token_t)];
    snapshot[@"codeSignatureValid"] = @(0 != (process->codesigning_flags & PROCESS_CS_VALID));
    snapshot[@"signatureValid"] = @((0 != (process->codesigning_flags & PROCESS_CS_VALID)) &&
                                      (0 == (process->codesigning_flags & PROCESS_CS_ADHOC)));
    snapshot[@"cdhash"] = [NSData dataWithBytes:process->cdhash length:sizeof(process->cdhash)];
    NSString* signingIdentifier = stringForToken(process->signing_id);
    NSString* teamIdentifier = stringForToken(process->team_id);
    if(nil != signingIdentifier) snapshot[@"signingIdentifier"] = signingIdentifier;
    if(nil != teamIdentifier) snapshot[@"teamIdentifier"] = teamIdentifier;
    if(version >= 4)
        snapshot[@"parentAuditToken"] = [NSData dataWithBytes:&process->parent_audit_token length:sizeof(audit_token_t)];
    return [snapshot copy];
}

-(NSDictionary*)normalizedSnapshot:(NSDictionary*)snapshot
{
    NSString* identity = identityForToken(snapshot[@"auditToken"]);
    NSString* path = snapshot[@"path"];
    if(nil == identity || NO == [path isKindOfClass:NSString.class] || NO == path.isAbsolutePath) return nil;

    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    result[@"identity"] = identity;
    result[@"auditToken"] = [snapshot[@"auditToken"] copy];
    result[@"path"] = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
    for(NSString* key in @[@"signingIdentifier", @"teamIdentifier"])
        if([snapshot[key] isKindOfClass:NSString.class]) result[key] = [snapshot[key] copy];
    if([snapshot[@"signatureValid"] isKindOfClass:NSNumber.class])
        result[@"signatureValid"] = @([snapshot[@"signatureValid"] boolValue]);
    if([snapshot[@"codeSignatureValid"] isKindOfClass:NSNumber.class])
        result[@"codeSignatureValid"] = @([snapshot[@"codeSignatureValid"] boolValue]);
    if([snapshot[@"cdhash"] isKindOfClass:NSData.class]) result[@"cdhash"] = [snapshot[@"cdhash"] copy];
    if([snapshot[@"parentAuditToken"] isKindOfClass:NSData.class] &&
       sizeof(audit_token_t) == [snapshot[@"parentAuditToken"] length])
        result[@"parentAuditToken"] = [snapshot[@"parentAuditToken"] copy];
    return [result copy];
}

-(NSDictionary*)entryForSnapshot:(NSDictionary*)snapshot
{
    NSDictionary* existing = processes[snapshot[@"identity"]];
    if(nil != existing)
    {
        //The first kernel snapshot pins this execution. Later credential, parent,
        //or signing-flag changes must not remove an already observed strict owner.
        return existing;
    }

    NSString* parentIdentity = identityForToken(snapshot[@"parentAuditToken"]);
    NSDictionary* parent = nil == parentIdentity ? nil : processes[parentIdentity];
    NSArray* ancestors = @[];
    BOOL complete = NO;
    if(nil != parent && NO == [parentIdentity isEqual:snapshot[@"identity"]])
    {
        ancestors = [parent[@"ancestors"] arrayByAddingObject:parent[@"snapshot"]];
        complete = [parent[@"complete"] boolValue];
    }
    //Only a kernel snapshot explicitly identifying no parent can terminate the chain.
    else if(nil != snapshot[@"parentAuditToken"] && nil == parentIdentity)
        complete = YES;

    return @{@"snapshot":snapshot, @"ancestors":ancestors, @"complete":@(complete)};
}

-(BOOL)storeEntry:(NSDictionary*)entry identity:(NSString*)identity
{
    NSDictionary* existing = processes[identity];
    NSUInteger oldCount = nil == existing ? 0 : [existing[@"ancestors"] count] + 1;
    NSUInteger newCount = [entry[@"ancestors"] count] + 1;
    if((nil == existing && processes.count >= MAX_TRACKED_PROCESSES) ||
       snapshotCount - oldCount + newCount > MAX_LINEAGE_SNAPSHOTS)
    {
        [self degrade:@"Process lineage storage capacity was exceeded."];
        return NO;
    }
    processes[identity] = entry;
    snapshotCount = snapshotCount - oldCount + newCount;
    return YES;
}

-(void)recordSnapshot:(NSDictionary*)snapshot
{
    @synchronized(self)
    {
        NSDictionary* normalized = [self normalizedSnapshot:snapshot];
        if(nil == normalized)
        {
            [self degrade:@"A process event did not contain a usable audit identity and executable path."];
            return;
        }
        [self storeEntry:[self entryForSnapshot:normalized] identity:normalized[@"identity"]];
    }
}

-(void)recordForkParent:(NSDictionary*)parent child:(NSDictionary*)child
{
    @synchronized(self)
    {
        NSDictionary* parentSnapshot = [self normalizedSnapshot:parent];
        NSDictionary* childSnapshot = [self normalizedSnapshot:child];
        if(nil == parentSnapshot || nil == childSnapshot ||
           [parentSnapshot[@"identity"] isEqual:childSnapshot[@"identity"]])
        {
            [self degrade:@"A fork event did not contain distinct usable parent and child identities."];
            return;
        }
        NSDictionary* parentEntry = [self entryForSnapshot:parentSnapshot];
        if(NO == [self storeEntry:parentEntry identity:parentSnapshot[@"identity"]]) return;
        NSArray* ancestors = [parentEntry[@"ancestors"] arrayByAddingObject:parentEntry[@"snapshot"]];
        NSDictionary* existingChild = processes[childSnapshot[@"identity"]];
        NSDictionary* childEntry = @{@"snapshot":existingChild[@"snapshot"] ?: childSnapshot, @"ancestors":ancestors,
                                     @"complete":parentEntry[@"complete"]};
        [self storeEntry:childEntry identity:childSnapshot[@"identity"]];
    }
}

-(void)recordExecSource:(NSDictionary*)source target:(NSDictionary*)target
{
    [self recordExecSource:source target:target retireSource:YES];
}

-(void)recordExecSource:(NSDictionary*)source target:(NSDictionary*)target retireSource:(BOOL)retireSource
{
    @synchronized(self)
    {
        NSDictionary* sourceSnapshot = [self normalizedSnapshot:source];
        NSDictionary* targetSnapshot = [self normalizedSnapshot:target];
        if(nil == sourceSnapshot || nil == targetSnapshot)
        {
            [self degrade:@"An exec event did not contain usable source and target identities."];
            return;
        }

        NSDictionary* targetEntry = processes[targetSnapshot[@"identity"]];
        //AUTH and NOTIFY describe the same transition. Confirmation must not rebuild it.
        if(nil != targetEntry &&
           [sourceSnapshot[@"identity"] isEqual:targetSnapshot[@"identity"]] == NO)
        {
            NSArray* ancestors = targetEntry[@"ancestors"];
            if([[ancestors lastObject][@"identity"] isEqual:sourceSnapshot[@"identity"]])
            {
                [self storeEntry:@{@"snapshot":targetEntry[@"snapshot"], @"ancestors":ancestors,
                                  @"complete":targetEntry[@"complete"]} identity:targetSnapshot[@"identity"]];
                if(YES == retireSource) [self recordExitAuditToken:sourceSnapshot[@"auditToken"]];
                return;
            }
        }

        NSDictionary* sourceEntry = [self entryForSnapshot:sourceSnapshot];
        NSArray* ancestors = sourceEntry[@"ancestors"];
        if(NO == [sourceSnapshot[@"identity"] isEqual:targetSnapshot[@"identity"]] ||
           NO == [sourceSnapshot[@"path"] isEqual:targetSnapshot[@"path"]])
            ancestors = [ancestors arrayByAddingObject:sourceEntry[@"snapshot"]];
        NSDictionary* entry = @{@"snapshot":targetEntry[@"snapshot"] ?: targetSnapshot, @"ancestors":ancestors,
                                @"complete":sourceEntry[@"complete"]};
        if(NO == [self storeEntry:entry identity:targetSnapshot[@"identity"]]) return;
        if(YES == retireSource && NO == [sourceSnapshot[@"identity"] isEqual:targetSnapshot[@"identity"]])
            [self recordExitAuditToken:sourceSnapshot[@"auditToken"]];
    }
}

-(void)recordExitAuditToken:(NSData*)auditToken
{
    @synchronized(self)
    {
        NSString* identity = identityForToken(auditToken);
        if(nil == identity)
        {
            [self degrade:@"An exit event did not contain a usable audit identity."];
            return;
        }
        [self clearPendingExecForIdentity:identity keepingTarget:nil];
        NSDictionary* entry = processes[identity];
        if(nil != entry)
        {
            snapshotCount -= [entry[@"ancestors"] count] + 1;
            [processes removeObjectForKey:identity];
        }
    }
}

-(void)clearPendingExecForIdentity:(NSString*)identity keepingTarget:(NSString*)targetIdentity
{
    NSString* pendingTarget = pendingExecTargets[identity];
    if(nil == pendingTarget) return;
    [pendingExecTargets removeObjectForKey:identity];
    if(NO == [pendingTarget isEqual:targetIdentity])
    {
        NSDictionary* entry = processes[pendingTarget];
        if(nil != entry)
        {
            snapshotCount -= [entry[@"ancestors"] count] + 1;
            [processes removeObjectForKey:pendingTarget];
        }
    }
}

-(NSArray<NSDictionary*>*)ancestorsForAuditToken:(NSData*)auditToken
{
    @synchronized(self)
    {
        NSString* identity = identityForToken(auditToken);
        if(nil == identity) return nil;
        NSDictionary* entry = processes[identity];
        if(nil == entry) return nil;
        return [entry[@"ancestors"] arrayByAddingObject:entry[@"snapshot"]];
    }
}

-(BOOL)lineageCompleteForAuditToken:(NSData*)auditToken
{
    @synchronized(self)
    {
        NSString* identity = identityForToken(auditToken);
        if(nil == identity) return NO;
        return [processes[identity][@"complete"] boolValue];
    }
}

-(void)handleMessage:(const es_message_t*)message client:(es_client_t*)eventClient
{
    @autoreleasepool
    {
        @synchronized(self)
        {
            //Once shutdown owns the client, no callback may call an ES API on it.
            if(YES == stopping) return;
            if(message->version < 2) [self degrade:@"Endpoint Security messages do not provide event sequence numbers."];
            else
            {
                NSNumber* event = @(message->event_type);
                NSNumber* previous = sequenceNumbers[event];
                if((nil != previous && message->seq_num != previous.unsignedLongLongValue + 1) ||
                   (nil == previous && 0 != message->seq_num))
                    [self degrade:@"Endpoint Security dropped process events; lineage is incomplete."];
                sequenceNumbers[event] = @(message->seq_num);
            }

            NSDictionary* source = snapshotForProcess(message->process, message->version);
            switch(message->event_type)
            {
                case ES_EVENT_TYPE_NOTIFY_FORK:
                    [self recordForkParent:source child:snapshotForProcess(message->event.fork.child, message->version)];
                    break;
                case ES_EVENT_TYPE_AUTH_EXEC:
                {
                    NSString* sourceIdentity = identityForToken(source[@"auditToken"]);
                    NSDictionary* target = snapshotForProcess(message->event.exec.target, message->version);
                    NSString* targetIdentity = identityForToken(target[@"auditToken"]);
                    //A retry from the same source replaces its unconfirmed attempt, even if the target identity repeats.
                    if(nil != sourceIdentity) [self clearPendingExecForIdentity:sourceIdentity keepingTarget:nil];
                    [self recordSnapshot:source];
                    [self recordExecSource:source target:target retireSource:NO];
                    if(nil != sourceIdentity && nil != targetIdentity && nil != processes[sourceIdentity] &&
                       nil != processes[targetIdentity] && NO == [sourceIdentity isEqual:targetIdentity])
                        pendingExecTargets[sourceIdentity] = targetIdentity;
                    break;
                }
                case ES_EVENT_TYPE_NOTIFY_EXEC:
                {
                    NSDictionary* target = snapshotForProcess(message->event.exec.target, message->version);
                    NSString* sourceIdentity = identityForToken(source[@"auditToken"]);
                    if(nil != sourceIdentity)
                        [self clearPendingExecForIdentity:sourceIdentity keepingTarget:identityForToken(target[@"auditToken"])];
                    [self recordExecSource:source target:target];
                    break;
                }
                case ES_EVENT_TYPE_NOTIFY_EXIT:
                    [self recordExitAuditToken:[NSData dataWithBytes:&message->process->audit_token length:sizeof(audit_token_t)]];
                    break;
                default:
                    break;
            }
            if(ES_ACTION_TYPE_AUTH == message->action_type &&
               ES_RESPOND_RESULT_SUCCESS != es_respond_auth_result(eventClient, message, ES_AUTH_RESULT_ALLOW, false))
                [self degrade:@"Endpoint Security could not acknowledge an execution event."];
        }
    }
}

@end
