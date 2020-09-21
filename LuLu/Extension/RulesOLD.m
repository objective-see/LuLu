//
//  file: Rules.m
//  project: lulu (launch daemon)
//  description: handles rules & actions such as add/delete
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"

#import "Rule.h"
#import "Rules.h"
#import "logging.h"
#import "Baseline.h"
#import "KextComms.h"
#import "utilities.h"
#import "Preferences.h"

//default systems 'allow' rules
NSString* const DEFAULT_RULES[] =
{
    @"/System/Library/PrivateFrameworks/ApplePushService.framework/apsd",
    @"/System/Library/CoreServices/AppleIDAuthAgent",
    @"/System/Library/PrivateFrameworks/AssistantServices.framework/assistantd",
    @"/usr/sbin/automount",
    @"/System/Library/PrivateFrameworks/HelpData.framework/Versions/A/Resources/helpd",
    @"/usr/sbin/mDNSResponder",
    @"/sbin/mount_nfs",
    @"/usr/libexec/mount_url",
    @"/usr/sbin/ntpd",
    @"/usr/sbin/ocspd",
    @"/usr/bin/sntp",
    @"/usr/libexec/trustd"
};

/* GLOBALS */

//kext comms object
extern KextComms* kextComms;

//baseline obj
extern Baseline* baseline;

//prefs obj
extern Preferences* preferences;

//log handle
extern os_log_t logHandle;

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

//load rules from disk
-(BOOL)load
{
    //result
    BOOL result = NO;
    
    //rule's file
    NSString* rulesFile = nil;
    
    //serialized rules
    NSDictionary* serializedRules = nil;
    
    //rules obj
    Rule* rule = nil;
    
    //init path to rule's file
    rulesFile = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    //sync rule generation
    // if a user imports rules, while this code is running, that's not ideal!
    @synchronized(self)
    {
        //don't exist?
        // likely first time, so generate default rules
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:rulesFile])
        {
            //generate
            if(YES != [self generateDefaultRules])
            {
                //err msg
                os_log(logHandle, "ERROR: failed to generate default rules");
                
                //bail
                goto bail;
            }
            
            //dbg msg
            os_log_debug(logHandle, "generated default rules");
        }
    }

    //load serialized rules from disk
    serializedRules = [NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE]];
    if(nil == serializedRules)
    {
        //err msg
        os_log(logHandle, "ERROR: failed to load rules from: %{public}@", RULES_FILE);
        
        //bail
        goto bail;
    }
    
    //create rule objects for each
    for(NSString* key in serializedRules)
    {
        //init
        rule = [[Rule alloc] init:key info:serializedRules[key]];
        if(nil == rule)
        {
            //err msg
            os_log(logHandle, "ERROR: failed to load rule for %{public}@", key);
            
            //skip
            continue;
        }
        
        //add
        self.rules[rule.path] = rule;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded %lu rules from: %{public}@", (unsigned long)self.rules.count, RULES_FILE);
    
    //tell user (via XPC) rules changed
    [self.xpcUserClient rulesChanged:[self serialize]];
    
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
    
    //binary
    Binary* binary = nil;
    
    //default cs flags
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
        os_log_debug(logHandle, "processing default binary, %{public}@", defaultBinary);
        
        //skip if binary doesn't exist
        // some don't on newer versions of macOS
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:defaultBinary])
        {
            //skip
            continue;
        }
        
        //init binary
        binary = [[Binary alloc] init:DEFAULT_RULES[i]];
        if(nil == binary)
        {
            //err msg
            os_log(logHandle, "ERROR: failed to generate binary for default rule: %{public}@", DEFAULT_RULES[i]);
            
            //skip
            continue;
        }
        
        //generate signing info
        [binary generateSigningInfo:flags];
        
        //add
        if(YES != [self add:binary.path signingInfo:binary.signingInfo action:RULE_STATE_ALLOW type:RULE_TYPE_DEFAULT user:0])
        {
            //err msg
            os_log(logHandle, "ERROR: failed to add rule");
            
            //skip
            continue;
        }
    }
    
    //dbg msg
    os_log_debug(logHandle, "generated (added) %lu default rules", sizeof(DEFAULT_RULES)/sizeof(DEFAULT_RULES[0]));
    
    //happy
    generated = YES;
    
bail:
    
    return generated;
}

//save to disk
-(BOOL)save
{
    //result
    BOOL result = NO;
    
    //serialized rules
    NSDictionary* serializedRules = nil;

    //serialize
    serializedRules = [self serialize];
    
    //write out
    if(YES != [serializedRules writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE] atomically:YES])
    {
        //err msg
        os_log(logHandle, "ERROR: failed to save rules to: %@", RULES_FILE);
        
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//convert list of rule objects to dictionary
-(NSMutableDictionary*)serialize
{
    //serialized rules
    NSMutableDictionary* serializedRules = nil;
    
    //alloc
    serializedRules = [NSMutableDictionary dictionary];
    
    //sync to access
    @synchronized(self.rules)
    {
        //iterate over all
        // serialize & add each rule
        for(NSString* path in self.rules)
        {
            //covert/add
            serializedRules[path] = [rules[path] serialize];
        }
    }
    
    return serializedRules;
}

//find rule
// look up by path, then verify that signing info/hash (still) matches
-(Rule*)find:(Process*)process
{
    //candiate (matching) rule
    Rule* candidateRule = nil;
    
    //matching rule
    Rule* matchingRule = nil;
    
    //signing status
    OSStatus signingStatus = !errSecSuccess;
    
    //thread priority
    double threadPriority = 0.0f;
    
    //default cs flags
    // note: since this is dynamic check, we don't need to check all architectures
    SecCSFlags flags = kSecCSDefaultFlags;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"attempting to find rule for process: %@ (%d)", process.path, process.pid]);
    
    //sync to access
    @synchronized(self.rules)
    {
        //always look up rule by path
        // key: full path of process/binary
        candidateRule = [self.rules objectForKey:process.path];
        
        //not found but 'global' set?
        // check for match via identifier
        if( (nil == candidateRule) &&
            (YES == [preferences.preferences[PREF_ALLOW_GLOBALLY] boolValue]) )
        {
            //find by code signing identifier
            candidateRule = [self findByIdentifier:process];
        }
        
        //not found?
        // just bail here
        if(nil == candidateRule)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"no candidate rule found...");
            
            //bail
            goto bail;
        }
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found candidate rule: %@", candidateRule]);

    //ok, found a matching rule
    // first, if needed, generate signing info for process
    if(nil == process.signingInfo)
    {
        //save thread priority
        threadPriority = [NSThread threadPriority];
        
        //reduce CPU
        [NSThread setThreadPriority:0.25];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"code signing info for process is nil ...will generate");
        
        //generate signing info
        [process generateSigningInfo:flags];
        
        //reset thread priority
        [NSThread setThreadPriority:threadPriority];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generated code signing info for process: %@", process.signingInfo]);
    }
    
    //unsigned/invalid procs have a hash
    // check this first to determine rule match
    if(nil != candidateRule.sha256)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"candiate rule has hash: %@", candidateRule.sha256]);
        
        //generate hash
        if(nil == process.binary.sha256)
        {
            //sync to hash
            @synchronized (process.binary) {
                
                //generate hash
                [process.binary generateHash];
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generated hash for process: %@", process.binary.sha256]);
        }
        
        //check for match
        if(YES == [process.binary.sha256 isEqualToString:candidateRule.sha256])
        {
            //save
            matchingRule = candidateRule;
            
            //dbg msg
            logMsg(LOG_DEBUG, @"hashes match, so accepting cadidate rule");
        }
        //mismatch
        else
        {
            //err msg(s)
            logMsg(LOG_ERR, [NSString stringWithFormat:@"process: %@ (%d)", process.path, process.pid]);
            logMsg(LOG_ERR, [NSString stringWithFormat:@"hash mismatch! process: %@ vs. candidate rule: %@ ...ignoring candidate rule", process.binary.sha256, candidateRule.sha256]);
        }
        
        //done!
        goto bail;
    }
    
    //check:
    // unsigned processes should have a hash
    if(nil == process.signingInfo)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"process: %@ (%d)", process.path, process.pid]);
        logMsg(LOG_ERR, @"process is unsigned, but has no hash! ...ignoring candidate rule");
    
        //bail
        goto bail;
    }
    
    //extract signing status
    signingStatus = [process.signingInfo[KEY_SIGNATURE_STATUS] intValue];
    
    //check:
    // invalidly signed proc should have a hash
    if(errSecSuccess != signingStatus)
    {
        //err msg
        // ...but only on non-process exit events
        if( (kPOSIXErrorESRCH != signingStatus)  &&
            (errSecCSNoSuchCode != signingStatus) &&
            (errSecCSStaticCodeChanged != signingStatus) )
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"process: %@ (%d)", process.path, process.pid]);
            logMsg(LOG_ERR, [NSString stringWithFormat:@"process is invalidly signed (%#x), but has no hash! ...ignoring candidate rule", signingStatus]);
        }
        
        //bail
        goto bail;
    }
    
    //check:
    // code signing id mismatch?
    if(YES != [process.signingInfo[KEY_SIGNATURE_IDENTIFIER] isEqualToString:candidateRule.signingInfo[KEY_SIGNATURE_IDENTIFIER]])
    {
        //err msg(s)
        logMsg(LOG_ERR, [NSString stringWithFormat:@"process: %@ (%d)", process.path, process.pid]);
        logMsg(LOG_ERR, [NSString stringWithFormat:@"code signing identifier mismatch! process: %@ vs. candidate rule: %@ ...ignoring candidate rule", process.signingInfo[KEY_SIGNATURE_IDENTIFIER], candidateRule.signingInfo[KEY_SIGNATURE_IDENTIFIER]]);
    
        //bail
        goto bail;
    }
    
    //check:
    // signing authorities mismatch?
    if(0 != [process.signingInfo[KEY_SIGNATURE_AUTHORITIES] count])
    {
        //compare all signing auths
        if(YES != [[NSCountedSet setWithArray:process.signingInfo[KEY_SIGNATURE_AUTHORITIES]] isEqualToSet: [NSCountedSet setWithArray:candidateRule.signingInfo[KEY_SIGNATURE_AUTHORITIES]]] )
        {
            //err msg(s)
            logMsg(LOG_ERR, [NSString stringWithFormat:@"process: %@ (%d)", process.path, process.pid]);
            logMsg(LOG_ERR, [NSString stringWithFormat:@"signing authority mismatch! process: %@ vs. candiate rule: %@ ...ignoring candidate rule", process.signingInfo[KEY_SIGNATURE_AUTHORITIES], candidateRule.signingInfo[KEY_SIGNATURE_AUTHORITIES]]);
            
            //bail
            goto bail;
        }
    }
    
    //candidate rule is as match!
    matchingRule = candidateRule;
    
bail:
    
    return matchingRule;
}

//find rule that matches process's code signing id
-(Rule*)findByIdentifier:(Process*)process
{
    //current rule
    Rule* currentRule = nil;
    
    //matching rule
    Rule* matchingRule = nil;
    
    //thread priority
    double threadPriority = 0.0f;
    
    //default cs flags
    // note: since this is dynamic check, we don't need to check all architectures
    SecCSFlags flags = kSecCSDefaultFlags;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"looking for rule that matches %@'s code signing ID", process.binary.name]);
    
    //if needed, generate signing info for process
    if(nil == process.signingInfo)
    {
        //save thread priority
        threadPriority = [NSThread threadPriority];
        
        //reduce CPU
        [NSThread setThreadPriority:0.25];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generating code signing info for %@ (%d) with flags: %d", process.binary.name, process.pid, flags]);
        
        //generate signing info
        [process generateSigningInfo:flags];
        
        //reset thread priority
        [NSThread setThreadPriority:threadPriority];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"done generating code signing info");
    }
    
    //(still) nil?
    if(nil == process.signingInfo)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to generate code signing info for (%d): %@", process.pid, process.binary.name]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"code info/signing ID: %@/%@", process.signingInfo, process.signingInfo[KEY_SIGNATURE_IDENTIFIER]]);
    
    //process has to be validly signed
    // and also have a binary identifier
    if( (noErr != [process.signingInfo[KEY_SIGNATURE_STATUS] intValue]) ||
        (nil == process.signingInfo[KEY_SIGNATURE_IDENTIFIER]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"(%d): %@ is not validly signed or doesn't have a code signing identifier, so ignoring", process.pid, process.binary.name]);
        
        //bail
        goto bail;
    }
    
    //scan all rules
    // find same same code signing identifier
    for(NSString* path in self.rules)
    {
        //get rule obj
        currentRule = self.rules[path];
    
        //match
        if(YES == [currentRule.signingInfo[KEY_SIGNATURE_IDENTIFIER] isEqualToString:process.signingInfo[KEY_SIGNATURE_IDENTIFIER]] )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"rule %@ matches %@", matchingRule.path, process.signingInfo[KEY_SIGNATURE_IDENTIFIER]]);
            
            //save
            matchingRule = currentRule;
            
            //done
            break;
        }
    }
    
bail:
    
    return matchingRule;
}

//add a rule
// will generate a hash of binary, if (valid) signing info not found...
-(BOOL)add:(NSString*)path signingInfo:(NSDictionary*)signingInfo action:(NSUInteger)action type:(NSUInteger)type user:(NSUInteger)user
{
    //result
    BOOL added = NO;
    
    //rule info
    NSMutableDictionary* ruleInfo = nil;
    
    //hash
    NSString* hash = nil;
    
    //rule
    Rule* rule = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding rule for %@ (%@): action %lu / type: %lu", path, signingInfo, (unsigned long)action, (unsigned long)type]);
    
    //alloc dictionary
    ruleInfo = [NSMutableDictionary dictionary];
    
    //add signing info
    if(nil != signingInfo)
    {
        //add signing info
        ruleInfo[RULE_SIGNING_INFO] = signingInfo;
    }
    
    //item unsigned/invalid?
    // generate hash (sha256)
    if( (nil == signingInfo) ||
        (errSecSuccess != [signingInfo[KEY_SIGNATURE_STATUS] intValue]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"signing info not found, or invalid for %@, will generate hash", path]);
        
        //generate hash
        hash = hashFile(path);
        if(0 == hash.length)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to hash file");
            
            //bail
            goto bail;
        }
        
        //add hash
        ruleInfo[RULE_HASH] = hash;
    }
    
    //add rule action
    ruleInfo[RULE_ACTION] = [NSNumber numberWithUnsignedInteger:action];
    
    //add rule type
    ruleInfo[RULE_TYPE] = [NSNumber numberWithUnsignedInteger:type];
    
    //add rule user
    ruleInfo[RULE_USER] = [NSNumber numberWithUnsignedInteger:user];
    
    //sync to access
    @synchronized(self.rules)
    {
        //init rule
        rule = [[Rule alloc] init:path info:ruleInfo];
        
        //add
        self.rules[path] = rule;
        
        //save to disk
        if(YES != [self save])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to save rules");
            
            //bail
            goto bail;
        }
    }
    
    //for any other process
    // tell kernel to add rule
    [self addToKernel:rule];
    
    //tell user (via XPC) rules changed
    [self.xpcUserClient rulesChanged:[self serialize]];
    
    //happy
    added = YES;
    
bail:
    
    return added;
}

//update (toggle) existing rule
-(BOOL)update:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user
{
    //result
    BOOL result = NO;
    
    //rule
    Rule* rule = nil;
    
    //sync to access
    @synchronized(self.rules)
    {
        //find rule
        rule = self.rules[path];
        if(nil == rule)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ignoring update request for rule, as it doesn't exists: %@", path]);
            
            //bail
            goto bail;
        }
        
        //update
        rule.action = [NSNumber numberWithUnsignedInteger:action];
        
        //save to disk
        [self save];
    }
    
    //for any other process
    // tell kernel to update (add/overwrite) rule
    [self addToKernel:rule];
    
    //tell user (via XPC) rules changed
    [self.xpcUserClient rulesChanged:[self serialize]];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//add to kernel
-(void)addToKernel:(Rule*)rule
{
    //find processes and add
    for(NSNumber* processID in getProcessIDs(rule.path, -1))
    {
        //add rule
        [kextComms addRule:[processID unsignedShortValue] action:rule.action.intValue];
    }
    
    return;
}

//delete rule
-(BOOL)delete:(NSString*)path
{
    //result
    BOOL result = NO;
    
    //sync to access
    @synchronized(self.rules)
    {
        //remove
        [self.rules removeObjectForKey:path];
        
        //save to disk
        if(YES != [self save])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to save rules");
            
            //bail
            goto bail;
        }
    }
    
    //find any running processes that match
    // then for each, tell the kernel to delete any rules it has
    for(NSNumber* processID in getProcessIDs(path, -1))
    {
        //remove rule
        [kextComms removeRule:[processID unsignedShortValue]];
    }
    
    //tell user (via XPC) rules changed
    [self.xpcUserClient rulesChanged:[self serialize]];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//delete all rules
-(BOOL)deleteAll
{
    //result
    BOOL result = NO;

    //error
    NSError* error = nil;
    
    //sync to access
    @synchronized(self.rules)
    {
        //delete all
        for(NSString* path in self.rules.allKeys)
        {
            //remove
            [self.rules removeObjectForKey:path];
            
            //find any running processes that match
            // then for each, tell the kernel to delete any rules it has
            for(NSNumber* processID in getProcessIDs(path, -1))
            {
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"pid (%@)", processID]);
                
                //remove rule
                [kextComms removeRule:[processID unsignedShortValue]];
            }
        }
        
        //remove old rules file
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE]])
        {
            //remove
            if(YES != [[NSFileManager defaultManager] removeItemAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE] error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete existing rules file %@ (error: %@)", RULES_FILE, error]);
                
                //bail
                goto bail;
            }
        }
        
    }//sync
    
    //tell user (via XPC) rules changed
    [self.xpcUserClient rulesChanged:[self serialize]];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

@end
