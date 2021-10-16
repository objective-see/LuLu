//
//  file: Rules.m
//  project: LuLu (launch daemon)
//  description: handles rules & actions such as add/delete
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"

#import "Rule.h"
#import "Rules.h"
#import "Process.h"
#import "utilities.h"
#import "Preferences.h"

//default systems 'allow' rules
NSString* const DEFAULT_RULES[] =
{
    @"/System/Library/PrivateFrameworks/ApplePushService.framework/apsd",
    @"/System/Library/PrivateFrameworks/AssistantServices.framework/Versions/A/Support/assistantd"
    @"/usr/sbin/automount",
    @"/System/Library/PrivateFrameworks/HelpData.framework/Versions/A/Resources/helpd",
    @"/usr/sbin/mDNSResponder",
    @"/sbin/mount_nfs",
    @"/usr/libexec/mount_url",
    @"/usr/sbin/ocspd",
    @"/usr/bin/sntp",
    @"/usr/libexec/trustd"
};

/* format of rules
    dictionary of dictionaries
    key: signing id or item path (if unsigned)
    values: dictionary with:
        key: 'rules':
        value: array of rules
 
        key: 'csFlags':
        value: item's code signing flags
*/

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//prefs obj
extern Preferences* preferences;

@implementation Rules

@synthesize rules;
@synthesize xpcUserClient;

//init method
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc rules dictionary
        rules = [NSMutableDictionary dictionary];
        
        //init XPC client
        xpcUserClient = [[XPCUserClient alloc] init];
    }
    
    return self;
}

//prepare
// first time? generate defaults rules
// upgrade (v1.0)? convert to new format
-(BOOL)prepare
{
    //flag
    BOOL prepared = NO;

    //error
    NSError* error = nil;
    
    //old rule's file
    NSString* rulesFile_V1 = nil;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //init path to old rule's file
    rulesFile_V1 = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE_V1];
    
    //init path to rule's file
    rulesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    //first check for old rules
    // ...and then upgrade to v2 format
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:rulesFile_V1])
    {
        //dbg msg
        os_log_debug(logHandle, "found v1.0 rules: %{public}@", rulesFile_V1);
        
        //upgrade
        if(YES != [self upgrade:[NSDictionary dictionaryWithContentsOfFile:rulesFile_V1]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to upgrade rules");
            
            //but continue
            // will revert to generating default rules
        }
        
        //always delete rule v1.0 file
        if(YES != [NSFileManager.defaultManager removeItemAtPath:rulesFile_V1 error:&error])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to removed v1.0 rules: %{public}@", rulesFile_V1);
            
        } else os_log_debug(logHandle, "removed v1.0 rules: %{public}@", rulesFile_V1);
        
    } else os_log_debug(logHandle, "no v1.0 rules...");
    
    //(still) no rules?
    // first time, so generate default rules
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:rulesFile])
    {
        //dbg msg
        os_log_debug(logHandle, "no rules found");
        
        //generate
        if(YES != [self generateDefaultRules])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to generate default rules");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "done generating default rules");
    }
    
    //happy
    prepared = YES;

bail:
    
    return prepared;
}
    
//upgrade rules from v1.0
// note: delete rules for paths the don't exist
-(BOOL)upgrade:(NSDictionary*)rules_v1
{
    //flag
    BOOL upgraded = NO;

    //dbg msg
    os_log_debug(logHandle, "upgrading v1 rules...");

    //upgrade all rules
    for(NSString* key in rules_v1)
    {
        //value
        NSDictionary* value = nil;
        
        //code signing info
        NSMutableDictionary* csInfo = nil;
        
        //info
        NSMutableDictionary* info = nil;
        
        //item doesn't exit?
        // just ignore it, and continue
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:key])
        {
            //dbg msg
            os_log_debug(logHandle, "ignoring (v1) rule for %{public}@, as it no longer exists on disk", key);
            
            //ignore
            continue;
        }
        
        //extact value
        value = rules_v1[key];
        
        //init info
        info = [NSMutableDictionary dictionary];
        
        //add path
        info[KEY_PATH] = key;
        
        //add action
        info[KEY_ACTION] = value[KEY_ACTION];
        
        //add type
        info[KEY_TYPE] = value[KEY_TYPE];
        
        //extact cs info
        csInfo = [value[KEY_CS_INFO] mutableCopy];
        
        //remove entitlments
        // not needed and can be loooong
        csInfo[KEY_CS_ENTITLEMENTS] = nil;
    
        //add cs info
        if(nil != csInfo) info[KEY_CS_INFO] = csInfo;
            
        //add
        // note: will save after loop
        if(YES != [self add:[[Rule alloc] init:info] save:NO])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add rule");
            
            //skip
            continue;
        }
    }
    
    //save
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save v1 -> v2 rules");
        
        //bail
        goto bail;
    }
    
    //happy
    upgraded = YES;
    
bail:
    
    return upgraded;
}

//load rules from disk
-(BOOL)load
{
    //result
    BOOL result = NO;
    
    //error
    NSError* error = nil;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //archived rules
    NSData* archivedRules = nil;
    
    //init path to rule's file
    rulesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    //dbg msg
    os_log_debug(logHandle, "loading rules from: %{public}@", rulesFile);
    
    //dbg msg
    os_log_debug(logHandle, "loading rules from %{public}@", RULES_FILE);
    
    //(now) load archived rules from disk
    archivedRules = [NSData dataWithContentsOfFile:rulesFile];
    if(nil == archivedRules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load rules from %{public}@", RULES_FILE);
        
        //bail
        goto bail;
    }
    
    //unarchive
    self.rules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [Rule class]]]
                                                       fromData:archivedRules error:&error];
    if(nil == self.rules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to unarchive rules from %{public}@ (%{public}@)", RULES_FILE, error);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded %lu rules", (unsigned long)self.rules.count);
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//generate default rules
-(BOOL)generateDefaultRules
{
    //flag
    BOOL generated = NO;
    
    //default binary
    NSString* defaultBinary = nil;
    
    //(rule) info
    NSMutableDictionary* info = nil;
    
    //binary
    Binary* binary = nil;
    
    //set cs flags
    SecCSFlags flags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSDoNotValidateResources | kSecCSCheckAllArchitectures;
    
    //dbg msg
    os_log_debug(logHandle, "generating default rules");
    
    //iterate overall default rule paths
    // generate binary obj/signing info for each
    for(NSUInteger i=0; i<sizeof(DEFAULT_RULES)/sizeof(DEFAULT_RULES[0]); i++)
    {
        //extract binary
        defaultBinary = DEFAULT_RULES[i];
        
        //dbg msg
        os_log_debug(logHandle, "processing (default) binary, %{public}@", defaultBinary);
        
        //skip if binary doesn't exist
        // some don't on newer versions of macOS
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:defaultBinary]) continue;
        
        //init binary
        binary = [[Binary alloc] init:DEFAULT_RULES[i]];
        if(nil == binary)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to generate binary for default rule: %{public}@", DEFAULT_RULES[i]);
            
            //skip
            continue;
        }
        
        //generate signing info
        [binary generateSigningInfo:flags];
        
        //alloc for (rule) info
        info = [@{KEY_PATH:binary.path, KEY_ACTION:@RULE_STATE_ALLOW, KEY_TYPE:@RULE_TYPE_DEFAULT} mutableCopy];
        
        //add binary cs info
        if(nil != binary.csInfo) info[KEY_CS_INFO] = binary.csInfo;
        
        //add
        // note: will save after loop
        if(YES != [self add:[[Rule alloc] init:info] save:NO])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add rule");
            
            //skip
            continue;
        }
    }
    
    //save
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save (generated) rules");
        
        //bail
        goto bail;
    }

    //happy
    generated = YES;
    
bail:
    
    return generated;
}

//add a rule
// and if specified, save to disk
-(BOOL)add:(Rule*)rule save:(BOOL)save
{
    //result
    BOOL added = NO;
    
    //dbg msg
    os_log_debug(logHandle, "adding rule: %{public}@ -> %{public}@", rule.key, rule);

    //sycn to access
    @synchronized(self.rules)
    {
        //new rule for process
        // need to init array and cs info
        if(nil == self.rules[rule.key])
        {
            //init
            self.rules[rule.key] = [NSMutableDictionary dictionary];
            
            //init (proc) rules
            self.rules[rule.key][KEY_RULES] = [NSMutableArray array];
            
            //add cs info
            if(nil != rule.csInfo)
            {
                //add
                self.rules[rule.key][KEY_CS_INFO] = rule.csInfo;
            }
        }
        
        //(now) add rule
        [self.rules[rule.key][KEY_RULES] addObject:rule];

    } //sync
    
    //save
    if(YES == save)
    {
        //save
        if(YES != [self save])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to save rules");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "saved rule to disk");
    }
    
    //happy
    added = YES;
    
bail:
    
    return added;
}

//find (matching) rule
-(Rule*)find:(Process*)process flow:(NEFilterSocketFlow*)flow
{
    //rule's cs info
    NSDictionary* csInfo = nil;
    
    //matching rule
    Rule* matchingRule = nil;
    
    //global rules
    NSArray* globalRules = nil;
    
    //directory rules
    NSMutableArray* directoryRules = nil;
    
    //item's rules
    NSArray* itemRules = nil;
    
    //canidate rules
    NSMutableArray* candidateRules = nil;
    
    //any match
    // item has a '*:*' rule
    Rule* anyMatch = nil;
    
    //partial match
    // *:port or ip:*
    Rule* partialMatch = nil;
    
    //exact match
    Rule* extactMatch = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //dbg msg
    os_log_debug(logHandle, "looking for rule for %{public}@ -> %{public}@", process.key, process.path);
    
    //sync to access
    @synchronized(self.rules)
    {
        //item rules
        itemRules = self.rules[process.key][KEY_RULES];
        
        //extract cs info
        csInfo = self.rules[process.key][KEY_CS_INFO];
            
        //cs info?
        // make sure it (still) matches
        if(nil != csInfo)
        {
            //match?
            if(YES == [process.csInfo isEqualToDictionary:csInfo])
            {
                //item rules
                itemRules = self.rules[process.key][KEY_RULES];
            }
            //no match
            // just print err msg
            else os_log_error(logHandle, "ERROR: code signing mismatch: %{public}@ / %{public}@", process.csInfo, csInfo);
        }
       
        //grab global rules
        globalRules = self.rules[VALUE_ANY][KEY_RULES];
        
        //init directory rules
        directoryRules = [NSMutableArray array];
        
        //add any directory rules
        // i.e. any rule that's '/<anything>*'
        for(NSString* key in self.rules)
        {
            //directory
            NSString* directory = nil;
            
            //directory rule?
            // grab first/any rule and check
            if(YES == ((Rule*)[self.rules[key][KEY_RULES] firstObject]).isDirectory.boolValue)
            {
                //init directory
                // ...by removing *
                directory = [key substringToIndex:(key.length-1)];
                
                //does item fall within dir?
                if(YES == [process.path hasPrefix:directory])
                {
                    //add
                    [directoryRules addObjectsFromArray:self.rules[key][KEY_RULES]];
                }
            }
        }
        
        //no global, directory, nor item rules
        // bail, with no match so user is prompted
        if( (nil == itemRules) &&
            (nil == globalRules) &&
            (0 == directoryRules.count) )
        {
            //no match
            goto bail;
        }
        
        //init candidate rules
        candidateRules = [NSMutableArray array];
        
        //add global rules first
        if(nil != globalRules) [candidateRules addObject:globalRules];
        
        //add directory rules next
        if(0 != directoryRules.count) [candidateRules addObject:directoryRules];
        
        //add item's rules last...
        if(nil != itemRules) [candidateRules addObject:itemRules];
        
        //extract remote endpoint
        remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
        
        //check each set of rules
        // set: global, directory, and/or item rules
        for(NSArray* rules in candidateRules)
        {
            //check all set of rules
            // note: * is a wildcard, meaning any match
            for(Rule* rule in rules)
            {
                //ingore if rule is temporary
                // and this pid doesn't match
                if( (nil != rule.pid) &&
                    (rule.pid.unsignedIntValue != process.pid) )
                {
                    //skip
                    continue;
                }
                
                //any match?
                if( (YES == [rule.endpointAddr isEqualToString:VALUE_ANY]) &&
                    (YES == [rule.endpointPort isEqualToString:VALUE_ANY]) )
                {
                    //dbg msg
                    os_log_debug(logHandle, "rule match: 'any'");
                    
                    //any
                    anyMatch = rule;
                    
                    //next
                    continue;
                }
                
                //port is any?
                // check for (partial) rule match: endpoint addr
                else if(YES == [rule.endpointPort isEqualToString:VALUE_ANY])
                {
                    //dbg msg
                    os_log_debug(logHandle, "rule port is any ('*'), will check host/url");
                    
                    //check endpoint host/url
                    if(YES == [self endpointAddrMatch:flow rule:rule])
                    {
                        //dbg msg
                        os_log_debug(logHandle, "rule match: 'partial' (endpoint addr)");
                        
                        //partial
                        partialMatch = rule;
                        
                        //next
                        continue;
                    }
                }
                
                //endpoint addr is any?
                // check for (partial) rule match: endpoint port
                else if(YES == [rule.endpointAddr isEqualToString:VALUE_ANY])
                {
                    //dbg msg
                    os_log_debug(logHandle, "rule address is any ('*'), will check port");
                    
                    //addr is any
                    //so check the port
                    if(YES == [rule.endpointPort isEqualToString:remoteEndpoint.port])
                    {
                        //dbg msg
                        os_log_debug(logHandle, "rule match: 'partial' (endpoint port)");
                        
                        //partial
                        partialMatch = rule;
                        
                        //next
                        continue;
                    }
                }
                
                //addr and port both set (not '*')
                // check that both endpoint addr and port match
                else
                {
                    //dbg msg
                    os_log_debug(logHandle, "address and port set, will check both for match");
                    
                    //port match?
                    if( (YES == [self endpointAddrMatch:flow rule:rule]) &&
                        (YES == [rule.endpointPort isEqualToString:remoteEndpoint.port]) )
                    {
                        //dbg msg
                            os_log_debug(logHandle, "rule match: 'exact'");
                            
                            //exact
                            extactMatch = rule;
                            
                            //next
                            continue;
                    }
                }
                    
            } //all rule set
        
        } //all candidate rules
        
        //extact match?
        if(nil != extactMatch) matchingRule = extactMatch;
        
        //partial match?
        else if (nil != partialMatch) matchingRule = partialMatch;
        
        //any match?
        else if (nil != anyMatch) matchingRule = anyMatch;
    
    }//sync
        
bail:
    
    return matchingRule;
}

//check if endpoint host or url matches
// extra logic for checking/applying regex, etc...
-(BOOL)endpointAddrMatch:(NEFilterSocketFlow*)flow rule:(Rule*)rule
{
    //match
    BOOL isMatch = NO;
    
    //error
    NSError* error = nil;
    
    //endpoint regex
    NSRegularExpression* endpointAddrRegex = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //endpoint addr a regex?
    // init regex and check for match
    if(YES == rule.isEndpointAddrRegex)
    {
        //dbg msg
        os_log_debug(logHandle, "rule's endpoint address is a regex...");
        
        //init regex
        endpointAddrRegex = [NSRegularExpression regularExpressionWithPattern:rule.endpointAddr options:0 error:&error];
        if(nil == endpointAddrRegex)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to created regex from %{public}@ (error: %{public}@)", rule.endpointAddr, error);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "regex check: %{public}@ against %{public}@", rule.endpointAddr, remoteEndpoint.hostname);
        
        //check host name for regex match
        if( (nil != remoteEndpoint.hostname) &&
            (0 != [endpointAddrRegex numberOfMatchesInString:remoteEndpoint.hostname options:0 range:NSMakeRange(0, remoteEndpoint.hostname.length)]) )
        {
            //dbg msg
            os_log_debug(logHandle, "rule match: regex (endpoint hostname)");
            
            //match
            isMatch = YES;
            
            //bail
            goto bail;
        }
        
        //check url for regex match
        if( (nil != flow.URL.absoluteString) &&
            (0 != [endpointAddrRegex numberOfMatchesInString:flow.URL.absoluteString options:0 range:NSMakeRange(0, flow.URL.absoluteString.length)]) )
        {
            //dbg msg
            os_log_debug(logHandle, "rule match: regex (endpoint url)");
            
            //match
            isMatch = YES;
            
            //bail
            goto bail;
        }
    }
    
    //not regex
    // just check host and url for exact match
    else
    {
        if( (YES == [rule.endpointAddr isEqualToString:remoteEndpoint.hostname]) ||
            (YES == [rule.endpointAddr isEqualToString:flow.URL.absoluteString]) )
        {
            //dbg msg
            os_log_debug(logHandle, "rule match: endpoint host||url");
            
            //match
            isMatch = YES;
            
            //bail
            goto bail;
        }
    }
    
bail:
        
    return isMatch;
}

//delete rule
-(BOOL)delete:(NSString*)key rule:(NSString*)uuid
{
    //result
    BOOL result = NO;
    
    //rule index
    __block NSUInteger ruleIndex = -1;
    
    //dbg msg
    os_log_debug(logHandle, "deleting rule, key: %{public}@, rule id: %{public}@", key, uuid);
    
    //sync to access
    @synchronized(self.rules)
    {
        //no uuid
        // delete all (process') rules
        if(nil == uuid)
        {
            //remove
            [self.rules removeObjectForKey:key];
            
            //happy
            result = YES;
            
            //done
            goto bail;
        }
        
        //find matching rule
        [self.rules[key][KEY_RULES] enumerateObjectsUsingBlock:^(Rule* currentRule, NSUInteger index, BOOL* stop)
        {
            //is match?
            if(YES == [currentRule.uuid isEqualToString:uuid])
            {
                //save index
                ruleIndex = index;
            
                //stop
                *stop = YES;
            }
        }];
        
        //dbg msg
        os_log_debug(logHandle, "found rule at index: %lu", (unsigned long)ruleIndex);
        
        //remove
        if(-1 != ruleIndex)
        {
            //remove
            [self.rules[key][KEY_RULES] removeObjectAtIndex:ruleIndex];
            
            //last (item) rule?
            if(0 == ((NSMutableArray*)self.rules[key][KEY_RULES]).count)
            {
                //dbg msg
                os_log_debug(logHandle, "rule was only/last one for %{public}@, so removing item entry", key);
                
                //remove process
                [self.rules removeObjectForKey:key];
            }
        }
        
    } //sync
        
    //happy
    result = YES;
    
bail:
    
    //always save to disk
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save (updated) rules");
        
        //bail
        goto bail;
    }
    
    return result;
}

//save to disk
// note: temporary rules are ignored
// note: temporary rules for (now) dead processes are removed
-(BOOL)save
{
    //result
    BOOL result = NO;
    
    //error
    NSError* error = nil;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //(non-temp) rules
    NSMutableDictionary* persistentRules = nil;
    
    //archived rules
    NSData* archivedRules = nil;
    
    //init path to rule's file
    rulesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    //init persistent rules
    persistentRules = [NSMutableDictionary dictionary];
    
    //dbg msg
    os_log_debug(logHandle, "saving rules to %{public}@", rulesFile);
    
    //sync to access
    @synchronized(self.rules) {
    
        //generate list of persistent rules
        for(NSString* key in self.rules.allKeys)
        {
            //item's rules
            NSMutableArray* rules = nil;
            
            //init
            rules = self.rules[key][KEY_RULES];
            
            //first
            // prune any temporary rules for dead processes
            for(NSInteger i = rules.count-1; i >= 0; i--)
            {
                //pid
                NSNumber* processID = nil;
                
                //init
                processID = ((Rule*)(rules[i])).pid;
                
                //if rule has a pid
                // it's temporary, so check if process still alive
                if( (nil != processID) &&
                    (YES != isAlive(processID.unsignedIntValue)) )
                {
                    //remove
                    [rules removeObjectAtIndex:i];
                }
            }
            
            //no more rules?
            // i.e. all were temp to now dead processes...
            if(0 == rules.count)
            {
                //remove process
                [self.rules removeObjectForKey:key];
                
                //next
                continue;
            }
            
            //(re)init w/ make copy
            // ...as we're now going to filter out temp rules
            rules = [self.rules[key][KEY_RULES] mutableCopy];
            
            //remove temporary rules
            for(NSInteger i = rules.count-1; i >= 0; i--)
            {
                //if rule has a pid
                // it's temporary, and thus, remove
                if(nil != ((Rule*)(rules[i])).pid)
                {
                    //remove
                    [rules removeObjectAtIndex:i];
                }
            }
            
            //add if process (still) has persistent rules
            if(0 != rules.count)
            {
                //copy
                persistentRules[key] = self.rules[key];
                
                //but add only persistent rules
                persistentRules[key][KEY_RULES] = rules;
            }
        }
        
        //archive persistent rules
        archivedRules = [NSKeyedArchiver archivedDataWithRootObject:persistentRules requiringSecureCoding:YES error:&error];
        if(nil == archivedRules)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to archive rules: %{public}@", error);
            
            //bail
            goto bail;
        }
        
        //write out persistent rules
        if(YES != [archivedRules writeToFile:rulesFile atomically:YES])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to save archived rules to: %{public}@", rulesFile);
            
            //bail
            goto bail;
        }
        
    } //sync
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

@end
