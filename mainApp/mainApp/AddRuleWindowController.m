//
//  file: AddRuleWindowController.h
//  project: lulu (main app)
//  description: 'add rule' window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "utilities.h"
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
// invoke helper to set icon, and enable/select 'add' button
-(void)controlTextDidChange:(NSNotification *)notification
{
    //text field?
    // update the UI
    if([notification object] == self.processPath)
    {
        //update
        [self updateUI];
    }


bail:
    
    return;
}

//automatically called when 'enter' is hit
// invoke helper to set icon, and enable/select 'add' button
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //text field?
    // update the UI
    if([notification object] == self.processPath)
    {
        //update
        [self updateUI];
        
        //make 'add' selected
        [self.window makeFirstResponder:self.addButton];

    }
    
    return;
}

//'block'/'allow' button handler
// set state into iVar, so can accessed when sheet closes
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
    
    //can open app bundles
    panel.treatsFilePackagesAsDirectories = YES;
    
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
    
    //update UI
    [self updateUI];
    
    //make 'add' selected
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

//update the UI
// set icon, and enable/select 'add' button
-(void)updateUI
{
    //icon
    NSImage* processIcon = nil;
    
    //blank
    // disable 'add' button
    if(0 == self.processPath.stringValue.length)
    {
        //set state
        self.addButton.enabled = NO;
        
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
    
bail:
    
    return;
}

@end
