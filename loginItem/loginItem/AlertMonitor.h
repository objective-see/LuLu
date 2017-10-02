//
//  file: AlertMonitor.h
//  project: lulu (login item)
//  description: monitor for alerts from daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "AlertWindowController.h"
#import <Foundation/Foundation.h>

@interface AlertMonitor : NSObject

/* PROPERTIES */

//window controller
@property(strong)AlertWindowController* alertWindow;

//wait semaphore
@property dispatch_semaphore_t semaphore;


/* METHODS */

//forever,
// ->wait for & display alerts
-(void)monitor;

//when client is in passive mode: allow
-(void)passivelyAllow:(DaemonComms*)daemonComms alert:(NSDictionary*)alert;

//callback handler
// ->invoked when window closes
-(void)alertWindowClosed:(id)object;

@end
