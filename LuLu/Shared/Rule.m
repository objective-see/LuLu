//
//  file: Rule.h
//  project: LuLu (shared)
//  description: Rule object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "consts.h"
#import "utilities.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Rule

@synthesize scope;
@synthesize action;

//init method
-(id)init:(NSDictionary*)info
{
    //init super
    if(self = [super init])
    {
        //dbg msg
        os_log_debug(logHandle, "creating rule with: %{public}@", info);
        
        //create UUID
        self.uuid = [[NSUUID UUID] UUIDString];
        
        //init pid
        // only set for temporary rules
        if(YES == [info[KEY_TEMPORARY] boolValue])
        {
            //set
            self.pid = info[KEY_PROCESS_ID];
        }
        
        //init path
        self.path = info[KEY_PATH];
        
        //init name
        self.name = (nil != info[KEY_NAME]) ? info[KEY_NAME] : getProcessName(self.path);
        
        //init signing info
        self.csInfo = info[KEY_CS_INFO];
        
        //process scope (set via alert)
        // set endpoint info to all ('*')
        if( (nil != info[KEY_SCOPE]) &&
            (ACTION_SCOPE_PROCESS == [info[KEY_SCOPE] intValue]) )
        {
            //dbg msg
            os_log_debug(logHandle, "rule info has 'KEY_SCOPE' set to 'ACTION_SCOPE_PROCESS'");
            
            //any addr
            self.endpointAddr = VALUE_ANY;
            
            //any port
            self.endpointPort = VALUE_ANY;
        }
        //other use endpoint info
        // or if nil, set to all ('*')
        else
        {
            //init addr
            // nil? default to all ('*')
            self.endpointAddr = (nil != info[KEY_ENDPOINT_ADDR]) ? info[KEY_ENDPOINT_ADDR] : VALUE_ANY;
            
            //is endpoint addr a regex?
            self.isEndpointAddrRegex = [info[KEY_ENDPOINT_ADDR_IS_REGEX] boolValue];
            
            //init port
            // nil? default to all ('*')
            self.endpointPort = (nil != info[KEY_ENDPOINT_PORT]) ? info[KEY_ENDPOINT_PORT] : VALUE_ANY;
        }
        
        //set proto
        self.protocol = info[KEY_PROTOCOL];
    
        //set type
        self.type = info[KEY_TYPE];
        
        //init action
        self.action = info[KEY_ACTION];
        
        //now, generate key
        self.key = [self generateKey];
    }
        
    return self;
}

//generate id
// cs info or path
-(NSString*)generateKey
{
    //id
    NSString* key = nil;
    
    //signer
    NSInteger signer = None;
    
    //cs info?
    if(nil != self.csInfo)
    {
        //extract signer
        signer = [self.csInfo[KEY_CS_SIGNER] intValue];
        
        //apple/app store
        // just use cs id
        if( (Apple == signer) ||
            (AppStore == signer) )
        {
            //set key
            key = self.csInfo[KEY_CS_ID];
        }
        
        //dev id?
        // use cs id + (leaf) signer
        else if(DevID == signer)
        {
            //check for cs id/auths
            if( (0 != [self.csInfo[KEY_CS_ID] length]) &&
                (0 != [self.csInfo[KEY_CS_AUTHS] count]) )
            {
                //set
                key = [NSString stringWithFormat:@"%@:%@", self.csInfo[KEY_CS_ID], [self.csInfo[KEY_CS_AUTHS] firstObject]];
            }
        }
    }
    
    //no valid cs info, etc
    // just use item's path
    if(0 == key.length)
    {
        //set
        key = self.path;
    }
    
    //dbg msg
    os_log_debug(logHandle, "generated rule key: %{public}@", key);

    return key;
}

//is rule global?
-(NSNumber*)isGlobal
{
    //first time?
    // init and set
    if(nil == _isGlobal)
    {
        //set
        _isGlobal = [NSNumber numberWithBool:[self.path isEqualToString:VALUE_ANY]];
    }
    
    return _isGlobal;
}

//is rule directory?
-(NSNumber*)isDirectory
{
    //first time?
    // init and set
    if(nil == _isDirectory)
    {
        //set
        _isDirectory = [NSNumber numberWithBool:((YES == [self.path hasPrefix:@"/"]) && (YES == [self.path hasSuffix:@"/*"]))];
    }
    
    return _isDirectory;
}

//required as we support secure coding
+(BOOL)supportsSecureCoding
{
    return YES;
}

//init with coder
-(id)initWithCoder:(NSCoder *)decoder
{
    //super
    if(self = [super init])
    {
        //decode rule object
        
        self.key = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(key))];
        self.uuid = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(uuid))];
        
        self.pid = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(pid))];
        self.path = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(path))];
        self.name = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(name))];
        self.csInfo = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSDictionary class], [NSArray class], [NSString class], [NSNumber class]]] forKey:NSStringFromSelector(@selector(csInfo))];
        
        self.endpointAddr = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(endpointAddr))];
        self.isEndpointAddrRegex = [decoder decodeBoolForKey:NSStringFromSelector(@selector(isEndpointAddrRegex))];
        self.endpointPort = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(endpointPort))];
        
        self.type = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(type))];
        self.scope = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(scope))];
        self.action = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(action))];
        
    }
    
    return self;
}

//encode with coder
-(void)encodeWithCoder:(NSCoder *)encoder
{
    //encode rule object
    
    [encoder encodeObject:self.key forKey:NSStringFromSelector(@selector(key))];
    [encoder encodeObject:self.uuid forKey:NSStringFromSelector(@selector(uuid))];
    
    [encoder encodeObject:self.pid forKey:NSStringFromSelector(@selector(pid))];
    [encoder encodeObject:self.path forKey:NSStringFromSelector(@selector(path))];
    [encoder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    [encoder encodeObject:self.csInfo forKey:NSStringFromSelector(@selector(csInfo))];
    
    [encoder encodeObject:self.endpointAddr forKey:NSStringFromSelector(@selector(endpointAddr))];
    [encoder encodeBool:self.isEndpointAddrRegex forKey:NSStringFromSelector(@selector(isEndpointAddrRegex))];
    [encoder encodeObject:self.endpointPort forKey:NSStringFromSelector(@selector(endpointPort))];
    
    [encoder encodeObject:self.type forKey:NSStringFromSelector(@selector(type))];
    
    [encoder encodeObject:self.scope forKey:NSStringFromSelector(@selector(scope))];
    [encoder encodeObject:self.action forKey:NSStringFromSelector(@selector(action))];
    
    return;
}

//matches a string?
// used for filtering in UI
-(BOOL)matchesString:(NSString*)match
{
    //match
    BOOL matches = NO;
    
    //rule action (as string)
    NSString* action = nil;
    
    //init w/ allow
    if(RULE_STATE_ALLOW == self.action.integerValue)
    {
        action = @"allow";
    }
    //init w/ block
    else if(RULE_STATE_BLOCK == self.action.integerValue)
    {
        action = @"block";
    }
    
    //check name, path
    if( (YES == [self.name localizedCaseInsensitiveContainsString:match]) ||
        (YES == [self.path localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        
        //bail
        goto bail;
    }
    
    //check pid
    if( (nil != self.pid) &&
        (YES == [self.pid.stringValue containsString:match]) )
    {
        //match
        matches = YES;
        
        //bail
        goto bail;
    }
    
    //check cs id
    if( (nil != self.csInfo[KEY_CS_ID]) &&
        (YES == [self.csInfo[KEY_CS_ID] localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        
        //bail
        goto bail;
    }
    
    //endpoint addr/port
    if( (YES == [self.endpointAddr localizedCaseInsensitiveContainsString:match]) ||
        (YES == [self.endpointPort localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        
        //bail
        goto bail;
    }
    
    //check state
    if( (nil != action) &&
        (YES == [action localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        
        //bail
        goto bail;
    }
    
bail:
    
    return matches;
}

//matches a(nother) rule?
-(BOOL)isEqualToRule:(Rule *)rule
{
    return [self.uuid isEqualToString:rule.uuid];
}

//override description method
// allows rules to be 'pretty-printed'
-(NSString*)description
{
    //pid
    id pid = @"all";
    
    //temp, has pid?
    if(nil != self.pid) pid = self.pid;
        
    //just serialize
    return [NSString stringWithFormat:@"RULE: pid: %@, path: %@, name: %@, code signing info: %@, endpoint addr: %@, endpoint port: %@, action: %@, type: %@", pid, self.path, self.name, self.csInfo, self.endpointAddr, self.endpointPort, self.action, self.type];
}

@end
