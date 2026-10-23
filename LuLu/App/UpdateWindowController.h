//
//  file: UpdateWindowController.m
//  project: lulu
//  description: window handler for update window/popup (header)
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

@import Cocoa;

@interface UpdateWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property(weak)IBOutlet NSTextField *infoLabel;

//action button
@property(weak)IBOutlet NSButton *actionButton;

//label string
@property(nonatomic, retain)NSString* infoLabelString;

//url (to open when user clicks button)
@property(nonatomic, retain)NSString* url;


/* METHODS */

//save the main label (and url)
-(void)configure:(NSString*)label url:(NSString*)url;

//invoked when user clicks button
// ->trigger action such as opening product website, updating, etc
-(IBAction)buttonHandler:(id)sender;

@end
