//
//  test_no_client_fallback.m
//  LuLu
//
//  Exercises the production no-client helper without installing the system
//  extension or touching the machine's active firewall configuration.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <os/log.h>
#import <stdatomic.h>

#import "Alerts.h"
#import "BlockOrAllowList.h"
#import "FilterDataProvider.h"
#import "Preferences.h"
#import "Profiles.h"
#import "Rules.h"
#import "XPCListener.h"

//Globals normally owned by the extension's main translation unit.
Rules* rules = nil;
FilterDataProvider* provider = nil;
Alerts* alerts = nil;
BlockOrAllowList* allowList = nil;
BlockOrAllowList* blockList = nil;
XPCListener* xpcListener = nil;
Preferences* preferences = nil;
Profiles* profiles = nil;
dispatch_source_t dispatchSource = nil;
os_log_t logHandle = nil;

@interface TestRules : Rules
{
    atomic_uint _addCount;
}

-(NSUInteger)addCount;

@end

@implementation TestRules

-(BOOL)add:(Rule*)rule save:(BOOL)save
{
    atomic_fetch_add(&_addCount, 1);
    return YES;
}

-(NSUInteger)addCount
{
    return atomic_load(&_addCount);
}

@end


int main(void)
{
    @autoreleasepool
    {
        logHandle = os_log_create("com.objective-see.lulu.tests", "no-client");

        TestRules* testRules = [[TestRules alloc] init];
        rules = testRules;

        //The helper has no instance dependencies, so avoid initializing the
        //provider's timer and other extension runtime state in this unit test.
        FilterDataProvider* testProvider = [FilterDataProvider alloc];
        SEL selector = NSSelectorFromString(@"allowNoClient");
        if(YES != [testProvider respondsToSelector:selector])
        {
            NSLog(@"FAIL: production no-client helper is unavailable");
            return 1;
        }

        typedef NSInteger (*NoClientFunction)(id, SEL);
        NSInteger verdict = ((NoClientFunction)objc_msgSend)(testProvider, selector);
        if(0 != verdict)
        {
            NSLog(@"FAIL: expected allow verdict (0), got %ld", (long)verdict);
            return 1;
        }

        if(0 != testRules.addCount)
        {
            NSLog(@"FAIL: no-client fallback created %lu rule(s)", (unsigned long)testRules.addCount);
            return 1;
        }

        //Exercise repeated, concurrent fallbacks to catch accidental shared rule
        //creation or a stateful verdict in the helper.
        __block atomic_int unexpectedVerdicts = 0;
        dispatch_apply(64, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t iteration) {
            if(0 != ((NoClientFunction)objc_msgSend)(testProvider, selector))
            {
                atomic_fetch_add(&unexpectedVerdicts, 1);
            }
        });

        if(0 != atomic_load(&unexpectedVerdicts))
        {
            NSLog(@"FAIL: %d concurrent fallback(s) did not allow", atomic_load(&unexpectedVerdicts));
            return 1;
        }

        if(0 != testRules.addCount)
        {
            NSLog(@"FAIL: concurrent fallbacks created %lu rule(s)", (unsigned long)testRules.addCount);
            return 1;
        }

        NSLog(@"Tests Passed: 5/5");
        NSLog(@"PASS: repeated production no-client fallbacks allowed without adding rules");
    }

    return 0;
}
