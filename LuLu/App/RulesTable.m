//
//  file: RuleTable.m
//  project: lulu
//  description: subclass for rules table
//
//  created by Patrick Wardle
//  copyright (c) 2020 Objective-See. All rights reserved.
//

#import "Rule.h"
#import "consts.h"
#import "utilities.h"
#import "RulesTable.h"
#import "RulesWindowController.h"

@implementation RulesTable

//override
// create context/right click menu
-(NSMenu*)menuForEvent:(NSEvent *)event
{
    //item
    id item = nil;
 
    //selected row
    NSInteger selectedRow = -1;
    
    //menu
    NSMenu* menu = nil;
     
    //covert mouse click to selected row
    selectedRow = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    if(-1 == selectedRow)
    {
        //bail
        goto bail;
    }
    
    //make it selected
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
    
    //get item
    item = [((RulesWindowController*)self.delegate).outlineView itemAtRow:selectedRow];
    if(nil == item)
    {
        //bail
        goto bail;
    }
    
    //alloc menu
    menu = [[NSMenu alloc] init];
    
    //set delegate
    // 'RulesWindowController'
    menu.delegate = (id<NSMenuDelegate>)self.delegate;
    
    //don't auto enable
    menu.autoenablesItems = NO;
    
    //item row?
    // show paths
    if(YES == [item isKindOfClass:[NSArray class]])
    {
        //add item
        [menu insertItemWithTitle:NSLocalizedString(@"→ Show path(s)", @"→ Show path(s)") action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:0];
        
        //set tag
        menu.itemArray.firstObject.tag = MENU_SHOW_PATHS;
        
        //enable
        menu.itemArray.lastObject.enabled = YES;
        
        //add delete
        [menu insertItemWithTitle:NSLocalizedString(@"→ Delete rule(s)", @"→ Delete rule(s)") action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:1];
        
        //set tag
        menu.itemArray.lastObject.tag = MENU_DELETE_RULE;
        
        //enable
        menu.itemArray.lastObject.enabled = YES;
    }
    
    //rule row
    else if(YES == [item isKindOfClass:[Rule class]])
    {
        //set title
        [menu insertItemWithTitle:NSLocalizedString(@"→ Edit Rule", @"→ Edit Rule") action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:0];
        
        //set tag
        menu.itemArray.firstObject.tag = MENU_EDIT_RULE;
        
        //add delete
        [menu insertItemWithTitle:NSLocalizedString(@"→ Delete Rule", @"→ Delete Rule") action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:1];
        
        //set tag
        menu.itemArray.lastObject.tag = MENU_DELETE_RULE;
        
        //enable
        toggleMenu(menu, YES);
    }
    
bail:
    
    return menu;
}

@end
