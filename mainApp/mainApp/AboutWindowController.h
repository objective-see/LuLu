//
//  file: AboutWindowController.h
//  project: lulu (main app)
//  description: 'about' window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AboutWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property (weak) IBOutlet NSTextField *versionLabel;

//patrons
@property (unsafe_unretained) IBOutlet NSTextView *patrons;

/* METHODS */

//automatically invoked when user clicks any of the buttons
// ->perform actions, such as loading patreon or products URL
-(IBAction)buttonHandler:(id)sender;

@end
