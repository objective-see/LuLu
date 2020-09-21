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
//#import "AboutWindowController.h"
#import "ConfigureWindowController.h"

//block for install/uninstall
typedef void (^block)(NSNumber*);

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    
}

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

//status msg
@property (nonatomic, weak) IBOutlet NSTextField *statusMsg;

//configure window controller
@property(nonatomic, retain)ConfigureWindowController* configureWindowController;

@end
