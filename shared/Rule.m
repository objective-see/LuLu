//
//  file: Rule.h
//  project: lulu (shared)
//  description: Rule object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "Const.h"
#import "Utilities.h"
#import "Logging.h"

@implementation Rule

//init method
-(id)init:(NSString*)path rule:(NSDictionary*)rule
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //sanity check
        if(YES != [self validate:path rule:rule])
        {
            //unset
            self = nil;
            
            //bail
            goto bail;
        }
        
        //init path
        self.path = path;
        
        //init name
        self.name = getProcessName(path);

        //init action
        self.action = rule[RULE_ACTION];
        
        //init type
        self.type = rule[RULE_TYPE];
        
        //init user
        self.user = rule[RULE_USER];
    }
    
bail:
    
    return self;
}

//make sure rule dictionary has all the required members
-(BOOL)validate:(NSString*)path rule:(NSDictionary*)rule
{
    //result
    BOOL result = NO;
    
    //check(s)
    if( (nil == path) ||
        (nil == rule[RULE_TYPE]) ||
        (nil == rule[RULE_USER]) ||
        (nil == rule[RULE_ACTION]) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"invalid rule dictionary: %@", rule]);
        
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:
    
    return result;

}

//covert rule obj to dictionary
-(NSMutableDictionary*)serialize
{
    //serialized rule
    NSMutableDictionary* serializedRule = nil;
    
    //alloc
    serializedRule = [NSMutableDictionary dictionary];
    
    //add action
    serializedRule[RULE_ACTION] = self.action;
    
    //add type
    serializedRule[RULE_TYPE] = self.type;
    
    //add user
    serializedRule[RULE_USER] = self.user;
    
    return serializedRule;
}

//override description method
// ->allows rules to be 'pretty-printed'
-(NSString*)description
{
    //just serialize
    return [[self serialize] description];
}

@end
