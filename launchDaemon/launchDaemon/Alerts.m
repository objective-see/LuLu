//
//  file: Alerts.m
//  project: lulu (launch daemon)
//  description: alert related logic/tracking
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Alerts.h"
#import "logging.h"
#import "KextComms.h"
#import "utilities.h"
#import "KextListener.h"

/* GLOBALS */

//kext comms obj
extern KextComms* kextComms;

//kext listener obj
extern KextListener* kextListener;

@implementation Alerts

@synthesize shownAlerts;
@synthesize consoleUser;
@synthesize userObserver;
@synthesize relatedAlerts;
@synthesize xpcUserClient;
@synthesize undelivertedAlerts;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc shown
        shownAlerts = [NSMutableDictionary dictionary];
        
        //alloc related
        relatedAlerts = [NSMutableDictionary dictionary];
        
        //alloc undelivered
        undelivertedAlerts = [NSMutableDictionary dictionary];
        
        //init user xpc client
        xpcUserClient = [[XPCUserClient alloc] init];
        
        //register listener for new client/user (login item)
        // when it fires, deliver any alerts that occured when user wasn't logged in
        self.userObserver = [[NSNotificationCenter defaultCenter] addObserverForName:USER_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            //grab console user
            self.consoleUser = getConsoleUser();
            
            //process alerts
            [self processUndelivered];
        }];
    }
    
    return self;
}

//create an alert object
// note: can treat sockaddr_in and sockaddr_in6 as 'same same' for family, port, etc
-(NSMutableDictionary*)create:(struct networkOutEvent_s*)event process:(Process*)process
{
    //event for alert
    NSMutableDictionary* alert = nil;
    
    //remote ip address
    NSString* remoteAddress = nil;
    
    //remote host name
    NSString* remoteHost = nil;
    
    //alloc
    alert = [NSMutableDictionary dictionary];
    
    //covert IP address to string
    remoteAddress = convertSocketAddr((struct sockaddr*)&(event->remoteAddress));
    
    //add pid
    alert[ALERT_PID] = [NSNumber numberWithUnsignedInt:event->pid];
    
    //add args
    if(0 != process.arguments.count)
    {
        //add
        alert[ALERT_ARGS] = process.arguments;
    }
    
    //add path
    alert[ALERT_PATH] = process.path;
    
    //add (remote) ip
    alert[ALERT_IPADDR] = remoteAddress;
    
    //try get host name from DNS cache
    // since it's based on recv'ing data from kernel, try for a bit...
    for(int i=0; i<5; i++)
    {
        //try grab host name
        remoteHost = kextListener.dnsCache[alert[ALERT_IPADDR]];
        if(nil != remoteHost)
        {
            //add
            alert[ALERT_HOSTNAME] = remoteHost;
            
            //done
            break;
        }
        
        //nap
        [NSThread sleepForTimeInterval:0.10f];
    }
    
    //add (remote) port
    alert[ALERT_PORT] = [NSNumber numberWithUnsignedShort:ntohs(event->remoteAddress.sin6_port)];
    
    //add protocol (socket type)
    alert[ALERT_PROTOCOL] = [NSNumber numberWithInt:event->socketType];
    
    //add signing info
    if(nil != process.signingInfo)
    {
        //add
        alert[ALERT_SIGNINGINFO] = process.signingInfo;
    }
    
    //add hash
    if(nil != process.binary.sha256)
    {
        //add
        alert[ALERT_HASH] = process.binary.sha256;
    }
    
    return alert;
}

//is related to a shown alert?
// a) for a given pid
// b) for this path, if signing info/hash matches
-(BOOL)isRelated:(pid_t)pid process:(Process*)process
{
    //flag
    __block BOOL related = NO;
    
    //alert
    NSDictionary* alert = nil;
    
    //sync
    @synchronized(self.shownAlerts)
    {
        //when process is nil
        // only have pid, so check for any match
        if(nil == process)
        {
            //check for pid match
            [self.shownAlerts enumerateKeysAndObjectsUsingBlock: ^(id key, NSDictionary* alert, BOOL *stop) {
                
                //match?
                if([alert[ALERT_PID] unsignedIntValue] == pid)
                {
                    //set flag
                    related = YES;
                    
                    //stop searching
                    *stop = YES;
                }
            }];
            
            //bail
            goto bail;
        }
        
        //check process
        else
        {
            //grab alert
            // none, means its new
            alert = self.shownAlerts[process.path];
            if(nil == alert)
            {
                //bail
                goto bail;
            }
            
            //check hash first
            if(nil != process.binary.sha256)
            {
                //check
                if(YES == [alert[RULE_HASH] isEqualToString:process.binary.sha256])
                {
                    //ok hashes match
                    related = YES;
                }
                
                //bail
                // either way
                goto bail;
            }
            
            //check code signing info
            else if(nil != process.signingInfo)
            {
                //signing issue?
                if(noErr != [process.signingInfo[KEY_SIGNATURE_STATUS] intValue])
                {
                    //bail
                    goto bail;
                }
                
                //signing auths match?
                if(YES == [[NSCountedSet setWithArray:alert[RULE_SIGNING_INFO][KEY_SIGNATURE_AUTHORITIES]] isEqualToSet: [NSCountedSet setWithArray:process.signingInfo[KEY_SIGNATURE_AUTHORITIES]]])
                {
                    //ok signing match
                    related = YES;
                }
                
                //bail
                // either way
                goto bail;
            }
        }
        
    }//sync
    
bail:
    
    return related;
}

//add an alert to 'related'
-(void)addRelated:(pid_t)pid process:(Process*)process
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding alert to 'related': %@ (%d)", process.path, pid]);
    
    //save
    @synchronized(self.relatedAlerts)
    {
        //first time
        // init array for pids
        if(nil == self.relatedAlerts[process.path])
        {
            //create array
            self.relatedAlerts[process.path] = [NSMutableArray array];
        }
        
        //add
        [self.relatedAlerts[process.path] addObject:[NSNumber numberWithInt:pid]];
    }
    
    return;
}

//process related alerts
// for persistent rules: adds each to kext
// for temporary rules:  deliver to user (via XPC)
-(void)processRelated:(NSDictionary*)alert 
{
    //path
    NSString* path = nil;
    
    //process ids
    NSMutableArray* pids = nil;
    
    //related alert
    NSMutableDictionary* relatedAlert = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"processing any related alerts");
    
    //grab path
    path = alert[ALERT_PATH];
    
    //sync
    @synchronized(self.relatedAlerts)
    {
    
    //grab pids
    pids = self.relatedAlerts[path];
    if(0 == pids.count)
    {
        //bail
        goto bail;
    }

    //rule not temporary?
    // process all pids, sending response to kernel
    if(YES != [alert[ALERT_TEMPORARY] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"rule is not temporary, so applying same user action to all %lu related alerts", (unsigned long)pids.count]);
        
        //process all pids
        // send response to kernel
        for(NSNumber* pid in pids)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding rule for related alert (process: %@)", alert[ALERT_PATH]]);
            
            //tell kext
            [kextComms addRule:pid.unsignedIntValue action:[alert[ALERT_ACTION] unsignedIntValue]];
        }
        
        //remove all
        [self removeRelated:path];
    }
    
    //rule is temporary
    // queue up next related rule
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"rule was temporary, so delivering...");
        
        //make copy of alert
        relatedAlert = [alert mutableCopy];
        
        //update pid
        // everything else should be the same!
        relatedAlert[ALERT_PID] = [pids firstObject];
        
        //now remove (just this) pid from list of related alerts
        [self.relatedAlerts[path] removeObject:relatedAlert[ALERT_PID]];
        if(0 == [self.relatedAlerts[path] count])
        {
            //remove list, as pid was last item
            [self.relatedAlerts removeObjectForKey:path];
        }
        
        //deliver alert
        [self deliver:relatedAlert];
    }
        
    }//sync

bail:
    
    return;
}

//remove an alert from 'related'
-(void)removeRelated:(NSString*)path
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing alert from 'related': %@", path]);
    
    //sync
    @synchronized(self.relatedAlerts)
    {
        //remove from 'related' alerts
        [self.relatedAlerts removeObjectForKey:path];
    }
    
    return;
}

//add an alert to 'shown'
-(void)addShown:(NSDictionary*)alert
{
    //path (key)
    NSString* path = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding alert to 'shown': %@", alert]);
    
    //add alert
    @synchronized(self.shownAlerts)
    {
        //grab path
        path = alert[ALERT_PATH];
        
        //add
        self.shownAlerts[path] = alert;
    }
    
    return;
}

//remove an alert from 'shown'
-(void)removeShown:(NSDictionary*)alert
{
    //path (key)
    NSString* path = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing alert from 'shown': %@", alert]);
    
    //remove alert
    @synchronized(self.shownAlerts)
    {
        //grab path
        path = alert[ALERT_PATH];
    
        //remove
        [self.shownAlerts removeObjectForKey:path];
    }
    
    return;
}

//via XPC, send an alert
-(void)deliver:(NSDictionary*)alert
{
    //send via XPC to user (login item)
    // failure likely means no client, so just allow, but save
    if(YES != [self.xpcUserClient deliverAlert:alert])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"failed to deliver alert to user (no client?)");
        
        //allow process
        [kextComms addRule:[alert[ALERT_PID] unsignedIntValue] action:RULE_STATE_ALLOW];
        
        //save undelivered alert
        [self addUndeliverted:alert];
        
        //bail
        goto bail;
    }
    
    //save alert
    [self addShown:alert];
    
bail:
    
    return;
}

//add an alert 'undelivered'
-(void)addUndeliverted:(NSDictionary*)alert
{
    //path
    NSString* path = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding alert to 'undelivered': %@", alert]);
    
    //add alert
    @synchronized(self.undelivertedAlerts)
    {
        //grab path
        path = alert[ALERT_PATH];
        
        //add
        self.undelivertedAlerts[path] = alert;
    }
    
    return;
}

//process undelivered alerts
// add to queue, and to 'shown' alert
-(void)processUndelivered
{
    //alert
    NSDictionary* alert = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing %lu undelivered alerts", self.undelivertedAlerts.count]);
    
    //sync
    @synchronized(self.undelivertedAlerts)
    {
        //process all undelivered alerts
        // add to queue, and to 'shown' alert
        for(NSString* path in self.undelivertedAlerts.allKeys)
        {
            //grab alert
            alert = self.undelivertedAlerts[path];
            
            //deliver alert
            [self deliver:alert];
    
            //remove
            [self.undelivertedAlerts removeObjectForKey:path];
            
            //save to 'shown'
            [self addShown:alert];
        }
    }
    return;
}

@end
