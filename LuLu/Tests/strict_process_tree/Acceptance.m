// Execute production policy and provider code with kernel-event fixtures.
#import "Support.h"
#import "Rule.h"
#import "XPCDaemon.h"
#import "ProcessTreeTracker.h"
#import <Security/Security.h>
#import <bsm/libbsm.h>
#import <netinet/in.h>
#import <objc/runtime.h>

@interface FilterDataProvider (AcceptanceEntryPoints)
-(NSInteger)processEvent:(NEFilterFlow*)flow;
-(void)addRelatedFlow:(NSString*)key flow:(NEFilterSocketFlow*)flow;
-(void)processRelatedFlow:(NSString*)key;
@end

@interface FixtureTracker : ProcessTreeTracker
@property BOOL fixtureAvailable;
@property BOOL fixtureHealthy;
@end
@implementation FixtureTracker
-(id)init
{
    self = [super init];
    if(nil != self) { self.fixtureAvailable = YES; self.fixtureHealthy = YES; }
    return self;
}
-(BOOL)available { return self.fixtureAvailable; }
-(BOOL)healthy { return self.fixtureHealthy; }
@end

// Only the profile's load dependency is controlled; XPCDaemon.setProfile executes unchanged.
@interface ProfileLoadRules : Rules
@property BOOL fixtureLoadResult;
@property NSUInteger fixtureLoadCalls;
@end
@implementation ProfileLoadRules
-(BOOL)load { ++self.fixtureLoadCalls; return self.fixtureLoadResult; }
@end

static NSUInteger passed;
static NSUInteger failed;
static NSString* const ROOT_PATH = @"/opt/claude/bin/claude";

static void check(BOOL condition, NSString* name)
{
    if(condition) { ++passed; printf("PASS %s\n", name.UTF8String); }
    else { ++failed; fprintf(stderr, "FAIL %s\n", name.UTF8String); }
}
static NSDictionary* signature(void)
{
    return @{KEY_CS_STATUS:@(errSecSuccess), KEY_CS_SIGNER:@(DevID),
        KEY_CS_ID:@"com.anthropic.claude", KEY_CS_TEAM_ID:@"CLAUDETEAM",
        KEY_CS_AUTHS:@[@"Developer ID Application: Fixture (CLAUDETEAM)"]};
}
static NSDictionary* snapshot(NSData* token, NSString* path, NSData* parent, BOOL signedRoot)
{
    NSMutableDictionary* result = [@{@"auditToken":token, @"path":path,
        @"signatureValid":@(signedRoot)} mutableCopy];
    result[@"parentAuditToken"] = parent ?: acceptanceToken(0, 0);
    if(signedRoot)
    {
        result[@"signingIdentifier"] = signature()[KEY_CS_ID];
        result[@"teamIdentifier"] = signature()[KEY_CS_TEAM_ID];
    }
    return result;
}
static Rule* policy(NSString* path, NSString* address, NSString* port, int protocol, NSDictionary* signing)
{
    NSMutableDictionary* info = [@{KEY_PATH:path, KEY_SCOPE:@ACTION_SCOPE_PROCESS_TREE_STRICT,
        KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_USER,
        KEY_ENDPOINT_ADDR:address, KEY_ENDPOINT_PORT:port,
        KEY_ENDPOINT_ADDR_IS_REGEX:@(EndpointTypeExact), KEY_PROTOCOL:@(protocol)} mutableCopy];
    if(signing) info[KEY_CS_INFO] = signing;
    Rule* rule = [[Rule alloc] init:info];
    check(nil != rule, @"strict rule created by production Rule initializer");
    check([rules add:rule save:NO], @"strict rule accepted without disk writes");
    return rule;
}
static FixtureTracker* setup(void)
{
    resetCollaborators();
    FixtureTracker* tracker = [[FixtureTracker alloc] init];
    rules.processTreeTracker = tracker;
    policy(ROOT_PATH, @"127.0.0.1", @"17897", IPPROTO_TCP, signature());
    return tracker;
}
static NSNumber* decision(NSData* token, NSString* address, NSString* port, int protocol)
{
    return [rules strictDecisionForAuditToken:token process:testProcesses[token]
        flow:acceptanceFlow(token, address, port, protocol)];
}
static void expectDecision(NSData* token, NSString* address, NSString* port, int protocol,
                           NSInteger expected, NSString* name)
{
    NSNumber* actual = decision(token, address, port, protocol);
    check(actual != nil && actual.integerValue == expected, name);
}
static BOOL verdictIs(NEFilterNewFlowVerdict* actual, BOOL allow)
{
    // Compare with the framework's own verdict shape; action flags have no public getters.
    NEFilterNewFlowVerdict* expected = allow ? NEFilterNewFlowVerdict.allowVerdict : NEFilterNewFlowVerdict.dropVerdict;
    BOOL equal = actual != nil && [actual.description isEqualToString:expected.description];
    if(NO == equal) fprintf(stderr, "Verdict got %s; expected %s\n", actual.description.UTF8String, expected.description.UTF8String);
    return equal;
}
static void expectProvider(AcceptanceProvider* provider, NSData* token, NSString* address,
                           NSString* port, int protocol, BOOL allow, NSString* name)
{
    NEFilterNewFlowVerdict* actual = [provider handleNewFlow:acceptanceFlow(token, address, port, protocol)];
    check(verdictIs(actual, allow), name);
}

static void endpointAndProviderTests(void)
{
    FixtureTracker* tracker = setup();
    NSData* root = acceptanceToken(41001, 11);
    NSDictionary* rootSnapshot = snapshot(root, ROOT_PATH, nil, YES);
    [tracker recordSnapshot:rootSnapshot];
    acceptanceProcess(root, ROOT_PATH, signature());
    AcceptanceProvider* provider = acceptanceProvider();
    check(nil != provider, @"isolated production provider instance exists");
    check(![NEFilterNewFlowVerdict.allowVerdict.description isEqualToString:NEFilterNewFlowVerdict.dropVerdict.description],
        @"framework Allow and Drop fixtures are distinct");
    NSArray* endpointCases = @[
        @[@"127.0.0.1", @"17897", @(IPPROTO_TCP), @YES],
        @[@"127.0.0.1", @"17898", @(IPPROTO_TCP), @NO],
        @[@"127.0.0.2", @"17897", @(IPPROTO_TCP), @NO],
        @[@"::1", @"17897", @(IPPROTO_TCP), @NO],
        @[@"203.0.113.7", @"443", @(IPPROTO_TCP), @NO],
        @[@"2001:db8::7", @"443", @(IPPROTO_TCP), @NO],
        @[@"203.0.113.7", @"53", @(IPPROTO_UDP), @NO],
        @[@"2001:db8::7", @"53", @(IPPROTO_UDP), @NO],
        @[@"127.0.0.1", @"17897", @(IPPROTO_UDP), @NO],
        @[@"127.0.0.1", @"53", @(IPPROTO_UDP), @NO],
        @[@"localhost", @"17897", @(IPPROTO_TCP), @NO]];
    testAllowListMatches = YES;
    for(NSArray* entry in endpointCases)
    {
        NSString* name = [NSString stringWithFormat:@"provider %@:%@ protocol %@ %@ with localhost/DNS/allowlist/passive Allow prefs",
            entry[0], entry[1], entry[2], [entry[3] boolValue] ? @"allows" : @"denies"];
        expectProvider(provider, root, entry[0], entry[1], [entry[2] intValue], [entry[3] boolValue], name);
    }
    AcceptanceFlow* spoof = acceptanceFlow(root, @"203.0.113.7", @"17897", IPPROTO_TCP);
    spoof.remoteHostname = @"127.0.0.1";
    spoof.URL = [NSURL URLWithString:@"http://127.0.0.1:17897/"];
    check(verdictIs([provider handleNewFlow:spoof], NO), @"URL/hostname cannot spoof numeric endpoint permission");

    NSData* child = acceptanceToken(41002, 12);
    NSDictionary* childSnapshot = snapshot(child, @"/usr/bin/curl", root, NO);
    [tracker recordForkParent:rootSnapshot child:childSnapshot];
    Process* childProcess = acceptanceProcess(child, @"/usr/bin/curl", nil);
    Rule* childAllow = [[Rule alloc] init:@{KEY_PATH:childProcess.path, KEY_ACTION:@RULE_STATE_ALLOW,
        KEY_TYPE:@RULE_TYPE_USER, KEY_SCOPE:@ACTION_SCOPE_PROCESS}];
    [rules add:childAllow save:NO];
    expectProvider(provider, child, @"203.0.113.7", @"443", IPPROTO_TCP, NO,
        @"child outside root directory with own Allow cannot bypass strict ancestor");

    NSMutableDictionary* savedPreferences = preferences.preferences;
    preferences.preferences = [NSMutableDictionary dictionary];
    expectProvider(provider, child, @"203.0.113.7", @"443", IPPROTO_TCP, NO,
        @"empty preferences cannot bypass known strict child denial");
    expectProvider(provider, child, @"127.0.0.1", @"17897", IPPROTO_TCP, YES,
        @"empty preferences preserve explicit strict TCP proxy exception");
    NSData* unobservedRoot = acceptanceToken(41004, 14);
    acceptanceProcess(unobservedRoot, ROOT_PATH, signature());
    expectProvider(provider, unobservedRoot, @"203.0.113.7", @"443", IPPROTO_TCP, NO,
        @"empty preferences and cache miss cannot bypass selected root denial");
    NSData* unobservedUnrelated = acceptanceToken(41005, 15);
    acceptanceProcess(unobservedUnrelated, @"/opt/unrelated/client", nil);
    expectProvider(provider, unobservedUnrelated, @"203.0.113.7", @"443", IPPROTO_TCP, YES,
        @"empty preferences preserve unrelated flow Allow behavior");
    preferences.preferences = [@{PREF_IS_DISABLED:@YES} mutableCopy];
    expectProvider(provider, child, @"203.0.113.7", @"443", IPPROTO_TCP, YES,
        @"explicit master-disable retains established Allow behavior");
    preferences.preferences = savedPreferences;

    testProcessLookupFails = YES;
    [provider.cache removeAllObjects];
    NSUInteger lookupsBefore = testProcessLookups;
    expectProvider(provider, child, @"203.0.113.7", @"443", IPPROTO_TCP, NO,
        @"known strict child denies before process-construction fail-open");
    check(testProcessLookups == lookupsBefore, @"strict denial needs no process construction");
    expectProvider(provider, child, @"127.0.0.1", @"17897", IPPROTO_TCP, YES,
        @"known strict exception usable despite process-construction failure");
    testProcessLookupFails = NO;

    NSData* unrelated = acceptanceToken(41003, 13);
    Process* unrelatedProcess = acceptanceProcess(unrelated, @"/opt/mihomo/mihomo", nil);
    [tracker recordSnapshot:snapshot(unrelated, unrelatedProcess.path, nil, NO)];
    check(nil == decision(unrelated, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"unrelated Mihomo has no strict verdict");
    expectProvider(provider, unrelated, @"127.0.0.1", @"7897", IPPROTO_TCP, YES,
        @"unrelated Mihomo localhost 7897 follows existing prefs");
    expectProvider(provider, unrelated, @"203.0.113.7", @"443", IPPROTO_TCP, YES,
        @"unrelated process retains normal Allow policy");

    [provider addRelatedFlow:childProcess.key flow:acceptanceFlow(child, @"203.0.113.7", @"443", IPPROTO_TCP)];
    AcceptanceFlow* paused = [provider.relatedFlows[childProcess.key] firstObject];
    [provider resumeFlowsForKey:childProcess.key verdict:NEFilterNewFlowVerdict.allowVerdict];
    check(verdictIs(provider.resumedVerdicts[[NSValue valueWithNonretainedObject:paused]], NO),
        @"disconnect Allow rechecks strict verdict for paused flow");
    AcceptanceFlow* queued = acceptanceFlow(child, @"203.0.113.7", @"443", IPPROTO_TCP);
    [provider addRelatedFlow:childProcess.key flow:queued];
    [provider processRelatedFlow:childProcess.key];
    check(verdictIs(provider.resumedVerdicts[[NSValue valueWithNonretainedObject:queued]], NO),
        @"related-flow response re-evaluates strict constraints");

    preferences.preferences[PREF_BLOCK_MODE] = @YES;
    testAllowListMatches = NO;
    expectProvider(provider, root, @"127.0.0.1", @"17897", IPPROTO_TCP, NO,
        @"strict Allow exception still obeys global block mode");
}

static void lineageAndIdentityTests(void)
{
    FixtureTracker* tracker = setup();
    NSData* root = acceptanceToken(42001, 21);
    NSData* child = acceptanceToken(42002, 22);
    NSData* grandchild = acceptanceToken(42003, 23);
    NSDictionary* r = snapshot(root, ROOT_PATH, nil, YES);
    NSDictionary* c = snapshot(child, @"/usr/bin/python3", root, NO);
    NSDictionary* g = snapshot(grandchild, @"/usr/bin/curl", child, NO);
    [tracker recordForkParent:r child:c];
    [tracker recordForkParent:c child:g];
    acceptanceProcess(root, ROOT_PATH, signature());
    acceptanceProcess(child, @"/usr/bin/python3", nil);
    acceptanceProcess(grandchild, @"/usr/bin/curl", nil);
    [tracker recordExitAuditToken:root];
    [tracker recordExitAuditToken:child];
    NSDictionary* adopted = snapshot(grandchild, @"/usr/bin/curl", acceptanceToken(1, 1), NO);
    [tracker recordSnapshot:adopted];
    expectDecision(grandchild, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"grandchild retains strict ancestry after root/intermediate exit and launchd adoption");
    expectDecision(grandchild, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"orphan grandchild retains intended proxy exception");
    [tracker recordExitAuditToken:grandchild];
    NSData* reused = acceptanceToken(42003, 24);
    [tracker recordSnapshot:snapshot(reused, @"/opt/unrelated/client", nil, NO)];
    acceptanceProcess(reused, @"/opt/unrelated/client", nil);
    check(nil == decision(reused, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"reused PID with new audit version does not inherit strict ancestry");

    NSData* original = acceptanceToken(43001, 31);
    NSData* execTarget = acceptanceToken(43001, 32);
    NSDictionary* source = snapshot(original, ROOT_PATH, nil, YES);
    NSDictionary* target = snapshot(execTarget, @"/usr/bin/python3", nil, NO);
    [tracker recordSnapshot:source];
    [tracker recordExecSource:source target:target];
    acceptanceProcess(execTarget, @"/usr/bin/python3", nil);
    expectDecision(execTarget, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"root exec to different identity/path keeps selected strict lineage");

    NSData* alternate = acceptanceToken(43002, 33);
    NSString* alternatePath = @"/opt/another/claude";
    [tracker recordSnapshot:snapshot(alternate, alternatePath, nil, YES)];
    acceptanceProcess(alternate, alternatePath, signature());
    check(nil == decision(alternate, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"same signer in another executable path is not selected");
    NSData* wrongTeam = acceptanceToken(43003, 34);
    NSMutableDictionary* wrong = [snapshot(wrongTeam, ROOT_PATH, nil, YES) mutableCopy];
    wrong[@"teamIdentifier"] = @"OTHERTEAM";
    [tracker recordSnapshot:wrong];
    NSMutableDictionary* wrongCS = [signature() mutableCopy];
    wrongCS[KEY_CS_TEAM_ID] = @"OTHERTEAM";
    acceptanceProcess(wrongTeam, ROOT_PATH, wrongCS);
    check(nil == decision(wrongTeam, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"wrong signing team at selected path is not trusted as selected root");
    tracker.fixtureHealthy = NO;
    expectDecision(execTarget, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"known strict lineage denies exception after monitor health loss");
    tracker.fixtureHealthy = YES;
    tracker.fixtureAvailable = NO;
    expectDecision(execTarget, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"known strict lineage denies exception when monitor unavailable");
    check(nil == decision(reused, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"monitor unavailable does not apply strict policy to unrelated process");
}

static void scopeCompatibilityTests(void)
{
    resetCollaborators();
    FixtureTracker* tracker = [[FixtureTracker alloc] init];
    rules.processTreeTracker = tracker;
    NSData* parentToken = acceptanceToken(44001, 41);
    NSData* childToken = acceptanceToken(44002, 42);
    Process* child = acceptanceProcess(childToken, @"/usr/bin/curl", nil);
    child.ancestors = [@[@{KEY_PROCESS_ID:@44001, KEY_PROCESS_PATH:ROOT_PATH}] mutableCopy];
    Rule* parentBlock = [[Rule alloc] init:@{KEY_PATH:ROOT_PATH, KEY_SCOPE:@ACTION_SCOPE_PROCESS_TREE,
        KEY_ACTION:@RULE_STATE_BLOCK, KEY_TYPE:@RULE_TYPE_USER}];
    Rule* childAllow = [[Rule alloc] init:@{KEY_PATH:child.path, KEY_SCOPE:@ACTION_SCOPE_PROCESS,
        KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_USER}];
    [rules add:parentBlock save:NO];
    [rules add:childAllow save:NO];
    Rule* actual = [rules find:child flow:acceptanceFlow(childToken, @"203.0.113.7", @"443", IPPROTO_TCP)];
    check(actual == childAllow, @"scope 2 keeps child own-rule priority");
    check(nil == decision(childToken, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"scope 2 does not enter strict evaluation");
    policy(ROOT_PATH, @"127.0.0.1", @"17897", IPPROTO_TCP, nil);
    [tracker recordForkParent:snapshot(parentToken, ROOT_PATH, nil, NO)
                        child:snapshot(childToken, child.path, parentToken, NO)];
    expectDecision(childToken, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"explicit unsigned exact root also constrains its observed child");
    actual = [rules find:child flow:acceptanceFlow(childToken, @"203.0.113.7", @"443", IPPROTO_TCP)];
    check(actual != nil && actual.action.integerValue == RULE_STATE_BLOCK,
        @"Rules.find cannot bypass strict policy with child own-rule Allow");
}

static void constraintCompositionTests(void)
{
    FixtureTracker* tracker = setup();
    NSData* root = acceptanceToken(45001, 51);
    NSData* child = acceptanceToken(45002, 52);
    NSDictionary* r = snapshot(root, ROOT_PATH, nil, YES);
    NSDictionary* c = snapshot(child, @"/opt/second/bin/client", root, NO);
    [tracker recordForkParent:r child:c];
    acceptanceProcess(root, ROOT_PATH, signature());
    acceptanceProcess(child, c[@"path"], nil);
    Rule* baseline = [[Rule alloc] init:@{KEY_PATH:ROOT_PATH, KEY_SCOPE:@ACTION_SCOPE_PROCESS_TREE_STRICT,
        KEY_ACTION:@RULE_STATE_BLOCK, KEY_TYPE:@RULE_TYPE_USER, KEY_CS_INFO:signature(),
        KEY_ENDPOINT_ADDR:VALUE_ANY, KEY_ENDPOINT_PORT:VALUE_ANY}];
    check([rules add:baseline save:NO], @"optional wildcard default deny accepted");
    expectDecision(child, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"specific TCP exception outranks wildcard deny within same strict owner");
    Rule* tie = [[Rule alloc] init:@{KEY_PATH:ROOT_PATH, KEY_SCOPE:@ACTION_SCOPE_PROCESS_TREE_STRICT,
        KEY_ACTION:@RULE_STATE_BLOCK, KEY_TYPE:@RULE_TYPE_USER, KEY_CS_INFO:signature(),
        KEY_ENDPOINT_ADDR:@"127.0.0.1", KEY_ENDPOINT_PORT:@"17897", KEY_PROTOCOL:@(IPPROTO_TCP)}];
    [rules add:tie save:NO];
    expectDecision(child, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"equal specificity Block wins over Allow");
    tie.isDisabled = @YES;
    expectDecision(child, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"disabled strict constraint is excluded");
    policy(c[@"path"], @"127.0.0.1", @"17898", IPPROTO_TCP, nil);
    expectDecision(child, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"nested strict owners intersect; parent Allow cannot bypass child strict owner");
    expectDecision(child, @"127.0.0.1", @"17898", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"nested strict owners intersect; child Allow cannot bypass parent strict owner");

    tracker = setup();
    [tracker recordSnapshot:r];
    acceptanceProcess(root, ROOT_PATH, signature());
    Rule* cidr = [[Rule alloc] init:@{KEY_PATH:ROOT_PATH, KEY_SCOPE:@ACTION_SCOPE_PROCESS_TREE_STRICT,
        KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_USER, KEY_CS_INFO:signature(),
        KEY_ENDPOINT_ADDR:@"192.0.2.0/24", KEY_ENDPOINT_PORT:@"443",
        KEY_ENDPOINT_ADDR_IS_REGEX:@(EndpointTypeCIDR), KEY_PROTOCOL:@(IPPROTO_TCP)}];
    check([rules add:cidr save:NO], @"numeric CIDR constraint accepted");
    expectDecision(root, @"192.0.2.7", @"443", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"CIDR permission uses actual numeric endpoint");
    AcceptanceFlow* spoof = acceptanceFlow(root, @"203.0.113.7", @"443", IPPROTO_TCP);
    spoof.remoteHostname = @"192.0.2.7";
    spoof.URL = [NSURL URLWithString:@"https://192.0.2.7/"];
    NSNumber* actual = [rules strictDecisionForAuditToken:root process:testProcesses[root] flow:spoof];
    check(actual != nil && actual.integerValue == RULE_STATE_BLOCK,
        @"CIDR cannot be bypassed with hostname or URL metadata");

    NSData* unknown = acceptanceToken(45003, 53);
    acceptanceProcess(unknown, @"/usr/bin/curl", nil);
    check(nil == decision(unknown, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"unobserved unrelated identity is explicitly outside claimed strict coverage");
    NSData* untrackedRoot = acceptanceToken(45004, 54);
    acceptanceProcess(untrackedRoot, ROOT_PATH, signature());
    tracker.fixtureAvailable = NO;
    expectDecision(untrackedRoot, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"selected root path/signature fails closed without lineage monitoring");
}

static void retainedOwnershipTests(void)
{
    FixtureTracker* tracker = setup();
    NSData* root = acceptanceToken(46001, 61);
    NSData* child = acceptanceToken(46002, 62);
    NSDictionary* original = snapshot(root, ROOT_PATH, nil, YES);
    [tracker recordSnapshot:original];
    NSMutableDictionary* changed = [original mutableCopy];
    changed[@"signatureValid"] = @NO;
    [tracker recordSnapshot:changed];
    NSDictionary* externalChild = snapshot(child, @"/usr/bin/curl", root, NO);
    [tracker recordForkParent:changed child:externalChild];
    Process* childProcess = acceptanceProcess(child, externalChild[@"path"], nil);
    [rules add:[[Rule alloc] init:@{KEY_PATH:childProcess.path, KEY_ACTION:@RULE_STATE_ALLOW,
        KEY_TYPE:@RULE_TYPE_USER, KEY_SCOPE:@ACTION_SCOPE_PROCESS}] save:NO];
    expectDecision(child, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"captured strict root keeps ownership after signature validity loss before fork");
    AcceptanceProvider* provider = acceptanceProvider();
    expectProvider(provider, child, @"203.0.113.7", @"443", IPPROTO_TCP, NO,
        @"trust-loss descendant own Allow cannot bypass captured strict root");

    resetCollaborators();
    tracker = [[FixtureTracker alloc] init];
    rules.processTreeTracker = tracker;
    NSFileManager* manager = NSFileManager.defaultManager;
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString* first = [directory stringByAppendingPathComponent:@"first"];
    NSString* second = [directory stringByAppendingPathComponent:@"second"];
    NSString* alias = [directory stringByAppendingPathComponent:@"selected"];
    [manager createFileAtPath:first contents:NSData.data attributes:nil];
    [manager createFileAtPath:second contents:NSData.data attributes:nil];
    [manager createSymbolicLinkAtPath:alias withDestinationPath:first error:NULL];
    Rule* selected = policy(alias, @"127.0.0.1", @"17897", IPPROTO_TCP, nil);
    NSString* canonicalFirst = first.stringByResolvingSymlinksInPath;
    check([selected.path isEqualToString:canonicalFirst], @"selected symlink root freezes canonical executable path");
    NSData* selectedToken = acceptanceToken(46003, 63);
    NSData* selectedChild = acceptanceToken(46004, 64);
    [tracker recordForkParent:snapshot(selectedToken, canonicalFirst, nil, NO)
                        child:snapshot(selectedChild, @"/usr/bin/python3", selectedToken, NO)];
    acceptanceProcess(selectedChild, @"/usr/bin/python3", nil);
    [manager removeItemAtPath:alias error:NULL];
    [manager createSymbolicLinkAtPath:alias withDestinationPath:second error:NULL];
    expectDecision(selectedChild, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"retargeting selected symlink cannot release existing descendant restriction");
    [manager removeItemAtPath:first error:NULL];
    [rules cleanup:YES];
    check([rules.rules[selected.key][KEY_RULES] containsObject:selected],
        @"full cleanup retains strict permanent root after executable deletion");
    expectDecision(selectedChild, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"deleted root cleanup cannot release living descendants");
    [manager removeItemAtPath:directory error:NULL];
}

static void adhocHashPinTests(void)
{
    resetCollaborators();
    FixtureTracker* tracker = [[FixtureTracker alloc] init];
    rules.processTreeTracker = tracker;
    NSData* root = acceptanceToken(47001, 71);
    NSData* wrong = acceptanceToken(47002, 72);
    NSData* hash = [NSMutableData dataWithLength:20];
    NSDictionary* signing = @{KEY_CS_STATUS:@(errSecSuccess), KEY_CS_SIGNER:@(AdHoc),
        KEY_CS_ID:@"canary", KEY_CS_CDHASH:@"0000000000000000000000000000000000000000"};
    policy(ROOT_PATH, @"127.0.0.1", @"17897", IPPROTO_TCP, signing);
    NSMutableDictionary* signedSnapshot = [snapshot(root, ROOT_PATH, nil, NO) mutableCopy];
    signedSnapshot[@"signingIdentifier"] = @"canary";
    signedSnapshot[@"codeSignatureValid"] = @YES;
    signedSnapshot[@"cdhash"] = hash;
    [tracker recordSnapshot:signedSnapshot];
    acceptanceProcess(root, ROOT_PATH, signing);
    expectDecision(root, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"ad-hoc kernel snapshot with exact CDHash matches explicit hash pin");
    expectDecision(root, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"ad-hoc pinned root remains default deny");
    NSMutableDictionary* mismatch = [signedSnapshot mutableCopy];
    mismatch[@"auditToken"] = wrong;
    NSMutableData* otherHash = [NSMutableData dataWithLength:20];
    ((uint8_t*)otherHash.mutableBytes)[0] = 1;
    mismatch[@"cdhash"] = otherHash;
    [tracker recordSnapshot:mismatch];
    NSMutableDictionary* mismatchingSigning = [signing mutableCopy];
    mismatchingSigning[KEY_CS_CDHASH] = @"0100000000000000000000000000000000000000";
    acceptanceProcess(wrong, ROOT_PATH, mismatchingSigning);
    check(nil == decision(wrong, @"203.0.113.7", @"443", IPPROTO_TCP),
        @"same path and identifier with different ad-hoc CDHash is not selected");
}

static void profileActivationTests(void)
{
    resetCollaborators();
    NSString* oldProfile = @"/memory-fixture/previous-profile";
    testCurrentProfilePath = oldProfile;
    ProfileLoadRules* profileRules = [[ProfileLoadRules alloc] init];
    rules = profileRules;
    XPCDaemon* daemon = [[XPCDaemon alloc] init];
    __block NSUInteger replies = 0;
    __block BOOL replyValue = YES;
    profileRules.fixtureLoadResult = NO;
    [daemon setProfile:nil reply:^(BOOL result) { ++replies; replyValue = result; }];
    check(replies == 1 && NO == replyValue, @"actual XPC profile switch replies false once after rules activation failure");
    check(profileRules.fixtureLoadCalls == 1, @"XPC profile switch attempts rules activation before preferences");
    check([testCurrentProfilePath isEqualToString:oldProfile], @"failed profile activation restores previous profile path");
    check([testProfileSetPaths isEqualToArray:@[NSNull.null, oldProfile]], @"failed Default-profile switch restores only memory profile collaborator");
    check(testPreferencesLoads == 0, @"failed strict profile activation does not reload preferences");
    check(testRulesChangedCalls == 0, @"failed strict profile activation does not announce success to client");

    replies = 0;
    testProfileSetPaths = [NSMutableArray array];
    profileRules.fixtureLoadResult = YES;
    [daemon setProfile:nil reply:^(BOOL result) { ++replies; replyValue = result; }];
    check(replies == 1 && YES == replyValue, @"actual XPC successful profile switch replies true once");
    check(nil == testCurrentProfilePath, @"successful Default-profile switch keeps selected Default path");
    check([testProfileSetPaths isEqualToArray:@[NSNull.null]], @"successful profile switch does not roll back");
    check(testPreferencesLoads == 1, @"successful profile activation reloads preferences once");
    check(testRulesChangedCalls == 1, @"successful profile activation notifies client once");
}

static void pausedRootCacheEvictionTest(void)
{
    setup();
    NSData* token = acceptanceToken(48001, 81);
    Process* process = acceptanceProcess(token, ROOT_PATH, signature());
    AcceptanceProvider* provider = acceptanceProvider();
    AcceptanceFlow* paused = acceptanceFlow(token, @"203.0.113.7", @"443", IPPROTO_TCP);
    [provider.cache setObject:process forKey:token];
    [provider addRelatedFlow:process.key flow:paused];
    [provider.cache removeAllObjects];
    check(nil == [rules.processTreeTracker ancestorsForAuditToken:token], @"paused-root fixture has no captured ES identity");
    NSUInteger priorLookups = testProcessLookups;
    [provider resumeFlowsForKey:process.key verdict:NEFilterNewFlowVerdict.allowVerdict];
    check(verdictIs(provider.resumedVerdicts[[NSValue valueWithNonretainedObject:paused]], NO),
        @"paused selected root remains strict after process-cache eviction before auto-Allow resume");
    check(testProcessLookups == priorLookups + 1, @"active strict policy resolves missing process once on resume");

    resetCollaborators();
    provider = acceptanceProvider();
    paused = acceptanceFlow(token, @"203.0.113.7", @"443", IPPROTO_TCP);
    priorLookups = testProcessLookups;
    [provider resumeFlow:paused withVerdict:NEFilterNewFlowVerdict.allowVerdict];
    check(verdictIs(provider.resumedVerdicts[[NSValue valueWithNonretainedObject:paused]], YES),
        @"ordinary paused flow retains auto-Allow without strict policy");
    check(testProcessLookups == priorLookups, @"resume skips extra process lookup without active strict policy");
}

static void samePathIdentityOwnerTests(void)
{
    resetCollaborators();
    FixtureTracker* tracker = [[FixtureTracker alloc] init];
    rules.processTreeTracker = tracker;
    NSDictionary* signingA = @{KEY_CS_STATUS:@(errSecSuccess), KEY_CS_SIGNER:@(AdHoc),
        KEY_CS_ID:@"canary", KEY_CS_CDHASH:@"0000000000000000000000000000000000000000"};
    NSDictionary* signingB = @{KEY_CS_STATUS:@(errSecSuccess), KEY_CS_SIGNER:@(AdHoc),
        KEY_CS_ID:@"canary", KEY_CS_CDHASH:@"0100000000000000000000000000000000000000"};
    Rule* ruleA = policy(ROOT_PATH, @"127.0.0.1", @"17897", IPPROTO_TCP, signingA);
    Rule* ruleB = policy(ROOT_PATH, @"127.0.0.1", @"17898", IPPROTO_TCP, signingB);
    check([ruleA.key isEqual:ruleB.key] && [ruleA.path isEqual:ruleB.path],
        @"different hash-pin owners deliberately share storage key and executable path");
    NSData* rootA = acceptanceToken(49001, 91);
    NSData* execB = acceptanceToken(49001, 92);
    NSData* independentB = acceptanceToken(49002, 93);
    NSMutableDictionary* snapshotA = [snapshot(rootA, ROOT_PATH, nil, NO) mutableCopy];
    snapshotA[@"signingIdentifier"] = @"canary";
    snapshotA[@"codeSignatureValid"] = @YES;
    snapshotA[@"cdhash"] = [NSData dataWithBytes:(uint8_t[20]){0} length:20];
    NSMutableDictionary* snapshotB = [snapshot(execB, ROOT_PATH, nil, NO) mutableCopy];
    snapshotB[@"signingIdentifier"] = @"canary";
    snapshotB[@"codeSignatureValid"] = @YES;
    snapshotB[@"cdhash"] = [NSData dataWithBytes:(uint8_t[20]){1} length:20];
    NSMutableDictionary* standaloneB = [snapshotB mutableCopy];
    standaloneB[@"auditToken"] = independentB;
    [tracker recordSnapshot:snapshotA];
    [tracker recordSnapshot:standaloneB];
    acceptanceProcess(rootA, ROOT_PATH, signingA);
    acceptanceProcess(independentB, ROOT_PATH, signingB);
    expectDecision(rootA, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"hash A owner alone allows its configured TCP endpoint");
    expectDecision(rootA, @"127.0.0.1", @"17898", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"hash A owner alone denies hash B-only endpoint");
    expectDecision(independentB, @"127.0.0.1", @"17898", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"independent hash B owner alone allows its configured TCP endpoint");
    expectDecision(independentB, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"independent hash B owner alone denies hash A-only endpoint");
    [tracker recordExecSource:snapshotA target:snapshotB];
    acceptanceProcess(execB, ROOT_PATH, signingB);
    expectDecision(execB, @"127.0.0.1", @"17898", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"exec to hash B at same path cannot union B-only permission with strict ancestor A");
    expectDecision(execB, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"exec hash B retains its own restriction on ancestor A-only permission");
    expectDecision(execB, @"203.0.113.7", @"443", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"both same-path hash owners remain default deny");
    policy(ROOT_PATH, @"127.0.0.1", @"17900", IPPROTO_TCP, signingA);
    policy(ROOT_PATH, @"127.0.0.1", @"17900", IPPROTO_TCP, signingB);
    expectDecision(execB, @"127.0.0.1", @"17900", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"same-path hash owners allow only their shared intersection endpoint");
    expectProvider(acceptanceProvider(), execB, @"127.0.0.1", @"17898", IPPROTO_TCP, NO,
        @"public provider drops exec B-only endpoint despite identical path and rule key");

    resetCollaborators();
    tracker = [[FixtureTracker alloc] init];
    rules.processTreeTracker = tracker;
    NSMutableDictionary* teamA = [signature() mutableCopy];
    teamA[KEY_CS_SIGNER] = @(AppStore);
    NSMutableDictionary* teamB = [teamA mutableCopy];
    teamB[KEY_CS_TEAM_ID] = @"OTHERTEAM";
    ruleA = policy(ROOT_PATH, @"127.0.0.1", @"17897", IPPROTO_TCP, teamA);
    ruleB = policy(ROOT_PATH, @"127.0.0.1", @"17898", IPPROTO_TCP, teamB);
    check([ruleA.key isEqual:ruleB.key] && [ruleA.path isEqual:ruleB.path],
        @"different signed teams with same identifier share legacy App Store storage key");
    rootA = acceptanceToken(49003, 94);
    execB = acceptanceToken(49003, 95);
    snapshotA = [snapshot(rootA, ROOT_PATH, nil, YES) mutableCopy];
    snapshotB = [snapshot(execB, ROOT_PATH, nil, YES) mutableCopy];
    snapshotB[@"teamIdentifier"] = @"OTHERTEAM";
    [tracker recordSnapshot:snapshotA];
    acceptanceProcess(rootA, ROOT_PATH, teamA);
    expectDecision(rootA, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_ALLOW,
        @"team A owner alone retains its configured permission");
    [tracker recordExecSource:snapshotA target:snapshotB];
    acceptanceProcess(execB, ROOT_PATH, teamB);
    expectDecision(execB, @"127.0.0.1", @"17898", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"same-path identifier with different team cannot union strict ancestor permission");
    expectDecision(execB, @"127.0.0.1", @"17897", IPPROTO_TCP, RULE_STATE_BLOCK,
        @"same-path signed-team owners enforce both restrictions after exec");
}

int main(void)
{
    @autoreleasepool
    {
        endpointAndProviderTests();
        lineageAndIdentityTests();
        scopeCompatibilityTests();
        constraintCompositionTests();
        retainedOwnershipTests();
        adhocHashPinTests();
        profileActivationTests();
        pausedRootCacheEvictionTest();
        samePathIdentityOwnerTests();
        printf("\n%lu passed; %lu failed. Production Rule / Rules / ProcessTreeTracker / FilterDataProvider executed.\n",
            (unsigned long)passed, (unsigned long)failed);
    }
    return failed ? 1 : 0;
}
