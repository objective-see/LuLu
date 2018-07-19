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

//signers
enum Signer{None, Apple, AppStore, DevID, AdHoc};

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signer
#define KEY_SIGNATURE_SIGNER @"signatureSigner"

//signing auths
#define KEY_SIGNATURE_AUTHORITIES @"signatureAuthorities"

//code signing id
#define KEY_SIGNATURE_IDENTIFIER @"signatureIdentifier"

//entitlements
#define KEY_SIGNATURE_ENTITLEMENTS @"signatureEntitlements"

/* TYPEDEFS */

//block for library
typedef void (^ProcessCallbackBlock)(Process* _Nonnull);

/* OBJECT: PROCESS INFO */

@interface ProcInfo : NSObject

//init w/ flag
// flag dictates if CPU-intensive logic (code signing, etc) should be preformed
-(id _Nullable)init:(BOOL)goEasy;

//start monitoring
-(void)start:(ProcessCallbackBlock _Nonnull )callback;

//stop monitoring
-(void)stop;

//get list of running processes
-(NSMutableArray* _Nonnull)currentProcesses;

@end

/* OBJECT: PROCESS */

@interface Process : NSObject

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//user id
@property uid_t uid;

//type
// used by process mon
@property u_int16_t type;

//exit code
@property u_int32_t exit;

//path
@property(nonatomic, retain)NSString* _Nullable path;

//args
@property(nonatomic, retain)NSMutableArray* _Nonnull arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* _Nonnull ancestors;

//signing info
@property(nonatomic, retain)NSMutableDictionary* _Nonnull signingInfo;

//Binary object
// has path, hash, etc
@property(nonatomic, retain)Binary* _Nonnull binary;

//timestamp
@property(nonatomic, retain)NSDate* _Nonnull timestamp;

/* METHODS */

//init with a pid
// method will then (try) fill out rest of object
-(id _Nullable)init:(pid_t)processID;

//generate signing info
// also classifies if Apple/from App Store/etc.
-(void)generateSigningInfo:(SecCSFlags)flags;

//set process's path
-(void)pathFromPid;

//generate list of ancestors
-(void)enumerateAncestors;

//class method
// get's parent of arbitrary process
+(pid_t)getParentID:(pid_t)child;

@end

/* OBJECT: BINARY */

@interface Binary : NSObject
{
    
}

/* PROPERTIES */

//path
@property(nonatomic, retain)NSString* _Nonnull path;

//name
@property(nonatomic, retain)NSString* _Nonnull name;

//icon
@property(nonatomic, retain)NSImage* _Nonnull icon;

//file attributes
@property(nonatomic, retain)NSDictionary* _Nullable attributes;

//spotlight meta data
@property(nonatomic, retain)NSDictionary* _Nullable metadata;

//bundle
// nil for non-apps
@property(nonatomic, retain)NSBundle* _Nullable bundle;

//signing info
@property(nonatomic, retain)NSDictionary* _Nonnull signingInfo;

//hash
@property(nonatomic, retain)NSMutableString* _Nonnull sha256;

//identifier
// either signing id or sha256 hash
@property(nonatomic, retain)NSString* _Nonnull identifier;

/* METHODS */

//init w/ a path
-(id _Nonnull)init:(NSString* _Nonnull)path;

/* the following methods are rather CPU-intensive
   as such, if the proc monitoring is run with the 'goEasy' option, they aren't automatically invoked
*/
 
//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
-(void)getIcon;

//generate signing info (statically)
-(void)generateSigningInfo:(SecCSFlags)flags;

/* the following methods are not invoked automatically
   as such, if you code has to manually invoke them if you want this info
 */

//generate hash
// algo: sha256
-(void)generateHash;

//generate id
// either signing id, or sha256 hash
-(void)generateIdentifier;

@end

#endif
