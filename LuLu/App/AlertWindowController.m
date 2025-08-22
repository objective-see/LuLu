//
//  file: AlertWindowController.m
//  project: lulu
//  description: window controller for main firewall alert
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;
#import <sys/socket.h>

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "AlertWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc for daemon comms
extern XPCDaemonClient* xpcDaemonClient;

@implementation AlertWindowController

@synthesize alert;
@synthesize processIcon;
@synthesize processName;
@synthesize ancestryButton;
@synthesize ancestryPopover;
@synthesize processHierarchy;
@synthesize virusTotalButton;
@synthesize signingInfoButton;

#define DEFAULT_WINDOW_HEIGHT 244
#define DEFAULT_WINDOW_HEIGHT_EXPANDED 452

//center window
// also, transparency
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //full size content view for translucency
    self.window.styleMask = self.window.styleMask | NSWindowStyleMaskFullSizeContentView;
    
    //title bar translucency
    self.window.titlebarAppearsTransparent = YES;
    
    //move via background
    self.window.movableByWindowBackground = YES;
    
    //init formatter for rule expiration
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateFormat:@"HH:mm"];
    [timeFormatter setLocale:[NSLocale currentLocale]];
    [timeFormatter setTimeZone:[NSTimeZone systemTimeZone]];

    //add formatter to input
    self.ruleDurationCustomAmount.formatter = timeFormatter;
    
    return;
}

//delegate method
// populate/configure alert window
-(void)windowDidLoad
{
    //process pid
    pid_t processID = 0;
    
    //process args
    NSMutableString* arguments = nil;

    //timestamp formatter
    NSDateFormatter *timeFormat = nil;
    
    //paragraph style
    NSMutableParagraphStyle* paragraphStyle = nil;
    
    //title attributes (for temporary label)
    NSMutableDictionary* titleAttributes = nil;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //height
    NSUInteger height = 0;
    
    //url
    NSURL* url = nil;
    
    //selected duration
    NSInteger lastRuleDurationTag = 0;
    
    //init paragraph style
    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    
    //init dictionary for title attributes
    titleAttributes = [NSMutableDictionary dictionary];
    
    //extract process ID
    processID = [self.alert[KEY_PROCESS_ID] intValue];
    
    //get preferences
    preferences = [xpcDaemonClient getPreferences];
    
    //do we have access?
    // build hierarchy here
    if(0 == kill(processID, 0))
    {
        //extract
        self.processHierarchy = generateProcessHierarchy(processID);
        
        //dbg msg
        os_log_debug(logHandle, "(re)generated process hierarchy: %{public}@", self.processHierarchy);
    }
    else
    {
        //extract
        self.processHierarchy = alert[KEY_PROCESS_ANCESTORS];
    }
    
    //disable ancestory button if no ancestors
    if(0 == self.processHierarchy.count) 
    {
        //disable
        self.ancestryButton.enabled = NO;
    }
    
    //disable VirusTotal button if preference is set
    // this is enough, as all VT integration only occurs when user interacts with button
    if(YES == [preferences[PREF_NO_VT_MODE] boolValue])
    {
        //dbg msg
        os_log_debug(logHandle, "user has disabled VirusTotal integrations, so disabling VT button");
        
        //disable
        self.virusTotalButton.enabled = NO;
    }
    
    //default to using url
    // though we trim as we don't want the whole URL
    if(nil != self.alert[KEY_URL])
    {
        //init url
        url = [NSURL URLWithString:self.alert[KEY_URL]];
        
        //extract host
        self.endpoint = url.host;
    }
    //use IP address
    else
    {
        //set
        self.endpoint = self.alert[KEY_HOST];
    }
    
    //sanity check
    if(nil == self.endpoint)
    {
        //set
        self.endpoint = NSLocalizedString(@"unknown", @"unknown");
    }
    
    /* TOP */
    
    //set process icon
    self.processIcon.image = getIconForProcess(self.alert[KEY_PATH]);
    
    //process signing info
    [self setSigningIcon];
    
    //set name
    self.processName.stringValue = self.alert[KEY_PROCESS_NAME];
    
    //ensure process name clips
    self.processName.wantsLayer = YES;
    self.processName.layer.masksToBounds = YES;
    
    //alert message
    self.alertMessage.string = [NSString stringWithFormat:NSLocalizedString(@"is connecting to %@", @"is connecting to %@"), self.endpoint];
    
    //set tooltip to full URL
    if(nil != url)
    {
        //use (full) URLs
        self.alertMessage.toolTip = [NSString stringWithFormat:NSLocalizedString(@"Full URL: %@", @"Full URL: %@"), url.absoluteString];
    }
    
    /* BOTTOM (DETAILS) */
    
    //process pid
    self.processID.stringValue = [self.alert[KEY_PROCESS_ID] stringValue];

    //process args
    // none? means error
    if(0 == [self.alert[KEY_PROCESS_ARGS] count])
    {
        //unknown
        self.processArgs.stringValue = NSLocalizedString(@"unknown", @"unknown");
    }
    //process args
    // only one? means, argv[0] and none
    else if(1 == [self.alert[KEY_PROCESS_ARGS] count])
    {
        //none
        self.processArgs.stringValue = NSLocalizedString(@"none", @"none");
    }
    
    //process args
    // more than one? create string of all
    else
    {
        //alloc
        arguments = [NSMutableString string];
        
        //add each
        // but skip argv[0]
        for(NSUInteger i=0; i<[self.alert[KEY_PROCESS_ARGS] count]; i++)
        {
            //skip first
            if(0 == i) continue;
            
            //add arg
            [arguments appendFormat:@"%@ ", [self.alert[KEY_PROCESS_ARGS] objectAtIndex:i]];
        }
        
        //add to UI
        self.processArgs.stringValue = arguments;
    }
    
    //set tooltip
    self.processArgs.toolTip = [NSString stringWithFormat:NSLocalizedString(@"Process Arguments: %@", @"Process Arguments: %@"), self.processArgs.stringValue];
    
    //process path for normal processes
    if(YES != [self.alert[KEY_PROCESS_DELETED] boolValue])
    {
        //add as is
        self.processPath.string = self.alert[KEY_PATH];
    }
    //deleted processes
    // strike thru, so user knows
    else
    {
        //strike thru
        [self.processPath.textStorage setAttributedString: [[NSAttributedString alloc] initWithString:self.alert[KEY_PATH] attributes:@{NSStrikethroughStyleAttributeName:@(NSUnderlineStyleSingle)}]];
    }
    
    //set wrapping
    [self setWrapping:self.processPath];
    
    //set tooltip
    self.processPath.toolTip = [NSString stringWithFormat:NSLocalizedString(@"Process Path: %@", @"Process Path: %@"), self.processPath.string];
    
    //ensure process path clips
    self.processPath.wantsLayer = YES;
    self.processPath.layer.masksToBounds = YES;
        
    //ip address
    self.ipAddress.stringValue = (nil != self.alert[KEY_HOST]) ? self.alert[KEY_HOST] : NSLocalizedString(@"unknown", @"unknown");
    
    //port & proto
    self.portProto.stringValue = [NSString stringWithFormat:@"%@ (%@)", self.alert[KEY_ENDPOINT_PORT], [self convertProtocol:self.alert[KEY_PROTOCOL]]];

    //alloc time formatter
    timeFormat = [[NSDateFormatter alloc] init];
    
    //set format
    timeFormat.dateFormat = @"HH:mm:ss";
    
    //add timestamp
    self.timeStamp.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Time stamp: %@", @"Time stamp: %@"), [timeFormat stringFromDate:[[NSDate alloc] init]]];
    
    //set paragraph style to left
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    //set paragraph attribute for temporary label
    titleAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
    
    //set color to label default
    titleAttributes[NSForegroundColorAttributeName] = [NSColor labelColor];
    
    //set font
    titleAttributes[NSFontAttributeName] = [NSFont fontWithName:@"Menlo-Regular" size:12];
    
    //process deleted?
    // rule scope can only be temporary (as we don't have a path)
    if(YES == [self.alert[KEY_PROCESS_DELETED] boolValue])
    {
        //on
        self.ruleDurationProcess.state = NSControlStateValueOn;
        
        //disable others
        self.ruleDurationAlways.enabled = NO;
        self.ruleDurationCustom.enabled = NO;
    }
    //otherwise make sure others are (always) enabled
    else
    {
        //enable
        self.ruleDurationAlways.enabled = YES;
        self.ruleDurationCustom.enabled = YES;
    }

    //set rule scope
    // ...based on last one
    [self.actionScope selectItemAtIndex:[preferences[PREF_ALERT_LAST_RULE_SCOPE] integerValue]];
    
    //grab last rule duration tag
    lastRuleDurationTag = [preferences[PREF_ALERT_LAST_RULE_DURATION] integerValue];
    
    //not set
    // default to always
    if(0 == lastRuleDurationTag)
    {
        self.ruleDurationAlways.state = NSControlStateValueOn;
    }
    
    //set rule duration
    // ...based on last one
    else if(lastRuleDurationTag == self.ruleDurationAlways.tag)
    {
        //set: on
        self.ruleDurationAlways.state = NSControlStateValueOn;
    }
    else if(lastRuleDurationTag == self.ruleDurationProcess.tag)
    {
        //set: on
        self.ruleDurationProcess.state = NSControlStateValueOn;
    }
    else if(lastRuleDurationTag == self.ruleDurationCustom.tag)
    {
        //set: on
        self.ruleDurationCustom.state = NSControlStateValueOn;
    }
    
    //show touch bar
    [self initTouchBar];

    //default height
    height = DEFAULT_WINDOW_HEIGHT;
    
    //resize to handle size of alert
    [self.window setFrame:NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, self.window.frame.size.width, height) display:YES];
    
    //make 'allow' button first responder
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        [self.window makeFirstResponder:self.allowButton];
        
    });
    
    //show details?
    // if user expanded them on the last alert
    if(NSControlStateValueOn == [preferences[PREF_ALERT_SHOW_OPTIONS] integerValue])
    {
        //set 'options' button state to on
        self.showOptions.state = NSControlStateValueOn;
        
        //toggle, to show options
        [self toggleOptionsView:self.showOptions];
    }
    //otherwise
    // (re)set back to defaults
    else
    {
        //default min
        [self.window setContentMinSize:NSMakeSize(self.window.frame.size.width, DEFAULT_WINDOW_HEIGHT)];
        
        //default max
        [self.window setContentMaxSize:NSMakeSize(self.window.frame.size.width, DEFAULT_WINDOW_HEIGHT)];
        
        //(re)set action scope
        [self.actionScope selectItemAtIndex:ACTION_SCOPE_PROCESS];
        
        //(re)set rule scope
        self.ruleDurationAlways.state = NSControlStateValueOn;
    }
    
bail:
    
    return;
}

//covert number protocol to name
-(NSString*)convertProtocol:(NSNumber*)protocol
{
    //protocol
    NSString* name = nil;
    
    //convert
    switch(protocol.intValue)
    {
        //tcp
        case IPPROTO_TCP:
            name = @"TCP";
            break;
            
        //udp
        case IPPROTO_UDP:
            name = @"UDP";
            break;
            
        //??
        default:
            name = [NSString stringWithFormat:NSLocalizedString(@"<unknown (%d)>", @"<unknown (%d)>"), [self.alert[KEY_PROTOCOL] intValue]];
    }
    
    return name;
}

//set signing icon
-(void)setSigningIcon
{
    //signing info
    NSDictionary* signingInfo = nil;
    
    //extract
    signingInfo = self.alert[KEY_CS_INFO];
    
    //dbg msg
    os_log_debug(logHandle, "signing info: %{public}@", signingInfo);
    
    //none?
    // just set to unknown
    if(nil == signingInfo)
    {
        //set icon
        signingInfoButton.image = [NSImage imageNamed:@"SignedUnknown"];
        
        //bail
        goto bail;
    }
    
    //parse signing info
    switch([signingInfo[KEY_CS_STATUS] intValue])
    {
        //happily signed
        case noErr:
            
            //item signed by apple
            if(Apple == [signingInfo[KEY_CS_SIGNER] intValue])
            {
                //set icon
                signingInfoButton.image = [NSImage imageNamed:@"SignedApple"];
            }
            //signed by dev id/ad hoc, etc
            else
            {
                //set icon
                signingInfoButton.image = [NSImage imageNamed:@"Signed"];
            }
            
            break;
            
        //unsigned
        case errSecCSUnsigned:
            
            //set icon
            signingInfoButton.image = [NSImage imageNamed:@"Unsigned"];
            
            break;
            
        default:
            
            //set icon
            signingInfoButton.image = [NSImage imageNamed:@"SignedUnknown"];
    }
    
bail:
    
    return;
}

//automatically invoked when user clicks signing icon
// depending on state, show/populate the popup, or close it
-(IBAction)signingInfoButtonHandler:(id)sender
{
    //not open?
    // show popover
    if(YES != self.signingInfoPopover.isShown)
    {
        //open
        [self openSigningInfoPopover];
    }
    
    //otherwise close it
    else
    {
        //close
        [self.signingInfoPopover close];
    }
    
    return;
}

//open signing info popover
-(void)openSigningInfoPopover
{
    //view controller
    SigningInfoViewController* popoverDelegate = nil;
    
    //set button state
    self.signingInfoButton.state = NSControlStateValueOn;
    
    //grab delegate
    popoverDelegate = (SigningInfoViewController*)self.signingInfoPopover.delegate;
    
    //set icon image
    popoverDelegate.icon.image = self.signingInfoButton.image;
    
    //set alert info
    popoverDelegate.alert = self.alert;
    
    //show popover
    [self.signingInfoPopover showRelativeToRect:[self.signingInfoButton bounds] ofView:self.signingInfoButton preferredEdge:NSMaxYEdge];
    
    return;
}

//VT button handler
// open user's browser w/ VT results
-(IBAction)vtButtonHandler:(id)sender
{
    NSString* hash = hashFile(self.processPath.string);
    if(!hash) {
        
        //show error
        showAlert(NSAlertStyleWarning, [NSString stringWithFormat:NSLocalizedString(@"ERROR: Failed to hash %@", @"ERROR: Failed to hash %@"), self.processName.stringValue], nil, @[NSLocalizedString(@"OK", @"OK")]);
        
        return;
        
    }

    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", hash]]];
    
    return;
}

//invoked when user clicks process ancestry button
// depending on state, show/populate the popup, or close it
-(IBAction)ancestryButtonHandler:(id)sender
{
    //open popover
    if(NSControlStateValueOn == self.ancestryButton.state)
    {
        //add the index value to each process in the hierarchy
        // used to populate outline/table
        for(NSUInteger i = 0; i<self.processHierarchy.count; i++)
        {
            //set index
            self.processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
        }

        //set process hierarchy
        self.ancestryViewController.processHierarchy = processHierarchy;
        
        //dynamically (re)size popover
        [self setPopoverSize];
        
        //reload it
        [self.ancestryOutline reloadData];
        
        //auto-expand
        [self.ancestryOutline expandItem:nil expandChildren:YES];
        
        //show popover
        [self.ancestryPopover showRelativeToRect:[self.ancestryButton bounds] ofView:self.ancestryButton preferredEdge:NSMaxYEdge];
    }
    
    //close popover
    else
    {
        //close
        [self.ancestryPopover close];
    }
    
    return;
}

//set the popover window size
// make it roughly fit to content
-(void)setPopoverSize
{
    //popover's frame
    CGRect popoverFrame = {0};
    
    //required height
    CGFloat popoverHeight = 0.0f;
    
    //text of current row
    NSString* currentRow = nil;
    
    //width of current row
    CGFloat currentRowWidth = 0.0f;
    
    //length of max line
    CGFloat maxRowWidth = 0.0f;
    
    //extra rows
    NSUInteger extraRows = 0;
    
    //when hierarchy is less than 4
    // ->set (some) extra rows
    if(self.ancestryViewController.processHierarchy.count < 4)
    {
        //5 total
        extraRows = 4 - self.ancestryViewController.processHierarchy.count;
    }
    
    //calc total window height
    // ->number of rows + extra rows, * height
    popoverHeight = (self.ancestryViewController.processHierarchy.count + extraRows + 2) * [self.ancestryOutline rowHeight];
    
    //get window's frame
    popoverFrame = self.ancestryView.frame;
    
    //calculate max line width
    for(NSUInteger i=0; i<self.ancestryViewController.processHierarchy.count; i++)
    {
        //generate text of current row
        currentRow = [NSString stringWithFormat:NSLocalizedString(@"%@ (pid: %@)", @"%@ (pid: %@)"), self.ancestryViewController.processHierarchy[i][@"name"], [self.ancestryViewController.processHierarchy lastObject][@"pid"]];
        
        //calculate width
        // ->first w/ indentation
        currentRowWidth = [self.ancestryOutline indentationPerLevel] * (i+1);
        
        //calculate width
        // ->then size of string in row
        currentRowWidth += [currentRow sizeWithAttributes: @{NSFontAttributeName: self.ancestryTextCell.font}].width;
        
        //save it greater than max
        if(maxRowWidth < currentRowWidth)
        {
            //save
            maxRowWidth = currentRowWidth;
        }
    }
    
    //add some padding
    // ->scroll bar, etc
    maxRowWidth += 50;
    
    //set height
    popoverFrame.size.height = popoverHeight;
    
    //set width
    popoverFrame.size.width = maxRowWidth;
    
    //set new frame
    self.ancestryView.frame = popoverFrame;
    
    return;
}

//close any open popups
-(void)closePopups
{
    //process ancestry popup
    if(NSControlStateValueOn == self.ancestryButton.state)
    {
        //close
        [self.ancestryPopover close];
        
        //set button state to off
        self.ancestryButton.state = NSControlStateValueOff;
    }
    
    //signing info popup
    if(NSControlStateValueOn == self.signingInfoButton.state)
    {
        //close
        [self.signingInfoPopover close];
        
        //set button state to off
        self.signingInfoButton.state = NSControlStateValueOff;
    }
    
    return;
}

//button handler
// close popups, grap user response/send to daemon, save 'preferences' (options shown, etc)
-(IBAction)handleUserResponse:(id)sender
{
    //rule expiration
    NSDate* expiration = nil;
    
    //show options state
    NSInteger showOptionsState = 0;
    
    //rule scope index
    NSInteger ruleScopeIndex = 0;
    
    //rule duration
    NSInteger ruleDurationTag = 0;
    
    //response to daemon
    NSMutableDictionary* alertResponse = nil;
    
    //dbg msg
    os_log_debug(logHandle, "handling user response");
    
    //grab state
    showOptionsState = self.showOptions.state;
    
    //grab action scope index
    ruleScopeIndex = self.actionScope.indexOfSelectedItem;
    
    //get selected rule duration
    if(self.ruleDurationAlways.state == NSControlStateValueOn)
    {
        //save
        ruleDurationTag = self.ruleDurationAlways.tag;
    }
    else if(self.ruleDurationProcess.state == NSControlStateValueOn)
    {
        //save
        ruleDurationTag = self.ruleDurationProcess.tag;
    }
    else if(self.ruleDurationCustom.state == NSControlStateValueOn)
    {
        //save
        ruleDurationTag = self.ruleDurationCustom.tag;
    }

    //init alert response
    // start w/ copy of received alert
    alertResponse = [self.alert mutableCopy];
    
    //set type as user
    alertResponse[KEY_TYPE] = @(RULE_TYPE_USER);
    
    //add current user
    alertResponse[KEY_USER_ID] = @(getuid());
    
    //add user response
    alertResponse[KEY_ACTION] = @(((NSButton*)sender).tag);
    
    //add action scope
    alertResponse[KEY_SCOPE] = @(ruleScopeIndex);

    //rule duration temporary (pid)?
    if(NSControlStateValueOn == self.ruleDurationProcess.state)
    {
        //set flag
        alertResponse[KEY_DURATION_PROCESS] = @1;
    }
    
    //rule duration temporary (expiration)?
    else if(NSControlStateValueOn == self.ruleDurationCustom.state)
    {
        //get expiration
        expiration = absoluteDate([self.ruleDurationCustomAmount.formatter dateFromString:self.ruleDurationCustomAmount.stringValue]);
        
        //dbg msg
        os_log_debug(logHandle, "rule expiration: %@", expiration);
        
        //add
        alertResponse[KEY_DURATION_EXPIRATION] = expiration;
    }
    
    //set endpoint addr
    alertResponse[KEY_ENDPOINT_ADDR] = self.endpoint;
    
    //close popups
    [self closePopups];
    
    //close window
    [self.window close];
    
    //dbg msg
    os_log_debug(logHandle, "replying to alert %{public}@", alertResponse);
    
    //reply
    self.reply(alertResponse);
    
    //save preferences
    // includes options shown/last action scope, etc.
    [xpcDaemonClient updatePreferences:@{PREF_ALERT_SHOW_OPTIONS: @(showOptionsState),
                                         PREF_ALERT_LAST_RULE_SCOPE: @(ruleScopeIndex),
                                         PREF_ALERT_LAST_RULE_DURATION: @(ruleDurationTag)}];
    
    //set app's background/foreground state
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
    
    return;
}

//init/show touch bar
-(void)initTouchBar
{
    //touch bar items
    NSArray *touchBarItems = nil;
    
    //alloc/init
    self.touchBar = [[NSTouchBar alloc] init];
    if(nil == self.touchBar)
    {
        //no touch bar?
        goto bail;
    }
    
    //set delegate
    self.touchBar.delegate = self;
    
    //set id
    self.touchBar.customizationIdentifier = @BUNDLE_ID;
    
    //init items
    touchBarItems = @[@".icon", @".label", @".block", @".allow"];
    
    //set items
    self.touchBar.defaultItemIdentifiers = touchBarItems;
    
    //set customization items
    self.touchBar.customizationAllowedItemIdentifiers = touchBarItems;
    
bail:
    
    return;
}

//delegate method
// init item for touch bar
-(NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    //icon view
    NSImageView *iconView = nil;
    
    //icon
    NSImage* icon = nil;
    
    //item
    NSCustomTouchBarItem *touchBarItem = nil;
    
    //init item
    touchBarItem = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    
    //icon
    if(YES == [identifier isEqualToString: @".icon" ])
    {
        //init icon view
        iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 30.0, 30.0)];
        
        //enable layer
        [iconView setWantsLayer:YES];
        
        //set color
        [iconView.layer setBackgroundColor:[[NSColor windowBackgroundColor] CGColor]];
        
        //mask
        iconView.layer.masksToBounds = YES;
        
        //round corners
        iconView.layer.cornerRadius = 3.0;
        
        //load icon image
        icon = [NSImage imageNamed:@"Icon"];
        
        //set size
        icon.size = CGSizeMake(30, 30);
        
        //add image
        iconView.image = icon;
        
        //set view
        touchBarItem.view = iconView;
    }
    
    //label
    else if(YES == [identifier isEqualToString:@".label"])
    {
        //item label
        touchBarItem.view = [NSTextField labelWithString:[NSString stringWithFormat:@"%@ %@", self.processName.stringValue,self.alertMessage.string]];
    }
    
    //block button
    else if(YES == [identifier isEqualToString:@".block"])
    {
        //init button
        touchBarItem.view = [NSButton buttonWithTitle: @"Block" target:self action: @selector(handleUserResponse:)];
        
        //set tag
        // 0: block
        ((NSButton*)touchBarItem.view).tag = 0;
    }
    
    //allow button
    else if(YES == [identifier isEqualToString:@".allow"])
    {
        //init button
        touchBarItem.view = [NSButton buttonWithTitle: @"Allow" target:self action: @selector(handleUserResponse:)];
        
        //set tag
        // 1: allow
        ((NSButton*)touchBarItem.view).tag = 1;
    }
    
    return touchBarItem;
}

//groups radio buttons
-(IBAction)ruleDurationHandler:(id)sender {
   
    //need this method so radio buttons are mutually exclusive
}

//show / hide option view
-(IBAction)toggleOptionsView:(id)sender {
    
    //frame
    NSRect origin = {0};
    
    //dbg msg
    os_log_debug(logHandle, "toggling option's view, state: %ld", (long)self.showOptions.state);

    //frame
    NSRect windowFrame = self.window.frame;

    //on
    if(NSControlStateValueOn == self.showOptions.state)
    {
        origin = self.window.contentView.frame;
        origin.origin.y = self.window.contentView.frame.size.height;
        
        windowFrame.size.height += NSHeight(self.options.frame); //NSHeight(self.options.frame);
        windowFrame.origin.y -= NSHeight(self.options.frame);
        
        [self.window setContentMinSize:NSMakeSize(self.window.frame.size.width, DEFAULT_WINDOW_HEIGHT_EXPANDED)];
        [self.window setContentMaxSize:NSMakeSize(self.window.frame.size.width, DEFAULT_WINDOW_HEIGHT_EXPANDED)];
        
        [self.options setHidden:NO];
        
        [self.window layoutIfNeeded];
        [self.window displayIfNeeded];
        
        //dbg msg
        os_log_debug(logHandle, "added option view to window");
    }
    //off
    else
    {
        //[self.options removeFromSuperview];
        [self.options setHidden:YES];
        
        //dbg msg
        os_log_debug(logHandle, "removed option view from window");
        
        windowFrame.size.height -= NSHeight(self.options.frame);
        windowFrame.origin.y += NSHeight(self.options.frame);
        
        [self.window setContentMinSize:NSMakeSize(self.window.frame.size.width, DEFAULT_WINDOW_HEIGHT)];
        [self.window setContentMaxSize:NSMakeSize(self.window.frame.size.width, DEFAULT_WINDOW_HEIGHT)];
    }
        
    //resize
    [self.window setFrame:windowFrame display:YES animate:YES];
    
    return;
}

//set wrapping
-(void)setWrapping:(NSTextView*)textView {
    
    NSRange fullRange = {0,0};
    NSMutableAttributedString* mutableAttrString = nil;
    
    mutableAttrString = [textView.textStorage mutableCopy];
    fullRange = NSMakeRange(0, mutableAttrString.length);

    [mutableAttrString enumerateAttributesInRange:fullRange
                                            options:0
                                         usingBlock:^(NSDictionary* attrs, NSRange range, BOOL *stop) {
        
        NSMutableParagraphStyle* mutableParagraphStyle = nil;
        
        NSParagraphStyle* existingStyle = attrs[NSParagraphStyleAttributeName];
        if(nil != existingStyle)
        {
            mutableParagraphStyle = [existingStyle mutableCopy];
        }
        else
        {
            mutableParagraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        mutableParagraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
        
        NSMutableDictionary* newAttrs = [attrs mutableCopy];
        newAttrs[NSParagraphStyleAttributeName] = mutableParagraphStyle;
        [mutableAttrString setAttributes:newAttrs range:range];
    }];
    
    [textView.textStorage setAttributedString:mutableAttrString];
    
    return;
}

@end
