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

#import <objc/runtime.h>

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
        //url
        NSURL* remoteURL = nil;
        
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
        self.name = (nil != info[KEY_PROCESS_NAME]) ? info[KEY_PROCESS_NAME] : getProcessName(0, self.path);
        
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
        
        //init url
        if(YES != [self.endpointAddr isEqualToString:VALUE_ANY])
        {
            //init url
            // add prefix
            if(YES != [self.endpointAddr hasPrefix:@"http"])
            {
                //init url
                remoteURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", self.endpointAddr]];
            }
            //no prefix needed
            else
            {
                //init url
                remoteURL = [NSURL URLWithString:self.endpointAddr];
            }
            
            //get host name
            self.endpointHost = remoteURL.host;
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

//is rule temporary
-(BOOL)isTemporary
{
    return (nil != self.pid);
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
        
        self.isEndpointAddrRegex = [decoder decodeBoolForKey:NSStringFromSelector(@selector(isEndpointAddrRegex))];
        self.endpointAddr = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(endpointAddr))];
        self.endpointHost = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(endpointHost))];
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
    [encoder encodeObject:self.endpointHost forKey:NSStringFromSelector(@selector(endpointHost))];
    [encoder encodeObject:self.endpointPort forKey:NSStringFromSelector(@selector(endpointPort))];
    [encoder encodeBool:self.isEndpointAddrRegex forKey:NSStringFromSelector(@selector(isEndpointAddrRegex))];
    
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
        action = @"Allow";
    }
    //init w/ block
    else if(RULE_STATE_BLOCK == self.action.integerValue)
    {
        action = @"Block";
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

//covert rule to dictionary
// needed for conversion to JSON
-(NSMutableString*)toJSON
{
    //dbg msg
    os_log_debug(logHandle, "converting rule to JSON...");
    
    //json
    NSMutableString* json = nil;
    
    //init
    json = [NSMutableString string];
    
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(key)), self.key];
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(uuid)), self.uuid];
    
    if(nil != self.pid)
    {
        [json appendFormat:@"\"%@\" : \"%d\",", NSStringFromSelector(@selector(pid)), self.pid.intValue];
    }
    
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(path)), self.path];
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(name)), self.name];
    
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(endpointAddr)), self.endpointAddr];
    
    if(nil != self.endpointHost)
    {
        [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(endpointHost)), self.endpointHost];
    }
    
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(endpointPort)), self.endpointPort];
    [json appendFormat:@"\"%@\" : \"%d\",", NSStringFromSelector(@selector(isEndpointAddrRegex)), self.isEndpointAddrRegex];

    [json appendFormat:@"\"%@\" : \"%d\",", NSStringFromSelector(@selector(type)), self.type.intValue];
    [json appendFormat:@"\"%@\" : \"%d\",", NSStringFromSelector(@selector(scope)), self.scope.intValue];
    [json appendFormat:@"\"%@\" : \"%d\",", NSStringFromSelector(@selector(action)), self.action.intValue];
    
    //cs info
    // dictionary...
    if(nil != self.csInfo)
    {
        [json appendFormat:@"\"%@\" : {", NSStringFromSelector(@selector(csInfo))];
        
        //convert each key/value pair
        for(NSString* key in self.csInfo)
        {
            //extract value
            id value = self.csInfo[key];
            
            //string?
            if(YES == [value isKindOfClass:[NSString class]])
            {
                //append
                [json appendFormat:@"\"%@\" : \"%@\",", key, value];
            }
            
            //number?
            if(YES == [value isKindOfClass:[NSNumber class]])
            {
                //append
                [json appendFormat:@"\"%@\" : \"%d\",", key, [value intValue]];
            }
            
            //array?
            if(YES == [value isKindOfClass:[NSArray class]])
            {
                //append
                [json appendFormat:@"\"%@\" : [", key];
                
                //add each item
                for(id item in value)
                {
                    [json appendFormat:@"\"%@\",", item];
                }
                
                //remove last ','
                if(YES == [json hasSuffix:@","])
                {
                    //remove
                    [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
                }
                
                //end
                [json appendFormat:@"],"];
            }
        }
        
        //remove last ','
        if(YES == [json hasSuffix:@","])
        {
            //remove
            [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
        }
        
        //end
        [json appendFormat:@"}"];
    }
    
    //remove last ','
    if(YES == [json hasSuffix:@","])
    {
        //remove
        [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
    }
    
    return json;
}

//make a rule obj from a dictioanary
-(id)initFromJSON:(NSDictionary*)info
{
    //formatter
    NSNumberFormatter* formatter = nil;
    
    //init
    formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //super
    if(self = [super init])
    {
        //init
        self.key = info[NSStringFromSelector(@selector(key))];
        if(YES != [self.key isKindOfClass:[NSString class]])
        {
            self = nil;
            goto bail;
        }
        
        self.uuid = info[NSStringFromSelector(@selector(uuid))];
        if(YES != [self.uuid isKindOfClass:[NSString class]])
        {
            self = nil;
            goto bail;
        }
        
        self.pid = info[NSStringFromSelector(@selector(pid))];
        if(YES != [self.pid isKindOfClass:[NSNumber class]])
        {
            self = nil;
            goto bail;
        }
        
        self.path = info[NSStringFromSelector(@selector(path))];
        self.name = info[NSStringFromSelector(@selector(name))];
        
        self.csInfo = info[NSStringFromSelector(@selector(csInfo))];
        
        self.endpointAddr = info[NSStringFromSelector(@selector(endpointAddr))];
        self.endpointHost = info[NSStringFromSelector(@selector(endpointHost))];
        self.endpointPort = info[NSStringFromSelector(@selector(endpointPort))];
        
        self.isEndpointAddrRegex = [info[NSStringFromSelector(@selector(isEndpointAddrRegex))] boolValue];
        
        self.type = [formatter numberFromString:info[NSStringFromSelector(@selector(type))]];
        self.scope = [formatter numberFromString:info[NSStringFromSelector(@selector(scope))]];
        self.action = [formatter numberFromString:info[NSStringFromSelector(@selector(action))]];
    }
    
bail:
        
    return self;
}

@end
