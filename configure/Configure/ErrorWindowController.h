//
//  file: ErrorWindowController.h
//  project: lulu (config)
//  description: error window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ErrorWindowController : NSWindowController <NSWindowDelegate>
{
    
}

//main msg in window
@property (weak, atomic) IBOutlet NSTextField *errMsg;

//sub msg in window
@property (weak, atomic) IBOutlet NSTextField *errSubMsg;

//info/help/fix button
@property (weak, atomic) IBOutlet NSButton *infoButton;

//close button
@property (weak, atomic) IBOutlet NSButton *closeButton;

//(optional) url for 'Info' button
@property(nonatomic, retain) NSURL* errorURL;

//flag indicating close button should exit app
@property(atomic) BOOL shouldExit;

/* METHODS */

//configure the object/window
-(void)configure:(NSDictionary*)errorInfo;

//display (show) window
-(void)display;

@end
