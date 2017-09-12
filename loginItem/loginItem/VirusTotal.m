//
//  file: VirusTotal.m
//  project: lulu (login item)
//  description: interface to VirusTotal
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "VirusTotal.h"
#import "AppDelegate.h"

@implementation VirusTotal

//thread function
// ->runs in the background to get virus total info about items
-(BOOL)queryVT:(NSMutableDictionary*)item
{
    //flag
    BOOL gotResponse = NO;
    
    //file attributes
    NSDictionary* attributes = nil;
    
    //item data
    NSMutableDictionary* itemData = nil;
    
    //VT query URL
    NSURL* queryURL = nil;
    
    //vt response
    NSDictionary* response = nil;
    
    //post data
    // ->JSON'd items
    NSData* postData = nil;
    
    //error var
    NSError* error = nil;
    
    //init
    itemData = [NSMutableDictionary dictionary];

    //init query URL
    queryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", VT_QUERY_URL, VT_API_KEY]];
   
    //get file attributes
    attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:item[@"path"] error:nil];
    
    //set item path
    itemData[@"image_path"] = item[@"path"];
    
    //set hash
    itemData[@"hash"] = item[@"hash"];
    
    //set creation time
    if(nil != attributes)
    {
        //set
        itemData[@"creation_datetime"] = attributes.fileCreationDate.description;
    }
    //set unknown
    else
    {
        //set
        itemData[@"creation_datetime"] = @"unknown";
    }
    
    //convert items to JSON'd data for POST request
    // ->wrap since we are serializing JSON
    @try
    {
        //convert items
        postData = [NSJSONSerialization dataWithJSONObject:@[itemData] options:kNilOptions error:&error];
        if(nil == postData)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to convert paramters %@, to JSON (%@)", itemData, error]);
            
            //bail
            goto bail;
        }
        
    }
    //bail on exceptions
    @catch(NSException *exception)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to convert paramters %@, to JSON (%@)", itemData, exception]);
        
        //bail
        goto bail;
    }

    //make query to VT
    response = [self postRequest:queryURL postData:postData];
    if(nil == response)
    {
        //bail
        goto bail;
    }
    
    //got response
    gotResponse = YES;
    
    //process all results
    // ->save VT result dictionary into item
    for(NSDictionary* result in response[VT_RESULTS])
    {
        //for matches, save vt info
        if(YES == [result[@"hash"] isEqualToString:item[@"hash"]])
        {
            //save
            item[@"vtInfo"] = result;
            
            //next
            break;
        }
    }
    
bail:
    
    return gotResponse;
}

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url postData:(NSData*)postData
{
    //results
    __block NSDictionary* results = nil;
    
    //request
    NSMutableURLRequest *request = nil;
   
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init wait semaphore
    semaphore = dispatch_semaphore_create(0);
    
    //alloc/init request
    request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    //set user agent
    [request setValue:VT_USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    //set content type
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    //set content length
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-length"];
    
    //add POST data
    [request setHTTPBody:postData];
    
    //set method type
    [request setHTTPMethod:@"POST"];

    //send request
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error)
    {
        //sanity check(s)
        if( (nil != data) &&
            (nil == error) &&
            (200 == (long)((NSHTTPURLResponse *)response).statusCode) )
        {
            //serialize response into NSData obj
            // ->wrap since we are serializing JSON
            @try
            {
                //serialized
                results = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            }
            //bail on any exceptions
            @catch (NSException *exception)
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"converting response %@ to JSON threw %@", data, exception]);
            }
        }
        //error making request
        // log error message with details
        else
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to query VirusTotal (%@, %@)", error, response]);
        }
        
        //trigger
        dispatch_semaphore_signal(semaphore);
        
    }] resume];
    
    //wait for request to complete
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
bail:
    
    return results;
}

@end
