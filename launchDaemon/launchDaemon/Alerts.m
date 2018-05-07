//
//  file: Alerts.m
//  project: lulu (launch daemon)
//  description: alert related logic/tracking
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Queue.h"
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

//queue object
extern Queue* eventQueue;

@implementation Alerts

@synthesize shownAlerts;
@synthesize relatedAlerts;
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
    
    //add path
    alert[ALERT_PATH] = process.path;
    
    //add (remote) ip
    alert[ALERT_IPADDR] = convertSocketAddr((struct sockaddr*)&(event->remoteAddress));
    
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
    if(nil != process.binary.signingInfo)
    {
        //add
        alert[ALERT_SIGNINGINFO] = process.binary.signingInfo;
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
            else if(nil != process.binary.signingInfo)
            {
                //signing issue?
                if(noErr != [process.binary.signingInfo[KEY_SIGNATURE_STATUS] intValue])
                {
                    //bail
                    goto bail;
                }
                
                //signing auths match?
                if(YES == [[NSCountedSet setWithArray:alert[RULE_SIGNING_INFO][KEY_SIGNING_AUTHORITIES]] isEqualToSet: [NSCountedSet setWithArray:process.binary.signingInfo[KEY_SIGNING_AUTHORITIES]]])
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
// adds each to kext, and removes
-(void)processRelated:(NSDictionary*)alert
{
    //path
    NSString* path = nil;
    
    //process ids
    NSMutableSet* pids = nil;
    
    //grab path
    path = alert[ALERT_PATH];
    
    //grab pids
    pids = self.relatedAlerts[path];
    
    //process all pids
    // send response to kernel
    for(NSNumber* pid in pids)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding rule for related alert (process: %@)", alert[ALERT_PATH]]);
        
        //tell kext
        [kextComms addRule:pid.unsignedIntValue action:[alert[ALERT_ACTION] unsignedIntValue]];
    }
    
    //remove
    [self removeRelated:path];
    
    return;
}

//remove an alert from 'related'
-(void)removeRelated:(NSString*)path
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing alert to 'related': %@", path]);
    
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

//add an alert 'undelivered'
-(void)addUndeliverted:(struct networkOutEvent_s*)event process:(Process*)process
{
    //alert
    NSDictionary* alert = nil;
    
    //path
    NSString* path = nil;
    
    //create
    alert = [self create:event process:process];
    
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
    logMsg(LOG_DEBUG, @"processing undelivered alerts");
    
    //sync
    @synchronized(self.undelivertedAlerts)
    {
        //process all undelivered alerts
        // add to queue, and to 'shown' alert
        for(NSString* path in self.undelivertedAlerts)
        {
            //grab alert
            alert = self.undelivertedAlerts[path];
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"enqueue'ing alert: %@", alert]);
            
            //add to global queue
            // this will trigger processing of alert
            [eventQueue enqueue:alert];
            
            //save to 'shown'
            [self addShown:alert];
        }
    
    }
    
    return;
}

//remove an alert from 'undelivered'
-(void)removeUndeliverted:(NSDictionary*)alert
{
    //path (key)
    NSString* path = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing alert from 'undelivered': %@", alert]);
    
    //remove alert
    @synchronized(self.undelivertedAlerts)
    {
        //grab path
        path = alert[ALERT_PATH];
        
        //remove
        [self.undelivertedAlerts removeObjectForKey:path];
    }
    
    return;
}

@end
