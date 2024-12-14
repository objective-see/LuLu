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
        // note: only set for temporary rules
        if(YES == [info[KEY_DURATION_PROCESS] boolValue])
        {
            //set
            self.pid = info[KEY_PROCESS_ID];
        }
        
        //set creation
        self.creation = [NSDate date];
        
        //init expiration
        // though this won't (usually) be set
        self.expiration = info[KEY_DURATION_EXPIRATION];
        
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
        
        //init URL obj (w/ scheme)
        // so we can extract a host
        if(YES != [self.endpointAddr isEqualToString:VALUE_ANY])
        {
            //init url w/ scheme
            if(YES != [self.endpointAddr hasPrefix:@"http"])
            {
                //init url
                remoteURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", self.endpointAddr]];
            }
            //no scheme needed
            else
            {
                //init url
                remoteURL = [NSURL URLWithString:self.endpointAddr];
            }
            
            //now with URL obj, get host name
            self.endpointHost = remoteURL.host;
        }
        
        //set proto
        self.protocol = info[KEY_PROTOCOL];
    
        //set type
        self.type = info[KEY_TYPE];
        
        //init action
        self.action = info[KEY_ACTION];
        
        //now, generate key
        if(nil != info[KEY_KEY])
        {
            //set
            self.key = info[KEY_KEY];
        }
        //generate key
        else
        {
            //generate
            self.key = [self generateKey];
        }
    }
        
    return self;
}

//generate key
// note: this matches process' generate key algo
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

//is rule temporary?
// ...just if its duration is set to process lifetime (e.g. has a pid)
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
        
        self.creation = [decoder decodeObjectOfClass:[NSDate class] forKey:NSStringFromSelector(@selector(creation))];
        self.expiration = [decoder decodeObjectOfClass:[NSDate class] forKey:NSStringFromSelector(@selector(expiration))];
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

    [encoder encodeObject:self.creation forKey:NSStringFromSelector(@selector(creation))];
    [encoder encodeObject:self.expiration forKey:NSStringFromSelector(@selector(expiration))];

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
        action = NSLocalizedString(@"Allow", "@Allow");
    }
    //init w/ block
    else if(RULE_STATE_BLOCK == self.action.integerValue)
    {
        action = NSLocalizedString(@"Block", @"Block");
    }
    
    //check name, path
    if( (YES == [self.name localizedCaseInsensitiveContainsString:match]) ||
        (YES == [self.path localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        goto bail;
    }
    
    //check pid
    if( (nil != self.pid) &&
        (YES == [self.pid.stringValue containsString:match]) )
    {
        //match
        matches = YES;
        goto bail;
    }
    
    //check cs id
    if( (nil != self.csInfo[KEY_CS_ID]) &&
        (YES == [self.csInfo[KEY_CS_ID] localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        goto bail;
    }
    
    //endpoint addr/port
    if( (YES == [self.endpointAddr localizedCaseInsensitiveContainsString:match]) ||
        (YES == [self.endpointPort localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
        goto bail;
    }
    
    //endpoint addr ('any')
    if( (YES == [self.endpointAddr isEqualToString:VALUE_ANY]) &&
        (YES == [match isEqualToString:NSLocalizedString(@"any address", @"any address")]) )
    {
        //match
        matches = YES;
        goto bail;
    }
    
    //endpoint port ('any')
    if( (YES == [self.endpointPort isEqualToString:VALUE_ANY]) &&
        (YES == [match isEqualToString:NSLocalizedString(@"any port", @"any port")]) )
    {
        //match
        matches = YES;
        goto bail;
    }
    
    //check state
    if( (nil != action) &&
        (YES == [action localizedCaseInsensitiveContainsString:match]) )
    {
        //match
        matches = YES;
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
    
    //expiration
    id expiration = @"never";
    
    //has pid?
    if(nil != self.pid)
    {
        pid = self.pid;
    }
    
    //has expiration?
    if(nil != self.expiration)
    {
        expiration = self.expiration;
    }
    
    //just serialize
    return [NSString stringWithFormat:@"RULE: pid: %@, path: %@, name: %@, code signing info: %@, endpoint addr: %@, endpoint port: %@, action: %@, type: %@, creation: %@, expiration: %@", pid, self.path, self.name, self.csInfo, self.endpointAddr, self.endpointPort, self.action, self.type, self.creation, self.expiration];
}

//covert rule to dictionary
// needed for conversion to JSON
// note: temporary properties (such as pid / expiration) not included
-(NSMutableString*)toJSON
{
    //json
    NSMutableString* json = nil;
    
    //escaped
    NSString* escaped = nil;
    
    //date formatter
    NSDateFormatter* dateFormatter = nil;
    
    //init formatter
    // format: ISO 8601 format
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
    //init
    json = [NSMutableString string];
    
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(key)), self.key];
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(uuid)), self.uuid];
    
    escaped = toEscapedJSON(self.path);
    if(nil != escaped)
    {
        [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(path)), escaped];
    }
    
    escaped = toEscapedJSON(self.name);
    if(nil != escaped)
    {
        [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(name)), escaped];
    }
    
    escaped = toEscapedJSON(self.endpointAddr);
    if(nil != escaped)
    {
        [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(endpointAddr)), escaped];
    }
    
    if(nil != self.endpointHost)
    {
        escaped = toEscapedJSON(self.endpointHost);
        if(nil != escaped)
        {
            [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(endpointHost)), escaped];
        }
    }
    
    //creation
    if(nil != self.creation)
    {
        [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(creation)), [dateFormatter stringFromDate:self.creation]];
    }
    
    //expiration
    if(nil != self.expiration)
    {
        [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(creation)), [dateFormatter stringFromDate:self.expiration]];
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
                escaped = toEscapedJSON(value);
                if(nil != escaped)
                {
                    //append
                    [json appendFormat:@"\"%@\" : %@,", key, escaped];
                }
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
                    //string?
                    if(YES == [item isKindOfClass:[NSString class]])
                    {
                        escaped = toEscapedJSON(item);
                        if(nil != escaped)
                        {
                            //append
                            [json appendFormat:@"%@,", escaped];
                        }
                    }
                    else
                    {
                        [json appendFormat:@"\"%@\",", item];
                    }
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
    //date formatter
    NSDateFormatter* dateFormatter = nil;
    
    //number formatter
    NSNumberFormatter* numberFormatter = nil;
    
    //init formatter
    // format: ISO 8601 format
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
    //init
    numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    //dbg msg
    //os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //super
    if(self = [super init])
    {
        //init + sanity checks
        self.key = info[NSStringFromSelector(@selector(key))];
        if(YES != [self.key isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'key' should be a string, not %@", self.key.className);
            
            self = nil;
            goto bail;
        }
        
        self.uuid = info[NSStringFromSelector(@selector(uuid))];
        if(YES != [self.uuid isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'uuid' should be a string, not %@", self.uuid.className);
            
            self = nil;
            goto bail;
        }
        
        self.path = info[NSStringFromSelector(@selector(path))];
        if(YES != [self.path isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'path' should be a string, not %@", self.path.className);
            
            self = nil;
            goto bail;
        }
        
        self.name = info[NSStringFromSelector(@selector(name))];
        if(YES != [self.name isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'name' should be a string, not %@", self.name.className);
            
            self = nil;
            goto bail;
        }
        
        self.csInfo = info[NSStringFromSelector(@selector(csInfo))];
        if( (nil != self.csInfo) &&
            (YES != [self.csInfo isKindOfClass:[NSDictionary class]]) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'csInfo' should be a dictionary, not %@", self.csInfo.className);
            
            self = nil;
            goto bail;
        }

        self.endpointAddr = info[NSStringFromSelector(@selector(endpointAddr))];
        if(YES != [self.endpointAddr isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'endpointAddr' should be a string, not %@", self.endpointAddr.className);
            
            self = nil;
            goto bail;
        }
        
        self.endpointHost = info[NSStringFromSelector(@selector(endpointHost))];
        if( (nil != self.endpointHost) &&
            (YES != [self.endpointHost isKindOfClass:[NSString class]]) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'endpointHost' should be a string, not %@", self.endpointHost.className);
            
            self = nil;
            goto bail;
        }
        
        self.endpointPort = info[NSStringFromSelector(@selector(endpointPort))];
        if(YES != [self.endpointPort isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'endpointPort' should be a string, not %@", self.endpointPort.className);
            
            self = nil;
            goto bail;
        }
        
        self.isEndpointAddrRegex = [info[NSStringFromSelector(@selector(isEndpointAddrRegex))] boolValue];
        
        self.type = [numberFormatter numberFromString:info[NSStringFromSelector(@selector(type))]];
        if(YES != [self.type isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'type' should be a number, not %@", self.type.className);
            
            self = nil;
            goto bail;
        }
        
        self.scope = [numberFormatter numberFromString:info[NSStringFromSelector(@selector(scope))]];
        if(YES != [self.scope isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'scope' should be a number, not %@", self.scope.className);
            
            self = nil;
            goto bail;
        }
        
        self.action = [numberFormatter numberFromString:info[NSStringFromSelector(@selector(action))]];
        if(YES != [self.action isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'action' should be a number, not %@", self.endpointPort.className);
            
            self = nil;
            goto bail;
        }
        
        //creation (date)
        self.creation = [dateFormatter dateFromString:info[NSStringFromSelector(@selector(creation))]];
        
        //expiration
        self.expiration = [dateFormatter dateFromString:info[NSStringFromSelector(@selector(expiration))]];
        
    }
    
bail:
        
    return self;
}

@end
