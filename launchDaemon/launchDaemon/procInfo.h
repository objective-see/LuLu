//
//  File: procInfo.h
//  Project: Proc Info
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//  License:    Creative Commons Attribution-NonCommercial 4.0 International License
//

#ifndef procInfo_h
#define procInfo_h

#import <libproc.h>
#import <sys/sysctl.h>
#import <Foundation/Foundation.h>

/* CLASSES */

@class Binary;
@class Process;


/* DEFINES */

//from audit_kevents.h
#define EVENT_EXIT		1
#define	EVENT_FORK      2   
#define EVENT_EXECVE    23
#define EVENT_EXEC      27
#define EVENT_SPAWN     43190

/* TYPEDEFS */

//block for library
typedef void (^ProcessCallbackBlock)(Process*);


/* OBJECT: PROCESS INFO */

@interface ProcInfo : NSObject

//start monitoring
-(BOOL)start:(ProcessCallbackBlock)callback;

//stop monitoring
-(void)stop;

//get list of running processes
-(NSMutableArray*)currentProcesses;

@end

/* OBJECT: PROCESS */

@interface Process : NSObject

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//user id
@property uid_t user;

//type
// used by process mon
@property u_int16_t type;

//exit code
@property u_int32_t exit;

//path
@property (nonatomic, retain) NSString* path;

//args
@property (nonatomic, retain) NSMutableArray* arguments;

//ancestors
@property (nonatomic, retain) NSMutableArray* ancestors;

//Binary object
// ->has path, hash, etc
@property (nonatomic, retain) Binary* binary;

//timestamp
@property (nonatomic, retain) NSDate* timestamp;

/* METHODS */

//init with a pid
// ->method will then (try) fill out rest of object
-(id)init:(pid_t)processID;

//set process's path
-(void)pathFromPid;

//generate list of ancestors
-(void)enumerateAncestors;

//class method to get parent of arbitrary process
+(pid_t)getParentID:(pid_t)child;

@end

/* OBJECT: BINARY */

@interface Binary : NSObject
{
    
}

/* PROPERTIES */

//path
@property (nonatomic, retain)NSString* path;

//name
@property (nonatomic, retain)NSString* name;

//file attributes
@property (nonatomic, retain)NSDictionary* attributes;

//signing info
@property (nonatomic, retain)NSDictionary* signingInfo;

//flag indicating binary belongs to Apple OS
@property BOOL isApple;

//flag indicating binary is from official App Store
@property BOOL isAppStore;

/* METHODS */

//init w/ an info dictionary
-(id)init:(NSString*)path;

@end

#endif
