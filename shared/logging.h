//
//  file: logging.h
//  project: lulu (shared)
//  description: logging functions (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Logging_h
#define Logging_h

#import <syslog.h>

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

//log a msg to syslog
// ->also disk, if error
void logMsg(int level, NSString* msg);

//prep/open log file
BOOL initLogging();

//get path to log file
NSString* logFilePath();

//de-init logging
void deinitLogging();

//log to file
void log2File(NSString* msg);

#endif
