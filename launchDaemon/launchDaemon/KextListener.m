//
//  file: KextListener.m
//  project: lulu (launch daemon)
//  description: listener for events from kernel
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "Rule.h"
#import "Rules.h"
#import "Queue.h"
#import "Alerts.h"
#import "consts.h"
#import "logging.h"
#import "Baseline.h"
#import "procInfo.h"
#import "KextComms.h"
#import "utilities.h"
#import "Preferences.h"
#import "KextListener.h"
#import "ProcListener.h"
#import "UserClientShared.h"

/* GLOBALS */

//rules obj
extern Rules* rules;

//kext comms obj
extern KextComms* kextComms;

//alerts obj
extern Alerts* alerts;

//queue object
extern Queue* eventQueue;

//process monitor
extern ProcessListener* processListener;

//prefs obj
extern Preferences* preferences;

//baseline obj
extern Baseline* baseline;

//client connected
extern NSInteger clientConnected;

@implementation KextListener

@synthesize dnsCache;
@synthesize grayList;
@synthesize passiveProcesses;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init DNS 'cache'
        dnsCache = [NSMutableDictionary dictionary];
        
        //init list for passively allowed procs
        passiveProcesses = [NSMutableArray array];
        
        //init gray list obj
        grayList = [[GrayList alloc] init];
    }
    
    return self;
}

//kick off threads to monitor for kext events
-(void)monitor
{
    //process
    __block Process* process = nil;
    
    //start thread to listen for queue events from kext
    [NSThread detachNewThreadSelector:@selector(processEvents) toTarget:self withObject:nil];
    
    //start process end observer
    self.processEndObvserver =  [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_PROCESS_END object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //extract process
        process = notification.userInfo[NOTIFICATION_PROCESS_END];
        if(nil == process)
        {
            //bail
            return;
        }
        
        //remove from list of passive process
        [self.passiveProcesses removeObject:[NSNumber numberWithInt:process.pid]];
    }];

    return;
}


/* 

// by design, anybody can subscribe to these events
// the code below illustrates this...
 
//thread function
// recv() broadcast connection notification events from kext
-(void)recvNotifications
{
    //status var
    int status = -1;
    
    //system socket
    int systemSocket = -1;
    
    //struct for vendor code
    // ->set via call to ioctl/SIOCGKEVVENDOR
    struct kev_vendor_code vendorCode = {0};
    
    //struct for kernel request
    // ->set filtering options
    struct kev_request kevRequest = {0};
    
    //struct for broadcast data from the kext
    struct kern_event_msg *kernEventMsg = {0};
    
    //message from kext
    // ->size is cumulation of header, struct, and max length of a proc path
    char kextMsg[KEV_MSG_HEADER_SIZE + sizeof(struct connectionEvent)] = {0};
    
    //bytes received from system socket
    ssize_t bytesReceived = -1;
    
    //custom struct
    // ->process data from kext
    struct connectionEvent* connection = NULL;
    
    //create system socket
    systemSocket = socket(PF_SYSTEM, SOCK_RAW, SYSPROTO_EVENT);
    if(-1 == systemSocket)
    {
        //set status var
        status = errno;
        
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"socket() failed with %d", status]);
        
        //bail
        goto bail;
    }
    
    //set vendor name string
    strncpy(vendorCode.vendor_string, OBJECTIVE_SEE_VENDOR, KEV_VENDOR_CODE_MAX_STR_LEN);
    
    //get vendor name -> vendor code mapping
    status = ioctl(systemSocket, SIOCGKEVVENDOR, &vendorCode);
    if(0 != status)
    {
        //bail
        goto bail;
    }
    
    //init filtering options
    // ->only interested in objective-see's events
    kevRequest.vendor_code = vendorCode.vendor_code;
    
    //...any class
    kevRequest.kev_class = KEV_ANY_CLASS;
    
    //...any subclass
    kevRequest.kev_subclass = KEV_ANY_SUBCLASS;
    
    //tell kernel what we want to filter on
    status = ioctl(systemSocket, SIOCSKEVFILT, &kevRequest);
    if(0 != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ioctl(...,SIOCSKEVFILT,...) failed with %d", status]);
        
        //goto bail;
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"created system socket & set options, now entering recv() loop");
 
    //foreverz
    // ->listen/parse network events from kext
    while(YES)
    {
        //ask the kext for process began events
        // ->will block until event is ready
        bytesReceived = recv(systemSocket, kextMsg, sizeof(kextMsg), 0);
        
        //type cast
        // ->to access kev_event_msg header
        kernEventMsg = (struct kern_event_msg*)kextMsg;
        
        //sanity check
        // ->make sure data recv'd looks ok, sizewise
        if( (bytesReceived < KEV_MSG_HEADER_SIZE) ||
            (bytesReceived != kernEventMsg->total_size))
        {
            //ignore
            continue;
        }
        
        //only care about socket events
        if( (EVENT_CONNECT_OUT != kernEventMsg->event_code) &&
            (EVENT_DATA_OUT != kernEventMsg->event_code) )
        {
            //skip
            continue;
        }
        
        //type cast custom data
        // ->begins right after header
        connection = (struct connectionEvent*)&kernEventMsg->event_data[0];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"connection event: pid: %d \n", connection->pid]);
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"connection event: local socket: %@ \n", convertSocketAddr(&connection->localAddress)]);
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"connection event: remote socket: %@ \n", convertSocketAddr(&connection->remoteAddress)]);
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"connection event: socket type: %d \n", connection->socketType]);
        
    }//while(YES)
    
//bail
bail:
    
    //close socket
    if(-1 != systemSocket)
    {
        //close
        close(systemSocket);
    }

    return;
}

*/

//process events from the kernel (queue)
// based on code from Singh's 'Mac OS X Internals' pp. 1466
-(void)processEvents
{
    //status
    kern_return_t status = kIOReturnError;
    
    //mach port for receiving queue events
    mach_port_t recvPort = 0;
    
    //mapped memory
    mach_vm_address_t mappedMemory = 0;
    
    //size of mapped memory
    mach_vm_size_t mappedMemorySize = 0;
    
    //data item on queue
    // custom firewall event struct
    firewallEvent event = {0};
    
    //size of data item on queue
    UInt32 eventSize = 0;
    
    //init size of data item on queue
    eventSize = sizeof(firewallEvent);
    
    //allocate mach port
    // used to receive notifications from IODataQueue
    recvPort = IODataQueueAllocateNotificationPort();
    if(0 == recvPort)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to allocate mach port for queue notifications");
        
        //bail
        goto bail;
    }
    
    //set notification port
    // will call registerNotificationPort() in kext
    status = IOConnectSetNotificationPort(kextComms.connection, 0x1, recvPort, 0x0);
    if(status != kIOReturnSuccess)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to register mach port for queue notifications (error: %d)", status]);
        
        //bail
        goto bail;
    }
    
    //map memory
    // will call clientMemoryForType() in kext
    status = IOConnectMapMemory(kextComms.connection, kIODefaultMemoryType, mach_task_self(), &mappedMemory, &mappedMemorySize, kIOMapAnywhere);
    if(status != kIOReturnSuccess)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to map memory for queue notifications (error: %d)", status]);
        
        //bail
        goto bail;
    }
    
    //wait for data
    while(kIOReturnSuccess == IODataQueueWaitForAvailableData((IODataQueueMemory *)mappedMemory, recvPort))
    {
        //more data?
        while(IODataQueueDataAvailable((IODataQueueMemory *)mappedMemory))
        {
            //reset
            memset(&event, 0x0, sizeof(firewallEvent));
            
            //dequeue a firewall event
            status = IODataQueueDequeue((IODataQueueMemory *)mappedMemory, &event, &eventSize);
            if(kIOReturnSuccess != status)
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to dequeue firewall event (error: %d)", status]);
                
                //next
                continue;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"dequeued new firewall event from kernel (type: %d)", event.genericEvent.type]);
            
            //should ignore?
            if(YES == [preferences.preferences[PREF_IS_DISABLED] boolValue])
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"firewall 'disabled', so ignoring event");
                
                //next
                continue;
            }
            
            //parse/handle event
            switch(event.genericEvent.type)
            {
                //network out events
                case EVENT_NETWORK_OUT:
                {
                    //dispatch to handle/process rule
                    // code signing computations, slow for big apps, don't want those to slow everything down
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        
                        //process
                        [self processNetworkOut:((struct networkOutEvent_s*)&event.networkOutEvent)];
                        
                    });
                    
                    break;
                }
               
                //dns response events
                case EVENT_DNS_RESPONSE:
                {
                    //process
                    [self processDNSResponse:(struct dnsResponseEvent_s*)&event.dnsResponseEvent];
                    
                    break;
                }
                    
                default:
                    break;
            }
        
        } //IODataQueueDataAvailable
        
    } //IODataQueueWaitForAvailableData
    
bail:
    
    //dbg msg
    // since we shouldn't get here unless error/shutdown
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"returning from %s", __PRETTY_FUNCTION__]);
    
    //unmap memory
    if(0 != mappedMemory)
    {
        //unmap
        status = IOConnectUnmapMemory(kextComms.connection, kIODefaultMemoryType, mach_task_self(), mappedMemory);
        if(kIOReturnSuccess != status)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unmap memory (error: %d)", status]);
        }
        
        //unset
        mappedMemory = 0;
    }
    
    //destroy recv port
    if(0 != recvPort)
    {
        //destroy
        mach_port_destroy(mach_task_self(), recvPort);
        
        //unset
        recvPort = 0;
    }
    
    return;
}

//process a network out event from the kernel
// if there is no matching rule, will tell client to show alert
-(void)processNetworkOut:(struct networkOutEvent_s*)event
{
    //alert info
    NSMutableDictionary* alert = nil;
    
    //process obj
    Process* process = nil;
    
    //matching rule obj
    Rule* matchingRule = nil;
    
    //default cs flags
    // note: since this is dynamic check, we don't need to check all architectures, skip resources, etf
    SecCSFlags flags = kSecCSDefaultFlags;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing 'network out' event from kernel queue: %d /  %@", event->pid, convertSocketAddr((struct sockaddr*)&(event->remoteAddress))]);
    
    //check if alert was already processed for this pid
    if(YES == [alerts isRelated:event->pid process:nil])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"an alert already shown for this process (%d), so ignoring", event->pid]);
        
        //bail
        goto bail;
    }
    
    //nap a bit
    // for a processes fork/exec, this should process monitor time to register exec event
    [NSThread sleepForTimeInterval:0.5f];
    
    //try find process via process monitor
    // waits up to one second, since sometime delay in process events
    process = [self findProcess:event->pid];
    if(nil == process)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"couldn't find process (%d) in process monitor", event->pid]);
        
        //couldn't find proc
        // did it die already?
        if(YES != isProcessAlive(event->pid))
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"process is dead (exited?), so ignoring");
            
            //fail 'close'
            // tell kernel to block
            [kextComms addRule:event->pid action:RULE_STATE_BLOCK];
            
            //bail
            goto bail;
        }
        
        //manually create process obj
        process = [[Process alloc] init:event->pid];
    }
    
    //check again
    // should have a process obj now
    if(nil == process)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find and/or create process object for %d, will allow", event->pid]);
        
        //fail 'open'
        // tell kernel to allow...
        [kextComms addRule:event->pid action:RULE_STATE_ALLOW];
        
        //bail
        // not sure what else to do...
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process object for 'network out' event :%@'", process]);

    //proc monitor invoked in 'go easy' mode
    // so generate signing info for process here
    if(nil == process.signingInfo)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generating code signing info for %@ (%d) with flags: %d", process.binary.name, process.pid, flags]);
        
        //generate signing info
        [process generateSigningInfo:flags];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"done generating code signing info");
    }
    
    //not signed, or err?
    // generate hash (sha256)
    if( (nil == process.signingInfo) ||
        (errSecSuccess != [process.signingInfo[KEY_SIGNATURE_STATUS] intValue]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generating hash for %@ (%d)", process.binary.name, process.pid]);
        
        //generate hash
        [process.binary generateHash];
    
        //dbg msg
        logMsg(LOG_DEBUG, @"done generating hash");
    }
    
    //existing rule for process
    matchingRule = [rules find:process];
    if(nil != matchingRule)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found matching rule for %@ (%d): %@\n", process.binary.name, process.pid, matchingRule]);
        
        //tell kernel to add rule for this process
        [kextComms addRule:event->pid action:matchingRule.action.unsignedIntValue];
        
        //all set
        goto bail;
    }
    
    /* NO MATCHING RULE FOUND */
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"no (saved) rule found for %@ (%d)", process.binary.name, process.pid]);
    
    //if it's an apple process and that preference is set; allow!
    // unless the binary is something like 'curl' which malware could abuse (still alert!)
    if( (YES == [preferences.preferences[PREF_ALLOW_APPLE] boolValue]) &&
        (Apple == [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) )
    {
        //though make sure isn't a graylisted binary
        // such binaries, even if signed by apple, should alert user
        if(YES != [grayList isGrayListed:process])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"due to preferences, allowing (non-graylisted) apple process %d/%@", process.pid, process.path]);
            
            //create 'apple' rule
            [rules add:process.path signingInfo:process.signingInfo action:RULE_STATE_ALLOW type:RULE_TYPE_APPLE user:0];
            
            //all set
            goto bail;
        }
        
        //dbg msg
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"while signed by apple, %@ is gray listed, so will alert", process.binary.name]);
        }
    }
    
    //if it's a prev installed 3rd-party process and that preference is set; allow!
    if( (YES == [preferences.preferences[PREF_ALLOW_INSTALLED] boolValue]) &&
        (Apple != [process.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) )
    {
        //pre-installed?
        if(YES == [baseline wasInstalled:process.binary signingInfo:process.signingInfo])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"due to preferences, allowing 3rd-party pre-installed process %@", process.path]);
        
            //create 'installed' rule
            [rules add:process.path signingInfo:process.signingInfo action:RULE_STATE_ALLOW type:RULE_TYPE_BASELINE user:0];
        
            //all set
            goto bail;
        }
        
        //if binary is validly signed
        // check for a parent (pre)installed app
        if( (nil != process.signingInfo) &&
            (noErr == [process.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
            (YES == [baseline wasParentInstalled:process]) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"due to preferences, allowing 3rd-party pre-installed process child %@", process.path]);
            
            //create 'installed' rule
            [rules add:process.path signingInfo:process.signingInfo action:RULE_STATE_ALLOW type:RULE_TYPE_BASELINE user:0];
            
            //all set
            goto bail;
        }
    }
    
    //no connected client
    // a) allow
    // b) save for delivery later...
    if(YES != clientConnected)
    {
        //dbg msg
        // also log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"no active (enabled) client, so telling kernel to 'allow'");
        
        //allow
        [kextComms addRule:event->pid action:RULE_STATE_ALLOW];
        
        //save
        // only 1 per path...
        [alerts addUndeliverted:event process:process];
        
        //all set
        goto bail;
    }
    
    //ignore if client is in passive mode
    if(YES == [preferences.preferences[PREF_PASSIVE_MODE] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client in passive mode, so allowing %@", process.path]);
        
        //allow
        [kextComms addRule:event->pid action:RULE_STATE_ALLOW];
        
        //save
        // will remove rules if user toggles off this mode
        [self.passiveProcesses addObject:[NSNumber numberWithInt:event->pid]];
        
        //all set
        goto bail;
    }
    
    //ok, have an new process, and an active/enabled client!
    // queue up alert to trigger delivery to client, so user can allow/block
    else
    {
        //check if alert was already shown for same path
        // ...and is just awaiting a response from the user
        if(YES == [alerts isRelated:event->pid process:process])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"alert already shown for this path (%@), so ignoring", process.path]);
            
            //add related rule
            [alerts addRelated:event->pid process:process];
            
            //bail
            goto bail;
        }
        
        //create alert
        alert = [alerts create:event process:process];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"no rule found, adding alert to queue: %@", alert]);
        
        //add to global queue
        // will trigger processing of alert
        [eventQueue enqueue:alert];
        
        //save it
        [alerts addShown:alert];
    }
    
bail:
    
    return;
}

//process a dns packet from the kernel
// just looking to extract name/ip address mappings
-(void)processDNSResponse:(struct dnsResponseEvent_s*)event
{
    //dns header
    struct dnsHeader* dnsHeader = NULL;
    
    //end of response
    unsigned char* end = NULL;
    
    //dns data
    unsigned char* dnsData = NULL;
    
    //offset to name
    NSUInteger nameOffset = 0;
    
    //name from CNAME
    NSString* cName = nil;
    
    //name from A/AAAA
    NSString* aName = nil;
    
    //type
    // A, AAAA, etc...
    unsigned short addressType = 0;
    
    //ip address
    NSString* ipAddress = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"processing 'dns response' event from kernel");
    
    //type cast
    dnsHeader = (struct dnsHeader*)event->response;
    
    //init end
    end = event->response+sizeof(event->response);
    
    //print out DNS response
    //for(int i = 0; i<sizeof(event->response); i++)
    //  logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%d/%02x", i, event->response[i] & 0xFF]);

    //init pointer to DNS data
    // begins right after (fixed) DNS header
    dnsData = (unsigned char*)((unsigned char*)dnsHeader + sizeof(struct dnsHeader));
    if(dnsData >= end)
    {
        //bail
        goto bail;
    }
    
    //skip over any question entries
    // they should always come first, ya?
    for(NSUInteger i = 0; i < ntohs(dnsHeader->qdcount); i++)
    {
        //sanity check
        if(dnsData >= end)
        {
            //bail
            goto bail;
        }
        
        //skip over URL
        // look for NULL terminator
        while(*dnsData++);
        
        //skip question type
        dnsData += sizeof(unsigned short);
        if(dnsData >= end)
        {
            //bail
            goto bail;
        }
        
        //skip question class
        dnsData += sizeof(unsigned short);
        if(dnsData >= end)
        {
            //bail
            goto bail;
        }
    }
    
    //now, parse answers
    // this is all we really care about...
    for(NSUInteger i = 0; i < ntohs(dnsHeader->ancount); i++)
    {
        //sanity check
        // answers should be at least 0xC
        if(dnsData+0xC >= end)
        {
            //bail
            goto bail;
        }
        
        //first byte should alway indicated 'offset'
        if(0xC0 != *dnsData++)
        {
            //bail
            goto bail;
        }
        
        //extract name offset
        nameOffset = *dnsData++ & 0xFF;
        if(nameOffset >= sizeof(event->response))
        {
            //bail
            goto bail;
        }
        
        //extract address type
        addressType = ntohs(*(unsigned short*)dnsData);
        
        //only process certain addr types
        // A (0x1), CNAME (0x5), and AAAA (0x1C)
        if( (0x1 != addressType) &&
            (0x5 != addressType) &&
            (0x1C != addressType) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%d is not a supported dns answer type", addressType]);
            
            //bail
            goto bail;
        }
        
        //skip over type
        dnsData += sizeof(unsigned short);

        //skip class
        dnsData += sizeof(unsigned short);
        
        //skip ttl
        dnsData += sizeof(unsigned int);
        
        //address type: CNAME
        // extact (first) instance of name
        if(0x5 == addressType)
        {
            //only extract first
            if(nil == cName)
            {
                //extact name
                cName = extractDNSName((unsigned char*)dnsHeader, (unsigned char*)dnsHeader + nameOffset, (unsigned char*)dnsHeader + sizeof(event->response));
            }
            
            //skip over size + length of data
            dnsData += sizeof(unsigned short) + ntohs(*(unsigned short*)dnsData);
        }
        
        //type A
        else if(0x1 == addressType)
        {
            //extact name
            // but only if we don't have one from the first cname
            if(nil == cName)
            {
                //extract
                aName = extractDNSName((unsigned char*)dnsHeader, (unsigned char*)dnsHeader + nameOffset, (unsigned char*)dnsHeader + sizeof(event->response));
            }
            
            //length should be 4
            if(0x4 != ntohs(*(unsigned short*)dnsData))
            {
                //bail
                goto bail;
            }
            
            //skip over length
            dnsData += sizeof(unsigned short);
            
            //ipv4 addr is 0x4
            if(dnsData+0x4 >= end)
            {
                //bail
                goto bail;
            }
            
            //covert
            ipAddress = convertIPAddr(dnsData, AF_INET);
            
            //skip over IP address
            // for IPv4 addresses, this will always be 4
            dnsData += 0x4;
        }
        
        //type AAAA
        else if(0x1C == addressType)
        {
            //extact name
            // but only if we don't have one from the first cname
            if(nil == cName)
            {
                //extract
                aName = extractDNSName((unsigned char*)dnsHeader, (unsigned char*)dnsHeader + nameOffset, (unsigned char*)dnsHeader + sizeof(event->response));
            }
            
            //length should be 0x10
            if(0x10 != ntohs(*(unsigned short*)dnsData))
            {
                //bail
                goto bail;
            }
            
            //skip over length
            dnsData += sizeof(unsigned short);
            
            //ipv6 addr is 0x10
            if(dnsData+0x10 >= end)
            {
                //bail
                goto bail;
            }
            
            //convert
            ipAddress = convertIPAddr(dnsData, AF_INET6);
            
            //skip over IP address
            // for IPv4 addresses, this will always be 0x10
            dnsData += 0x10;
        }
        
        //add to DNS 'cache'
        if(0 != ipAddress.length)
        {
            //default to first cName
            if(nil != cName)
            {
                //add to cache
                self.dnsCache[ipAddress] = cName;
                
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding cName %@ -> %@ to DNS 'cache'", cName, ipAddress]);
            }
            //otherwise
            // use aName
            else if(nil != aName)
            {
                //add to cache
                self.dnsCache[ipAddress] = aName;
                
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding aName %@ -> %@ to DNS 'cache'", aName, ipAddress]);
            }
        }
        
    }//parse answers
    
bail:
    
    return;
}

//try/wait to get process
// process mon sometimes a bit slow...
-(Process*)findProcess:(pid_t)pid
{
    //process obj
    Process* process = nil;

    //count
    NSUInteger i = 0;

    //try up to a second
    for(i=0; i<10; i++)
    {
        //try find process
        process = processListener.processes[[NSNumber numberWithUnsignedInt:pid]];
        if(nil != process)
        {
            //found  it
            break;
        }
        
        //nap
        [NSThread sleepForTimeInterval:0.10f];
    }
    
    return process;
}

@end
