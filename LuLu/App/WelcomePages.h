//
//  file: WelcomePages.h
//  project: lulu (main app)
//  description: first-run pages: welcome, permissions, configure, support (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Cocoa;

/* PAGE */

//a page
// header (icon, title, message), content, and a (LuLu green) footer with the 'next' button
// ...all pages share one size, so the window never resizes between them
@interface WelcomePage : NSView

/* PROPERTIES */

//'next' button (footer, right)
@property(nonatomic, strong, readonly)NSButton* nextButton;

/* METHODS */

//init
// wordmark & title are optional
-(instancetype)initWithIcon:(NSImage*)icon iconSize:(CGFloat)iconSize wordmark:(NSImage*)wordmark title:(NSString*)title message:(NSString*)message;

//add 'next' button to footer
-(NSButton*)addNextButton:(NSString*)title tag:(NSInteger)tag target:(id)target action:(SEL)action;

@end

/* ROWS */

//a row: badge (symbol), title, detail, optional message, and optional accessory (right)
@interface CardRow : NSView

/* PROPERTIES */

//accessory (right aligned, vertically centered)
@property(nonatomic, strong)NSView* accessory;

//draw (rounded) card background
@property(nonatomic)BOOL showsBackground;

/* METHODS */

//init
-(instancetype)initWithSymbol:(NSString*)symbol color:(NSColor*)color title:(NSString*)title detail:(NSString*)detail width:(CGFloat)width;

//set message (orange/red), shown below detail
-(void)setMessage:(NSString*)message color:(NSColor*)color;

//height (for current contents)
-(CGFloat)requiredHeight;

@end

//state of a permission
typedef NS_ENUM(NSInteger, PermissionState) {
    PermissionStatePending,     //not started
    PermissionStateChecking,    //being requested / checked
    PermissionStateWaiting,     //needs the user (see message)
    PermissionStateGranted,     //granted
    PermissionStateFailed       //gave up (see message); user can retry
};

//a permission row
// card row w/ status (and 'Open System Settings…' button, when the user is needed)
@interface PermissionRow : CardRow

/* PROPERTIES */

//state
@property(nonatomic, readonly)PermissionState state;

/* METHODS */

//init
// settings URL is optional (no button w/o one)
-(instancetype)initWithSymbol:(NSString*)symbol title:(NSString*)title detail:(NSString*)detail settingsURL:(NSString*)settingsURL;

//set state
// message is shown for 'waiting'/'failed'
-(void)setState:(PermissionState)state message:(NSString*)message;

@end

/* PAGES */

//welcome (splash)
@interface WelcomeSplashPage : WelcomePage
-(instancetype)init;
@end

//permissions
// system extension approval & content filter
@interface PermissionsPage : WelcomePage

/* PROPERTIES */

//rows
@property(nonatomic, strong, readonly)PermissionRow* extensionRow;
@property(nonatomic, strong, readonly)PermissionRow* filterRow;

/* METHODS */

//init
-(instancetype)init;

//update 'next' button per the rows' states
// 'Next' once both granted, 'Retry' after a failure, disabled otherwise
-(void)updateNextButton;

@end

//configure
// initial (rule) preferences
@interface ConfigurePage : WelcomePage

/* PROPERTIES */

//switches
@property(nonatomic, strong, readonly)NSSwitch* allowApple;
@property(nonatomic, strong, readonly)NSSwitch* allowInstalled;
@property(nonatomic, strong, readonly)NSSwitch* allowDNS;

/* METHODS */

//init
-(instancetype)init;

@end

//support
// sponsor ask + friends of objective-see
@interface SupportPage : WelcomePage

/* PROPERTIES */

//'support us' button
@property(nonatomic, strong, readonly)NSButton* supportButton;

/* METHODS */

//init
// 'support us' button invokes action on target (w/ tag)
-(instancetype)initWithSupportTag:(NSInteger)tag target:(id)target action:(SEL)action;

@end
