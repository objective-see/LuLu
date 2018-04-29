//
//  file: RuleTable.m
//  project: lulu (main app)
//  description: subclass for rules table
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
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
    //rule
    Rule* rule = nil;
    
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
    
    //find rule
    rule = [(RulesWindowController*)self.delegate ruleForRow:selectedRow];
    if(nil == rule)
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
    
    //allow?
    // show 'block' to toggle
    if(RULE_STATE_ALLOW == rule.action.integerValue)
    {
        [menu insertItemWithTitle:@"toggle (block)" action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:0];
        
        //set tag
        menu.itemArray.firstObject.tag = MENU_ITEM_BLOCK;
    }
    
    //block
    // show 'allow' to toggle
    else
    {
        //set title
        [menu insertItemWithTitle:@"toggle (allow)" action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:0];
        
        //set tag
        menu.itemArray.firstObject.tag = MENU_ITEM_ALLOW;
    }
    
    //add delete
    [menu insertItemWithTitle:@"delete rule" action:NSSelectorFromString(@"rowMenuHandler:") keyEquivalent:@"" atIndex:1];
    
    //set tag
    menu.itemArray.lastObject.tag = MENU_ITEM_DELETE;
    
    //disable menu for default (system) rules
    // these should not be edited via normal users!
    if(RULE_TYPE_DEFAULT == rule.type.intValue)
    {
        //disable menu
        toggleMenu(menu, NO);
        
        //bail
        goto bail;
    }

    //enable
    toggleMenu(menu, YES);
    
bail:
    
    return menu;
}

@end
