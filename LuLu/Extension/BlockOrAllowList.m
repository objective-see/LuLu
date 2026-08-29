//
//  BlockOrAllowList.m
//  Extension
//
//  Created by Patrick Wardle on 11/6/20.
//  Copyright © 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Preferences.h"
#import "BlockOrAllowList.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//preferences
extern Preferences* preferences;

@implementation BlockOrAllowList

-(id)init:(NSString*)path
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save list
        self.path = path;
        
        //load
        [self load:self.path];
    }
    
    return self;
}

//was specified block list remote
// ...just checks if prefixed with http:// || https://
-(BOOL)isRemote
{
    //specified path a URL?
    return ((YES == [self.path hasPrefix:@"http://"]) || (YES == [self.path hasPrefix:@"https://"]));
}

//should reload
// checks file modification time
-(BOOL)shouldReload
{
    //flag
    BOOL shouldReload = NO;
    
    //current mod. time
    NSDate* modified = nil;
    
    //if it's remote
    // can't tell, so default to no
    if(YES == [self isRemote])
    {
        //bail
        goto bail;
    }

    //no (local) path?
    // nothing loaded, so nothing to reload
    if(0 == self.path.length)
    {
        //bail
        goto bail;
    }

    //get modified timestamp
    modified = [[NSFileManager.defaultManager attributesOfItemAtPath:self.path error:nil] objectForKey:NSFileModificationDate];

    //no timestamp?
    // file is gone/unreadable -> reload (to clear) if we still hold stale items
    // note: load: empties items, so this naturally fires just once (not per-flow)
    if(nil == modified)
    {
        //stale items to clear?
        if(0 != self.items.count)
        {
            //dbg msg
            os_log_debug(logHandle, "list file is missing/unreadable ...will reload to clear stale items");

            //yes
            shouldReload = YES;
        }

        //bail
        goto bail;
    }

    //was file modified?
    if(NSOrderedDescending == [modified compare:self.lastModified])
    {
        //dbg msg
        os_log_debug(logHandle, "block list was modified ...will reload");

        //yes
        shouldReload = YES;
    }
    
bail:
    
    return shouldReload;
}

//stop the daily (remote) reload timer, if any
-(void)stopReloadTimer
{
    if(nil != self.reloadTimer)
    {
        dispatch_source_cancel(self.reloadTimer);
        self.reloadTimer = nil;
    }
}

//clear the list
// empties items & stops any (remote) reload timer
-(void)clear
{
    //sync
    @synchronized (self) {

        //dbg msg
        os_log_debug(logHandle, "clearing list");

        //reset path
        self.path = @"";

        //reset list
        [self.items removeAllObjects];

        //reset timestamp
        self.lastModified = nil;

        //stop any (remote) reload timer
        [self stopReloadTimer];
    }
}

//(re)load
-(BOOL)load:(NSString*)path
{
    //result
    BOOL loaded = NO;

    //error
    NSError* error = nil;
    
    //file contents
    NSString* list = nil;
    
    //sync
    @synchronized (self) {
        
    //update path
    self.path = path;
        
    //dbg msg
    os_log_debug(logHandle, "%s", __PRETTY_FUNCTION__);
    
    //check
    // path?
    if(0 == self.path.length)
    {
        //dbg msg
        os_log_debug(logHandle, "no list specified...");

        //no remote list -> stop any reload timer
        [self stopReloadTimer];

        //nothing to load (success)
        loaded = YES;

        //bail
        goto bail;
    }
        
    //remote?
    // load via URL
    if(YES == [self isRemote])
    {
        //dbg msg
        os_log_debug(logHandle, "(re)loading (remote) list");
        
        //load
        list = [NSString stringWithContentsOfURL:[NSURL URLWithString:self.path] encoding:NSUTF8StringEncoding error:&error];
        if(nil != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to (re)load (remote) list, %{public}@ (error: %{public}@)", self.path, error);

            //bail
            goto bail;
        }

        //arm the daily (re)load timer, just once
        // a single repeating source - so reloads don't stack on each load:
        if(nil == self.reloadTimer)
        {
            //weak self, to avoid pinning this object via the (forever-repeating) timer
            __weak typeof(self) weakSelf = self;

            //create + schedule (first fire in 24h, then every 24h)
            self.reloadTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
            dispatch_source_set_timer(self.reloadTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(24 * 60 * 60 * NSEC_PER_SEC)), (uint64_t)(24 * 60 * 60 * NSEC_PER_SEC), (uint64_t)(60 * 60 * NSEC_PER_SEC));
            dispatch_source_set_event_handler(self.reloadTimer, ^{

                //dbg msg
                os_log_debug(logHandle, "(re)loading (remote) list");

                //(re)load (current path)
                [weakSelf load:weakSelf.path];
            });
            dispatch_resume(self.reloadTimer);
        }
    }
    
    //local file
    // check and load
    else
    {
        //dbg msg
        os_log_debug(logHandle, "(re)loading (local) list, %{public}@", self.path);

        //local (not remote) -> stop any reload timer
        [self stopReloadTimer];

        //(re)load
        list = [NSString stringWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:&error];
        if(nil != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to (re)load (local) list, %{public}@ (error: %{public}@)", self.path, error);
            
            // clear items, as 'shouldReload' intends
            [self.items removeAllObjects];
            
            //bail
            goto bail;
        }
        
        //save timestamp
        self.lastModified = [[NSFileManager.defaultManager attributesOfItemAtPath:self.path error:nil] objectForKey:NSFileModificationDate];
    }
    
    //init set
    // of trimmed/lower-cased items
    self.items = [NSMutableSet setWithArray:[[[list componentsSeparatedByString:@"\n"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *item, NSDictionary *bindings) {
                //trim
                NSString* trimmed = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                //make sure its not empty/not a comment
                return (trimmed.length > 0 && ![trimmed hasPrefix:@"#"]);
        
            }]] valueForKey:@"lowercaseString"]];
        
    //dbg msg
    os_log_debug(logHandle, "(re)loaded %lu list items", (unsigned long)self.items.count);

    //success
    loaded = YES;

    } //sync

bail:

    return loaded;
}

//check if flow matches item on block or allow list
// note: currently lists don't support port matching
-(BOOL)isMatch:(NEFilterSocketFlow*)flow
{
    //match
    BOOL isMatch = NO;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //endpoint url/hosts
    NSMutableSet* endpointNames = nil;
    
    //matches
    NSSet* matches = nil;
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //need to reload list?
    // checks timestamp to see if modified
    if(YES == [self shouldReload])
    {
        //(re)load list
        [self load:self.path];
    }
    
    //sync
    @synchronized (self) {
        
    //init endpoint names
    endpointNames = [NSMutableSet set];
        
    //add url
    if(nil != flow.URL.absoluteString)
    {
        //add full url
        [endpointNames addObject:flow.URL.absoluteString.lowercaseString];
    }
    
    //add host
    if(nil != flow.URL.host)
    {
        //add full url
        [endpointNames addObject:flow.URL.host.lowercaseString];
    }
        
    //add host name
    if(nil != remoteEndpoint.hostname)
    {
        //add
        [endpointNames addObject:remoteEndpoint.hostname.lowercaseString];
    }
    
    //macOS 11+?
    // add remote host name
    if(@available(macOS 11, *))
    {
        //add remote host name
        if(nil != flow.remoteHostname)
        {
            //add
            [endpointNames addObject:flow.remoteHostname.lowercaseString];
         
            //if it starts w/ 'www.'
            // strip and add that too
            if(YES == [flow.remoteHostname hasPrefix:@"www."])
            {
                //add
                [endpointNames addObject:[[flow.remoteHostname substringFromIndex:4] lowercaseString]];
            }
        }
    }
    
    //first check for "all"
    // for IPV4 -> '0.0.0.0/0'
    if( (AF_INET == flow.socketFamily) &&
        ([self.items containsObject:@"0.0.0.0/0"]) )
    {
        isMatch = YES;
        goto bail;
    }
    //for IPV6 -> '::/0'
    else if( (AF_INET6 == flow.socketFamily) &&
             ([self.items containsObject:@"::/0"]) )
    {
        isMatch = YES;
        goto bail;
    }
   
    //find matches
    matches = [self.items objectsPassingTest:^BOOL(NSString* item, BOOL* stop) {
        return [endpointNames containsObject:item];
    }];
        
    //any matches?
    if(0 != matches.count)
    {
        //dbg msg
        os_log_debug(logHandle, "endpoint names %{public}@ matched the following list items %{public}@", endpointNames, matches);
       
        //set flag
        isMatch = YES;
    }
        
    }//sync
    
bail:
    
    return isMatch;
}

@end
