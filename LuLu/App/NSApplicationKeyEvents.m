//
//  file: NSApplicationKeyEvents.h
//  project: LuLu
//  description: adds support for keyboard shortcuts (header)
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

#import "NSApplicationKeyEvents.h"

@implementation NSApplicationKeyEvents

//to enable copy/paste etc even though we don't have an 'Edit' menu
// details: http://stackoverflow.com/questions/970707/cocoa-keyboard-shortcuts-in-dialog-without-an-edit-menu
-(void) sendEvent:(NSEvent *)event
{
    //only care about key down + command
    if( (NSEventTypeKeyDown != event.type) ||
        (NSEventModifierFlagCommand != (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask)) )
    {
        //bail
        goto bail;
    }
    
    //+c (copy)
    if(YES == [[event charactersIgnoringModifiers] isEqualToString:@"c"])
    {
        //copy
        if([self sendAction:@selector(copy:) to:nil from:self])
        {
            return;
        }
    }
            
    //+v (paste)
    else if ([[event charactersIgnoringModifiers] isEqualToString:@"v"])
    {
        //paste
        if([self sendAction:@selector(paste:) to:nil from:self])
        {
            return;
        }
    }
            
    //+x (cut)
    else if ([[event charactersIgnoringModifiers] isEqualToString:@"x"])
    {
        //cut
        if([self sendAction:@selector(cut:) to:nil from:self])
        {
            return;
        }
    }
            
    //+a (select all)
    else if([[event charactersIgnoringModifiers] isEqualToString:@"a"])
    {
        if ([self sendAction:@selector(selectAll:) to:nil from:self])
        {
            return;
        }
    }
    
    //+h (hide window)
    else if([[event charactersIgnoringModifiers] isEqualToString:@"h"])
    {
        if ([self sendAction:@selector(hide:) to:nil from:self])
        {
            return;
        }
    }
    
    //+w (close window)
    else if([[event charactersIgnoringModifiers] isEqualToString:@"w"])
    {
        //close
        [[[NSApplication sharedApplication] keyWindow] close];
        
        return;
    }

bail:

    //super
    [super sendEvent:event];
    
    return;
}

@end
