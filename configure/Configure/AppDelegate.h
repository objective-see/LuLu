//
//  file: AppDelegate.h
//  project: lulu (config)
//  description: application main/delegate (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Configure.h"
#import "HelperComms.h"
#import "AboutWindowController.h"
#import "ConfigureWindowController.h"

//block for install/uninstall
typedef void (^block)(NSNumber*);

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    
}

//config object
@property(nonatomic, retain) Configure* configureObj;

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

//status msg
@property (nonatomic, weak) IBOutlet NSTextField *statusMsg;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//configure window controller
@property(nonatomic, retain)ConfigureWindowController* configureWindowController;


/* METHODS */

//display configuration window w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(BOOL)isInstalled;

@end
