//
//  file: VirusTotal.h
//  project: lulu (login item)
//  description: interface to VirusTotal (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

//query url
#define VT_QUERY_URL @"https://www.virustotal.com/partners/sysinternals/file-reports?apikey="

//(public) api key
#define VT_API_KEY @"233f22e200ca5822bd91103043ccac138b910db79f29af5616a9afe8b6f215ad"

//user agent
#define VT_USER_AGENT @"VirusTotal"

//results
#define VT_RESULTS @"data"

//results response code
#define VT_RESULTS_RESPONSE @"response_code"

//result url
#define VT_RESULTS_URL @"permalink"

//result hash
#define VT_RESULT_HASH @"hash"

//results positives
#define VT_RESULTS_POSITIVES @"positives"

//results total
#define VT_RESULTS_TOTAL @"total"

@interface VirusTotal : NSObject
{
    
}

/* METHODS */

//thread function
// runs in the background to get virus total info about items
-(BOOL)queryVT:(NSMutableDictionary*)item;

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url postData:(NSData*)postData;

@end
