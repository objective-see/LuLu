//
//  file: NSApplicationKeyEvents.h
//  project: lulu (shared)
//  description: adds support for keyboard shortcuts (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "NSApplicationKeyEvents.h"

@implementation NSApplicationKeyEvents

//to enable copy/paste etc even though we don't have an 'Edit' menu
// details: http://stackoverflow.com/questions/970707/cocoa-keyboard-shortcuts-in-dialog-without-an-edit-menu
-(void) sendEvent:(NSEvent *)event
{
    //keydown?
    if([event type] == NSKeyDown)
    {
        //command?
        if(([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask)
        {
            //+c
            // copy
            if(YES == [[event charactersIgnoringModifiers] isEqualToString:@"c"])
            {
                //copy
                if([self sendAction:@selector(copy:) to:nil from:self])
                {
                    return;
                }
            }
            
            //+v
            // paste
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"v"])
            {
                //paste
                if([self sendAction:@selector(paste:) to:nil from:self])
                {
                    return;
                }
            }
            
            //+x
            // cut
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"x"])
            {
                //cut
                if([self sendAction:@selector(cut:) to:nil from:self])
                {
                    return;
                }
            }
            
            //+a
            // select all
            else if([[event charactersIgnoringModifiers] isEqualToString:@"a"])
            {
                if ([self sendAction:@selector(selectAll:) to:nil from:self])
                {
                    return;
                }
            }
        }
    }
    
    //super
    [super sendEvent:event];
}

@end
