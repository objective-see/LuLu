//
//  file: AddRuleWindowController.h
//  project: lulu (main app)
//  description: 'add rule' window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "const.h"
#import "logging.h"
#import "Utilities.h"
#import "AddRuleWindowController.h"

@implementation AddRuleWindowController

@synthesize action;
@synthesize addButton;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //set icon
    self.icon.image = [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
    
    //resize
    [self.icon.image setSize:NSMakeSize(128, 128)];
    
    //set delegate for process path text field
    self.processPath.delegate = self;
    
    //init to block
    self.action = RULE_STATE_BLOCK;
    
    //'add' button should be disabled
    // ...until user enters an app/binary
    self.addButton.enabled = NO;
    
    return;
}

//automatically called when editing start
// update UI by resetting icon and disabling 'add' button
-(void)controlTextDidBeginEditing:(NSNotification *)obj
{
    //reset icon
    self.icon.image = [[NSWorkspace sharedWorkspace]
                       iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
    
    //resize
    [self.icon.image setSize:NSMakeSize(128, 128)];
    
    //disable 'add' button
    self.addButton.enabled = NO;
    
    return;
}

//automatically called when text changes
// ensure 'add' button state is correct
//  enabled when there is text
//  disabled when there is no test
-(void)controlTextDidChange:(NSNotification *)notification
{
    //not text field?
    if([notification object] != self.processPath)
    {
        //bail
        goto bail;
    }
    
    //set state
    self.addButton.enabled = (BOOL)self.processPath.stringValue.length;
    
bail:
    
    return;
}

//automatically called when 'enter' is hit
// set icon, and enable/select 'add' button
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //icon
    NSImage* processIcon = nil;
    
    //not text field?
    if([notification object] != self.processPath)
    {
        //bail
        goto bail;
    }
    
    //get icon
    processIcon = getIconForProcess(self.processPath.stringValue);
    if(nil != processIcon)
    {
        //add
        self.icon.image = processIcon;
    }
    
    //enable 'add' button
    self.addButton.enabled = YES;
    
    //make 'add' selected
    [self.window makeFirstResponder:self.addButton];
    
bail:
    
    return;
}

//'block'/'allow' button handler
// ->set state into iVar, so can accessed when sheet closes
-(IBAction)radioButtonsHandler:(id)sender
{
    //block button clicked
    if(BUTTON_BLOCK == ((NSButton*)sender).tag)
    {
        //set
        self.action = RULE_STATE_BLOCK;
    }
    
    //allow button clicked
    else
    {
        //set
        self.action = RULE_STATE_ALLOW;
    }
    
    return;
}

//'browse' button handler
//  open a panel for user to select file
-(IBAction)browseButtonHandler:(id)sender
{
    //'browse' panel
    NSOpenPanel *panel = nil;
    
    //response to 'browse' panel
    NSInteger response = 0;
    
    //init panel
    panel = [NSOpenPanel openPanel];
    
    //allow files
    panel.canChooseFiles = YES;
    
    //allow directories (app bundles)
    panel.canChooseDirectories = YES;
    
    //start in /Apps
    panel.directoryURL = [NSURL fileURLWithPath:@"/Applications"];
    
    //disable multiple selections
    panel.allowsMultipleSelection = NO;
    
    //show it
    response = [panel runModal];
    
    //ignore cancel
    if(NSFileHandlingPanelCancelButton == response)
    {
        //bail
        goto bail;
    }
    
    //set text
    self.processPath.stringValue = panel.URL.path;
    
    //make 'add' selected
    // will also trigger 'end editing' for text field
    [self.window makeFirstResponder:self.addButton];
    
bail:
    
    return;
}

//'cancel' button handler
// close sheet, returning NSModalResponseCancel
-(IBAction)cancelButtonHandler:(id)sender
{
    //close & return NSModalResponseCancel
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    
    return;
}

//'add' button handler
// close sheet, returning NSModalResponseOK
-(IBAction)addButtonHandler:(id)sender
{
    //close & return NSModalResponseCancel
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    return;
}

@end
