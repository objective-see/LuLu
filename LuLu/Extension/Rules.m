//
//  file: Rules.m
//  project: LuLu (launch daemon)
//  description: handles rules & actions such as add/delete
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Rules.h"
#import "Alerts.h"
#import "consts.h"
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

//alerts obj
extern Alerts* alerts;

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
        
        //save (generated rules)
        if(YES != [self save])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to save (generated) rules");
            
            //bail
            goto bail;
        }

        //dbg msg
        os_log_debug(logHandle, "done generating/saving default rules");
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
        if(nil != csInfo)
        {
            //add
            info[KEY_CS_INFO] = csInfo;
        }
            
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

//get rule's path
// either default, or one in current profile
-(NSString*)getPath
{
    //path
    NSString* path = nil;
    
    //current profile
    NSString* currentProfile =  [preferences getCurrentProfile];
    
    //init path to rule's file
    // which might be in a profile directory
    if(nil != currentProfile)
    {
        path = [currentProfile stringByAppendingPathComponent:RULES_FILE];
    }
    //otherwise default
    else
    {
        //init w/ default
        path = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    }
    
    return path;
}

//load rules from disk
// either default location, or from current profile
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
    
    //item rules
    NSArray* itemRules = nil;
    
    //interval for expirations
    NSTimeInterval timeInterval = 0;
    
    //init path
    rulesFile = [self getPath];
    
    //dbg msg
    os_log_debug(logHandle, "loading rules from: %{public}@", rulesFile);
    
    //(now) load archived rules from disk
    archivedRules = [NSData dataWithContentsOfFile:rulesFile];
    if(nil == archivedRules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load rules from %{public}@", rulesFile);
        
        //bail
        goto bail;
    }
    
    //unarchive
    self.rules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSMutableSet class], [NSDate class], [Rule class]]]
                                                       fromData:archivedRules error:&error];
    if(nil == self.rules)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to unarchive rules from %{public}@ (%{public}@)", RULES_FILE, error);
        
        //bail
        goto bail;
    }
    
    //make sure all item rules have a set for 'external' paths
    // older rules didn't use this, so let's make do it here manually
    for(NSString* key in self.rules)
    {
        //skip global rules
        if(YES == [key isEqualToString:VALUE_ANY])
        {
            continue;
        }
        
        //skip directory rules
        // grab first/any rule and check
        if(YES == ((Rule*)[self.rules[key][KEY_RULES] firstObject]).isDirectory.boolValue)
        {
            continue;
        }
        
        //paths set nil?
        // alloc for paths
        if(nil == self.rules[key][KEY_PATHS])
        {
            //alloc
            self.rules[key][KEY_PATHS] = [NSMutableSet set];
        }
    }
    
    //setup deletion for any rules that have an expiration
    for(NSString* key in self.rules)
    {
        //item rules
        itemRules = self.rules[key][KEY_RULES];
        
        //check each
        for(Rule* rule in itemRules)
        {
            //skip
            if(nil == rule.expiration)
            {
                continue;
            }
            
            //dbg msg
            os_log_debug(logHandle, "loaded rule has an expiration date set: %{public}@", rule.expiration);
            
            //interval
            timeInterval = [rule.expiration timeIntervalSinceNow];
            
            //already expired?
            // just go ahead and delete
            if(timeInterval <= 0)
            {
                //delete
                [self delete:rule.key rule:rule.uuid];
            }
            
            //setup dispatch to delete
            else
            {
                //dbg msg
                os_log_debug(logHandle, "setting up dispatch to delete one expiration is hit");
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    
                    //dbg msg
                    os_log_debug(logHandle, "rule expiration hit, will delete!");
                    
                    //delete
                    [self delete:rule.key rule:rule.uuid];
                    
                    //tell user rules changed
                    [alerts.xpcUserClient rulesChanged];
                    
                });
            }
        }
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
        if(YES != [self add:[[Rule alloc] init:info] save:NO])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add rule");
            
            //skip
            continue;
        }
    }

    //happy
    generated = YES;
    
bail:
    
    return generated;
}

//add a (new) rule
// and if specified, save to disk
-(BOOL)add:(Rule*)rule save:(BOOL)save
{
    //result
    BOOL added = NO;
    
    //interval for expirations
    NSTimeInterval timeInterval = 0;
    
    //dbg msg
    os_log_debug(logHandle, "adding rule: %{public}@ -> %{public}@", rule.key, rule);

    //sanity check
    if(nil == rule)
    {
        //err msg
        os_log_error(logHandle, "ERROR: can't add nil rule");
        
        //bail
        goto bail;
    }
    
    //sync to access
    @synchronized(self.rules)
    {
        //new rule for item
        // need to init array for rules, paths, & cs info
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
            
            //init set for all paths
            self.rules[rule.key][KEY_PATHS] = [NSMutableSet set];
        }
        
        //always add path (for UI)
        // note, insertion into a set is unique
        if(0 != rule.path.length)
        {
            //add
            [self.rules[rule.key][KEY_PATHS] addObject:rule.path];
        }
        
        //(now) add rule
        [self.rules[rule.key][KEY_RULES] addObject:rule];

    } //sync
    
    //handle expirations
    // setup dispatch to delete once it hit
    if(nil != rule.expiration)
    {
        //dbg msg
        os_log_debug(logHandle, "rule has an expiration date set: %{public}@", rule.expiration);
        
        timeInterval = [rule.expiration timeIntervalSinceNow];
        if(timeInterval > 0) {
            
            //dbg msg
            os_log_debug(logHandle, "setting up dispatch to delete one expiration is hit");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                //dbg msg
                os_log_debug(logHandle, "rule expiration hit, will delete!");
                
                //delete
                [self delete:rule.key rule:rule.uuid];
                
                //tell user rules changed
                [alerts.xpcUserClient rulesChanged];
                
            });
        }
    }

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
    //no need to save
    else
    {
        //dbg msg
        os_log_debug(logHandle, "'save' not set (rule is temporary), so no need to write it out to disk");
    }
    
    //happy
    added = YES;
    
bail:
    
    return added;
}

//update an item's cs info
// and also the cs info of all its rule
-(void)updateCSInfo:(Process*)process
{
    //dbg msg
    os_log_debug(logHandle, "updating code signing information for %{public}@ and its rules", process);
    
    //sync
    @synchronized(self.rules)
    {
        //update item's cs info
        self.rules[process.key][KEY_CS_INFO] = process.csInfo;
        
        //update also the cs info of all its rule
        for(Rule* rule in self.rules[process.key][KEY_RULES])
        {
            //update
            rule.csInfo = process.csInfo;
        }
    }
    
    return;
}

//find (matching) rule
-(Rule*)find:(Process*)process flow:(NEFilterSocketFlow*)flow csChange:(BOOL*)csChange
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
            //mismatch?
            // ignore...
            if(YES != matchesCSInfo(process.csInfo, csInfo))
            {
                //set
                *csChange = YES;
                
                //err msg
                os_log_error(logHandle, "ERROR: code signing mismatch: %{public}@ / %{public}@", process.csInfo, csInfo);
                
                //bail
                goto bail;
            }
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
                //skip any disabled rule(s)
                if(0 != rule.isDisabled.intValue) {
                    
                    //dbg msg
                    os_log_debug(logHandle, "skipping disabled rule match %{public}@", rule);
                    
                    //skip
                    continue;
                }
                
                //checks for temp rules
                if(YES == [rule isTemporary])
                {
                    //process?
                    // check process's pid matches rule's pid
                    if( (nil != rule.pid) &&
                        (rule.pid.unsignedIntValue != process.pid) )
                    {
                        //skip
                        continue;
                    }
                }
                
                //expiration?
                // double check if 'now' is after expiration
                if( (nil != rule.expiration) &&
                    ([[NSDate date] compare:rule.expiration] == NSOrderedDescending) )
                {
                    //err msg
                    os_log_error(logHandle, "ERROR: rule %{public}@ has expired, should already have been removed", rule);
                    
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
                    os_log_debug(logHandle, "address and port set (%{public}@:%{public}@), will check both for match", rule.endpointAddr, rule.endpointPort);
                    
                    //match?
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
    
    //endpoint url/hosts
    NSMutableArray* endpointNames = nil;
    
    //endpoint regex
    NSRegularExpression* endpointAddrRegex = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //dbg msg
    os_log_debug(logHandle, "%s", __PRETTY_FUNCTION__);
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //init endpoint names
    endpointNames = [NSMutableArray array];
    
    //add url
    // and just host (as this is what is shown in alert)
    if(nil != flow.URL.absoluteString)
    {
        //add full url
        [endpointNames addObject:flow.URL.absoluteString];
        
        //add host
        [endpointNames addObject:flow.URL.host];
    }
    
    //add host name
    if(nil != remoteEndpoint.hostname)
    {
        //add
        [endpointNames addObject:remoteEndpoint.hostname];
    }
    
    //macOS 11+?
    // add remote host name
    if(@available(macOS 11, *))
    {
        //add remote host name
        if(nil != flow.remoteHostname)
        {
            //add
            [endpointNames addObject:flow.remoteHostname];
        }
    }
    
    //dbg msg
    os_log_debug(logHandle, "checking rule's endpoint address (%{public}@) and rule's endpoint host %{public}@ against %{public}@", rule.endpointAddr, rule.endpointHost, endpointNames);
    
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
        
        //check each
        for(NSString* endpointName in endpointNames)
        {
            //match?
            if(0 != [endpointAddrRegex numberOfMatchesInString:endpointName options:0 range:NSMakeRange(0, endpointName.length)])
            {
                //dbg msg
                os_log_debug(logHandle, "rule match: regex on %{public}@", endpointName);
                
                //match
                isMatch = YES;
                
                //bail
                goto bail;
            }
        }
    }
    
    //not regex
    // check rule's endpoint address and host for (exact) match
    else
    {
        //check each
        for(NSString* endpointName in endpointNames)
        {
            //dbg msg
            os_log_debug(logHandle, "checking %{public}@ vs. %{public}@", rule.endpointAddr, endpointName);
            
            //check against rule's endpoint address
            if(NSOrderedSame == [rule.endpointAddr caseInsensitiveCompare:endpointName])
            {
                //dbg msg
                os_log_debug(logHandle, "rule match (endpoint address): %{public}@", endpointName);
                
                //match
                isMatch = YES;
                goto bail;
            }
            
            //(also) check against rule's endpoint host
            if( (nil != rule.endpointHost) &&
                (NSOrderedSame == [rule.endpointHost caseInsensitiveCompare:endpointName]) )
            {
                //dbg msg
                os_log_debug(logHandle, "rule match: (endpoint host) %{public}@", endpointName);
                
                //match
                isMatch = YES;
                goto bail;
            }
        }
    }
    
bail:
        
    return isMatch;
}

//toggle rule
// either disable, or (re)enable
-(BOOL)toggleRule:(NSString*)key rule:(NSString*)uuid
{
    //result
    BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "toggling rule, key: %{public}@, rule id: %{public}@", key, uuid);
    
    //sync to access
    @synchronized(self.rules)
    {
        //no uuid
        // toggle all (process') rules
        if(nil == uuid)
        {
            //toggle all
            for(Rule* rule in self.rules[key][KEY_RULES])
            {
                //toggle each
                rule.isDisabled = (rule.isDisabled.boolValue) ? nil : @YES;
            }
            
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
                //toggle each
                currentRule.isDisabled = (currentRule.isDisabled.boolValue) ? nil : @YES;
            
                //done
                *stop = YES;
            }
        }];
        
    } //sync
        
    //happy
    result = YES;
    
bail:
    
    //always save to disk
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save (toggled) rules");
        
        //not happy
        result = NO;
    }
    
    return result;
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
        
        //not happy
        result = NO;
    }
    
    return result;
}

//save to disk
// note: temporary rules are ignored
-(BOOL)save
{
    //result
    BOOL result = NO;
    
    //error
    NSError* error = nil;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //persistent rules
    NSMutableDictionary* persistentRules = nil;
    
    //archived rules
    NSData* archivedRules = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //init
    persistentRules = [NSMutableDictionary dictionary];
    
    //init path
    rulesFile = [self getPath];
    
    //dbg msg
    os_log_debug(logHandle, "saving (non-temp) rules to %{public}@", rulesFile);
    
    //sync to save
    @synchronized(self) {
        
        //generate list of non-temp rules
        // these are the ones we'll write out
        for(NSString* key in self.rules.allKeys)
        {
            //item's rules
            NSMutableArray* itemRules = nil;
            
            //init
            itemRules = [NSMutableArray array];
            
            //add only non-temporary rules
            for(Rule* itemRule in self.rules[key][KEY_RULES])
            {
                //temp?
                if(YES == [itemRule isTemporary])
                {
                    //skip
                    continue;
                }
                
                //add
                [itemRules addObject:itemRule];
            }
            
            //any non-temp rules?
            // add to rules we're going to write out
            if(0 != itemRules.count)
            {
                //start w/ empty dictionary
                persistentRules[key] = [NSMutableDictionary dictionary];
                                
                //add (non-temp) rules
                persistentRules[key][KEY_RULES] = itemRules;
                
                //add cs info
                if(nil != self.rules[key][KEY_CS_INFO])
                {
                    //add
                    persistentRules[key][KEY_CS_INFO] = self.rules[key][KEY_CS_INFO];
                }
                
                //add paths info
                if(nil != self.rules[key][KEY_PATHS])
                {
                    //add
                    persistentRules[key][KEY_PATHS] = self.rules[key][KEY_PATHS];
                }
            }
        }
        
        //serialize
        archivedRules = [NSKeyedArchiver archivedDataWithRootObject:persistentRules requiringSecureCoding:YES error:&error];
        if(nil == archivedRules)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to serialize rules: %{public}@", error);
                
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "serialized rules");
        
        //write out rules
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

//import rules
-(BOOL)import:(NSData*)importedRules
{
    //flag
    BOOL result = NO;
    
    //unserialized rules
    NSDictionary* unarchivedRules = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@", __PRETTY_FUNCTION__, importedRules);
    
    //sanity check
    if(YES != [importedRules isKindOfClass:[NSData class]])
    {
        //err msg
        os_log_error(logHandle, "ERROR: imported rules are not a NSData");
        goto bail;
    }
        
    //unarchive
    unarchivedRules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSMutableSet class], [NSDate class], [Rule class]]] fromData:importedRules error:&error];
    
    //error?
    if( (nil != error) ||
        (nil == unarchivedRules) )
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to unarchive (imported) rules (error: %{public}@)", error);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "unarchived (imported) %lu rules", (unsigned long)unarchivedRules.count);
    
    //update
    @synchronized (self)
    {
        //update
        self.rules = [unarchivedRules mutableCopy];
    }
    
    //save
    if(YES != [self save])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to save (imported) rules");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "saved (imported) rules");
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//cleanup
// a) rule expired
// a) path was deleted
// b) point to non-existent processes (temp rule)
-(NSUInteger)cleanup
{
    //count
    NSUInteger deletedRules = 0;
    
    //rules to delete
    NSMutableArray* rules2Delete = nil;
    
    //dbg msg
    os_log_debug(logHandle, "cleaning up rules");
    
    //alloc
    rules2Delete = [NSMutableArray array];
    
    //sync to access
    @synchronized(self.rules)
    {
        //gather all rules with deleted paths
        for(NSString* key in self.rules.allKeys)
        {
            //paths
            NSArray* paths = nil;
            
            //path
            NSString* path = nil;
            
            //rules for item
            NSArray* rules = nil;
            
            //(first) rule
            Rule* rule = nil;
            
            //flag
            BOOL allDeleted = YES;
            
            //interval for expiration check
            NSTimeInterval timeInterval = 0;
            
            //extract 'external' paths
            paths = self.rules[key][KEY_PATHS];
            
            //extract rules for item
            rules = self.rules[key][KEY_RULES];
            
            //extract (first) rule
            rule = rules.firstObject;
            
            //skip global rules
            if(YES == rule.isGlobal.boolValue)
            {
                //skip
                continue;
            }
            
            //directory rule?
            // check if directory has been deleted
            if(YES == rule.isDirectory.boolValue)
            {
                //directory rules end in /*
                // so first remove the trailing '*'
                path = [rule.path substringToIndex:path.length - 1];
                
                //was directory deleted?
                if(YES != [NSFileManager.defaultManager fileExistsAtPath:path])
                {
                    //dbg msg
                    os_log_debug(logHandle, "%{public}@ is gone, will delete directory rule", path);
                    
                    //add to list
                    [rules2Delete addObject:rule];
                }
                
                //next
                continue;
            }
            
            //for (normal) item rules
            // first set flag if all 'external' paths have been deleted
            for(NSString* path in paths)
            {
                //path still there?
                if(YES == [NSFileManager.defaultManager fileExistsAtPath:path])
                {
                    //toggle
                    allDeleted = NO;
                    
                    //done
                    break;
                }
            }
            
            //check each rule's 'internal' path
            // and expiration, and process id (temp rules)
            for(Rule* rule in rules)
            {
                //was path deleted?
                // and all 'external' paths too?
                if( (YES == allDeleted) &&
                    (YES != [NSFileManager.defaultManager fileExistsAtPath:rule.path]))
                {
                    //dbg msg
                    os_log_debug(logHandle, "%{public}@ is gone - will delete rule", rule.path);
                    
                    //add to list
                    [rules2Delete addObject:rule];
                    
                    //next
                    continue;
                }
                
                //did process (for temp rule) exit?
                if( (YES == [rule isTemporary]) &&
                    (YES != isAlive(rule.pid.intValue)) )
                {
                    //dbg msg
                    os_log_debug(logHandle, "process-level (temporary) rule's process (%@) has exited - will delete rule", rule.pid);
                    
                    //add to list
                    [rules2Delete addObject:rule];
                    
                    //next
                    continue;
                }
                
                //did rule expire?
                if(nil != rule.expiration)
                {
                    //compute interval
                    // and check if it expired
                    timeInterval = [rule.expiration timeIntervalSinceNow];
                    if(timeInterval <= 0)
                    {
                        //dbg msg
                        os_log_debug(logHandle, "rule's expiration has hit (%@) - will delete rule", rule.expiration);
                        
                        //add to list
                        [rules2Delete addObject:rule];
                        
                        //next
                        continue;
                    }
                }
            }
        }
    }
    
    //save count
    deletedRules = rules2Delete.count;
    
    //now delete each
    for(Rule* rule in rules2Delete)
    {
        //delete
        [self delete:rule.key rule:rule.uuid];
    }
    
    //dbg msg
    os_log_debug(logHandle, "cleaned up/deleted %ld rules", (long)deletedRules);
    
    return deletedRules;
}

@end
