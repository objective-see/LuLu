//
//  file: logging.m
//  project: lulu (shared)
//  description: logging functions
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "logging.h"

//global log file handle
NSFileHandle* logFileHandle = nil;

//log a msg
// ->default to syslog, and if an err msg, to disk
void logMsg(int level, NSString* msg)
{
    //flag for logging
    BOOL shouldLog = NO;
    
    //log prefix
    NSMutableString* logPrefix = nil;
    
    //first grab logging flag
    shouldLog = (LOG_TO_FILE == (level & LOG_TO_FILE));
    
    //then remove it
    // ->make sure syslog is happy
    level &= ~LOG_TO_FILE;
    
    //alloc/init
    // ->always start w/ 'LULU' + pid
    logPrefix = [NSMutableString stringWithFormat:@"LULU(%d)", getpid()];
    
    //if its error, add error to prefix
    if(LOG_ERR == level)
    {
        //add
        [logPrefix appendString:@" ERROR"];
    }
    
    //debug mode logic
    #ifdef DEBUG
    
    //in debug mode promote debug msgs to LOG_NOTICE
    // OSX/macOS only shows LOG_NOTICE and above
    if(LOG_DEBUG == level)
    {
        //promote
        level = LOG_NOTICE;
    }
    
    #endif
    
    //log to syslog if a level was specified
    // as code doesn't use LOG_EMERG (0), this check is ok
    if(0 != level)
    {
        //log to syslog
        syslog(level, "%s: %s", [logPrefix UTF8String], [msg UTF8String]);
    }
    
    //when a message is to be logged to file
    // ->log it, when logging is enabled
    if(YES == shouldLog)
    {
        //but only when logging is enable
        if(nil != logFileHandle)
        {
            //log
            log2File(msg);
        }
    }
    
    return;
}

//log to file
void log2File(NSString* msg)
{
    //append timestamp
    // write msg out to disk
    [logFileHandle writeData:[[NSString stringWithFormat:@"%@: %@\n", [NSDate date], msg] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return;
}

//de-init logging
void deinitLogging()
{
    //dbg msg
    // ->and to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging ending");
    
    //close file handle
    [logFileHandle closeFile];
    
    //nil out
    logFileHandle = nil;
    
    return;
}

//prep/open log file
BOOL initLogging()
{
    //ret var
    BOOL bRet = NO;
    
    //log file path
    NSString* logPath = nil;
    
    //init log path
    // '/Library/Logs/Lulu.log'
    logPath = [@"/Library/Logs/" stringByAppendingPathComponent:LOG_FILE_NAME];
    
    //first time
    //  create file
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:logPath])
    {
        //create
        if(YES != [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create log file, %@", logPath]);
            
            //bail
            goto bail;
        }
    }
    
    //get file handle
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if(nil == logFileHandle)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to get log file handle to %@", logPath]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"opened log file; %@", logPath]);
    #endif
    
    //seek to end
    [logFileHandle seekToEndOfFile];
    
    //dbg msg
    // ->and to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging intialized");
    
    //happy
    bRet = YES;
    
bail:
    
    return bRet;
}
