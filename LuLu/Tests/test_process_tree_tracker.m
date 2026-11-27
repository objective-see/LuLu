#import "ProcessTreeTracker.h"
#import <EndpointSecurity/EndpointSecurity.h>
#import <bsm/libbsm.h>

@interface ProcessTreeTracker (FixtureEvents)
-(void)handleMessage:(const es_message_t*)message client:(es_client_t*)client;
@end

static es_handler_block_t handler;
static ProcessTreeTracker* tracker;
static NSData* expectedTarget;
static NSUInteger assertions;
static NSUInteger authResponses;
static es_new_client_result_t createResult = ES_NEW_CLIENT_RESULT_SUCCESS;
static es_return_t subscribeResult = ES_RETURN_SUCCESS;

static void checkAtLine(BOOL condition, int line)
{
    assertions++;
    if(NO == condition) { fprintf(stderr, "FAIL line %d\n", line); abort(); }
}
#define check(condition) checkAtLine((condition), __LINE__)

//Only the transport is simulated. Production mutation and ES dispatch code execute.
es_new_client_result_t es_new_client(es_client_t** client, es_handler_block_t block)
{
    if(ES_NEW_CLIENT_RESULT_SUCCESS != createResult) return createResult;
    *client = (es_client_t*)0x1;
    handler = [block copy];
    return ES_NEW_CLIENT_RESULT_SUCCESS;
}
es_return_t es_subscribe(es_client_t* client, const es_event_type_t* events, uint32_t count)
{
    check(4 == count);
    return subscribeResult;
}
es_return_t es_delete_client(es_client_t* client)
{
    handler = nil;
    return ES_RETURN_SUCCESS;
}
es_respond_result_t es_respond_auth_result(es_client_t* client, const es_message_t* message, es_auth_result_t result, bool cache)
{
    check(ES_AUTH_RESULT_ALLOW == result && false == cache);
    check(nil != [tracker ancestorsForAuditToken:expectedTarget]);
    authResponses++;
    return ES_RESPOND_RESULT_SUCCESS;
}

static NSData* token(pid_t pid, uint32_t version, uid_t uid)
{
    audit_token_t audit = {0};
    audit.val[1] = uid;
    audit.val[5] = pid;
    audit.val[7] = version;
    return [NSData dataWithBytes:&audit length:sizeof(audit)];
}
static NSDictionary* snapshot(pid_t pid, uint32_t version, NSString* path)
{
    return @{@"path":path, @"auditToken":token(pid, version, 501), @"signatureValid":@YES,
        @"signingIdentifier":@"com.test.root", @"teamIdentifier":@"TESTTEAM",
        @"parentAuditToken":token(0, 0, 0)};
}
static es_process_t process(NSData* audit, es_file_t* file)
{
    es_process_t result = {0};
    memcpy(&result.audit_token, audit.bytes, sizeof(audit_token_t));
    result.executable = file;
    result.codesigning_flags = 1;
    return result;
}

int main(void)
{
    @autoreleasepool
    {
        tracker = [[ProcessTreeTracker alloc] init];
        check([tracker start]);
        NSDictionary* root = snapshot(900, 1, @"/tmp");
        NSDictionary* child = snapshot(901, 2, @"/usr/bin/child");
        NSDictionary* grandchild = snapshot(902, 3, @"/usr/bin/grandchild");
        [tracker recordForkParent:root child:child];
        [tracker recordForkParent:child child:grandchild];
        [tracker recordExitAuditToken:root[@"auditToken"]];
        check(3 == [[tracker ancestorsForAuditToken:grandchild[@"auditToken"]] count]);
        check([[[tracker ancestorsForAuditToken:grandchild[@"auditToken"]] firstObject][@"path"] isEqual:[@"/tmp" stringByResolvingSymlinksInPath]]);
        check([tracker lineageCompleteForAuditToken:grandchild[@"auditToken"]]);
        [tracker recordSnapshot:snapshot(900, 4, @"/usr/bin/unrelated")];
        check(1 == [[tracker ancestorsForAuditToken:token(900, 4, 501)] count]);
        check(2 == [[tracker ancestorsForAuditToken:token(901, 2, 0)] count]);
        check(nil == [tracker ancestorsForAuditToken:token(901, 99, 501)]);
        check(nil == [tracker ancestorsForAuditToken:[NSData data]]);
        NSDictionary* replacement = snapshot(901, 5, @"/usr/bin/replacement");
        [tracker recordExecSource:child target:replacement];
        [tracker recordExecSource:child target:replacement];
        check(3 == [[tracker ancestorsForAuditToken:replacement[@"auditToken"]] count]);
        check([[[tracker ancestorsForAuditToken:replacement[@"auditToken"]] firstObject][@"teamIdentifier"] isEqual:@"TESTTEAM"]);

        NSMutableDictionary* mutable = [snapshot(903, 6, @"/usr/bin/original") mutableCopy];
        [tracker recordSnapshot:mutable];
        mutable[@"path"] = @"/usr/bin/changed";
        check([[[tracker ancestorsForAuditToken:mutable[@"auditToken"]] lastObject][@"path"] isEqual:@"/usr/bin/original"]);

        NSDictionary* signedRoot = snapshot(904, 7, @"/usr/bin/selected");
        [tracker recordSnapshot:signedRoot];
        NSMutableDictionary* invalidatedRoot = [signedRoot mutableCopy];
        invalidatedRoot[@"signatureValid"] = @NO;
        invalidatedRoot[@"signingIdentifier"] = @"changed.identifier";
        invalidatedRoot[@"path"] = @"/usr/bin/different";
        invalidatedRoot[@"auditToken"] = token(904, 7, 0);
        [tracker recordSnapshot:invalidatedRoot];
        NSDictionary* selectedChild = snapshot(905, 8, @"/usr/bin/child");
        [tracker recordForkParent:invalidatedRoot child:selectedChild];
        NSDictionary* pinned = [[tracker ancestorsForAuditToken:selectedChild[@"auditToken"]] firstObject];
        check([pinned[@"signatureValid"] boolValue]);
        check([pinned[@"signingIdentifier"] isEqual:@"com.test.root"]);
        check([pinned[@"path"] isEqual:@"/usr/bin/selected"]);
        [tracker recordSnapshot:snapshot(904, 9, @"/usr/bin/new-generation")];
        check(1 == [[tracker ancestorsForAuditToken:token(904, 9, 0)] count]);

        [tracker stop];
        check([tracker start]);
        es_file_t rootFile = {.path={.length=14, .data="/usr/bin/root"}};
        rootFile.path.length = strlen(rootFile.path.data);
        es_file_t helperFile = {.path={.length=15, .data="/usr/bin/helper"}};
        helperFile.path.length = strlen(helperFile.path.data);
        es_process_t source = process(token(910, 1, 501), &rootFile);
        es_process_t target = process(token(910, 2, 501), &helperFile);
        es_message_t event = {0};
        event.version = 4;
        event.process = &source;
        event.event_type = ES_EVENT_TYPE_AUTH_EXEC;
        event.action_type = ES_ACTION_TYPE_AUTH;
        event.event.exec.target = &target;
        expectedTarget = token(910, 2, 501);
        handler((es_client_t*)0x1, &event);
        check(1 == authResponses);
        check(2 == [[tracker ancestorsForAuditToken:expectedTarget] count]);
        check([[[tracker ancestorsForAuditToken:expectedTarget] lastObject][@"codeSignatureValid"] boolValue]);
        event.event_type = ES_EVENT_TYPE_NOTIFY_EXEC;
        event.action_type = ES_ACTION_TYPE_NOTIFY;
        handler((es_client_t*)0x1, &event);
        check(2 == [[tracker ancestorsForAuditToken:expectedTarget] count]);
        check(nil == [tracker ancestorsForAuditToken:token(910, 1, 501)]);

        es_process_t forkChild = process(token(911, 3, 501), &helperFile);
        event.process = &target;
        event.event_type = ES_EVENT_TYPE_NOTIFY_FORK;
        event.event.fork.child = &forkChild;
        handler((es_client_t*)0x1, &event);
        event.seq_num = 2;
        handler((es_client_t*)0x1, &event);
        check(NO == tracker.healthy);
        check([tracker.failureReason containsString:@"dropped"]);
        event.seq_num = 3;
        handler((es_client_t*)0x1, &event);
        check(NO == tracker.healthy);

        [tracker stop];
        check([tracker start]);
        source = process(token(920, 1, 501), &rootFile);
        target = process(token(920, 2, 501), &helperFile);
        event = (es_message_t){0};
        event.version = 4;
        event.process = &source;
        event.event_type = ES_EVENT_TYPE_AUTH_EXEC;
        event.action_type = ES_ACTION_TYPE_AUTH;
        event.event.exec.target = &target;
        expectedTarget = token(920, 2, 501);
        handler((es_client_t*)0x1, &event);

        //Simulated retry: an unconfirmed future identity must not pin an earlier executable.
        target = process(token(920, 2, 501), &rootFile);
        target.signing_id = (es_string_token_t){.length=15, .data="com.test.second"};
        event.seq_num = 1;
        handler((es_client_t*)0x1, &event);
        NSArray* retried = [tracker ancestorsForAuditToken:expectedTarget];
        check([retried.lastObject[@"path"] isEqual:@"/usr/bin/root"]);
        check([retried.lastObject[@"signingIdentifier"] isEqual:@"com.test.second"]);
        check([retried.firstObject[@"identity"] isEqual:@"920:1"] && 2 == retried.count);

        target = process(token(920, 3, 501), &helperFile);
        event.seq_num = 2;
        expectedTarget = token(920, 3, 501);
        handler((es_client_t*)0x1, &event);
        check(nil == [tracker ancestorsForAuditToken:token(920, 2, 501)]);
        check(nil != [tracker ancestorsForAuditToken:expectedTarget]);
        event.event_type = ES_EVENT_TYPE_NOTIFY_EXIT;
        event.action_type = ES_ACTION_TYPE_NOTIFY;
        event.seq_num = 0;
        handler((es_client_t*)0x1, &event);
        check(nil == [tracker ancestorsForAuditToken:expectedTarget]);
        check(tracker.healthy);

        es_handler_block_t oldHandler = handler;
        [tracker stop];
        check(NO == tracker.available && NO == tracker.healthy);
        check(nil == [tracker ancestorsForAuditToken:expectedTarget]);
        NSUInteger responseCount = authResponses;
        event.event_type = ES_EVENT_TYPE_AUTH_EXEC;
        event.action_type = ES_ACTION_TYPE_AUTH;
        oldHandler((es_client_t*)0x1, &event);
        check(responseCount == authResponses);

        createResult = ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED;
        check(NO == [tracker start]);
        check(NO == tracker.available && NO == tracker.healthy);
        check([tracker.failureReason containsString:@"creation"]);
        createResult = ES_NEW_CLIENT_RESULT_SUCCESS;
        subscribeResult = ES_RETURN_ERROR;
        check(NO == [tracker start]);
        check(NO == tracker.available && NO == tracker.healthy);
        check([tracker.failureReason containsString:@"subscription"]);
        subscribeResult = ES_RETURN_SUCCESS;

        [tracker stop];
        check([tracker start]);
        NSDictionary* previous = snapshot(1000, 1, @"/usr/bin/root");
        [tracker recordSnapshot:previous];
        for(pid_t pid = 1001; pid < 1735; pid++)
        {
            NSDictionary* next = snapshot(pid, 1, @"/usr/bin/child");
            [tracker recordForkParent:previous child:next];
            previous = next;
        }
        check(NO == tracker.healthy);
        check([tracker.failureReason containsString:@"capacity"]);
        check(nil != [tracker ancestorsForAuditToken:token(1000, 1, 501)]);
        [tracker stop];
        check(nil != [tracker ancestorsForAuditToken:token(1000, 1, 501)]);
        createResult = ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED;
        check(NO == [tracker start]);
        check(NO == tracker.available && NO == tracker.healthy);
        check(nil != [tracker ancestorsForAuditToken:token(1000, 1, 501)]);
        tracker = nil;
        printf("%lu tracker assertions passed. ES transport simulated; no system interception tested.\n", (unsigned long)assertions);
    }
    return 0;
}
