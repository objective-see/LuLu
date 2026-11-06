#import <Cocoa/Cocoa.h>
#import <OSLog/OSLog.h>
#import <netinet/in.h>

#import "consts.h"
#import "Rule.h"
#import "RulesWindowController.h"
#import "PrefsWindowController.h"
#import "AlertWindowController.h"
#import "Update.h"
#import "3rd-party/OrderedDictionary.h"

os_log_t logHandle;
XPCDaemonClient* xpcDaemonClient;
NSMutableDictionary* alerts;

static NSUInteger failures = 0;
static NSMutableDictionary* fakePreferences;
static NSMutableDictionary* lastPreferenceUpdate;
static NSUInteger getPreferencesCalls = 0;
static NSUInteger updatePreferencesCalls = 0;
static NSUInteger getProfilesCalls = 0;
static NSUInteger unexpectedXPCCalls = 0;

#define CHECK(condition, format, ...) do { \
    if(!(condition)) { \
        failures++; \
        fprintf(stderr, "FAIL: %s\n", [[NSString stringWithFormat:(format), ##__VA_ARGS__] UTF8String]); \
    } \
} while(0)

@interface RulesWindowController (TestAccess)
-(OrderedDictionary*)filter;
-(IBAction)rulesViewSelectorHandler:(id)sender;
-(IBAction)filterBoxHandler:(id)sender;
@end

@interface RulesTable : NSOutlineView
@end
@implementation RulesTable
@end

@interface TestAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic) NSUInteger preferencesChangedCalls;
@property(nonatomic) NSUInteger activationPolicyCalls;
@property(nonatomic, copy) NSDictionary* lastPreferences;
@end

@implementation TestAppDelegate
-(void)preferencesChanged:(NSDictionary*)preferences
{
    self.preferencesChangedCalls++;
    self.lastPreferences = preferences;
}
-(void)setActivationPolicy { self.activationPolicyCalls++; }
-(void)profilesChanged {}
-(void)showRules:(id)sender { (void)sender; }
@end

static void UnexpectedXPC(NSString* selector)
{
    unexpectedXPCCalls++;
    fprintf(stderr, "FAIL: unexpected fake XPC call: %s\n", selector.UTF8String);
}

@implementation XPCDaemonClient
-(NSDictionary*)getPreferences
{
    getPreferencesCalls++;
    return [fakePreferences copy];
}
-(NSDictionary*)updatePreferences:(NSDictionary*)preferences
{
    updatePreferencesCalls++;
    lastPreferenceUpdate = [preferences mutableCopy];
    [fakePreferences addEntriesFromDictionary:preferences];
    return [fakePreferences copy];
}
-(NSString*)getCurrentProfile { return nil; }
-(NSMutableArray*)getProfiles
{
    getProfilesCalls++;
    return [NSMutableArray arrayWithObject:@"Work"];
}
-(BOOL)waitForDaemon:(NSUInteger)maxAttempts { (void)maxAttempts; UnexpectedXPC(@"waitForDaemon:"); return NO; }
-(NSDictionary*)getRules { UnexpectedXPC(@"getRules"); return @{}; }
-(void)addRule:(NSDictionary*)info { (void)info; UnexpectedXPC(@"addRule:"); }
-(void)toggleRule:(NSString*)key rule:(NSString*)uuid state:(NSNumber*)state { (void)key; (void)uuid; (void)state; UnexpectedXPC(@"toggleRule:rule:state:"); }
-(void)deleteRule:(NSString*)key rule:(NSString*)uuid { (void)key; (void)uuid; UnexpectedXPC(@"deleteRule:rule:"); }
-(BOOL)importRules:(NSData*)newRules userOnly:(BOOL)userOnly { (void)newRules; (void)userOnly; UnexpectedXPC(@"importRules:userOnly:"); return NO; }
-(NSInteger)cleanupRules:(BOOL)full { (void)full; UnexpectedXPC(@"cleanupRules:"); return 0; }
-(BOOL)setProfile:(NSString*)name { (void)name; UnexpectedXPC(@"setProfile:"); return NO; }
-(BOOL)addProfile:(NSString*)name preferences:(NSDictionary*)preferences { (void)name; (void)preferences; UnexpectedXPC(@"addProfile:preferences:"); return NO; }
-(BOOL)deleteProfile:(NSString*)name { (void)name; UnexpectedXPC(@"deleteProfile:"); return NO; }
-(BOOL)uninstall { UnexpectedXPC(@"uninstall"); return NO; }
@end

@implementation AddRuleWindowController
@end
@implementation ItemPathsWindowController
@end
@implementation UpdateWindowController
-(void)configure:(NSString*)label { (void)label; }
@end
@implementation Update
-(void)checkForUpdate:(void (^)(NSUInteger, NSString*))completionHandler { (void)completionHandler; }
@end

@interface VirusTotalViewController : NSViewController
@property(weak) IBOutlet NSTextField* message;
@property(weak) IBOutlet NSProgressIndicator* vtSpinner;
@end
@implementation VirusTotalViewController
@end

NSString* getAppVersion(void) { return @"test"; }
NSString* getBundleExecutable(NSString* appPath) { return appPath; }
NSString* getProcessName(pid_t pid, NSString* path) { (void)pid; return path.lastPathComponent; }
NSImage* getIconForProcess(NSString* path) { (void)path; return [[NSImage alloc] initWithSize:NSMakeSize(16, 16)]; }
void makeModal(NSWindowController* windowController) { (void)windowController; }
BOOL applyGlass(NSWindow* window) { (void)window; return NO; }
NSMutableArray* generateProcessHierarchy(pid_t child) { (void)child; return [NSMutableArray array]; }
NSMutableString* hashFile(NSString* filePath) { (void)filePath; return nil; }
NSModalResponse showAlert(NSAlertStyle style, NSString* messageText, NSString* informativeText, NSArray* buttons)
{
    (void)style; (void)messageText; (void)informativeText; (void)buttons;
    failures++;
    fprintf(stderr, "FAIL: unexpected alert\n");
    return NSAlertFirstButtonReturn;
}
BOOL isAddressRange(NSString* spec) { (void)spec; return NO; }
BOOL parseAddressRange(NSString* spec, int* family, uint8_t* lo, uint8_t* hi, int* length)
{
    (void)spec; (void)family; (void)lo; (void)hi; (void)length;
    return NO;
}
BOOL addressInRange(NSString* address, int family, const uint8_t* lo, const uint8_t* hi, int length)
{
    (void)address; (void)family; (void)lo; (void)hi; (void)length;
    return NO;
}
NSString* regexFromGlob(NSString* glob) { return [NSRegularExpression escapedPatternForString:glob]; }
NSString* toEscapedJSON(NSString* input)
{
    if(nil == input) return nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:@[input] options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [json substringWithRange:NSMakeRange(1, json.length - 2)];
}

static NSArray<NSView*>* Descendants(NSView* root)
{
    NSMutableArray<NSView*>* result = [NSMutableArray array];
    for(NSView* child in root.subviews)
    {
        [result addObject:child];
        [result addObjectsFromArray:Descendants(child)];
    }
    return result;
}

static BOOL UsesMenlo(NSView* view)
{
    NSFont* font = nil;
    if([view isKindOfClass:[NSTextField class]]) font = ((NSTextField*)view).font;
    else if([view isKindOfClass:[NSButton class]]) font = ((NSButton*)view).font;
    else if([view isKindOfClass:[NSPopUpButton class]]) font = ((NSPopUpButton*)view).font;
    return [font.fontName containsString:@"Menlo"];
}

static id AccessibilityObject(NSControl* control)
{
    return NSAccessibilityUnignoredDescendant(control);
}

static NSString* AccessibilityLabel(NSControl* control)
{
    id object = AccessibilityObject(control);
    return [object accessibilityLabel];
}

static NSToolbarItem* ToolbarItemWithTag(NSToolbar* toolbar, NSInteger tag)
{
    for(NSToolbarItem* item in toolbar.items)
    {
        if(item.tag == tag) return item;
    }
    return nil;
}

static Rule* MakeRule(NSString* name, NSString* path, NSInteger type, NSInteger action)
{
    Rule* rule = [[Rule alloc] init];
    rule.uuid = NSUUID.UUID.UUIDString;
    rule.key = path;
    rule.name = name;
    rule.path = path;
    rule.type = @(type);
    rule.action = @(action);
    rule.scope = @(ACTION_SCOPE_ENDPOINT);
    rule.endpointAddr = [name.lowercaseString stringByAppendingString:@".example"];
    rule.endpointPort = @"443";
    rule.creation = [NSDate date];
    rule.isDisabled = @NO;
    return rule;
}

static void TestPreferencesController(TestAppDelegate* appDelegate, NSString* language)
{
    NSUInteger initialPreferencesCalls = getPreferencesCalls;
    PrefsWindowController* controller = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    CHECK(nil != controller.window, @"Preferences NIB did not load");
    CHECK(getPreferencesCalls == initialPreferencesCalls + 1, @"awakeFromNib did not load preferences exactly once");
    CHECK([controller.window.title length] > 0, @"Preferences window title is empty");

    NSArray<NSView*>* panes = @[controller.rulesView, controller.modesView, controller.listsView,
                                controller.profilesView, controller.updateView];
    for(NSView* pane in panes)
    {
        CHECK(nil != pane, @"A preference pane outlet is missing");
        for(NSView* view in Descendants(pane))
        {
            CHECK(NO == UsesMenlo(view), @"Menlo font remained in pane %@ on %@", pane, view);
        }
    }

    for(NSInteger tag = 1; tag <= 12; tag++)
    {
        NSButton* button = (NSButton*)[controller.window.contentView viewWithTag:tag];
        if(nil == button)
        {
            for(NSView* pane in panes)
            {
                button = (NSButton*)[pane viewWithTag:tag];
                if(nil != button) break;
            }
        }
        CHECK([button isKindOfClass:[NSButton class]], @"Preference toggle %ld is missing", (long)tag);
        CHECK(button.title.length == 0, @"Preference toggle %ld is no longer icon-only", (long)tag);
        id accessibilityObject = AccessibilityObject(button);
        CHECK([accessibilityObject isKindOfClass:[NSButtonCell class]], @"Preference toggle %ld does not expose its button cell", (long)tag);
        CHECK(AccessibilityLabel(button).length > 0, @"Preference toggle %ld has no accessibility label before switching panes", (long)tag);
        CHECK([button.toolTip isEqualToString:AccessibilityLabel(button)], @"Preference toggle %ld tooltip does not match its label", (long)tag);
    }

    NSDictionary* expectedAppleLabels = @{
        @"en": @"Allow Apple Programs",
        @"zh-Hant": @"允許 Apple 程式",
        @"ur": @"ایپل پروگراموں کو اجازت دیں"
    };
    NSButton* appleButton = (NSButton*)[controller.rulesView viewWithTag:1];
    CHECK([AccessibilityLabel(appleButton) isEqualToString:expectedAppleLabels[language]],
          @"localized preference label mismatch for %@: %@", language, AccessibilityLabel(appleButton));

    for(NSInteger tag = 0; tag <= 4; tag++)
    {
        NSToolbarItem* item = ToolbarItemWithTag(controller.toolbar, tag);
        CHECK(nil != item, @"toolbar item %ld is missing", (long)tag);
        [controller toolbarButtonHandler:item];
        NSView* expectedView = panes[(NSUInteger)tag];
        CHECK(expectedView.superview == controller.window.contentView, @"toolbar item %ld did not install its pane", (long)tag);
    }
    CHECK(getProfilesCalls == 1, @"Profiles pane did not load profiles exactly once");
    CHECK(controller.profiles.count == 2, @"Profiles pane count mismatch");
    CHECK([controller.profiles.firstObject isEqualToString:@"Default"], @"Profiles pane did not prepend Default");

    [controller toolbarButtonHandler:ToolbarItemWithTag(controller.toolbar, TOOLBAR_RULES)];
    controller.toolbar.selectedItemIdentifier = TOOLBAR_RULES_ID;
    appleButton = (NSButton*)[controller.rulesView viewWithTag:1];
    appleButton.state = NSControlStateValueOn;
    [controller togglePreference:appleButton];
    CHECK(updatePreferencesCalls > 0, @"togglePreference did not save through XPC boundary");
    CHECK([lastPreferenceUpdate[PREF_ALLOW_APPLE] boolValue], @"togglePreference saved the wrong preference");
    CHECK(appDelegate.preferencesChangedCalls > 0, @"togglePreference did not notify the app delegate");

    fakePreferences[PREF_ALLOW_APPLE] = @NO;
    NSUInteger beforeReload = getPreferencesCalls;
    [controller reload];
    appleButton = (NSButton*)[controller.rulesView viewWithTag:1];
    CHECK(getPreferencesCalls == beforeReload + 1, @"reload did not fetch preferences exactly once");
    CHECK(appleButton.state == NSControlStateValueOff, @"reload did not restore the saved toggle state");
}

static void TestRulesController(NSString* language)
{
    RulesWindowController* controller = [[RulesWindowController alloc] initWithWindowNibName:@"Rules"];
    CHECK(nil != controller.window, @"Rules NIB did not load");
    CHECK([controller.outlineView isKindOfClass:[RulesTable class]], @"Rules NIB did not instantiate its custom outline class");
    CHECK(controller.outlineView.target == controller, @"awakeFromNib did not set outline target");
    CHECK(controller.outlineView.doubleAction == @selector(doubleClickHandler:), @"awakeFromNib did not set double action");
    CHECK(controller.outlineView.rowHeight == 56.0, @"windowDidLoad row height mismatch: %.1f", controller.outlineView.rowHeight);
    CHECK(NSEqualSizes(controller.outlineView.intercellSpacing, NSMakeSize(3.0, 2.0)), @"windowDidLoad intercell spacing mismatch");
    CHECK(controller.outlineView.indentationPerLevel == 42.0, @"windowDidLoad indentation mismatch");
    CHECK(controller.filterBox.focusRingType == NSFocusRingTypeDefault, @"search field focus ring is disabled");
    CHECK([controller.filterBox.accessibilityLabel isEqualToString:controller.filterBox.placeholderString], @"search accessibility label mismatch");
    CHECK([AccessibilityObject(controller.filterBox) isKindOfClass:[NSSearchFieldCell class]], @"search field does not expose its cell as the AX object");
    CHECK([AccessibilityLabel(controller.filterBox) isEqualToString:controller.filterBox.placeholderString], @"search AX label mismatch");
    CHECK([AccessibilityObject(controller.rulesViewSelector) isKindOfClass:[NSPopUpButtonCell class]], @"rules selector does not expose its cell as the AX object");
    CHECK(AccessibilityLabel(controller.rulesViewSelector).length > 0, @"rules selector has no accessibility label");
    CHECK([AccessibilityObject(controller.addRuleButton) isKindOfClass:[NSButtonCell class]], @"add-rule control does not expose its cell as the AX object");
    CHECK([AccessibilityLabel(controller.addRuleButton) isEqualToString:controller.addRuleLabel.stringValue], @"add-rule AX label mismatch");

    NSDictionary* expectedPlaceholders = @{
        @"en": @"Filter Rules",
        @"zh-Hant": @"過濾規則",
        @"ur": @"قوانین فلٹر کریں"
    };
    CHECK([controller.filterBox.placeholderString isEqualToString:expectedPlaceholders[language]],
          @"localized search placeholder mismatch for %@: %@", language, controller.filterBox.placeholderString);
    CHECK(controller.rulesViewSelector.numberOfItems == 7, @"rules selector item count mismatch");
    BOOL hasUserRulesItem = NO;
    for(NSMenuItem* item in controller.rulesViewSelector.itemArray)
    {
        if(item.tag == RULE_TYPE_USER) hasUserRulesItem = YES;
    }
    CHECK(hasUserRulesItem, @"rules selector lost the user-rules item");

    Rule* apple = MakeRule(@"Alpha", @"/Applications/Alpha.app", RULE_TYPE_APPLE, RULE_STATE_ALLOW);
    Rule* alphaUser = MakeRule(@"Alpha Helper", @"/Applications/Alpha.app", RULE_TYPE_USER, RULE_STATE_BLOCK);
    Rule* betaUser = MakeRule(@"Beta", @"/Applications/Beta.app", RULE_TYPE_USER, RULE_STATE_ALLOW);
    NSArray* alphaRules = @[apple, alphaUser];
    NSArray* betaRules = @[betaUser];
    OrderedDictionary* allRules = [[OrderedDictionary alloc] init];
    [allRules insertObject:@{KEY_RULES:alphaRules, KEY_PATHS:@[apple.path]} forKey:apple.path atIndex:0];
    [allRules insertObject:@{KEY_RULES:betaRules, KEY_PATHS:@[betaUser.path]} forKey:betaUser.path atIndex:1];
    controller.rules = allRules;

    controller.selectedRuleView = RULE_TYPE_ALL;
    controller.filterBox.stringValue = @"";
    CHECK([controller filter] == allRules, @"all/empty filter should preserve the original ordered dictionary");

    [controller.rulesViewSelector selectItemWithTag:RULE_TYPE_USER];
    [controller rulesViewSelectorHandler:controller.rulesViewSelector];
    CHECK(controller.selectedRuleView == RULE_TYPE_USER, @"selected rule filter did not update");
    CHECK(controller.addRuleButton.enabled, @"user-rules view disabled Add Rule");
    CHECK(controller.rulesFiltered.count == 2, @"user-rules filter returned the wrong process count");
    CHECK([controller.rules[apple.path][KEY_RULES] isEqualToArray:alphaRules], @"type filter mutated source rules");

    controller.filterBox.stringValue = @"Beta";
    [controller filterBoxHandler:controller.filterBox];
    CHECK(controller.rulesFiltered.count == 1, @"search filter returned the wrong process count");
    CHECK([controller.rulesFiltered.allKeys.firstObject isEqualToString:betaUser.path], @"search filter returned the wrong process");
    CHECK([controller.rules[apple.path][KEY_RULES] isEqualToArray:alphaRules], @"search filter mutated first source item");
    CHECK([controller.rules[betaUser.path][KEY_RULES] isEqualToArray:betaRules], @"search filter mutated second source item");

    NSTableColumn* mainColumn = controller.outlineView.tableColumns[0];
    NSTableColumn* actionColumn = controller.outlineView.tableColumns[1];
    NSTableCellView* processCell = (NSTableCellView*)[controller outlineView:controller.outlineView viewForTableColumn:mainColumn item:alphaRules];
    [processCell layoutSubtreeIfNeeded];
    CHECK(processCell != nil, @"process prototype cell was not created");
    CHECK(NO == [processCell.textField.font.fontName containsString:@"Menlo"], @"process cell kept Menlo typography");
    NSTextField* processDetail = (NSTextField*)[processCell viewWithTag:101];
    CHECK(processDetail.font.pointSize == 11.0, @"process detail font mismatch");
    CGFloat detailLineHeight = [[[NSLayoutManager alloc] init] defaultLineHeightForFont:processDetail.font];
    CHECK(detailLineHeight <= NSHeight(processDetail.bounds) + 0.5,
          @"process detail font line height %.1f exceeds its %.1f-point laid-out label", detailLineHeight, NSHeight(processDetail.bounds));

    NSTableCellView* connectionCell = (NSTableCellView*)[controller outlineView:controller.outlineView viewForTableColumn:mainColumn item:betaUser];
    CHECK(connectionCell != nil, @"connection prototype cell was not created");
    id connectionTextAX = AccessibilityObject(connectionCell.textField);
    CHECK([connectionTextAX isKindOfClass:[NSTextFieldCell class]], @"connection text does not expose its text cell");
    CHECK([[connectionTextAX accessibilityValue] isEqualToString:connectionCell.textField.stringValue], @"connection text AX value mismatch");
    CHECK([connectionCell.textField.font.fontName containsString:@"Mono"], @"connection cell did not use the system monospaced font");

    NSTableCellView* ruleCell = (NSTableCellView*)[controller outlineView:controller.outlineView viewForTableColumn:actionColumn item:betaUser];
    NSButton* ruleMenu = (NSButton*)[ruleCell viewWithTag:110];
    CHECK([AccessibilityObject(ruleMenu) isKindOfClass:[NSButtonCell class]], @"rule action menu does not expose its button cell");
    CHECK([NSAccessibilityUnignoredChildren(ruleCell.accessibilityChildren) containsObject:AccessibilityObject(ruleMenu)],
          @"rule action cell hides its menu from the AX children");
    CHECK([AccessibilityLabel(ruleMenu) isEqualToString:NSLocalizedString(@"Rule", @"Rule")], @"single-rule action menu label mismatch");
    CHECK([ruleMenu.toolTip isEqualToString:AccessibilityLabel(ruleMenu)], @"rule action menu tooltip mismatch");

    NSTableCellView* groupCell = (NSTableCellView*)[controller outlineView:controller.outlineView viewForTableColumn:actionColumn item:alphaRules];
    NSButton* groupMenu = (NSButton*)[groupCell viewWithTag:110];
    CHECK(groupCell.textField.stringValue.length == 0, @"group action cell retained reused rule text");
    CHECK([AccessibilityLabel(groupMenu) isEqualToString:NSLocalizedString(@"Rules", @"Rules")], @"multi-rule group menu label mismatch");
    CHECK([groupMenu.toolTip isEqualToString:AccessibilityLabel(groupMenu)], @"group menu tooltip mismatch");

    NSTableCellView* singleGroupCell = (NSTableCellView*)[controller outlineView:controller.outlineView viewForTableColumn:actionColumn item:betaRules];
    NSButton* singleGroupMenu = (NSButton*)[singleGroupCell viewWithTag:110];
    CHECK([AccessibilityLabel(singleGroupMenu) isEqualToString:NSLocalizedString(@"Rule", @"Rule")], @"single-rule group menu label mismatch");
}

static NSDictionary* AlertFixture(NSString* uuid)
{
    return @{
        KEY_UUID:uuid,
        KEY_PROCESS_ID:@(INT_MAX),
        KEY_PROCESS_NAME:@"Network Tool",
        KEY_PROCESS_ARGS:@[@"/Applications/Network Tool.app/Contents/MacOS/Network Tool", @"--sync"],
        KEY_PATH:@"/Applications/Network Tool.app/Contents/MacOS/Network Tool",
        KEY_PROCESS_DELETED:@NO,
        KEY_PROCESS_ANCESTORS:[NSMutableArray array],
        KEY_HOST:@"203.0.113.8",
        KEY_HOST_NAME:@"service.example",
        KEY_ENDPOINT_PORT:@"443",
        KEY_PROTOCOL:@(IPPROTO_TCP)
    };
}

static NSArray<NSButton*>* AlertResponseButtons(AlertWindowController* controller)
{
    NSMutableArray<NSButton*>* buttons = [NSMutableArray array];
    for(NSView* view in Descendants(controller.window.contentView))
    {
        if([view isKindOfClass:[NSButton class]] && ((NSButton*)view).action == @selector(handleUserResponse:))
        {
            [buttons addObject:(NSButton*)view];
        }
    }
    return buttons;
}

static void TestAlertResponse(TestAppDelegate* appDelegate, NSInteger expectedAction)
{
    NSString* uuid = NSUUID.UUID.UUIDString;
    NSDictionary* fixture = AlertFixture(uuid);
    alerts[uuid] = fixture;
    __block NSDictionary* reply = nil;
    AlertWindowController* controller = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindow"];
    controller.alert = fixture;
    controller.reply = ^(NSDictionary* response) { reply = response; };
    CHECK(nil != controller.window, @"Alert NIB did not load");
    CHECK([controller.processName.stringValue isEqualToString:@"Network Tool"], @"Alert lifecycle did not populate process name");
    CHECK([controller.alertMessage.string containsString:@"service.example"], @"Alert lifecycle did not populate endpoint message");
    CHECK(controller.processName.font.pointSize == 21.0, @"Alert process name font mismatch");
    CHECK(controller.alertMessage.font.pointSize == 15.0, @"Alert message font mismatch");

    NSArray<NSButton*>* buttons = AlertResponseButtons(controller);
    CHECK(buttons.count == 2, @"Alert did not retain exactly two response buttons");
    NSButton* selectedButton = nil;
    for(NSButton* button in buttons)
    {
        CHECK(button.target == controller, @"Alert response button target changed");
        CHECK(button.font.pointSize == 14.0, @"Alert response button font mismatch");
        CHECK([button.toolTip containsString:@"Network Tool"], @"Alert response tooltip lacks process name");
        CHECK([button.toolTip containsString:@"service.example"], @"Alert response tooltip lacks endpoint");
        id accessibilityObject = AccessibilityObject(button);
        CHECK([accessibilityObject isKindOfClass:[NSButtonCell class]], @"Alert response does not expose its button cell");
        CHECK([[accessibilityObject accessibilityHelp] isEqualToString:button.toolTip], @"Alert response AX help does not match tooltip");
        if(button.tag == expectedAction) selectedButton = button;
    }

    NSUInteger previousUpdates = updatePreferencesCalls;
    NSUInteger previousActivationCalls = appDelegate.activationPolicyCalls;
    CHECK(nil != selectedButton, @"Alert response button %ld is missing", (long)expectedAction);
    [selectedButton performClick:nil];
    CHECK([reply[KEY_ACTION] integerValue] == expectedAction, @"Alert response action mismatch");
    CHECK([reply[KEY_TYPE] integerValue] == RULE_TYPE_USER, @"Alert response type mismatch");
    CHECK([reply[KEY_ENDPOINT_ADDR] isEqualToString:@"service.example"], @"Alert response endpoint mismatch");
    CHECK(updatePreferencesCalls == previousUpdates + 1, @"Alert response did not persist UI preferences");
    CHECK(nil == alerts[uuid], @"Alert response did not clear the active alert");
    CHECK(appDelegate.activationPolicyCalls == previousActivationCalls + 1, @"Alert response did not refresh activation policy");
}

static void TestAlertController(TestAppDelegate* appDelegate)
{
    TestAlertResponse(appDelegate, BUTTON_BLOCK);
    TestAlertResponse(appDelegate, BUTTON_ALLOW);
}

static void ResetFakePreferences(void)
{
    fakePreferences = [@{
        PREF_ALLOW_APPLE:@NO, PREF_ALLOW_INSTALLED:@YES, PREF_ALLOW_DNS:@YES,
        PREF_ALLOW_LOCALHOST:@YES, PREF_ALLOW_SIMULATOR:@NO,
        PREF_PASSIVE_MODE:@NO, PREF_PASSIVE_MODE_ACTION:@0, PREF_PASSIVE_MODE_RULES:@0,
        PREF_BLOCK_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_VT_MODE:@NO,
        PREF_USE_ALLOW_LIST:@NO, PREF_ALLOW_LIST:@"", PREF_USE_BLOCK_LIST:@NO,
        PREF_BLOCK_LIST:@"", PREF_NO_UPDATE_MODE:@NO,
        PREF_ALERT_SHOW_OPTIONS:@NO, PREF_ALERT_LAST_RULE_SCOPE:@(ACTION_SCOPE_PROCESS),
        PREF_ALERT_LAST_RULE_DURATION:@(RuleDurationAlways)
    } mutableCopy];
}

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {
        (void)argc; (void)argv;
        logHandle = os_log_create("com.objective-see.lulu.tests", "interface-controllers");
        ResetFakePreferences();
        xpcDaemonClient = [[XPCDaemonClient alloc] init];
        alerts = [NSMutableDictionary dictionary];
        [NSApplication sharedApplication];
        TestAppDelegate* appDelegate = [[TestAppDelegate alloc] init];
        NSApp.delegate = appDelegate;

        NSString* language = NSProcessInfo.processInfo.environment[@"TEST_LANGUAGE"] ?: @"en";
        TestPreferencesController(appDelegate, language);
        TestRulesController(language);
        TestAlertController(appDelegate);
        CHECK(unexpectedXPCCalls == 0, @"unexpected XPC calls: %lu", (unsigned long)unexpectedXPCCalls);

        if(0 != failures)
        {
            fprintf(stderr, "FAILED %lu interface controller assertions (%s)\n", (unsigned long)failures, language.UTF8String);
            return 1;
        }
        printf("PASS interface controllers (%s)\n", language.UTF8String);
    }
    return 0;
}
