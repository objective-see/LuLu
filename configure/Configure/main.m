//
//  file: main.m
//  project: lulu (config app)
//  description: main interface, for config (install/uninstall)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Sentry;

#import "consts.h"
#import "logging.h"

int main(int argc, char *argv[])
{
    //error
    NSError* error = nil;
    
    //init crash reporting client
    SentryClient.sharedClient = [[SentryClient alloc] initWithDsn:CRASH_REPORTING_URL didFailWithError:&error];
    if(nil == error)
    {
        //start crash handler
        [SentryClient.sharedClient startCrashHandlerWithError:&error];
    }
    
    //any errors?
    // just log, but keep going...
    if(nil != error)
    {
        //log error
        logMsg(LOG_ERR, [NSString stringWithFormat:@"initializing 'Sentry' failed with %@", error]);
    }
    
    //kick main app logic
    return NSApplicationMain(argc,  (const char **) argv);
}
