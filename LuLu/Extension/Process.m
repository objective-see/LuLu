//
//  File: Process.m
//  Project: Proc Info
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//  License:    Creative Commons Attribution-NonCommercial 4.0 International License
//

#import "signing.h"
#import "Process.h"
#import "Utilities.h"

#import <dlfcn.h>
#import <libproc.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Process

@synthesize pid;
@synthesize exit;
@synthesize path;
@synthesize csInfo;
@synthesize ancestors;
@synthesize arguments;
@synthesize timestamp;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc array for args
        arguments = [NSMutableArray array];
        
        //alloc array for parents
        ancestors = [NSMutableArray array];
            
        //set start time
        timestamp = [NSDate date];
        
        //init pid
        self.pid = -1;
        
        //init user
        self.uid = -1;
        
        //init exit
        self.exit = -1;
    }
    
    return self;
}

//init with a token / pid
// method will then (try) fill out rest of object
-(id)init:(audit_token_t*)token
{
    //current token
    NSData* currentToken = nil;
    
    //init self/super
    self = [self init];
    if(self)
    {
        //save pid
        self.pid = audit_token_to_pid(*token);
        if(0 == self.pid)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'audit_token_to_pid' returned NULL\n");
            
            //unset
            self = nil;
            
            //bail
            goto bail;
        }
        
        //get path
        // also sets 'self.deleted' iVar
        [self getPath:token];
        if(0 == self.path.length)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to find path for process %d\n", self.pid);
            
            //unset
            self = nil;
            
            //bail
            goto bail;
        }
        
        //set name
        //name for normal procs
        if(YES != self.deleted)
        {
            //get/add
            self.name = getProcessName(0, self.path);
        }
        //for delete procs
        // get path via pid
        else
        {
            //get/add
            self.name = getProcessName(self.pid, self.path);
        }
        
        //get user
        self.uid = audit_token_to_euid(*token);
        
        //generate (dynamic) code information
        [self generateSigningInfo:token];
        
        //generate key
        // based on cs info, or path
        self.key = [self generateKey];
        
        //init binary
        self.binary = [[Binary alloc] init:self.path];
        
        /* pid specific logic
           note: pids can wrap,
           so we check audit token is still same!
         */
        
        //set args
        [self getArgs];
        
        //enum ancestors
        [self enumerateAncestors];
        
        //grab current (audit) token
        currentToken = tokenForPid(self.pid);
        
        //check!
        // if it's changed, means pid points to new process, so unset parent, args, etc as these may be invalid!
        if( (0 == currentToken.length) ||
            (audit_token_to_pidversion(*token) != audit_token_to_pidversion(*(audit_token_t*)currentToken.bytes)) )
        {
            //err msg
            os_log_error(logHandle, "ERROR: audit token mismatch ...pid re-used?");
            
            //unset
            arguments = nil;
            
            //alloc array for parents
            ancestors = nil;
        }
    }
    
bail:
    
    return self;
}

//generate key
// note: this matches rules' generate key algo
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
    os_log_debug(logHandle, "generated process key: %{public}@", key);

    return key;
}

//generate list of ancestors
-(void)enumerateAncestors
{
    //current process id
    pid_t currentPID = -1;
    
    //current name
    NSString* currentName = nil;
    
    //parent pid
    pid_t parentPID = -1;
    
    //rpid function
    static pid_t (*getRPID)(pid_t pid) = NULL;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //only once
    // init requirements
    dispatch_once(&onceToken, ^{
        
        //get function pointer
        getRPID = dlsym(RTLD_NEXT, "responsibility_get_pid_responsible_for_pid");
        
    });
    
    //start w/ self
    currentPID = self.pid;
    
    do {
        
        //get name
        if(nil == (currentName = getProcessPath(currentPID)))
        {
            //default
            currentName = @"unknown";
        }
        
        //add
        [self.ancestors insertObject:[@{KEY_PROCESS_ID:[NSNumber numberWithInt:currentPID], KEY_PROCESS_NAME:currentName} mutableCopy] atIndex:0];
        
        //for parent
        // first try via rPID
        if(NULL != getRPID)
        {
            //get rpid
            parentPID = getRPID(currentPID);
        }
        
        //couldn't find/get rPID?
        // default back to using standard method
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //get parent pid
            parentPID = getParent(currentPID);
        }
        
        //done?
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //bail
            break;
        }
        
        //update
        currentPID = parentPID;
        
    } while(YES);
    
    //now, will all items added
    // add each item's index for UI purposes
    for(NSUInteger i = 0; i < self.ancestors.count; i++)
    {
        //set index
        self.ancestors[i][KEY_INDEX] = [NSNumber numberWithInteger:i];
    }

    return;
}

//set process's path
-(void)getPath:(audit_token_t*)token
{
    //status
    OSStatus status = !errSecSuccess;
    
    //code ref
    SecCodeRef code = NULL;
    
    //path
    CFURLRef path = nil;
    
    //obtain code ref
    status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit:[NSData dataWithBytes:token length:sizeof(audit_token_t)]}), kSecCSDefaultFlags, &code);
    if(errSecSuccess == status)
    {
        //copy path
        status = SecCodeCopyPath(code, kSecCSDefaultFlags, &path);
        if(errSecSuccess == status)
        {
            //extract/copy path
            self.path = [((__bridge NSURL*)path).path copy];
        }
        //err msg
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'SecCodeCopyPath' failed with': %#x", status);
        }
    }
    //err msg
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'SecCodeCopyGuestWithAttributes' failed with': %#x", status);
    }
    
    //process's binary deleted?
    if(kPOSIXErrorENOENT == status)
    {
        //dbg msg
        os_log_debug(logHandle, "process %d's binary appears to be deleted", pid);
        
        //set flag
        self.deleted = YES;
    }

    //path (still) nil?
    // try other methods
    if(nil == path)
    {
        //get path via pid
        self.path = getProcessPath(self.pid);
    }
    
    //resolve symlinks
    self.path = [self.path stringByResolvingSymlinksInPath];
    
    //free path
    if(NULL != path)
    {
        //free
        CFRelease(path);
        path = NULL;
    }
    
    //free code ref
    if(NULL != code)
    {
        //free
        CFRelease(code);
        code = NULL;
    }
    
    return;
}

//extract commandline args
// saves into 'arguments' ivar
-(void)getArgs
{
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* processArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //arg
    NSString* argument = nil;
    
    //start of (each) arg
    char* argStart = NULL;
    
    //size of buffers, etc
    size_t size = 0;
    
    //parser pointer
    char* parser = NULL;
    
    //init mib
    // want system's size for max args
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    //set size
    size = sizeof(systemMaxArgs);
    
    //get system's size for max args
    if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
    {
        //bail
        goto bail;
    }
    
    //alloc space for args
    processArgs = malloc(systemMaxArgs);
    if(NULL == processArgs)
    {
        //bail
        goto bail;
    }
    
    //init mib
    // want process args
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pid;
    
    //set size
    size = (size_t)systemMaxArgs;
    
    //get process's args
    if(-1 == sysctl(mib, 3, processArgs, &size, NULL, 0))
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // ensure buffer is somewhat sane
    if(size <= sizeof(int))
    {
        //bail
        goto bail;
    }
    
    //extract number of args
    // at start of buffer
    memcpy(&numberOfArgs, processArgs, sizeof(numberOfArgs));
    
    //init pointer to start of args
    // they start right after # of args
    parser = processArgs + sizeof(numberOfArgs);
    
    //scan until end of process's NULL-terminated path
    while(parser < &processArgs[size])
    {
        //scan till NULL-terminator
        if(0x0 == *parser)
        {
            //end of exe name
            break;
        }
        
        //next char
        parser++;
    }
    
    //sanity check
    // make sure end-of-buffer wasn't reached
    if(parser == &processArgs[size])
    {
        //bail
        goto bail;
    }
    
    //skip all trailing NULLs
    // scan will end when non-NULL is found
    while(parser < &processArgs[size])
    {
        //scan till NULL-terminator
        if(0x0 != *parser)
        {
            //ok, got to argv[0]
            break;
        }
        
        //next char
        parser++;
    }
    
    //sanity check
    // (again), make sure end-of-buffer wasn't reached
    if(parser == &processArgs[size])
    {
        //bail
        goto bail;
    }
    
    //parser should now point to argv[0], process name
    // init arg start
    argStart = parser;
    
    //keep scanning until all args are found
    // each is NULL-terminated
    while(parser < &processArgs[size])
    {
        //each arg is NULL-terminated
        // so scan till NULL, then save into array
        if(*parser == '\0')
        {
            //save arg
            if(NULL != argStart)
            {
                //try convert
                // ignore (if not UTF8, etc...)
                argument = [NSString stringWithUTF8String:argStart];
                if(nil != argument)
                {
                    //save
                    [self.arguments addObject:argument];
                }
            }
            
            //init string pointer to (possibly) next arg
            argStart = ++parser;
            
            //bail if we've hit arg cnt
            if(self.arguments.count == numberOfArgs)
            {
                //bail
                break;
            }
        }
        
        //next char
        parser++;
    }
    
bail:
    
    //free process args
    if(NULL != processArgs)
    {
        //free
        free(processArgs);
        
        //unset
        processArgs = NULL;
    }
    
    return;
}



//generate signing info
-(void)generateSigningInfo:(audit_token_t*)token
{
    //signing info
    NSMutableDictionary* extractedSigningInfo = nil;
    
    //extract signing info
    extractedSigningInfo = extractSigningInfo(token, nil, kSecCSDefaultFlags);
    
    //valid?
    // save into iVar
    if( (nil != extractedSigningInfo[KEY_CS_STATUS]) &&
        (noErr == [extractedSigningInfo[KEY_CS_STATUS] intValue]))
    {
        //save
        self.csInfo = extractedSigningInfo;
    }
    //dbg msg
    else os_log_debug(logHandle, "invalid code signing information for %{public}@: %{public}@", self.path, extractedSigningInfo);

    return;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"pid: %d\npath: %@\nuser: %d\nargs: %@\nancestors: %@\n signing info: %@\n binary:\n%@", self.pid, self.path, self.uid, self.arguments, self.ancestors, self.csInfo, self.binary];
}

@end
