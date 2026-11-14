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
#import <Security/Security.h>
#import <math.h>
#import <arpa/inet.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//derive an endpoint's match type from the address itself
EndpointType endpointTypeForAddress(NSString* address)
{
    //none/any? exact
    if( (0 == address.length) ||
        (YES == [address isEqualToString:VALUE_ANY]) ) return EndpointTypeExact;

    //contains a regex metacharacter? raw regex
    if(NSNotFound != [address rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\\()[]{}|^$+?"]].location) return EndpointTypeRegex;

    //contains a '*'? glob
    if(NSNotFound != [address rangeOfString:@"*"].location) return EndpointTypeGlob;

    //a CIDR or IP range?
    if(YES == isAddressRange(address)) return EndpointTypeCIDR;

    //default
    return EndpointTypeExact;
}

//strict policies require integer JSON numbers, never permissive string coercion
static BOOL isRuleInteger(id value, NSInteger minimum, NSInteger maximum)
{
    if(YES != [value isKindOfClass:[NSNumber class]]) return NO;
    if(CFBooleanGetTypeID() == CFGetTypeID((__bridge CFTypeRef)value)) return NO;
    double number = [value doubleValue];
    return isfinite(number) && (number == floor(number)) && (number >= minimum) && (number <= maximum);
}

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

        //validate explicit strict policies before using their input fields
        self.scope = info[KEY_SCOPE];
        if(YES == [self isStrictProcessTree])
        {
            self.path = info[KEY_PATH];
            self.action = info[KEY_ACTION];
            self.protocol = info[KEY_PROTOCOL];
            self.type = info[KEY_TYPE];
            self.csInfo = info[KEY_CS_INFO];
            self.pid = info[KEY_PROCESS_ID];
            self.expiration = info[KEY_DURATION_EXPIRATION];
            self.endpointAddr = (nil != info[KEY_ENDPOINT_ADDR]) ? info[KEY_ENDPOINT_ADDR] : VALUE_ANY;
            self.endpointPort = (nil != info[KEY_ENDPOINT_PORT]) ? info[KEY_ENDPOINT_PORT] : VALUE_ANY;

            id endpointType = info[KEY_ENDPOINT_ADDR_IS_REGEX];
            id duration = info[KEY_DURATION];
            if( ((nil != endpointType) && (YES != isRuleInteger(endpointType, EndpointTypeExact, EndpointTypeGlob))) ||
                ((nil != duration) && (YES != isRuleInteger(duration, RuleDurationAlways, RuleDurationAlways))) ) return nil;
            self.isEndpointAddrRegex = [endpointType integerValue];
            if(YES != [self isValidStrictProcessTree]) return nil;
            if((nil != info[KEY_PROCESS_NAME]) && (YES != [info[KEY_PROCESS_NAME] isKindOfClass:[NSString class]])) return nil;
            if((nil != info[KEY_KEY]) && (YES != [info[KEY_KEY] isKindOfClass:[NSString class]])) return nil;
        }
        
        //dbg msg
        os_log_debug(logHandle, "creating rule with: %{public}@", info);
        
        //create UUID
        self.uuid = [[NSUUID UUID] UUIDString];
        
        //init pid
        // note: only set for temporary process duration
        if(RuleDurationProcess == [info[KEY_DURATION] intValue]) {
            self.pid = info[KEY_PROCESS_ID];
        }
        
        //set creation
        self.creation = [NSDate date];
        
        //set expiration
        if(RuleDurationCustom == [info[KEY_DURATION] intValue]) {
            self.expiration = info[KEY_DURATION_EXPIRATION];
        }
        
        //strict roots retain the executable selected when the policy is created
        self.path = (YES == [self isStrictProcessTree]) ? [info[KEY_PATH] stringByResolvingSymlinksInPath] : info[KEY_PATH];
        
        //init name
        self.name = (nil != info[KEY_PROCESS_NAME]) ? info[KEY_PROCESS_NAME] : getProcessName(0, self.path);
        
        //init signing info
        self.csInfo = info[KEY_CS_INFO];

        //init scope
        // consulted at match time for 'process + kids' rules
        self.scope = info[KEY_SCOPE];

        //process (+ kids) scope (set via alert)
        // set endpoint info to all ('*')
        if( (nil != info[KEY_SCOPE]) &&
            ((ACTION_SCOPE_PROCESS == [info[KEY_SCOPE] intValue]) ||
             (ACTION_SCOPE_PROCESS_TREE == [info[KEY_SCOPE] intValue])) )
        {
            //dbg msg
            os_log_debug(logHandle, "rule info has 'KEY_SCOPE' set to 'ACTION_SCOPE_PROCESS' (or 'ACTION_SCOPE_PROCESS_TREE')");
            
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
            
            //endpoint addr match type {exact, regex, cidr}
            self.isEndpointAddrRegex = [info[KEY_ENDPOINT_ADDR_IS_REGEX] integerValue];
            
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

//is rule a strict process tree policy?
-(BOOL)isStrictProcessTree
{
    return ([self.scope respondsToSelector:@selector(integerValue)] &&
            (ACTION_SCOPE_PROCESS_TREE_STRICT == self.scope.integerValue));
}

//strict policies bind an exact permanent root to explicit network constraints
-(BOOL)isValidStrictProcessTree
{
    if(YES == _strictDecodedInvalid) return NO;
    if(YES != isRuleInteger(self.scope, ACTION_SCOPE_PROCESS_TREE_STRICT, ACTION_SCOPE_PROCESS_TREE_STRICT)) return NO;
    if(YES != isRuleInteger(self.action, RULE_STATE_BLOCK, RULE_STATE_ALLOW)) return NO;
    if(YES != isRuleInteger(self.type, RULE_TYPE_DEFAULT, RULE_TYPE_RECENT)) return NO;
    if((nil != self.isDisabled) && ((YES != [self.isDisabled isKindOfClass:[NSNumber class]]) ||
       ((0 != self.isDisabled.doubleValue) && (1 != self.isDisabled.doubleValue)))) return NO;
    if((nil != self.protocol) && (YES != isRuleInteger(self.protocol, 0, 255))) return NO;
    if((nil != self.pid) || (nil != self.expiration)) return NO;

    if( (YES != [self.path isKindOfClass:[NSString class]]) ||
        (YES != [self.path hasPrefix:@"/"]) || (YES == [self.path hasSuffix:@"/"]) ||
        (NSNotFound != [self.path rangeOfString:@"*"].location) ||
        (YES != [self.path isEqualToString:self.path.stringByStandardizingPath]) ) return NO;

    if((YES != [self.endpointAddr isKindOfClass:[NSString class]]) || (0 == self.endpointAddr.length)) return NO;
    if((YES != [self.endpointPort isKindOfClass:[NSString class]]) || (0 == self.endpointPort.length)) return NO;
    if(YES != [self.endpointPort isEqualToString:VALUE_ANY])
    {
        if(NSNotFound != [self.endpointPort rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet].location) return NO;
        if((self.endpointPort.integerValue < 1) || (self.endpointPort.integerValue > 65535)) return NO;
    }
    //strict endpoints match only numeric network addresses
    if(EndpointTypeCIDR == self.isEndpointAddrRegex)
    {
        if(YES != isAddressRange(self.endpointAddr)) return NO;
    }
    else if(EndpointTypeExact == self.isEndpointAddrRegex)
    {
        uint8_t address[16] = {0};
        if((YES != [self.endpointAddr isEqualToString:VALUE_ANY]) &&
           (1 != inet_pton(AF_INET, self.endpointAddr.UTF8String, address)) &&
           (1 != inet_pton(AF_INET6, self.endpointAddr.UTF8String, address))) return NO;
    }
    else return NO;

    //unsigned roots use their exact path; signed roots additionally pin identifier and team
    if(nil != self.csInfo)
    {
        if(YES != [self.csInfo isKindOfClass:[NSDictionary class]]) return NO;
        id authorities = self.csInfo[KEY_CS_AUTHS];
        if(nil != authorities)
        {
            if(YES != [authorities isKindOfClass:[NSArray class]]) return NO;
            for(id authority in authorities)
            {
                if(YES != [authority isKindOfClass:[NSString class]]) return NO;
            }
        }
        id cdhash = self.csInfo[KEY_CS_CDHASH];
        if(nil != cdhash)
        {
            if((YES != [cdhash isKindOfClass:[NSString class]]) || (40 != [cdhash length])) return NO;
            if(NSNotFound != [cdhash rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location) return NO;
        }
        id status = self.csInfo[KEY_CS_STATUS];
        if(YES != isRuleInteger(status, INT_MIN, INT_MAX)) return NO;
        if(errSecCSUnsigned == [status integerValue])
        {
            if((nil != self.csInfo[KEY_CS_ID]) || (nil != self.csInfo[KEY_CS_TEAM_ID]) || (nil != authorities) || (nil != cdhash)) return NO;
            if((nil != self.csInfo[KEY_CS_SIGNER]) && (YES != isRuleInteger(self.csInfo[KEY_CS_SIGNER], None, None))) return NO;
        }
        else
        {
            if(errSecSuccess != [status integerValue]) return NO;
            id signingID = self.csInfo[KEY_CS_ID];
            id teamID = self.csInfo[KEY_CS_TEAM_ID];
            id signer = self.csInfo[KEY_CS_SIGNER];
            if((nil != teamID) && (YES != [teamID isKindOfClass:[NSString class]])) return NO;
            if(0 != [teamID length])
            {
                if((YES != [signingID isKindOfClass:[NSString class]]) || (0 == [signingID length])) return NO;
                if(YES != isRuleInteger(signer, Apple, DevID)) return NO;
            }
            else
            {
                if((nil != signingID) && (YES != [signingID isKindOfClass:[NSString class]])) return NO;
                if(nil == cdhash) return NO;
                if((YES != isRuleInteger(signer, None, None)) && (YES != isRuleInteger(signer, Apple, Apple)) &&
                   (YES != isRuleInteger(signer, AdHoc, AdHoc))) return NO;
            }
        }
    }

    return YES;
}

//is rule temporary?
// ...just if its duration is set to process lifetime (e.g. has a pid)
-(BOOL)isTemporary
{
    return (nil != self.pid);
}

//is rule user (created)?
-(BOOL)isUserCreated
{
    return (self.type.intValue == RULE_TYPE_USER);
}

//lazily compile & cache the endpoint regex
// note: endpointAddr is immutable after creation, so the compiled regex is safe to cache
-(NSRegularExpression*)compiledEndpointRegex
{
    //compile once
    // note: globs are stored as entered (for the UI), so convert to a regex here
    @synchronized(self)
    {
        if(nil == self.endpointRegex)
        {
            //pattern
            NSString* pattern = nil;

            //glob?
            // convert to an (already-anchored) regex
            if(EndpointTypeGlob == self.isEndpointAddrRegex)
            {
                pattern = regexFromGlob(self.endpointAddr);
            }
            //raw regex
            // anchor for a full-string match, so e.g. 'apple\.com' does NOT match 'apple.com.evil.com'
            // note: '(?:...)' wraps the user's pattern so any top-level alternation ('a|b') stays within the anchors
            else
            {
                pattern = [NSString stringWithFormat:@"^(?:%@)$", self.endpointAddr];
            }

            self.endpointRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        }
    }

    return self.endpointRegex;
}

//check if a numeric IP string falls within this rule's CIDR/range endpoint
// note: parses & caches the bounds on first use (endpointAddr is immutable after creation)
-(BOOL)endpointAddrInRange:(NSString*)address
{
    //parse (& cache) bounds once
    @synchronized(self)
    {
        if(NO == _cidrParsed)
        {
            _cidrValid = parseAddressRange(self.endpointAddr, &_cidrFamily, _cidrLo, _cidrHi, &_cidrLength);
            _cidrParsed = YES;
        }
    }

    //couldn't parse? no match
    if(NO == _cidrValid) return NO;

    //numeric containment check
    return addressInRange(address, _cidrFamily, _cidrLo, _cidrHi, _cidrLength);
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

        //endpoint addr match type {exact, regex, cidr, glob}
        // note: newer archives store this as an object, so it decodes directly
        //       legacy archives stored it as an inline primitive (a bool, then later an integer), which
        //       'decodeObjectOfClass:' can't read (returns nil, w/o throwing) ...so derive it from the address
        // important: do NOT use 'decodeIntegerForKey:'/'decodeBoolForKey:' here — either throws on the
        //            other's format, which (w/ a raising decoder) aborts the entire load & loses all rules
        NSNumber* endpointAddrType = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(isEndpointAddrRegex))];
        self.isEndpointAddrRegex = (nil != endpointAddrType) ? endpointAddrType.integerValue : endpointTypeForAddress(self.endpointAddr);
        self.endpointHost = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(endpointHost))];
        self.endpointPort = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(endpointPort))];
        
        self.type = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(type))];
        self.scope = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(scope))];
        if(YES == [self isStrictProcessTree])
        {
            self.protocol = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(protocol))];
        }
        if( (YES == [self isStrictProcessTree]) &&
            (((nil != endpointAddrType) && (YES != isRuleInteger(endpointAddrType, EndpointTypeExact, EndpointTypeGlob))) ||
             ((nil == endpointAddrType) && [decoder containsValueForKey:NSStringFromSelector(@selector(isEndpointAddrRegex))])) ) _strictDecodedInvalid = YES;
        self.action = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(action))];
        
        self.isDisabled = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(isDisabled))];
        
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
    //endpoint addr match type
    // note: encoded as an object (not a primitive), so it can be decoded w/o any chance of a
    //       type-mismatch exception (which would abort the decode of *all* rules)
    [encoder encodeObject:(_strictDecodedInvalid ? @(-1) : @(self.isEndpointAddrRegex)) forKey:NSStringFromSelector(@selector(isEndpointAddrRegex))];
    
    [encoder encodeObject:self.type forKey:NSStringFromSelector(@selector(type))];
    [encoder encodeObject:self.scope forKey:NSStringFromSelector(@selector(scope))];
    if(YES == [self isStrictProcessTree])
    {
        [encoder encodeObject:self.protocol forKey:NSStringFromSelector(@selector(protocol))];
    }
    [encoder encodeObject:self.action forKey:NSStringFromSelector(@selector(action))];
    
    [encoder encodeObject:self.isDisabled forKey:NSStringFromSelector(@selector(isDisabled))];

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
    id pid = @"all";
    id isDisabled = @NO;
    id expiration = @"never";
    
    //has pid?
    if(self.pid)
    {
        pid = self.pid;
    }
    
    //has expiration?
    if(self.expiration)
    {
        expiration = self.expiration;
    }
    
    //disabled?
    if(self.isDisabled) {
        isDisabled = self.isDisabled;
    }
    
    //just serialize
    return [NSString stringWithFormat:@"RULE: pid: %@, path: %@, name: %@, endpoint addr: %@, endpoint port: %@, action: %@, type: %@, disabled: %@, creation: %@, expiration: %@", pid, self.path, self.name, self.endpointAddr, self.endpointPort, self.action, self.type, isDisabled, self.creation, expiration];
}

//covert rule to dictionary
// needed for conversion to JSON
// note: temporary properties (such as pid) not included
-(NSMutableString*)toJSON
{
    if((YES == [self isStrictProcessTree]) && (YES != [self isValidStrictProcessTree])) return nil;
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
    
    //key
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(key)), self.key];
    
    //uuid
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(uuid)), self.uuid];
    
    //path
    escaped = toEscapedJSON(self.path);
    if(nil != escaped)
    {
        [json appendFormat:@"\"%@\" : %@,", NSStringFromSelector(@selector(path)), escaped];
    }
    
    //name
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
        [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(creation)), [dateFormatter stringFromDate:self.creation]];
    }
    
    //expiration
    if(nil != self.expiration)
    {
        [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(expiration)), [dateFormatter stringFromDate:self.expiration]];
    }

    //port
    [json appendFormat:@"\"%@\" : \"%@\",", NSStringFromSelector(@selector(endpointPort)), self.endpointPort];
    
    //endpoint addr match type {exact, regex, cidr}
    [json appendFormat:@"\"%@\" : %ld,", NSStringFromSelector(@selector(isEndpointAddrRegex)), (long)self.isEndpointAddrRegex];

    //type
    [json appendFormat:@"\"%@\" : %d,", NSStringFromSelector(@selector(type)), self.type.intValue];
    
    //disabled
    if(nil != self.isDisabled)
    {
        [json appendFormat:@"\"%@\" : %d,", NSStringFromSelector(@selector(isDisabled)), self.isDisabled.intValue];
    }
    
    //scope
    [json appendFormat:@"\"%@\" : %d,", NSStringFromSelector(@selector(scope)), self.scope.intValue];
    
    //strict protocol (optional for any network protocol)
    if((YES == [self isStrictProcessTree]) && (nil != self.protocol))
    {
        [json appendFormat:@"\"%@\" : %d,", NSStringFromSelector(@selector(protocol)), self.protocol.intValue];
    }

    //action
    [json appendFormat:@"\"%@\" : %d,", NSStringFromSelector(@selector(action)), self.action.intValue];
    
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
                [json appendFormat:@"\"%@\" : %d,", key, [value intValue]];
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
    id value = nil;
    id inputScope = info[NSStringFromSelector(@selector(scope))];
    BOOL strict = ([inputScope respondsToSelector:@selector(integerValue)] &&
                   (ACTION_SCOPE_PROCESS_TREE_STRICT == [inputScope integerValue]));

    //strict JSON must not lose malformed numeric or lifetime constraints through coercion
    if(YES == strict)
    {
        if((YES != isRuleInteger(inputScope, ACTION_SCOPE_PROCESS_TREE_STRICT, ACTION_SCOPE_PROCESS_TREE_STRICT)) ||
           (YES != isRuleInteger(info[NSStringFromSelector(@selector(action))], RULE_STATE_BLOCK, RULE_STATE_ALLOW)) ||
           (YES != isRuleInteger(info[NSStringFromSelector(@selector(type))], RULE_TYPE_DEFAULT, RULE_TYPE_RECENT)) ||
           ((nil != info[NSStringFromSelector(@selector(isDisabled))]) && (YES != [info[NSStringFromSelector(@selector(isDisabled))] isKindOfClass:[NSNumber class]])) ||
           ((nil != info[NSStringFromSelector(@selector(protocol))]) && (YES != isRuleInteger(info[NSStringFromSelector(@selector(protocol))], 0, 255))) ||
           ((nil != info[NSStringFromSelector(@selector(isEndpointAddrRegex))]) && (YES != isRuleInteger(info[NSStringFromSelector(@selector(isEndpointAddrRegex))], EndpointTypeExact, EndpointTypeGlob))) ||
           (nil != info[KEY_PROCESS_ID]) || (nil != info[KEY_DURATION_EXPIRATION]) ||
           ((nil != info[KEY_DURATION]) && (YES != isRuleInteger(info[KEY_DURATION], RuleDurationAlways, RuleDurationAlways)))) return nil;
    }

    //date formatter
    NSDateFormatter* dateFormatter = nil;
    
    //init formatter
    // format: ISO 8601 format
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
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
            os_log_error(logHandle, "ERROR: 'key' should be a string, not %@", [self.key class]);
            
            self = nil;
            goto bail;
        }
        
        self.uuid = info[NSStringFromSelector(@selector(uuid))];
        if(YES != [self.uuid isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'uuid' should be a string, not %@", [self.uuid class]);
            
            self = nil;
            goto bail;
        }
        
        self.path = info[NSStringFromSelector(@selector(path))];
        if(YES != [self.path isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'path' should be a string, not %@", [self.path class]);
            
            self = nil;
            goto bail;
        }
        
        self.name = info[NSStringFromSelector(@selector(name))];
        if(YES != [self.name isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'name' should be a string, not %@", [self.name class]);
            
            self = nil;
            goto bail;
        }
        
        self.csInfo = info[NSStringFromSelector(@selector(csInfo))];
        if( (nil != self.csInfo) &&
            (YES != [self.csInfo isKindOfClass:[NSDictionary class]]) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'csInfo' should be a dictionary, not %@", [self.csInfo class]);
            
            self = nil;
            goto bail;
        }

        self.endpointAddr = info[NSStringFromSelector(@selector(endpointAddr))];
        if(YES != [self.endpointAddr isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'endpointAddr' should be a string, not %@", [self.endpointAddr class]);
            
            self = nil;
            goto bail;
        }
        
        self.endpointHost = info[NSStringFromSelector(@selector(endpointHost))];
        if( (nil != self.endpointHost) &&
            (YES != [self.endpointHost isKindOfClass:[NSString class]]) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'endpointHost' should be a string, not %@", [self.endpointHost class]);
            
            self = nil;
            goto bail;
        }
        
        self.endpointPort = info[NSStringFromSelector(@selector(endpointPort))];
        if(YES != [self.endpointPort isKindOfClass:[NSString class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'endpointPort' should be a string, not %@", [self.endpointPort class]);
            
            self = nil;
            goto bail;
        }
        
        //endpoint addr match type {exact, regex, cidr, glob}
        // validate before calling 'integerValue', as a non-number (e.g. NSNull) would throw
        id endpointAddrType = info[NSStringFromSelector(@selector(isEndpointAddrRegex))];
        if( (nil != endpointAddrType) &&
            (YES != [endpointAddrType isKindOfClass:[NSNumber class]]) &&
            (YES != [endpointAddrType isKindOfClass:[NSString class]]) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'isEndpointAddrRegex' should be a number, not %@", [endpointAddrType class]);

            self = nil;
            goto bail;
        }
        self.isEndpointAddrRegex = [endpointAddrType integerValue];

        self.type = info[NSStringFromSelector(@selector(type))];
        if([self.type isKindOfClass:[NSString class]]) {
            self.type = @([(NSString*)self.type integerValue]);
        }
        
        if(YES != [self.type isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'type' should be a number, not %@", [self.type class]);
            
            self = nil;
            goto bail;
        }
        
        self.scope = info[NSStringFromSelector(@selector(scope))];
        if([self.scope isKindOfClass:[NSString class]]) {
            self.scope = @([(NSString*)self.scope integerValue]);
        }
        
        if(YES != [self.scope isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'scope' should be a number, not %@", [self.scope class]);
            
            self = nil;
            goto bail;
        }
        
        if(YES == strict) self.protocol = info[NSStringFromSelector(@selector(protocol))];

        self.action = info[NSStringFromSelector(@selector(action))];
        if([self.action isKindOfClass:[NSString class]]) {
            self.action = @([(NSString*)self.action integerValue]);
        }
        
        if(YES != [self.action isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'action' should be a number, not %@", [self.action class]);
            
            self = nil;
            goto bail;
        }
        
        //disabled?
        // note: optional
        self.isDisabled = info[NSStringFromSelector(@selector(isDisabled))];
        if(self.isDisabled && [self.isDisabled isKindOfClass:[NSString class]]) {
            self.isDisabled = @([(NSString*)self.isDisabled integerValue]);
        }
        
        if(self.isDisabled && ![self.isDisabled isKindOfClass:[NSNumber class]])
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'disabled' should be a number or nil, not %@", [self.isDisabled class]);
            
            self = nil;
            goto bail;
        }
        
        //creation (date)
        value = info[NSStringFromSelector(@selector(creation))];
        if(value) {
            
            if(![value isKindOfClass:[NSString class]]) {
                //err msg
                os_log_error(logHandle, "ERROR: 'creation' should be a string, not %@", [value class]);
                
                self = nil;
                goto bail;
            }
            
            self.creation = [dateFormatter dateFromString:value];
            if(!self.creation) {
                //err msg
                os_log_error(logHandle, "ERROR: 'creation' date string is invalid: %@", value);
                
                self = nil;
                goto bail;
            }
        }
        
        //expiration
        value = info[NSStringFromSelector(@selector(expiration))];
        if(value) {
            
            if(![value isKindOfClass:[NSString class]]) {
                //err msg
                os_log_error(logHandle, "ERROR: 'expiration' should be a string, not %@", [value class]);
                
                self = nil;
                goto bail;
            }
            
            self.expiration = [dateFormatter dateFromString:value];
            if(!self.expiration) {
                //err msg
                os_log_error(logHandle, "ERROR: 'expiration' date string is invalid: %@", value);
                
                self = nil;
                goto bail;
            }
        }
        if(YES == strict)
        {
            if(YES != [self isValidStrictProcessTree]) self = nil;
            else self.path = [self.path stringByResolvingSymlinksInPath];
        }
    }

bail:

    return self;
}

@end
