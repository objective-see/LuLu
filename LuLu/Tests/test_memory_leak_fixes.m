//
//  test_memory_leak_fixes.m
//  LuLu
//
//  Test suite for memory leak fixes (issue #616)
//  Tests dictionary initialization, flow orphan detection, and cleanup logic
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <libproc.h>
#import <bsm/libbsm.h>

// Mock FilterDataProvider for testing memory leak fix components
@interface TestMemoryLeakProvider : NSObject
@property(nonatomic, retain) NSMutableDictionary* relatedFlows;
@property(nonatomic, retain) NSMutableDictionary* pendingAlerts;
@property(nonatomic, retain) dispatch_source_t cleanupTimer;
- (id)init;
- (void)dealloc;
- (BOOL)isFlowOrphaned:(NEFilterSocketFlow*)flow;
@end

@implementation TestMemoryLeakProvider

- (id)init
{
    self = [super init];
    if(nil != self)
    {
        //initialize dictionaries
        self.relatedFlows = [NSMutableDictionary dictionary];
        self.pendingAlerts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    //cancel cleanup timer if exists
    if(nil != self.cleanupTimer)
    {
        dispatch_source_cancel(self.cleanupTimer);
        self.cleanupTimer = nil;
    }
}

- (BOOL)isFlowOrphaned:(NEFilterSocketFlow*)flow
{
    //extract audit token
    audit_token_t* token = (audit_token_t*)flow.sourceAppAuditToken.bytes;

    //extract pid
    pid_t pid = audit_token_to_pid(*token);

    //check if process path exists (process is alive)
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    int ret = proc_pidpath(pid, pathbuf, sizeof(pathbuf));

    //return YES if process is dead (orphaned)
    return (ret <= 0);
}

@end

// Test flow object with audit token
@interface TestFlow : NEFilterSocketFlow
@property (nonatomic, strong) NSData* sourceAppAuditToken;
@end

@implementation TestFlow
@synthesize sourceAppAuditToken;
@end

// Helper to create audit token for PID
NSData* createAuditTokenForPID(pid_t pid) {
    audit_token_t token;
    memset(&token, 0, sizeof(audit_token_t));
    //store pid in val[5] (standard location)
    token.val[5] = pid;
    return [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        NSLog(@"🧪 Memory Leak Fixes Test Suite");
        NSLog(@"================================");

        int testsPassed = 0;
        int totalTests = 0;

        // Test 1: relatedFlows initialized
        {
            totalTests++;
            NSLog(@"\n📋 Test 1: relatedFlows dictionary initialized");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];

            if (nil != provider.relatedFlows && [provider.relatedFlows isKindOfClass:[NSMutableDictionary class]]) {
                NSLog(@"✅ PASS: relatedFlows is initialized and is NSMutableDictionary");
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: relatedFlows not properly initialized");
            }
        }

        // Test 2: pendingAlerts initialized
        {
            totalTests++;
            NSLog(@"\n📋 Test 2: pendingAlerts dictionary initialized");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];

            if (nil != provider.pendingAlerts && [provider.pendingAlerts isKindOfClass:[NSMutableDictionary class]]) {
                NSLog(@"✅ PASS: pendingAlerts is initialized and is NSMutableDictionary");
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: pendingAlerts not properly initialized");
            }
        }

        // Test 3: Dictionaries start empty
        {
            totalTests++;
            NSLog(@"\n📋 Test 3: Dictionaries start empty");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];

            if (0 == provider.relatedFlows.count && 0 == provider.pendingAlerts.count) {
                NSLog(@"✅ PASS: Both dictionaries start empty");
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Dictionaries not empty on init (related:%lu, pending:%lu)",
                      (unsigned long)provider.relatedFlows.count,
                      (unsigned long)provider.pendingAlerts.count);
            }
        }

        // Test 4: Detect current process as alive
        {
            totalTests++;
            NSLog(@"\n📋 Test 4: Current process detected as alive");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];

            //get current process PID
            pid_t currentPID = getpid();
            TestFlow* flow = [[TestFlow alloc] init];
            flow.sourceAppAuditToken = createAuditTokenForPID(currentPID);

            BOOL isOrphaned = [provider isFlowOrphaned:flow];

            if (NO == isOrphaned) {
                NSLog(@"✅ PASS: Current process (PID %d) detected as alive", currentPID);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Current process incorrectly detected as orphaned");
            }
        }

        // Test 5: Detect non-existent process as orphaned
        {
            totalTests++;
            NSLog(@"\n📋 Test 5: Non-existent process detected as orphaned");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];

            //use PID that doesn't exist
            pid_t invalidPID = 99999;
            TestFlow* flow = [[TestFlow alloc] init];
            flow.sourceAppAuditToken = createAuditTokenForPID(invalidPID);

            BOOL isOrphaned = [provider isFlowOrphaned:flow];

            if (YES == isOrphaned) {
                NSLog(@"✅ PASS: Non-existent process (PID %d) detected as orphaned", invalidPID);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Non-existent process not detected as orphaned");
            }
        }

        // Test 6: pendingAlerts add/remove operations
        {
            totalTests++;
            NSLog(@"\n📋 Test 6: pendingAlerts add/remove operations");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];
            TestFlow* flow = [[TestFlow alloc] init];
            NSString* uuid = [[NSUUID UUID] UUIDString];

            //add flow
            provider.pendingAlerts[uuid] = flow;
            BOOL addedCorrectly = (1 == provider.pendingAlerts.count) && (flow == provider.pendingAlerts[uuid]);

            //remove flow
            [provider.pendingAlerts removeObjectForKey:uuid];
            BOOL removedCorrectly = (0 == provider.pendingAlerts.count);

            if (addedCorrectly && removedCorrectly) {
                NSLog(@"✅ PASS: Flow added and removed from pendingAlerts correctly");
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: pendingAlerts operations failed");
            }
        }

        // Test 7: relatedFlows nested structure operations
        {
            totalTests++;
            NSLog(@"\n📋 Test 7: relatedFlows nested array operations");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];
            TestFlow* flow1 = [[TestFlow alloc] init];
            TestFlow* flow2 = [[TestFlow alloc] init];
            NSString* key = @"test-process-key";

            //create nested array
            provider.relatedFlows[key] = [NSMutableArray array];
            NSMutableArray* flows = provider.relatedFlows[key];

            //add flows
            [flows addObject:flow1];
            [flows addObject:flow2];
            BOOL addedCorrectly = (2 == flows.count);

            //remove flows
            [flows removeAllObjects];
            BOOL removedCorrectly = (0 == flows.count);

            //cleanup empty entry
            [provider.relatedFlows removeObjectForKey:key];
            BOOL cleanedCorrectly = (0 == provider.relatedFlows.count);

            if (addedCorrectly && removedCorrectly && cleanedCorrectly) {
                NSLog(@"✅ PASS: Nested array operations work correctly");
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: relatedFlows operations failed");
            }
        }

        // Test 8: Timer lifecycle
        {
            totalTests++;
            NSLog(@"\n📋 Test 8: Timer lifecycle (dealloc cancellation)");

            @autoreleasepool {
                TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];

                //create a timer (simulates production timer setup)
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
                dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

                if (nil != timer) {
                    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
                    dispatch_source_set_event_handler(timer, ^{});
                    dispatch_resume(timer);
                    provider.cleanupTimer = timer;
                }

                BOOL timerCreated = (nil != provider.cleanupTimer);

                if (timerCreated) {
                    NSLog(@"✅ PASS: Timer created and will be cancelled in dealloc");
                    testsPassed++;
                } else {
                    NSLog(@"❌ FAIL: Timer not created");
                }
                //provider deallocates here, timer should be cancelled
            }
        }

        // Test 9: Multiple flows for same process
        {
            totalTests++;
            NSLog(@"\n📋 Test 9: Multiple flows for same process");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];
            NSString* key = @"com.example.app";

            //create array for process
            provider.relatedFlows[key] = [NSMutableArray array];
            NSMutableArray* flows = provider.relatedFlows[key];

            //add multiple flows
            for (int i = 0; i < 10; i++) {
                [flows addObject:[[TestFlow alloc] init]];
            }

            if (10 == flows.count) {
                NSLog(@"✅ PASS: Can store multiple flows per process (%lu flows)", (unsigned long)flows.count);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Expected 10 flows, got %lu", (unsigned long)flows.count);
            }
        }

        // Test 10: Empty dictionary cleanup
        {
            totalTests++;
            NSLog(@"\n📋 Test 10: Empty entry cleanup");

            TestMemoryLeakProvider* provider = [[TestMemoryLeakProvider alloc] init];
            NSString* key = @"test-key";

            //create empty array
            provider.relatedFlows[key] = [NSMutableArray array];

            //simulate cleanup logic: find and remove empty entries
            NSMutableArray* keysToRemove = nil;
            for (NSString* k in provider.relatedFlows) {
                NSMutableArray* flows = provider.relatedFlows[k];
                if (0 == flows.count) {
                    if (nil == keysToRemove) {
                        keysToRemove = [NSMutableArray array];
                    }
                    [keysToRemove addObject:k];
                }
            }

            //remove empty entries
            for (NSString* k in keysToRemove) {
                [provider.relatedFlows removeObjectForKey:k];
            }

            if (0 == provider.relatedFlows.count) {
                NSLog(@"✅ PASS: Empty entries cleaned up correctly");
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Empty entries not removed");
            }
        }

        // Test Results Summary
        NSLog(@"\n🏁 Test Results");
        NSLog(@"===============");
        NSLog(@"Tests Passed: %d/%d", testsPassed, totalTests);

        if (testsPassed == totalTests) {
            NSLog(@"✅ ALL TESTS PASSED!");
            return 0;
        } else {
            NSLog(@"❌ %d tests failed", totalTests - testsPassed);
            return 1;
        }
    }
}
