//
//  file: AboutWindowController.h
//  project: lulu (config)
//  description: about window display/controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

@interface AboutWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property (weak, atomic) IBOutlet NSTextField *versionLabel;

//patrons
@property (unsafe_unretained, atomic) IBOutlet NSTextView *patrons;

//'support us' button
@property (weak, atomic) IBOutlet NSButton *supportUs;


@end
