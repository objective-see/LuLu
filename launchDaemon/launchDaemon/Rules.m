//
//  file: Rules.m
//  project: lulu (launch daemon)
//  description: handles rules & actions such as add/delete
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#import "const.h"

#import "Rule.h"
#import "Rules.h"
#import "logging.h"
#import "KextComms.h"
#import "Utilities.h"

//global kext comms object
extern KextComms* kextComms;

@implementation Rules

@synthesize rules;
@synthesize appQuery;

//init method
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc
        rules = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//load rules from disk
-(BOOL)load
{
    //result
    BOOL result = NO;
    
    //serialized rules
    NSDictionary* serializedRules = nil;
    
    //rules obj
    Rule* rule = nil;
    
    //load serialized rules from disk
    serializedRules = [NSMutableDictionary dictionaryWithContentsOfFile:RULES_FILE];
    if(nil == serializedRules)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rules from: %@", RULES_FILE]);
        
        //bail
        goto bail;
    }
    
    //create rule objects for each
    for(NSString* key in serializedRules)
    {
        //init
        rule = [[Rule alloc] init:key rule:serializedRules[key]];
        if(nil == rule)
        {
            //skip
            continue;
        }
        
        //add
        self.rules[rule.path] = rule;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded %lu rules from: %@", (unsigned long)self.rules.count, RULES_FILE]);
    
    //happy
    result = YES;
    
bail:
    
    return result;
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
    if(YES != [serializedRules writeToFile:RULES_FILE atomically:YES])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save rules to: %@", RULES_FILE]);
        
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//start query for all installed apps
// each will be allowed, as a 'baselined' application
// TODO: note: in the future, the installer will control this more, like whether to skip, baseline only apple apps, etc
-(void)startBaselining
{
    //check if baselining was already done
    // this is done by seeing if there are any rules w/ type 'baseline'
    for(NSString* path in self.rules.allKeys)
    {
        //baseline rule?
        if(RULE_TYPE_BASELINE == ((Rule*)self.rules[path]).type.intValue)
        {
            //bail
            goto bail;
        }
    }

    //dbg msg
    logMsg(LOG_DEBUG, @"generating 'allow' rules for all existing applications");
    
    //alloc
    appQuery = [[NSMetadataQuery alloc] init];
    
    //register for query completion
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endBaselining:) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
    
    //set predicate
    [self.appQuery setPredicate:[NSPredicate predicateWithFormat:@"kMDItemKind == 'Application'"]];
    
    //start query
    // ->will generate notification when done
    [self.appQuery startQuery];
    
bail:
    
    return;
}

//invoked when spotlight query is done
// process each installed app by adding 'allow' rule
// TODO: note: in the future, the installer will control this more, like whether to skip, baseline only apple apps, etc
-(void)endBaselining:(NSNotification *)notification
{
    //app url
    __block NSString* currentApp = nil;
    
    //full path to binary
    __block NSString* currentAppBinary = nil;
    
    //iterate over all
    // create/add default/baseline rule for each
    [self.appQuery enumerateResultsUsingBlock:^(id result, NSUInteger idx, BOOL *stop)
    {
        //grab current app
        currentApp = [result valueForAttribute:NSMetadataItemPathKey];
        if(nil == currentApp)
        {
            //skip
            return;
        }
        
        //skip app store
        // it's a default/system rule already
        if(YES == [currentApp isEqualToString:@"/Applications/App Store.app"])
        {
            //skip
            return;
        }
        
        //get full binary path
        currentAppBinary = getAppBinary(currentApp);
        if(nil == currentAppBinary)
        {
            //skip
            return;    
        }
        
        //add
        // allow, type: 'baseline'
        [self add:currentAppBinary action:RULE_STATE_ALLOW type:RULE_TYPE_BASELINE user:0];
        
    }];
    
    return;
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
        //iterate over all rules
        // ->serialize & add each
        for(NSString* path in self.rules)
        {
            //covert/add
            serializedRules[path] = [rules[path] serialize];
        }
    }
    
    return serializedRules;
}

//find
// for now, just by path
-(Rule*)find:(NSString*)path
{
    //matching rule
    Rule* matchingRule = nil;
    
    //sync to access
    @synchronized(self.rules)
    {
        //extract rule
        matchingRule = [self.rules objectForKey:path];
        if(nil == matchingRule)
        {
            //not found, bail
            goto bail;
        }
    }
    
    //TOOD: validate binary still matches hash
    
    //TOOD: check that rule is for this user!

bail:
    
    return matchingRule;
}

//add rule
// note: ignore if rule matches existing rule
-(BOOL)add:(NSString*)path action:(NSUInteger)action type:(NSUInteger)type user:(NSUInteger)user
{
    //result
    BOOL result = NO;
    
    //rule
    Rule* rule = nil;
    
    //sync to access
    @synchronized(self.rules)
    {
        //init rule
        rule = [[Rule alloc] init:path rule:@{RULE_ACTION:[NSNumber numberWithUnsignedInteger:action], RULE_TYPE:[NSNumber numberWithUnsignedInteger:type], RULE_USER:[NSNumber numberWithUnsignedInteger:user]}];
        
        //ignore
        if(nil != self.rules[path])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ignoring add request for rule, as it already exists: %@", path]);
            
            //bail
            goto bail;
        }
        
        //add
        self.rules[path] = rule;
        
        //save to disk
        [self save];
    }
    
    //tell kernel to add
    [self addToKernel:rule];

    //happy
    result = YES;
    
bail:
    
    return result;
}

//add to kernel
// TOOD: check hash, etc
-(void)addToKernel:(Rule*)rule
{
    //find processes and add
    for(NSNumber* processID in getProcessIDs(rule.path, -1))
    {
        //TODO: hash/sig matches?
        
        //add rule
        [kextComms addRule:[processID unsignedShortValue] action:(unsigned int)rule.action];
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
        [self save];
    }
    
    //find any running processes that match
    // ->then for each, tell the kernel to delete any rules it has
    for(NSNumber* processID in getProcessIDs(path, -1))
    {
        //remove rule
        [kextComms removeRule:[processID unsignedShortValue]];
    }

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
            // ->then for each, tell the kernel to delete any rules it has
            for(NSNumber* processID in getProcessIDs(path, -1))
            {
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"pid (%@)", processID]);
                
                //remove rule
                [kextComms removeRule:[processID unsignedShortValue]];
            }
        }
        
        //remove old rules file
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:RULES_FILE])
        {
            //remove
            if(YES != [[NSFileManager defaultManager] removeItemAtPath:RULES_FILE error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete existing rules file %@ (error: %@)", RULES_FILE, error]);
                
                //bail
                goto bail;
            }
        }
        
    }//sync
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

@end
