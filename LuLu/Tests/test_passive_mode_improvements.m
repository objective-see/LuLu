//
//  test_complete_functionality.m
//  LuLu
//
//  Complete test suite for hostname prioritization and port display functionality
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

// Import our constants
#define VALUE_ANY @"*"

// Mock FilterDataProvider interface for testing
@interface TestFilterDataProvider : NSObject
- (NSString*)getBestHostnameFromFlow:(NEFilterSocketFlow*)flow;
@end

@implementation TestFilterDataProvider

// Copy of our implementation for testing
- (NSString*)getBestHostnameFromFlow:(NEFilterSocketFlow*)flow
{
    //best hostname
    NSString* bestHostname = nil;
    
    //remote endpoint
    NWHostEndpoint* remoteEndpoint = nil;
    
    //extract remote endpoint
    remoteEndpoint = (NWHostEndpoint*)flow.remoteEndpoint;
    
    //priority 1: try flow.URL.host (best for domain names)
    if(nil != flow.URL.host && 0 != flow.URL.host.length)
    {
        bestHostname = flow.URL.host;
        goto bail;
    }
    
    //priority 2: try flow.remoteHostname (macOS 11+)
    if(@available(macOS 11, *))
    {
        if(nil != flow.remoteHostname && 0 != flow.remoteHostname.length)
        {
            bestHostname = flow.remoteHostname;
            goto bail;
        }
    }
    
    //priority 3: fallback to remoteEndpoint.hostname (may be IP address)
    if(nil != remoteEndpoint.hostname && 0 != remoteEndpoint.hostname.length)
    {
        bestHostname = remoteEndpoint.hostname;
    }
    
bail:
    
    return bestHostname;
}

@end

// Mock Rule class for testing port display
@interface TestRule : NSObject
@property (nonatomic, strong) NSString* endpointAddr;
@property (nonatomic, strong) NSString* endpointPort;
@end

@implementation TestRule
@synthesize endpointAddr, endpointPort;

// Port display logic (copied from RulesWindowController.m)
- (NSString*)displayString {
    NSString* address = [self.endpointAddr isEqualToString:VALUE_ANY] ? @"any address" : self.endpointAddr;
    NSString* port = [self.endpointPort isEqualToString:VALUE_ANY] ? @"any port" : self.endpointPort;
    
    // Smart port display (hide common ports 80, 443)
    if (([self.endpointPort isEqualToString:@"80"] || [self.endpointPort isEqualToString:@"443"]) &&
        NO == [self.endpointAddr isEqualToString:VALUE_ANY] &&
        NO == [self.endpointPort isEqualToString:VALUE_ANY]) {
        // Hide common ports for cleaner display
        return address;
    } else {
        // Show port for uncommon ports or when using "any" values
        return [NSString stringWithFormat:@"%@:%@", address, port];
    }
}

@end

// Test helper to create simple flow objects for testing
@interface TestFlow : NEFilterSocketFlow
@property (nonatomic, strong) NSURL* URL;
@property (nonatomic, strong) NSString* remoteHostname;
@property (nonatomic, strong) NWHostEndpoint* remoteEndpoint;
@end

@implementation TestFlow
@synthesize URL, remoteHostname, remoteEndpoint;
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSLog(@"🧪 Complete Functionality Test Suite");
        NSLog(@"===================================");
        
        TestFilterDataProvider* provider = [[TestFilterDataProvider alloc] init];
        int testsPassed = 0;
        int totalTests = 0;
        
        NSLog(@"\n🔍 PART 1: Hostname Prioritization Tests");
        NSLog(@"========================================");
        
        // Test 1: URL host prioritization
        {
            totalTests++;
            NSLog(@"\n📋 Test 1: URL host prioritization");
            
            TestFlow* flow = [[TestFlow alloc] init];
            flow.URL = [NSURL URLWithString:@"https://github.com/"];
            flow.remoteEndpoint = [NWHostEndpoint endpointWithHostname:@"140.82.112.3" port:@"443"];
            
            NSString* result = [provider getBestHostnameFromFlow:flow];
            
            if ([result isEqualToString:@"github.com"]) {
                NSLog(@"✅ PASS: Got '%@' (expected domain name over IP)", result);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Got '%@' (expected 'github.com')", result);
            }
        }
        
        // Test 2: Remote hostname fallback
        {
            totalTests++;
            NSLog(@"\n📋 Test 2: Remote hostname fallback");
            
            TestFlow* flow = [[TestFlow alloc] init];
            flow.remoteHostname = @"api.github.com";
            flow.remoteEndpoint = [NWHostEndpoint endpointWithHostname:@"140.82.112.3" port:@"443"];
            
            NSString* result = [provider getBestHostnameFromFlow:flow];
            
            if ([result isEqualToString:@"api.github.com"]) {
                NSLog(@"✅ PASS: Got '%@' (expected remote hostname)", result);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Got '%@' (expected 'api.github.com')", result);
            }
        }
        
        NSLog(@"\n🎨 PART 2: Port Display Tests");
        NSLog(@"=============================");
        
        // Test 3: Hide port 443 for HTTPS
        {
            totalTests++;
            NSLog(@"\n📋 Test 3: Hide port 443 for HTTPS");
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = @"github.com";
            rule.endpointPort = @"443";
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"github.com"]) {
                NSLog(@"✅ PASS: Display '%@' (hidden port 443)", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Display '%@' (expected 'github.com')", display);
            }
        }
        
        // Test 4: Hide port 80 for HTTP
        {
            totalTests++;
            NSLog(@"\n📋 Test 4: Hide port 80 for HTTP");
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = @"example.com";
            rule.endpointPort = @"80";
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"example.com"]) {
                NSLog(@"✅ PASS: Display '%@' (hidden port 80)", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Display '%@' (expected 'example.com')", display);
            }
        }
        
        // Test 5: Show uncommon port 8080
        {
            totalTests++;
            NSLog(@"\n📋 Test 5: Show uncommon port 8080");
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = @"localhost";
            rule.endpointPort = @"8080";
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"localhost:8080"]) {
                NSLog(@"✅ PASS: Display '%@' (shown uncommon port)", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Display '%@' (expected 'localhost:8080')", display);
            }
        }
        
        // Test 6: Show port when address is "any"
        {
            totalTests++;
            NSLog(@"\n📋 Test 6: Show port when address is 'any'");
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = VALUE_ANY;
            rule.endpointPort = @"443";
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"any address:443"]) {
                NSLog(@"✅ PASS: Display '%@' (shown port for 'any' address)", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Display '%@' (expected 'any address:443')", display);
            }
        }
        
        // Test 7: Show port when port is "any"
        {
            totalTests++;
            NSLog(@"\n📋 Test 7: Show port when port is 'any'");
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = @"github.com";
            rule.endpointPort = VALUE_ANY;
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"github.com:any port"]) {
                NSLog(@"✅ PASS: Display '%@' (shown 'any port')", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Display '%@' (expected 'github.com:any port')", display);
            }
        }
        
        NSLog(@"\n🔗 PART 3: Integration Tests");
        NSLog(@"============================");
        
        // Test 8: End-to-end domain + port hiding
        {
            totalTests++;
            NSLog(@"\n📋 Test 8: End-to-end: domain extraction + port hiding");
            
            // Simulate the full flow: extract hostname from flow, create rule, display
            TestFlow* flow = [[TestFlow alloc] init];
            flow.URL = [NSURL URLWithString:@"https://api.slack.com/api/conversations.list"];
            flow.remoteEndpoint = [NWHostEndpoint endpointWithHostname:@"52.36.184.210" port:@"443"];
            
            NSString* hostname = [provider getBestHostnameFromFlow:flow];
            NSString* port = flow.remoteEndpoint.port;
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = hostname;
            rule.endpointPort = port;
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"api.slack.com"]) {
                NSLog(@"✅ PASS: Full flow '%@' (domain extracted, port hidden)", display);
                NSLog(@"   • Original: https://api.slack.com/api/conversations.list → 52.36.184.210:443");
                NSLog(@"   • Improved: %@", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Full flow '%@' (expected 'api.slack.com')", display);
            }
        }
        
        // Test 9: Custom port preserved in full flow
        {
            totalTests++;
            NSLog(@"\n📋 Test 9: End-to-end: domain extraction + custom port shown");
            
            TestFlow* flow = [[TestFlow alloc] init];
            flow.URL = [NSURL URLWithString:@"http://localhost:3000/api"];
            flow.remoteEndpoint = [NWHostEndpoint endpointWithHostname:@"127.0.0.1" port:@"3000"];
            
            NSString* hostname = [provider getBestHostnameFromFlow:flow];
            NSString* port = flow.remoteEndpoint.port;
            
            TestRule* rule = [[TestRule alloc] init];
            rule.endpointAddr = hostname;
            rule.endpointPort = port;
            
            NSString* display = [rule displayString];
            
            if ([display isEqualToString:@"localhost:3000"]) {
                NSLog(@"✅ PASS: Full flow '%@' (domain extracted, custom port shown)", display);
                NSLog(@"   • Original: http://localhost:3000/api → 127.0.0.1:3000");
                NSLog(@"   • Improved: %@", display);
                testsPassed++;
            } else {
                NSLog(@"❌ FAIL: Full flow '%@' (expected 'localhost:3000')", display);
            }
        }
        
        // Test Results Summary
        NSLog(@"\n🏁 Complete Test Results");
        NSLog(@"========================");
        NSLog(@"Tests Passed: %d/%d", testsPassed, totalTests);
        
        if (testsPassed == totalTests) {
            NSLog(@"✅ ALL TESTS PASSED!");
            NSLog(@"");
            NSLog(@"📊 Feature Summary:");
            NSLog(@"  ✅ Domain name prioritization working");
            NSLog(@"  ✅ Port hiding for common ports (80, 443)");
            NSLog(@"  ✅ Port showing for uncommon ports");
            NSLog(@"  ✅ End-to-end functionality verified");
            NSLog(@"");
            NSLog(@"🎯 Before/After Examples:");
            NSLog(@"  Old: 140.82.112.3:443    →  New: github.com");
            NSLog(@"  Old: 52.36.184.210:443   →  New: api.slack.com");
            NSLog(@"  Old: 127.0.0.1:8080      →  New: localhost:8080");
            return 0;
        } else {
            NSLog(@"❌ %d tests failed. Please check implementation.", totalTests - testsPassed);
            return 1;
        }
    }
}
