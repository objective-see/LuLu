//
//  file: NSApplicationKeyEvents.h
//  project: LuLu
//  description: adds support for keyboard shortcuts (header)
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "AppDelegate.h"
#import "NSApplicationKeyEvents.h"

@implementation NSApplicationKeyEvents

//to enable copy/paste etc even though we don't have an 'Edit' menu
// details: http://stackoverflow.com/questions/970707/cocoa-keyboard-shortcuts-in-dialog-without-an-edit-menu
-(void)sendEvent:(NSEvent*)event
{
    //only care about key down
    if(NSEventTypeKeyDown != event.type)
    {
        //bail
        goto bail;
    }
        
    //delete?
    // in Rules window/table, delete row
    if( (NSDeleteCharacter == [event.charactersIgnoringModifiers characterAtIndex:0]) &&
        (YES == [event.window.identifier isEqualToString:@"Rules"]) &&
        (YES == [event.window.firstResponder.className isEqualToString:@"RulesTable"]) )
    {
        //delete rule
        [[((AppDelegate*)[[NSApplication sharedApplication] delegate]) rulesWindowController] deleteRule:nil];
        return;
    }
    
    //otherwise
    // ...only care about key down + command
    if(NSEventModifierFlagCommand != (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask))
    {
        //bail
        goto bail;
    }
    
    //+c (copy)
    if(YES == [event.charactersIgnoringModifiers isEqualToString:@"c"])
    {
        //copy
        if(YES == [self sendAction:@selector(copy:) to:nil from:self])
        {
            return;
        }
    }
            
    //+v (paste)
    else if ([event.charactersIgnoringModifiers isEqualToString:@"v"])
    {
        //paste
        if(YES == [self sendAction:@selector(paste:) to:nil from:self])
        {
            return;
        }
    }
            
    //+x (cut)
    else if ([event.charactersIgnoringModifiers isEqualToString:@"x"])
    {
        //cut
        if(YES == [self sendAction:@selector(cut:) to:nil from:self])
        {
            return;
        }
    }
            
    //+a (select all)
    else if([event.charactersIgnoringModifiers isEqualToString:@"a"])
    {
        //select
        if(YES == [self sendAction:@selector(selectAll:) to:nil from:self])
        {
            return;
        }
    }
    
    //+h (hide window)
    else if([event.charactersIgnoringModifiers isEqualToString:@"h"])
    {
        //hide
        if(YES == [self sendAction:@selector(hide:) to:nil from:self])
        {
            return;
        }
    }
    
    //+m (minimize window)
    else if([event.charactersIgnoringModifiers isEqualToString:@"m"])
    {
        //minimize
        [NSApplication.sharedApplication.keyWindow miniaturize:nil];
        return;
    }
    
    //+w (close window)
    // unless its an alert ...need response!
    else if( ([event.charactersIgnoringModifiers isEqualToString:@"w"]) &&
             (YES != [event.window.identifier isEqualToString:@"Alert"]) )
    {
        //close
        [NSApplication.sharedApplication.keyWindow close];
        return;
    }

    //+f (find, but only in rules window)
    else if( ([event.charactersIgnoringModifiers isEqualToString:@"f"]) &&
             (YES == [event.window.identifier isEqualToString:@"Rules"]) )
    {
        //iterate over all toolbar items
        // ...find rule search field, and select
        for(NSToolbarItem* item in NSApplication.sharedApplication.keyWindow.toolbar.items)
        {
            //not search field? skip
            if(RULE_SEARCH_FIELD != item.tag) continue;
            
            //and make it first responder
            [NSApplication.sharedApplication.keyWindow makeFirstResponder:item.view];
            
            //done
            return;
        }
    }
    
    //+, (show preferences)
    else if([event.charactersIgnoringModifiers isEqualToString:@","])
    {
        //show
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showPreferences:nil];
        return;
    }
    
bail:

    //super
    [super sendEvent:event];
    
    return;
}

@end
