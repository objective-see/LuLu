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
#import "KextComms.h"
#import "utilities.h"


//global kext comms object
extern KextComms* kextComms;

@implementation Rules

@synthesize rules;
//@synthesize appQuery;

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
    serializedRules = [NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE]];
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
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load rule for %@", key]);
            
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
    if(YES != [serializedRules writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE] atomically:YES])
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

//find rule
// TODO: validate signature too!
-(Rule*)find:(Process*)process
{
    //matching rule
    Rule* matchingRule = nil;
    
    //sync to access
    @synchronized(self.rules)
    {
        //extract rule
        matchingRule = [self.rules objectForKey:process.path];
        if(nil == matchingRule)
        {
            //not found, bail
            goto bail;
        }
    }
    
    //TODO: validate binary still matches hash
    
    //TODO: check that rule is for this user!

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
        //ignore existing rule
        // TODO: maybe call 'find' to also check signing info/hash?
        if(nil != self.rules[path])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ignoring add request for rule, as it already exists: %@", path]);
            
            //bail
            goto bail;
        }
        
        //init rule
        rule = [[Rule alloc] init:path rule:@{RULE_ACTION:[NSNumber numberWithUnsignedInteger:action], RULE_TYPE:[NSNumber numberWithUnsignedInteger:type], RULE_USER:[NSNumber numberWithUnsignedInteger:user]}];
        
        //add
        self.rules[path] = rule;
        
        //save to disk
        [self save];
    }
    
    //for any other process
    // tell kernel to add rule
    [self addToKernel:rule];

    //happy
    result = YES;
    
bail:
    
    return result;
}

//add to kernel
// TODO: check hash, etc
-(void)addToKernel:(Rule*)rule
{
    //find processes and add
    for(NSNumber* processID in getProcessIDs(rule.path, -1))
    {
        //TODO: hash/sig matches?
        
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
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

@end
