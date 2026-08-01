//
//  file: Alerts.m
//  project: lulu (launch daemon)
//  description: alert related logic/tracking
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Process.h"
#import "Alerts.h"
#import "utilities.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Alerts

@synthesize shownAlerts;
@synthesize consoleUser;
@synthesize xpcUserClient;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc shown
        shownAlerts = [NSMutableDictionary dictionary];
        
        //init user xpc client
        xpcUserClient = [[XPCUserClient alloc] init];
    }
    
    return self;
}

//create an alert dictionary
-(NSMutableDictionary*)create:(NEFilterSocketFlow*)flow process:(Process*)process
{
    //event for alert
    NSMutableDictionary* alert = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //alloc
    alert = [NSMutableDictionary dictionary];
    
    //add uuid
    alert[KEY_UUID] = [[NSUUID UUID] UUIDString];
    
    //add key
    alert[KEY_KEY] = process.key;
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //add pid
    alert[KEY_PROCESS_ID] = [NSNumber numberWithUnsignedInt:process.pid];
    
    //add args
    if(0 != process.arguments.count)
    {
        //add
        alert[KEY_PROCESS_ARGS] = process.arguments;
    }
    
    //add path
    alert[KEY_PATH] = process.path;
    
    //add name
    alert[KEY_PROCESS_NAME] = process.name;

    //add process state
    if(YES == process.deleted)
    {
        //add
        alert[KEY_PROCESS_DELETED] = @YES;
    }
    
    //process ancestors?
    // ...only add if more than just self
    if(process.ancestors.count > 1)
    {
        //add
        alert[KEY_PROCESS_ANCESTORS] = process.ancestors;
    }
    
    //add (remote) ip
    alert[KEY_HOST] = remoteEndpoint.hostname;

    //add (remote) host name (e.g. DNS name)
    // only available on macOS 11+
    if(@available(macOS 11, *))
    {
        //add
        if(nil != flow.remoteHostname)
        {
            //add
            alert[KEY_HOST_NAME] = flow.remoteHostname;
        }
    }

    //add (remote) host
    // as string though, since XPC doesn't like NSURLs
    if(nil != flow.URL)
    {
        //add
        alert[KEY_URL] = flow.URL.absoluteString;
    }
        
    //add (remote) port
    alert[KEY_ENDPOINT_PORT] = remoteEndpoint.port;
    
    //add protocol
    alert[KEY_PROTOCOL] = [NSNumber numberWithInt:flow.socketProtocol];

    //add signing info
    if(nil != process.csInfo)
    {
        //add
        alert[KEY_CS_INFO] = process.csInfo;
    }

    return alert;
}

//is related to a shown alert?
// checks if path/signing info is same
-(BOOL)isRelated:(Process*)process
{
    //flag
    __block BOOL related = NO;
    
    //alert
    NSDictionary* alert = nil;
    
    //sync
    @synchronized(self.shownAlerts)
    {
        //grab alert
        // none, means its new
        alert = self.shownAlerts[process.key];
        if(nil == alert)
        {
            //bail
            goto bail;
        }
        
        //related
        related = YES;
    
    }//sync
    
bail:
    
    return related;
}

//add an alert to 'shown'
-(void)addShown:(NSDictionary*)alert
{
    //dbg msg
    os_log_debug(logHandle, "adding alert to 'shown': %{public}@ -> %{public}@", alert[KEY_KEY], alert);
    
    //add alert
    @synchronized(self.shownAlerts)
    {
        //add
        self.shownAlerts[alert[KEY_KEY]] = alert;
    }
    
    return;
}

//remove alert(s) from 'shown'
// pass a (process) key to remove that one; pass nil to remove all
// note: removing all is needed when the client (GUI) goes away, else a process w/ a pending
//       alert stays 'related' forever (its flows queue into relatedFlows but never drain)
-(void)removeShown:(NSString*)key
{
    //sync
    @synchronized(self.shownAlerts)
    {
        //specific key?
        if(nil != key)
        {
            //dbg msg
            os_log_debug(logHandle, "removing alert from 'shown' for key: %{public}@", key);

            //remove
            [self.shownAlerts removeObjectForKey:key];
        }
        //nil key: remove all
        else
        {
            //dbg msg
            os_log_debug(logHandle, "removing all (%lu) shown alerts", (unsigned long)self.shownAlerts.count);

            //remove all
            [self.shownAlerts removeAllObjects];
        }
    }

    return;
}

//via XPC, send an alert to the client (user)
-(BOOL)deliver:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply
{
    //flag
    BOOL delivered = NO;

    //dbg msg
    os_log_debug(logHandle, "delivering alert %{public}@", alert);

    //send via XPC to user
    if(YES != (delivered = [self.xpcUserClient deliverAlert:alert reply:reply]))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to deliver alert to user (no client?)");
        
        //bail
        goto bail;
    }

bail:
    
    return delivered;
}

@end
