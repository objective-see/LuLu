//
//  test_strict_rule_format.m
//  LuLu
//  Focused production Rule construction and serialization tests
//

#import "Rule.h"
#import <Security/Security.h>
#import "signing.h"

os_log_t logHandle;
static NSUInteger checks = 0;

//crafted legacy archive input still decodes through the production Rule implementation
@interface RuleArchiveFixture : Rule
@property(nonatomic, retain)NSNumber* archivedEndpointType;
@property BOOL primitiveEndpointType;
@end

@implementation RuleArchiveFixture
-(void)encodeWithCoder:(NSCoder*)encoder
{
    for(NSString* key in @[@"key", @"uuid", @"pid", @"path", @"name", @"csInfo", @"endpointAddr", @"endpointHost", @"endpointPort", @"type", @"scope", @"action", @"isDisabled", @"creation", @"expiration"])
    {
        [encoder encodeObject:[self valueForKey:key] forKey:key];
    }
    if(YES == self.primitiveEndpointType)
    {
        [encoder encodeBool:NO forKey:@"isEndpointAddrRegex"];
    }
    else [encoder encodeObject:(self.archivedEndpointType ?: @(self.isEndpointAddrRegex)) forKey:@"isEndpointAddrRegex"];
}
@end

static NSData* fixtureArchive(RuleArchiveFixture* rule)
{
    NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    [archiver setClassName:@"Rule" forClass:RuleArchiveFixture.class];
    [archiver encodeObject:rule forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    return archiver.encodedData;
}

static void check(BOOL condition, NSString* message)
{
    checks++;
    if(NO == condition)
    {
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
        exit(1);
    }
}

static NSMutableDictionary* strictInfo(void)
{
    return [@{KEY_PATH:@"/opt/tool/bin/cli", KEY_PROCESS_NAME:@"cli", KEY_TYPE:@(RULE_TYPE_USER),
              KEY_SCOPE:@(ACTION_SCOPE_PROCESS_TREE_STRICT), KEY_ACTION:@(RULE_STATE_ALLOW),
              KEY_ENDPOINT_ADDR:@"127.0.0.1", KEY_ENDPOINT_PORT:@"17897", KEY_PROTOCOL:@6,
              KEY_ENDPOINT_ADDR_IS_REGEX:@(EndpointTypeExact), KEY_DURATION:@(RuleDurationAlways)} mutableCopy];
}

static NSMutableDictionary* ruleJSON(Rule* rule)
{
    NSString* text = [NSString stringWithFormat:@"{%@}", [rule toJSON]];
    NSError* error = nil;
    NSMutableDictionary* result = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
    check((nil != result) && (nil == error), @"production export emits valid JSON");
    return result;
}

static void rejectInfo(NSString* key, id value)
{
    NSMutableDictionary* info = strictInfo();
    info[key] = value;
    check(nil == [[Rule alloc] init:info], [NSString stringWithFormat:@"reject info %@=%@", key, value]);
}

int main(void)
{
    @autoreleasepool
    {
        logHandle = os_log_create("LuLu.Tests", "StrictRuleFormat");
        Rule* rule = [[Rule alloc] init:strictInfo()];
        check((nil != rule) && [rule isStrictProcessTree] && [rule isValidStrictProcessTree], @"construct strict rule");
        check([rule.endpointAddr isEqualToString:@"127.0.0.1"] && [rule.endpointPort isEqualToString:@"17897"] && [rule.protocol isEqual:@6], @"strict init preserves endpoint, port and TCP");
        check(!rule.isTemporary && !rule.expiration, @"strict rule is permanent");

        for(NSNumber* scope in @[@0, @1, @2])
        {
            NSMutableDictionary* info = strictInfo();
            info[KEY_SCOPE] = scope;
            Rule* legacy = [[Rule alloc] init:info];
            BOOL endpointScope = ACTION_SCOPE_ENDPOINT == scope.intValue;
            check([legacy.endpointAddr isEqualToString:(endpointScope ? @"127.0.0.1" : VALUE_ANY)] &&
                  [legacy.endpointPort isEqualToString:(endpointScope ? @"17897" : VALUE_ANY)], @"legacy scope endpoint behavior");
            check(!legacy.isStrictProcessTree, @"legacy rule remains nonstrict");
        }

        NSMutableDictionary* json = ruleJSON(rule);
        Rule* imported = [[Rule alloc] initFromJSON:json];
        check(imported.isValidStrictProcessTree && [imported.protocol isEqual:@6] && [imported.endpointPort isEqual:@"17897"] &&
              [imported.endpointAddr isEqual:@"127.0.0.1"] && [imported.uuid isEqual:rule.uuid], @"strict JSON round trip");
        [json removeObjectForKey:KEY_PROTOCOL];
        imported = [[Rule alloc] initFromJSON:json];
        check(imported.isValidStrictProcessTree && !imported.protocol, @"missing JSON protocol means any");
        for(NSNumber* protocol in @[@0, @6, @17, @255])
        {
            json[KEY_PROTOCOL] = protocol;
            imported = [[Rule alloc] initFromJSON:json];
            check(imported.isValidStrictProcessTree && [imported.protocol isEqual:protocol], @"valid protocol JSON round trip");
        }

        for(NSString* path in @[@"*", @"/opt/*", @"/opt/cli*", @"/opt/", @"/", @"relative", @"/opt/../bin/cli", @"/opt//bin/cli"])
        {
            rejectInfo(KEY_PATH, path);
            NSMutableDictionary* invalid = ruleJSON(rule);
            invalid[KEY_PATH] = path;
            check(nil == [[Rule alloc] initFromJSON:invalid], @"JSON rejects invalid root paths");
        }
        for(id protocol in @[@"6", @6.5, @-1, @256, @YES, [NSNull null]]) rejectInfo(KEY_PROTOCOL, protocol);
        for(id action in @[@"1", @0.5, @2, @YES, [NSNull null]]) rejectInfo(KEY_ACTION, action);
        for(id scope in @[@"3", @"3junk", @3.5]) rejectInfo(KEY_SCOPE, scope);
        for(id duration in @[@(RuleDurationOnce), @(RuleDurationProcess), @(RuleDurationCustom), @"101", @101.5]) rejectInfo(KEY_DURATION, duration);
        rejectInfo(KEY_PROCESS_ID, @42);
        rejectInfo(KEY_DURATION_EXPIRATION, [NSDate date]);
        for(id port in @[@"", @"0", @"65536", @"17897junk", @" 17897", @17897, [NSNull null]]) rejectInfo(KEY_ENDPOINT_PORT, port);
        for(id endpoint in @[@"", @"localhost", @"http://127.0.0.1", @"127.0.0.*", @"[::1]", @127, [NSNull null]]) rejectInfo(KEY_ENDPOINT_ADDR, endpoint);
        for(id endpointType in @[@"0", @0.5, @(EndpointTypeRegex), @(EndpointTypeGlob)]) rejectInfo(KEY_ENDPOINT_ADDR_IS_REGEX, endpointType);
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@0, KEY_CS_ID:@"com.vendor.cli", KEY_CS_SIGNER:@(DevID)});
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@0, KEY_CS_ID:@"com.vendor.cli", KEY_CS_TEAM_ID:@"TEAM", KEY_CS_SIGNER:@(AdHoc)});
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@-1});
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@(errSecCSUnsigned), KEY_CS_SIGNER:@(DevID)});
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@0, KEY_CS_ID:@"cli", KEY_CS_TEAM_ID:@"TEAM", KEY_CS_SIGNER:@(DevID), KEY_CS_AUTHS:@[@42]});
        rejectInfo(KEY_PROCESS_NAME, [NSNull null]);
        rejectInfo(KEY_KEY, [NSNull null]);
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@(errSecCSUnsigned), KEY_CS_ID:@"bad"});
        rejectInfo(KEY_CS_INFO, @{KEY_CS_STATUS:@0, KEY_CS_ID:@"cli", KEY_CS_TEAM_ID:@"TEAM", KEY_CS_SIGNER:@(DevID), KEY_CS_AUTHS:@"bad"});

        for(NSDictionary* change in @[@{KEY_ENDPOINT_ADDR:VALUE_ANY, KEY_ENDPOINT_PORT:VALUE_ANY, KEY_ACTION:@0},
                                     @{KEY_ENDPOINT_ADDR:@"::1"},
                                     @{KEY_ENDPOINT_ADDR:@"127.0.0.0/8", KEY_ENDPOINT_ADDR_IS_REGEX:@(EndpointTypeCIDR)},
                                     @{KEY_ENDPOINT_ADDR:@"127.0.0.1 - 127.0.0.3", KEY_ENDPOINT_ADDR_IS_REGEX:@(EndpointTypeCIDR)}])
        {
            NSMutableDictionary* info = strictInfo();
            [info addEntriesFromDictionary:change];
            Rule* valid = [[Rule alloc] init:info];
            check(valid.isValidStrictProcessTree, @"strict numeric or wildcard endpoint accepted");
            check([[[Rule alloc] initFromJSON:ruleJSON(valid)] isValidStrictProcessTree], @"strict numeric endpoint round trip");
        }

        NSMutableDictionary* signedInfo = strictInfo();
        signedInfo[KEY_CS_INFO] = @{KEY_CS_STATUS:@0, KEY_CS_ID:@"com.vendor.cli", KEY_CS_TEAM_ID:@"TEAM", KEY_CS_SIGNER:@(DevID), KEY_CS_AUTHS:@[@"Vendor"]};
        Rule* signedRule = [[Rule alloc] init:signedInfo];
        check(signedRule.isValidStrictProcessTree && [signedRule.key isEqual:@"com.vendor.cli:Vendor"], @"signed root keeps existing rule key generation");
        Rule* signedImport = [[Rule alloc] initFromJSON:ruleJSON(signedRule)];
        check(signedImport.isValidStrictProcessTree && [signedImport.csInfo[KEY_CS_TEAM_ID] isEqual:@"TEAM"], @"signing team survives JSON");
        signedInfo[KEY_CS_INFO] = @{KEY_CS_STATUS:@(errSecCSUnsigned)};
        check([[[Rule alloc] init:signedInfo] isValidStrictProcessTree], @"explicit unsigned root accepted");

        NSArray* mutations = @[@{KEY_SCOPE:@"3"}, @{KEY_SCOPE:@3.5}, @{KEY_ACTION:@"1"}, @{KEY_ACTION:@0.5},
                              @{KEY_PROTOCOL:@"6"}, @{KEY_PROTOCOL:@6.5}, @{KEY_PROTOCOL:[NSNull null]},
                              @{@"isEndpointAddrRegex":@0.5}, @{@"isEndpointAddrRegex":@"0"},
                              @{KEY_PROCESS_ID:@42}, @{KEY_DURATION_EXPIRATION:@"2030-01-01T00:00:00+0000"},
                              @{KEY_DURATION:@(RuleDurationProcess)}, @{KEY_TYPE:@"3"}, @{@"isDisabled":@0.5}];
        for(NSDictionary* mutation in mutations)
        {
            NSMutableDictionary* invalid = ruleJSON(rule);
            [invalid addEntriesFromDictionary:mutation];
            check(nil == [[Rule alloc] initFromJSON:invalid], @"strict JSON rejects numeric coercion or temporary policy");
        }

        NSError* error = nil;
        NSData* archive = [NSKeyedArchiver archivedDataWithRootObject:@[rule, signedRule] requiringSecureCoding:YES error:&error];
        check(archive && !error, @"actual secure archive writes");
        NSSet* classes = [NSSet setWithArray:@[NSArray.class, Rule.class]];
        NSArray* decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:archive error:&error];
        Rule* decodedRule = decoded.firstObject;
        Rule* decodedSigned = decoded.lastObject;
        check(decoded.count == 2 && !error && decodedRule.isValidStrictProcessTree && [decodedRule.protocol isEqual:@6], @"actual secure archive preserves strict protocol");
        check(decodedSigned.isValidStrictProcessTree && [decodedSigned.csInfo[KEY_CS_TEAM_ID] isEqual:@"TEAM"], @"secure archive preserves signing team");

        NSMutableDictionary* ordinaryInfo = strictInfo();
        ordinaryInfo[KEY_SCOPE] = @0;
        Rule* ordinary = [[Rule alloc] init:ordinaryInfo];
        check([ordinary.protocol isEqual:@6], @"ordinary init keeps existing in-memory protocol");
        NSMutableDictionary* ordinaryJSON = ruleJSON(ordinary);
        ordinaryJSON[KEY_SCOPE] = @"0";
        ordinaryJSON[KEY_ACTION] = @"1";
        ordinaryJSON[KEY_TYPE] = @"3";
        check(nil == ordinaryJSON[KEY_PROTOCOL], @"ordinary export preserves legacy protocol omission");
        ordinaryJSON[KEY_PROTOCOL] = @"ignored legacy field";
        imported = [[Rule alloc] initFromJSON:ordinaryJSON];
        check(imported && !imported.protocol && !imported.isStrictProcessTree, @"legacy JSON still accepts old number strings and absent protocol");
        archive = [NSKeyedArchiver archivedDataWithRootObject:ordinary requiringSecureCoding:YES error:&error];
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:archive error:&error];
        check(imported && !imported.protocol, @"absent secure protocol remains optional");

        Rule* malformed = [[Rule alloc] init:strictInfo()];
        malformed.protocol = @6.5;
        check(!malformed.isValidStrictProcessTree && !malformed.toJSON, @"invalid strict export cannot silently narrow protocol");
        archive = [NSKeyedArchiver archivedDataWithRootObject:@[ordinary, malformed] requiringSecureCoding:YES error:&error];
        decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:archive error:&error];
        malformed = decoded.lastObject;
        check(decoded.count == 2 && !error && malformed.isStrictProcessTree && !malformed.isValidStrictProcessTree, @"malformed strict archive stays identifiable and unrelated records decode");
        RuleArchiveFixture* oldArchiveRule = [[RuleArchiveFixture alloc] init:ordinaryInfo];
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:fixtureArchive(oldArchiveRule) error:&error];
        check(imported && !error && !imported.protocol && !imported.isStrictProcessTree, @"actual old archive with missing protocol field decodes");
        RuleArchiveFixture* strictArchiveRule = [[RuleArchiveFixture alloc] init:strictInfo()];
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:fixtureArchive(strictArchiveRule) error:&error];
        check(imported.isValidStrictProcessTree && !imported.protocol, @"strict archive missing optional protocol means any");
        strictArchiveRule.archivedEndpointType = @0.5;
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:fixtureArchive(strictArchiveRule) error:&error];
        check(imported.isStrictProcessTree && !imported.isValidStrictProcessTree && !imported.toJSON, @"fractional archive match type never silently coerces strict policy");
        archive = [NSKeyedArchiver archivedDataWithRootObject:imported requiringSecureCoding:YES error:&error];
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:archive error:&error];
        check(imported.isStrictProcessTree && !imported.isValidStrictProcessTree, @"rearchiving malformed match type cannot discard invalid marker");
        strictArchiveRule.primitiveEndpointType = YES;
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:fixtureArchive(strictArchiveRule) error:&error];
        check(imported.isStrictProcessTree && !imported.isValidStrictProcessTree, @"strict primitive archive match type cannot silently infer exact match");
        oldArchiveRule.primitiveEndpointType = YES;
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:fixtureArchive(oldArchiveRule) error:&error];
        check(imported && !error && !imported.isStrictProcessTree, @"legacy primitive archive match type remains loadable");
        NSString* work = @(getenv("STRICT_RULE_TEST_WORK"));
        NSString* targetA = [work stringByAppendingPathComponent:@"target-a"];
        NSString* targetB = [work stringByAppendingPathComponent:@"target-b"];
        NSString* alias = [work stringByAppendingPathComponent:@"selected-cli"];
        NSFileManager* files = NSFileManager.defaultManager;
        check([@"fixture-a" writeToFile:targetA atomically:YES encoding:NSUTF8StringEncoding error:&error] &&
              [@"fixture-b" writeToFile:targetB atomically:YES encoding:NSUTF8StringEncoding error:&error], @"create actual filesystem canonical root fixtures");
        check([files createSymbolicLinkAtPath:alias withDestinationPath:targetA error:&error], @"create selected executable symlink");
        NSMutableDictionary* aliasInfo = strictInfo();
        aliasInfo[KEY_PATH] = alias;
        Rule* pinned = [[Rule alloc] init:aliasInfo];
        NSString* canonicalA = [targetA stringByResolvingSymlinksInPath];
        check([pinned.path isEqual:canonicalA], @"programmatic strict root freezes canonical executable path");
        NSMutableDictionary* aliasJSON = ruleJSON(pinned);
        aliasJSON[KEY_PATH] = alias;
        Rule* pinnedJSON = [[Rule alloc] initFromJSON:aliasJSON];
        check([pinnedJSON.path isEqual:canonicalA], @"JSON strict root freezes canonical executable path");
        check([files removeItemAtPath:alias error:&error] &&
              [files createSymbolicLinkAtPath:alias withDestinationPath:targetB error:&error], @"retarget selected executable symlink");
        check([pinned.path isEqual:canonicalA] && [pinnedJSON.path isEqual:canonicalA] &&
              pinned.isValidStrictProcessTree && pinnedJSON.isValidStrictProcessTree, @"retargeting launcher does not change existing strict roots");
        check([ruleJSON(pinned)[KEY_PATH] isEqual:canonicalA], @"JSON persists selected canonical root after symlink changes");
        archive = [NSKeyedArchiver archivedDataWithRootObject:pinned requiringSecureCoding:YES error:&error];
        imported = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:archive error:&error];
        check([imported.path isEqual:canonicalA] && imported.isValidStrictProcessTree, @"secure archive preserves frozen canonical root after symlink changes");
        check([files removeItemAtPath:targetA error:&error], @"remove original executable fixture");
        check([pinned.path isEqual:canonicalA] && pinned.isValidStrictProcessTree, @"missing original executable does not discard permanent root");
        aliasJSON[KEY_PATH] = [work stringByAppendingString:@"/invalid/../selected-cli"];
        check(nil == [[Rule alloc] initFromJSON:aliasJSON], @"canonicalization never normalizes invalid raw strict JSON paths");
        NSString* canary = [work stringByAppendingPathComponent:@"canary"];
        NSDictionary* canaryCS = extractSigningInfo(NULL, canary, kSecCSDefaultFlags);
        check(errSecSuccess == [canaryCS[KEY_CS_STATUS] intValue] &&
              40 == [canaryCS[KEY_CS_CDHASH] length], @"production signing extraction gets real native canary CDHash");
        SecStaticCodeRef canaryCode = NULL;
        CFDictionaryRef canaryDetails = NULL;
        check(errSecSuccess == SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:canary], kSecCSDefaultFlags, &canaryCode) &&
              errSecSuccess == SecCodeCopySigningInformation(canaryCode, kSecCSSigningInformation, &canaryDetails), @"independent Security API reads native canary signing details");
        NSData* actualHash = ((__bridge NSDictionary*)canaryDetails)[(__bridge NSString*)kSecCodeInfoUnique];
        NSMutableString* expectedHash = [NSMutableString string];
        const uint8_t* hashBytes = actualHash.bytes;
        for(NSUInteger index = 0; index < actualHash.length; index++) [expectedHash appendFormat:@"%02x", hashBytes[index]];
        check([canaryCS[KEY_CS_CDHASH] isEqual:expectedHash], @"extracted CDHash equals Security API original bytes");
        if(canaryDetails) CFRelease(canaryDetails);
        if(canaryCode) CFRelease(canaryCode);
        NSMutableDictionary* canaryInfo = strictInfo();
        canaryInfo[KEY_PATH] = canary;
        canaryInfo[KEY_CS_INFO] = canaryCS;
        Rule* pinnedCanary = [[Rule alloc] init:canaryInfo];
        check(pinnedCanary.isValidStrictProcessTree, @"actual native teamless/ad hoc canary is accepted only with explicit image pin");
        Rule* canaryImport = [[Rule alloc] initFromJSON:ruleJSON(pinnedCanary)];
        check(canaryImport.isValidStrictProcessTree && [canaryImport.csInfo[KEY_CS_CDHASH] isEqual:expectedHash], @"actual canary hash pin JSON round trip");
        archive = [NSKeyedArchiver archivedDataWithRootObject:pinnedCanary requiringSecureCoding:YES error:&error];
        canaryImport = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:archive error:&error];
        check(canaryImport.isValidStrictProcessTree && [canaryImport.csInfo[KEY_CS_CDHASH] isEqual:expectedHash], @"actual canary hash pin secure archive round trip");
        NSMutableDictionary* hashCS = [canaryCS mutableCopy];
        [hashCS removeObjectForKey:KEY_CS_CDHASH];
        canaryInfo[KEY_CS_INFO] = hashCS;
        check(nil == [[Rule alloc] init:canaryInfo], @"actual ad hoc root requires CDHash pin");
        for(id badHash in @[@"", @"012345", @"ABCDEF0123456789ABCDEF0123456789ABCDEF0123", @"g123456789012345678901234567890123456789", @42, NSNull.null])
        {
            hashCS = [canaryCS mutableCopy];
            hashCS[KEY_CS_CDHASH] = badHash;
            canaryInfo[KEY_CS_INFO] = hashCS;
            check(nil == [[Rule alloc] init:canaryInfo], @"reject malformed image hash pin");
        }
        NSMutableDictionary* badHashJSON = ruleJSON(pinnedCanary);
        NSMutableDictionary* badHashSigning = [badHashJSON[@"csInfo"] mutableCopy];
        badHashSigning[KEY_CS_CDHASH] = @"012345";
        badHashJSON[@"csInfo"] = badHashSigning;
        check(nil == [[Rule alloc] initFromJSON:badHashJSON], @"strict JSON rejects malformed image pin");
        Rule* malformedHashArchive = [[Rule alloc] init:strictInfo()];
        malformedHashArchive.csInfo = badHashSigning;
        archive = [NSKeyedArchiver archivedDataWithRootObject:malformedHashArchive requiringSecureCoding:YES error:&error];
        canaryImport = [NSKeyedUnarchiver unarchivedObjectOfClass:Rule.class fromData:archive error:&error];
        check(canaryImport.isStrictProcessTree && !canaryImport.isValidStrictProcessTree && !canaryImport.toJSON, @"malformed archive image pin stays strict and cannot be normalized by export");
        hashCS = [canaryCS mutableCopy];
        hashCS[KEY_CS_STATUS] = @(errSecCSUnsigned);
        canaryInfo[KEY_CS_INFO] = hashCS;
        check(nil == [[Rule alloc] init:canaryInfo], @"hash cannot claim an unsigned status");
        hashCS = [canaryCS mutableCopy];
        hashCS[KEY_CS_STATUS] = @-1;
        canaryInfo[KEY_CS_INFO] = hashCS;
        check(nil == [[Rule alloc] init:canaryInfo], @"hash cannot bypass failed signature validation");
        hashCS = [canaryCS mutableCopy];
        hashCS[KEY_CS_SIGNER] = @(None);
        [hashCS removeObjectForKey:KEY_CS_ID];
        canaryInfo[KEY_CS_INFO] = hashCS;
        check([[[Rule alloc] init:canaryInfo] isValidStrictProcessTree], @"explicit teamless hash pin supports absent signing identifier");
        hashCS[KEY_CS_SIGNER] = @(Apple);
        canaryInfo[KEY_CS_INFO] = hashCS;
        check([[[Rule alloc] init:canaryInfo] isValidStrictProcessTree], @"explicit teamless Apple image pin accepted");
        fprintf(stdout, "PASS: %lu production Rule format checks\n", (unsigned long)checks);
    }
    return 0;
}
