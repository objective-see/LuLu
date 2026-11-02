//
//  file: WelcomePages.m
//  project: lulu (main app)
//  description: first-run pages: welcome, permissions, configure, support
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "consts.h"
#import "WelcomePages.h"

/* DEFINES */

//page size
#define PAGE_WIDTH 700
#define PAGE_HEIGHT 460

//footer (height)
#define FOOTER_HEIGHT 48

//rows (width, gap)
#define ROW_WIDTH 640
#define ROW_GAP 12

//row: padding
#define ROW_PADDING 14

//row: badge
#define BADGE_SIZE 36

//row: text column (x)
#define TEXT_X (ROW_PADDING + BADGE_SIZE + 14)

//permission row: status column (width)
#define STATUS_WIDTH 170

//fonts
#define FONT_HEADER @"AvenirNextCondensed-Regular"

/* HELPERS */

//(SF) symbol, when available
static NSImage* symbolImage(NSString* name, CGFloat size)
{
    //image
    NSImage* image = nil;
    
    //macOS 11+
    if(@available(macOS 11.0, *))
    {
        //load
        image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        image = [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightMedium]];
    }
    
    return image;
}

//label
static NSTextField* label(NSString* string, NSFont* font, NSColor* color, BOOL wraps)
{
    //label
    NSTextField* label = (YES == wraps) ? [NSTextField wrappingLabelWithString:string] : [NSTextField labelWithString:string];
    
    //no selection
    label.selectable = NO;
    
    //style
    label.font = font;
    label.textColor = color;
    
    return label;
}

//height of (wrapped) label, for width
static CGFloat labelHeight(NSTextField* label, CGFloat width)
{
    return ceil([label.cell cellSizeForBounds:NSMakeRect(0, 0, width, CGFLOAT_MAX)].height);
}

//(rounded) panel background color
// resolved for current appearance, as layer colors don't track dark/light mode
static CGColorRef panelColor(void)
{
    return [NSColor.labelColor colorWithAlphaComponent:0.05].CGColor;
}

#pragma mark -
#pragma mark page

@interface WelcomePage ()

//'next' button
@property(nonatomic, strong, readwrite)NSButton* nextButton;

//content (top)
// i.e. y, just below the header
@property(nonatomic)CGFloat contentTop;

@end

@implementation WelcomePage

//init
-(instancetype)initWithIcon:(NSImage*)icon iconSize:(CGFloat)iconSize wordmark:(NSImage*)wordmark title:(NSString*)title message:(NSString*)message
{
    //footer
    NSBox* footer = nil;
    
    //icon
    NSImageView* iconView = nil;
    
    //wordmark
    NSImageView* wordmarkView = nil;
    
    //title
    NSTextField* titleLabel = nil;
    
    //message
    NSTextField* messageLabel = nil;
    
    //y
    CGFloat y = PAGE_HEIGHT - 16;
    
    //(label) height
    CGFloat height = 0;
    
    //init super
    self = [super initWithFrame:NSMakeRect(0, 0, PAGE_WIDTH, PAGE_HEIGHT)];
    if(nil != self)
    {
        //layer
        // owner sets background (white) in light mode
        self.wantsLayer = YES;
        
        //footer
        // (LuLu) green
        footer = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, PAGE_WIDTH, FOOTER_HEIGHT)];
        footer.boxType = NSBoxCustom;
        footer.borderWidth = 0;
        footer.titlePosition = NSNoTitle;
        footer.fillColor = [NSColor colorWithSRGBRed:0.578 green:0.759 blue:0.237 alpha:1.0];
        [self addSubview:footer];
        
        //icon
        if(nil != icon)
        {
            //add
            y -= iconSize;
            iconView = [NSImageView imageViewWithImage:icon];
            iconView.frame = NSMakeRect((PAGE_WIDTH - iconSize)/2, y, iconSize, iconSize);
            iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
            [self addSubview:iconView];
        }
        
        //wordmark
        if(nil != wordmark)
        {
            //add
            // (asset is ~3.3:1)
            y -= 2 + 56;
            wordmarkView = [NSImageView imageViewWithImage:wordmark];
            wordmarkView.frame = NSMakeRect((PAGE_WIDTH - 184)/2, y, 184, 56);
            wordmarkView.imageScaling = NSImageScaleProportionallyUpOrDown;
            [self addSubview:wordmarkView];
        }
        
        //title
        if(nil != title)
        {
            //add
            y -= 4 + 38;
            titleLabel = label(title, [NSFont fontWithName:FONT_HEADER size:30], NSColor.labelColor, NO);
            titleLabel.alignment = NSTextAlignmentCenter;
            titleLabel.frame = NSMakeRect(0, y, PAGE_WIDTH, 38);
            [self addSubview:titleLabel];
        }
        
        //message
        if(nil != message)
        {
            //add
            messageLabel = label(message, [NSFont fontWithName:FONT_HEADER size:17], NSColor.secondaryLabelColor, YES);
            messageLabel.alignment = NSTextAlignmentCenter;
            height = labelHeight(messageLabel, PAGE_WIDTH - 100);
            y -= 4 + height;
            messageLabel.frame = NSMakeRect(50, y, PAGE_WIDTH - 100, height);
            [self addSubview:messageLabel];
        }
        
        //content starts below header
        self.contentTop = y - 14;
    }
    
    return self;
}

//add 'next' button
// bottom right of footer (not the default button: a blue bezel clashes with the green)
-(NSButton*)addNextButton:(NSString*)title tag:(NSInteger)tag target:(id)target action:(SEL)action
{
    //init
    self.nextButton = [NSButton buttonWithTitle:title target:target action:action];
    self.nextButton.bezelStyle = NSBezelStyleRounded;
    self.nextButton.tag = tag;
    self.nextButton.frame = NSMakeRect(PAGE_WIDTH - 14 - 81, 8, 81, 32);
    [self addSubview:self.nextButton];
    
    return self.nextButton;
}

@end

#pragma mark -
#pragma mark card row

@interface CardRow ()

//width
@property(nonatomic)CGFloat width;

//badge (symbol)
@property(nonatomic, strong)NSView* badge;

//badge color
@property(nonatomic, strong)NSColor* badgeColor;

//title
@property(nonatomic, strong)NSTextField* titleLabel;

//detail
@property(nonatomic, strong)NSTextField* detailLabel;

//message
@property(nonatomic, strong)NSTextField* messageLabel;

@end

@implementation CardRow

//init
-(instancetype)initWithSymbol:(NSString*)symbol color:(NSColor*)color title:(NSString*)title detail:(NSString*)detail width:(CGFloat)width
{
    //symbol
    NSImageView* symbolView = nil;
    
    //init super
    self = [super initWithFrame:NSMakeRect(0, 0, width, 0)];
    if(nil != self)
    {
        //save
        self.width = width;
        self.badgeColor = color;
        
        //(rounded) background
        self.wantsLayer = YES;
        self.layer.cornerRadius = 10;
        
        //badge
        self.badge = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, BADGE_SIZE, BADGE_SIZE)];
        self.badge.wantsLayer = YES;
        self.badge.layer.cornerRadius = 9;
        [self addSubview:self.badge];
        
        //badge: symbol
        symbolView = [[NSImageView alloc] initWithFrame:self.badge.bounds];
        symbolView.image = symbolImage(symbol, 20);
        symbolView.imageScaling = NSImageScaleProportionallyDown;
        symbolView.contentTintColor = color;
        [self.badge addSubview:symbolView];
        
        //title
        self.titleLabel = label(title, [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold], NSColor.labelColor, NO);
        [self addSubview:self.titleLabel];
        
        //detail
        self.detailLabel = label(detail, [NSFont systemFontOfSize:13], NSColor.secondaryLabelColor, YES);
        [self addSubview:self.detailLabel];
        
        //message
        self.messageLabel = label(@"", [NSFont systemFontOfSize:13], NSColor.systemOrangeColor, YES);
        self.messageLabel.hidden = YES;
        [self addSubview:self.messageLabel];
    }
    
    return self;
}

//set accessory
-(void)setAccessory:(NSView*)accessory
{
    //remove old
    [_accessory removeFromSuperview];
    
    //save & add
    _accessory = accessory;
    if(nil != accessory)
    {
        //add
        [self addSubview:accessory];
    }
    
    //(re)layout
    [self setNeedsLayout:YES];
    
    return;
}

//set message
-(void)setMessage:(NSString*)message color:(NSColor*)color
{
    //set
    self.messageLabel.stringValue = (nil != message) ? message : @"";
    self.messageLabel.textColor = color;
    self.messageLabel.hidden = (0 == message.length);
    
    //(re)layout (page)
    [self.superview setNeedsLayout:YES];
    
    return;
}

//text column (width)
-(CGFloat)textWidth
{
    return self.width - TEXT_X - ROW_PADDING - ((nil != self.accessory) ? NSWidth(self.accessory.frame) + 14 : 0);
}

//height (for current contents)
-(CGFloat)requiredHeight
{
    //height
    // padding, title, detail
    CGFloat height = ROW_PADDING + 18 + 2 + labelHeight(self.detailLabel, self.textWidth) + ROW_PADDING;
    
    //message?
    if(YES != self.messageLabel.hidden)
    {
        //add
        height += 4 + labelHeight(self.messageLabel, self.textWidth);
    }
    
    //badge & accessory need a minimum
    height = MAX(height, BADGE_SIZE + 2*ROW_PADDING);
    if(nil != self.accessory)
    {
        //max
        height = MAX(height, NSHeight(self.accessory.frame) + 2*ROW_PADDING);
    }
    
    return height;
}

//(re)layout when appearance changes
-(void)viewDidChangeEffectiveAppearance
{
    //super
    [super viewDidChangeEffectiveAppearance];
    
    //update
    [self setNeedsLayout:YES];
}

//layout
-(void)layout
{
    //height
    CGFloat height = NSHeight(self.bounds);
    
    //y
    CGFloat y = height - ROW_PADDING;
    
    //(label) height
    CGFloat labelH = 0;
    
    //text width
    CGFloat textW = self.textWidth;
    
    //super
    [super layout];
    
    //colors
    self.layer.backgroundColor = (YES == self.showsBackground) ? panelColor() : nil;
    self.badge.layer.backgroundColor = [self.badgeColor colorWithAlphaComponent:0.12].CGColor;
    
    //badge: vertically centered
    self.badge.frame = NSMakeRect(ROW_PADDING, floor((height - BADGE_SIZE)/2), BADGE_SIZE, BADGE_SIZE);
    
    //title
    y -= 18;
    self.titleLabel.frame = NSMakeRect(TEXT_X, y, textW, 18);
    
    //detail
    labelH = labelHeight(self.detailLabel, textW);
    y -= 2 + labelH;
    self.detailLabel.frame = NSMakeRect(TEXT_X, y, textW, labelH);
    
    //message
    if(YES != self.messageLabel.hidden)
    {
        //place
        labelH = labelHeight(self.messageLabel, textW);
        y -= 4 + labelH;
        self.messageLabel.frame = NSMakeRect(TEXT_X, y, textW, labelH);
    }
    
    //accessory: right aligned, vertically centered
    if(nil != self.accessory)
    {
        //place
        self.accessory.frame = NSMakeRect(self.width - ROW_PADDING - NSWidth(self.accessory.frame), floor((height - NSHeight(self.accessory.frame))/2), NSWidth(self.accessory.frame), NSHeight(self.accessory.frame));
    }
    
    return;
}

@end

#pragma mark -
#pragma mark permission row

@interface PermissionRow ()

//status: icon
@property(nonatomic, strong)NSImageView* statusIcon;

//status: spinner (checking)
@property(nonatomic, strong)NSProgressIndicator* spinner;

//status: text
@property(nonatomic, strong)NSTextField* statusLabel;

//'Open System Settings…'
@property(nonatomic, strong)NSButton* settingsButton;

//settings URL
@property(nonatomic, copy)NSString* settingsURL;

//state
@property(nonatomic, readwrite)PermissionState state;

@end

@implementation PermissionRow

//init
-(instancetype)initWithSymbol:(NSString*)symbol title:(NSString*)title detail:(NSString*)detail settingsURL:(NSString*)settingsURL
{
    //status (column)
    NSView* status = nil;
    
    //init super
    self = [super initWithSymbol:symbol color:NSColor.systemBlueColor title:title detail:detail width:ROW_WIDTH];
    if(nil != self)
    {
        //save
        self.settingsURL = settingsURL;
        
        //card
        self.showsBackground = YES;
        
        //status column
        // icon/spinner + text, and settings button below
        status = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, STATUS_WIDTH, 18)];
        
        //status: icon
        self.statusIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 18, 18)];
        self.statusIcon.imageScaling = NSImageScaleProportionallyDown;
        [status addSubview:self.statusIcon];
        
        //status: spinner
        self.spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
        self.spinner.style = NSProgressIndicatorStyleSpinning;
        self.spinner.controlSize = NSControlSizeSmall;
        self.spinner.displayedWhenStopped = NO;
        [status addSubview:self.spinner];
        
        //status: text
        self.statusLabel = label(@"", [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold], NSColor.tertiaryLabelColor, NO);
        [status addSubview:self.statusLabel];
        
        //settings button
        self.settingsButton = [NSButton buttonWithTitle:NSLocalizedString(@"Open System Settings…", @"Open System Settings…") target:self action:@selector(openSettings:)];
        self.settingsButton.bezelStyle = NSBezelStyleRounded;
        self.settingsButton.controlSize = NSControlSizeSmall;
        self.settingsButton.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
        [self.settingsButton sizeToFit];
        [status addSubview:self.settingsButton];
        
        //set as accessory
        self.accessory = status;
        
        //initial state
        [self setState:PermissionStatePending message:nil];
    }
    
    return self;
}

//set state
-(void)setState:(PermissionState)state message:(NSString*)message
{
    //status
    NSString* status = nil;
    
    //status (icon)
    NSString* symbol = nil;
    
    //status (color)
    NSColor* color = nil;
    
    //status (text) width
    CGFloat statusW = 0;
    
    //right edge
    CGFloat right = STATUS_WIDTH;
    
    //status (y)
    CGFloat statusY = 0;
    
    //show button?
    BOOL showButton = NO;
    
    //save
    _state = state;
    
    //per state
    switch(state)
    {
        case PermissionStatePending:
            status = NSLocalizedString(@"Waiting", @"Waiting");
            symbol = @"circle.dashed";
            color = NSColor.tertiaryLabelColor;
            break;
            
        case PermissionStateChecking:
            status = NSLocalizedString(@"Checking", @"Checking");
            color = NSColor.secondaryLabelColor;
            break;
            
        case PermissionStateWaiting:
            status = NSLocalizedString(@"Needs approval", @"Needs approval");
            symbol = @"exclamationmark.circle.fill";
            color = NSColor.systemOrangeColor;
            break;
            
        case PermissionStateGranted:
            status = NSLocalizedString(@"Granted", @"Granted");
            symbol = @"checkmark.circle.fill";
            color = NSColor.systemGreenColor;
            break;
            
        case PermissionStateFailed:
            status = NSLocalizedString(@"Not granted", @"Not granted");
            symbol = @"xmark.octagon.fill";
            color = NSColor.systemRedColor;
            break;
    }
    
    //status text
    self.statusLabel.stringValue = status;
    self.statusLabel.textColor = color;
    
    //status icon
    self.statusIcon.image = (nil != symbol) ? symbolImage(symbol, 14) : nil;
    self.statusIcon.contentTintColor = color;
    self.statusIcon.hidden = (nil == self.statusIcon.image);
    
    //spinner
    (PermissionStateChecking == state) ? [self.spinner startAnimation:nil] : [self.spinner stopAnimation:nil];
    
    //message
    [self setMessage:message color:(PermissionStateFailed == state) ? NSColor.systemRedColor : NSColor.systemOrangeColor];
    
    //settings button
    // when the user is needed (and there's somewhere to send them)
    showButton = (nil != self.settingsURL) && ((PermissionStateWaiting == state) || (PermissionStateFailed == state));
    self.settingsButton.hidden = !showButton;
    
    //layout status column
    // (accessory's size drives the row's layout)
    self.accessory.frame = NSMakeRect(0, 0, STATUS_WIDTH, (YES == showButton) ? 18 + 6 + NSHeight(self.settingsButton.frame) : 18);
    statusY = NSHeight(self.accessory.frame) - 18;
    
    //status: text (right aligned)
    statusW = ceil([self.statusLabel.cell cellSizeForBounds:NSMakeRect(0, 0, STATUS_WIDTH, 18)].width);
    self.statusLabel.frame = NSMakeRect(right - statusW, statusY, statusW, 18);
    
    //status: icon / spinner (left of text)
    self.statusIcon.frame = NSMakeRect(right - statusW - 22, statusY, 18, 18);
    self.spinner.frame = NSMakeRect(right - statusW - 22, statusY + 1, 16, 16);
    
    //settings button (right aligned, below)
    self.settingsButton.frame = NSMakeRect(right - NSWidth(self.settingsButton.frame) + 6, 0, NSWidth(self.settingsButton.frame), NSHeight(self.settingsButton.frame));
    
    //(re)layout (page)
    [self.superview setNeedsLayout:YES];
    
    return;
}

//open system settings
-(void)openSettings:(id)sender
{
    //open
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:self.settingsURL]];
}

@end

#pragma mark -
#pragma mark rows (layout helper)

//stack rows top-down from y, centered
static void layoutRows(NSView* page, NSArray<CardRow*>* rows, CGFloat y, CGFloat gap)
{
    //rows
    for(CardRow* row in rows)
    {
        //height
        CGFloat height = [row requiredHeight];
        
        //place
        y -= height;
        row.frame = NSMakeRect(floor((NSWidth(page.bounds) - NSWidth(row.frame))/2), y, NSWidth(row.frame), height);
        [row setNeedsLayout:YES];
        
        //gap
        y -= gap;
    }
    
    return;
}

#pragma mark -
#pragma mark welcome (splash) page

@interface WelcomeSplashPage ()

//feature rows
@property(nonatomic, strong)NSArray<CardRow*>* rows;

@end

@implementation WelcomeSplashPage

//init
-(instancetype)init
{
    //rows
    NSMutableArray* rows = [NSMutableArray array];
    
    //init super
    // icon, wordmark, and tagline
    self = [super initWithIcon:[NSImage imageNamed:@"Icon"] iconSize:96 wordmark:[NSImage imageNamed:@"LuLuText"] title:nil message:NSLocalizedString(@"The free, open-source firewall for macOS.", @"The free, open-source firewall for macOS.")];
    if(nil != self)
    {
        //feature: alerts
        [rows addObject:[[CardRow alloc] initWithSymbol:@"bell.badge" color:NSColor.systemBlueColor title:NSLocalizedString(@"Alerts on new connections", @"Alerts on new connections") detail:NSLocalizedString(@"When a program first tries to connect out, LuLu asks you to allow or block it.", @"When a program first tries to connect out, LuLu asks you to allow or block it.") width:560]];
        
        //feature: rules
        [rows addObject:[[CardRow alloc] initWithSymbol:@"checklist" color:NSColor.systemGreenColor title:NSLocalizedString(@"Rules you control", @"Rules you control") detail:NSLocalizedString(@"Allow or block by program, endpoint or domain; temporarily, or for good.", @"Allow or block by program, endpoint or domain; temporarily, or for good.") width:560]];
        
        //feature: modes
        [rows addObject:[[CardRow alloc] initWithSymbol:@"lock.shield" color:NSColor.systemPurpleColor title:NSLocalizedString(@"Block mode & profiles", @"Block mode & profiles") detail:NSLocalizedString(@"Block everything with one click, or switch between rule sets with profiles.", @"Block everything with one click, or switch between rule sets with profiles.") width:560]];
        
        //add
        for(CardRow* row in rows)
        {
            //add
            [self addSubview:row];
        }
        
        //save
        self.rows = rows;
    }
    
    return self;
}

//layout
-(void)layout
{
    //super
    [super layout];
    
    //rows
    layoutRows(self, self.rows, self.contentTop + 4, 2);
    
    return;
}

@end

#pragma mark -
#pragma mark permissions page

@interface PermissionsPage ()

//rows
@property(nonatomic, strong, readwrite)PermissionRow* extensionRow;
@property(nonatomic, strong, readwrite)PermissionRow* filterRow;

@end

@implementation PermissionsPage

//init
-(instancetype)init
{
    //settings URL
    // macOS 13+: 'Login Items & Extensions', else: security pane
    NSString* settingsURL = nil;
    
    //init super
    self = [super initWithIcon:NSApp.applicationIconImage iconSize:72 wordmark:nil title:NSLocalizedString(@"Permissions", @"Permissions") message:NSLocalizedString(@"LuLu needs its network extension approved, and permission to filter content. macOS will prompt you for both.", @"LuLu needs its network extension approved, and permission to filter content. macOS will prompt you for both.")];
    if(nil != self)
    {
        //settings URL
        if(@available(macOS 13.0, *))
        {
            //login items & extensions
            settingsURL = SETTINGS_EXTENSIONS_URL;
        }
        else
        {
            //security & privacy
            settingsURL = SETTINGS_SECURITY_URL;
        }
        
        //row: system extension
        self.extensionRow = [[PermissionRow alloc] initWithSymbol:@"puzzlepiece.extension" title:NSLocalizedString(@"Network Extension", @"Network Extension") detail:NSLocalizedString(@"Monitors outgoing connections, via Apple's Network Extension framework.", @"Monitors outgoing connections, via Apple's Network Extension framework.") settingsURL:settingsURL];
        [self addSubview:self.extensionRow];
        
        //row: content filter
        self.filterRow = [[PermissionRow alloc] initWithSymbol:@"network" title:NSLocalizedString(@"Content Filter", @"Content Filter") detail:NSLocalizedString(@"Lets LuLu allow or block each connection. Click 'Allow' when macOS asks.", @"Lets LuLu allow or block each connection. Click 'Allow' when macOS asks.") settingsURL:nil];
        [self addSubview:self.filterRow];
    }
    
    return self;
}

//layout
-(void)layout
{
    //super
    [super layout];
    
    //rows
    layoutRows(self, @[self.extensionRow, self.filterRow], self.contentTop, ROW_GAP);
    
    return;
}

//update 'next' button
-(void)updateNextButton
{
    //failed?
    BOOL failed = (PermissionStateFailed == self.extensionRow.state) || (PermissionStateFailed == self.filterRow.state);
    
    //granted?
    BOOL granted = (PermissionStateGranted == self.extensionRow.state) && (PermissionStateGranted == self.filterRow.state);
    
    //title
    self.nextButton.title = (YES == failed) ? NSLocalizedString(@"Retry", @"Retry") : NSLocalizedString(@"Next", @"Next");
    
    //enabled once both are granted (Next), or once a request failed (Retry)
    self.nextButton.enabled = (granted || failed);
    
    return;
}

@end

#pragma mark -
#pragma mark configure page

@interface ConfigurePage ()

//rows
@property(nonatomic, strong)NSArray<CardRow*>* rows;

//switches
@property(nonatomic, strong, readwrite)NSSwitch* allowApple;
@property(nonatomic, strong, readwrite)NSSwitch* allowInstalled;
@property(nonatomic, strong, readwrite)NSSwitch* allowDNS;

@end

@implementation ConfigurePage

//option row
// card w/ a switch (on, by default)
-(CardRow*)optionRow:(NSString*)symbol color:(NSColor*)color title:(NSString*)title detail:(NSString*)detail toggle:(NSSwitch**)toggle
{
    //row
    CardRow* row = [[CardRow alloc] initWithSymbol:symbol color:color title:title detail:detail width:ROW_WIDTH];
    row.showsBackground = YES;
    
    //switch
    *toggle = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    [*toggle sizeToFit];
    (*toggle).state = NSControlStateValueOn;
    row.accessory = *toggle;
    
    return row;
}

//init
-(instancetype)init
{
    //switches
    NSSwitch* allowApple = nil;
    NSSwitch* allowInstalled = nil;
    NSSwitch* allowDNS = nil;
    
    //init super
    self = [super initWithIcon:NSApp.applicationIconImage iconSize:72 wordmark:nil title:NSLocalizedString(@"Configure", @"Configure") message:NSLocalizedString(@"A few defaults to start with. All of these can be changed later, in LuLu's Settings.", @"A few defaults to start with. All of these can be changed later, in LuLu's Settings.")];
    if(nil != self)
    {
        //rows
        self.rows = @[
            [self optionRow:@"apple.logo" color:NSColor.labelColor title:NSLocalizedString(@"Allow Apple Programs", @"Allow Apple Programs") detail:NSLocalizedString(@"Outgoing connections from Apple-signed programs will be allowed.", @"Outgoing connections from Apple-signed programs will be allowed.") toggle:&allowApple],
            [self optionRow:@"shippingbox" color:NSColor.systemBlueColor title:NSLocalizedString(@"Allow Already Installed Programs", @"Allow Already Installed Programs") detail:NSLocalizedString(@"Outgoing connections from currently installed 3rd-party programs will be allowed.", @"Outgoing connections from currently installed 3rd-party programs will be allowed.") toggle:&allowInstalled],
            [self optionRow:@"globe" color:NSColor.systemGreenColor title:NSLocalizedString(@"Allow DNS Traffic", @"Allow DNS Traffic") detail:NSLocalizedString(@"All outgoing UDP traffic on port 53 will be allowed.", @"All outgoing UDP traffic on port 53 will be allowed.") toggle:&allowDNS]
        ];
        
        //save
        self.allowApple = allowApple;
        self.allowInstalled = allowInstalled;
        self.allowDNS = allowDNS;
        
        //add
        for(CardRow* row in self.rows)
        {
            //add
            [self addSubview:row];
        }
    }
    
    return self;
}

//layout
-(void)layout
{
    //super
    [super layout];
    
    //rows
    layoutRows(self, self.rows, self.contentTop, ROW_GAP);
    
    return;
}

@end

#pragma mark -
#pragma mark support page

@interface SupportPage ()

//'support us' button
@property(nonatomic, strong, readwrite)NSButton* supportButton;

//friends panel
@property(nonatomic, strong)NSView* panel;

@end

@implementation SupportPage

//init
-(instancetype)initWithSupportTag:(NSInteger)tag target:(id)target action:(SEL)action
{
    //friends panel
    NSView* panel = nil;
    
    //panel title
    NSTextField* mahalo = nil;
    
    //logos (rows of: name, (visual) weight, max width, max height, vertical nudge)
    // rendered monochrome (assets are mixed colors), and sized by a common area (times weight)
    // so wide wordmarks and compact marks look roughly the same size (same rows/weights as WhatsYourSign)
    NSArray* rows = @[
        @[@[@"FriendsPANW", @1.0, @150, @26, @0], @[@"FriendsIru", @0.5, @150, @26, @2], @[@"FriendsHuntress", @1.25, @150, @26, @0]],
        @[@[@"FriendsJamf", @1.0, @150, @26, @0], @[@"FriendsiVerify", @1.0, @150, @26, @0], @[@"FriendsMacPaw", @1.0, @150, @26, @1], @[@"FriendsMalwarebytes", @1.0, @150, @26, @0]],
        @[@[@"FriendsNorthPole", @2.6, @200, @34, @0], @[@"FriendsRippling", @1.0, @150, @26, @0], @[@"FriendsThreatLocker", @1.0, @150, @26, @0]]
    ];
    
    //logo rows: height, gap
    const CGFloat rowH = 34;
    const CGFloat rowGap = 8;
    
    //y
    CGFloat y = 0;
    
    //init super
    self = [super initWithIcon:[NSImage imageNamed:@"Heart"] iconSize:64 wordmark:nil title:NSLocalizedString(@"Support LuLu?", @"Support LuLu?") message:NSLocalizedString(@"LuLu is free, open-source, and written by a single (Mac-loving) coder!\nPlease consider supporting Objective-See.", @"LuLu is free, open-source, and written by a single (Mac-loving) coder!\nPlease consider supporting Objective-See.")];
    if(nil != self)
    {
        //'support us' button
        self.supportButton = [NSButton buttonWithTitle:NSLocalizedString(@"Support Us", @"Support Us") target:target action:action];
        self.supportButton.tag = tag;
        self.supportButton.bezelStyle = NSBezelStyleRounded;
        if(@available(macOS 11.0, *))
        {
            //large
            self.supportButton.controlSize = NSControlSizeLarge;
        }
        self.supportButton.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
        self.supportButton.image = symbolImage(@"heart.fill", 14);
        self.supportButton.imagePosition = NSImageLeft;
        self.supportButton.imageHugsTitle = YES;
        self.supportButton.bezelColor = NSColor.systemPinkColor;
        [self.supportButton sizeToFit];
        self.supportButton.frame = NSMakeRect(floor((PAGE_WIDTH - NSWidth(self.supportButton.frame) - 20)/2), self.contentTop + 2 - 34, NSWidth(self.supportButton.frame) + 20, 34);
        [self addSubview:self.supportButton];
        
        //friends panel
        // sized to its contents: padding, title, logo rows, padding
        y = NSMinY(self.supportButton.frame) - 12;
        panel = [[NSView alloc] initWithFrame:NSMakeRect((PAGE_WIDTH - ROW_WIDTH)/2, 0, ROW_WIDTH, 12 + 16 + 10 + rows.count*rowH + (rows.count - 1)*rowGap + 12)];
        panel.frame = NSMakeRect(NSMinX(panel.frame), y - NSHeight(panel.frame), ROW_WIDTH, NSHeight(panel.frame));
        panel.wantsLayer = YES;
        panel.layer.cornerRadius = 12;
        [self addSubview:panel];
        self.panel = panel;
        
        //panel title
        mahalo = label(NSLocalizedString(@"Mahalo to the Friends of Objective-See, who make this possible", @"Mahalo to the Friends of Objective-See, who make this possible"), [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold], NSColor.secondaryLabelColor, NO);
        mahalo.alignment = NSTextAlignmentCenter;
        mahalo.frame = NSMakeRect(0, NSHeight(panel.frame) - 12 - 16, NSWidth(panel.frame), 16);
        [panel addSubview:mahalo];
        
        //logos
        // rows, evenly spaced below the title; each logo centered (w/ nudge) in its row
        y = NSMinY(mahalo.frame) - 10;
        for(NSArray* row in rows)
        {
            //sizes (per logo)
            NSMutableArray* sizes = [NSMutableArray array];
            
            //total width
            CGFloat total = 0;
            
            //x
            CGFloat x = 0;
            
            //size each logo
            // from common (weighted) area, capped in height & width
            for(NSArray* logo in row)
            {
                //area (points^2)
                const CGFloat area = 2600.0;
                
                //image
                NSImage* image = [NSImage imageNamed:logo[0]];
                
                //aspect (w/h)
                CGFloat aspect = ((0 != image.size.width) && (0 != image.size.height)) ? image.size.width / image.size.height : 1.0;
                
                //size
                CGFloat height = MIN(sqrt((area * [logo[1] doubleValue]) / aspect), [logo[3] doubleValue]);
                CGFloat width = height * aspect;
                if(width > [logo[2] doubleValue])
                {
                    //cap
                    width = [logo[2] doubleValue];
                    height = width / aspect;
                }
                
                //save
                [sizes addObject:[NSValue valueWithSize:NSMakeSize(floor(width), floor(height))]];
                total += floor(width);
            }
            total += (row.count - 1) * 30;
            
            //place
            y -= rowH;
            x = floor((NSWidth(panel.frame) - total)/2);
            for(NSUInteger i = 0; i < row.count; i++)
            {
                //logo
                NSArray* logo = row[i];
                NSSize size = [sizes[i] sizeValue];
                NSImageView* logoView = nil;
                
                //template (monochrome)
                NSImage* image = [[NSImage imageNamed:logo[0]] copy];
                image.template = YES;
                
                //add
                logoView = [NSImageView imageViewWithImage:image];
                logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
                logoView.contentTintColor = [NSColor.labelColor colorWithAlphaComponent:0.7];
                logoView.toolTip = [logo[0] stringByReplacingOccurrencesOfString:@"Friends" withString:@""];
                logoView.frame = NSMakeRect(x, y + floor((rowH - size.height)/2) + [logo[4] doubleValue], size.width, size.height);
                [panel addSubview:logoView];
                
                //next
                x += size.width + 30;
            }
            
            //gap
            y -= rowGap;
        }
    }
    
    return self;
}

//layout
-(void)layout
{
    //super
    [super layout];
    
    //panel color
    self.panel.layer.backgroundColor = panelColor();
    
    return;
}

//(re)layout when appearance changes
-(void)viewDidChangeEffectiveAppearance
{
    //super
    [super viewDidChangeEffectiveAppearance];
    
    //update
    [self setNeedsLayout:YES];
}

@end
