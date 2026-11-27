#import "Support.h"
#import "GrayList.h"
#import "XPCUserClient.h"
#import "Binary.h"
#import "Profiles.h"
#import "utilities.h"
#import <bsm/libbsm.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <objc/runtime.h>

os_log_t logHandle;
Preferences* preferences;
Alerts* alerts;
Rules* rules;
FilterDataProvider* provider;
BlockOrAllowList* allowList;
BlockOrAllowList* blockList;
NSMutableDictionary<NSData*, Process*>* testProcesses;
BOOL testProcessLookupFails;
BOOL testProcessesAlive;
BOOL testAllowListMatches;
NSUInteger testProcessLookups;
NSUInteger testPreferencesLoads;
NSUInteger testRulesChangedCalls;
NSString* testCurrentProfilePath;
NSMutableArray* testProfileSetPaths;
Profiles* profiles;

@implementation AcceptanceFlow
@synthesize sourceAppAuditToken, remoteEndpoint, remoteHostname, URL;
@synthesize socketProtocol, socketFamily, direction;
@end

@implementation AcceptanceProvider
@end

// Capture the framework resume side effect after production FilterDataProvider policy runs.
static void captureFrameworkResume(id instance, SEL selector, NEFilterFlow* flow, NEFilterVerdict* verdict)
{
    AcceptanceProvider* instanceProvider = instance;
    instanceProvider.resumedVerdicts[[NSValue valueWithNonretainedObject:flow]] = (NEFilterNewFlowVerdict*)verdict;
}
AcceptanceProvider* acceptanceProvider(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method method = class_getInstanceMethod(NEFilterDataProvider.class, @selector(resumeFlow:withVerdict:));
        method_setImplementation(method, (IMP)captureFrameworkResume);
    });
    // Framework initialization requires an extension context; only instance state is supplied.
    AcceptanceProvider* instance = (AcceptanceProvider*)class_createInstance(AcceptanceProvider.class, 0);
    instance.cache = [[NSCache alloc] init];
    instance.grayList = [[GrayList alloc] init];
    instance.relatedFlows = [NSMutableDictionary dictionary];
    instance.resumedVerdicts = [NSMutableDictionary dictionary];
    return instance;
}

// Persistence is a collaborator side effect, isolated from the live rules file.
@interface AcceptanceRules : Rules
@end
@implementation AcceptanceRules
-(BOOL)save { return YES; }
@end

@implementation Process
-(id)init:(audit_token_t*)token
{
    ++testProcessLookups;
    if(testProcessLookupFails) return nil;
    return testProcesses[[NSData dataWithBytes:token length:sizeof(*token)]];
}
@end
@implementation Binary
@end
@implementation Preferences
-(NSString*)getCurrentProfile { return testCurrentProfilePath; }
-(void)setCurrentProfile:(NSString*)path { testCurrentProfilePath = [path copy]; }
-(BOOL)load { ++testPreferencesLoads; return YES; }
@end
@implementation Profiles
-(NSString*)resolve:(NSString*)name { return nil; }
-(void)set:(NSString*)path
{
    [testProfileSetPaths addObject:path ?: NSNull.null];
    [preferences setCurrentProfile:path];
}
@end
@implementation XPCUserClient
-(BOOL)isConnected { return NO; }
-(void)rulesChanged { ++testRulesChangedCalls; }
@end
@implementation GrayList
-(BOOL)isGrayListed:(Process*)process { return NO; }
@end
@implementation BlockOrAllowList
-(BOOL)isMatch:(NEFilterSocketFlow*)flow { return self == allowList && testAllowListMatches; }
@end
@implementation Alerts
-(BOOL)isRelated:(Process*)process { return NO; }
-(void)removeShown:(NSString*)key {}
-(NSMutableDictionary*)create:(NEFilterSocketFlow*)flow process:(Process*)process { return [NSMutableDictionary dictionary]; }
-(BOOL)deliver:(NSDictionary*)alert reply:(void (^)(NSDictionary*))reply { return NO; }
@end

// Only these live process/session lookups are isolated; utilities.m supplies matching.
BOOL isAlive(pid_t pid) { return testProcessesAlive; }
NSString* getConsoleUser(void) { return @"acceptance-user"; }

void resetCollaborators(void)
{
    logHandle = os_log_create("com.objective-see.lulu.acceptance", "policy");
    testProcesses = [NSMutableDictionary dictionary];
    testProcessLookupFails = NO;
    testProcessesAlive = YES;
    testAllowListMatches = NO;
    testProcessLookups = 0;
    testPreferencesLoads = 0;
    testRulesChangedCalls = 0;
    testCurrentProfilePath = nil;
    testProfileSetPaths = [NSMutableArray array];
    profiles = [[Profiles alloc] init];
    preferences = [[Preferences alloc] init];
    preferences.preferences = [@{PREF_ALLOW_LOCALHOST:@YES, PREF_ALLOW_DNS:@YES,
        PREF_PASSIVE_MODE:@YES, PREF_PASSIVE_MODE_ACTION:@PREF_PASSIVE_MODE_ALLOW,
        PREF_PASSIVE_MODE_RULES:@PREF_PASSIVE_MODE_RULES_NO,
        PREF_USE_ALLOW_LIST:@YES, PREF_ALLOW_LIST:@"isolated-test-list"} mutableCopy];
    alerts = [[Alerts alloc] init];
    alerts.consoleUser = @"acceptance-user";
    alerts.xpcUserClient = [[XPCUserClient alloc] init];
    allowList = [[BlockOrAllowList alloc] init];
    blockList = [[BlockOrAllowList alloc] init];
    rules = [[AcceptanceRules alloc] init];
}

NSData* acceptanceToken(pid_t pid, uint32_t version)
{
    audit_token_t token = {0};
    token.val[5] = (uint32_t)pid;
    token.val[7] = version;
    return [NSData dataWithBytes:&token length:sizeof(token)];
}
Process* acceptanceProcess(NSData* token, NSString* path, NSDictionary* signing)
{
    Process* process = [[Process alloc] init];
    process.auditToken = token;
    process.pid = audit_token_to_pid(*(audit_token_t*)token.bytes);
    process.path = path;
    process.name = path.lastPathComponent;
    process.csInfo = [signing mutableCopy];
    process.key = path;
    process.ancestors = [NSMutableArray array];
    process.binary = [[Binary alloc] init];
    process.binary.path = path;
    process.binary.name = process.name;
    testProcesses[token] = process;
    return process;
}
AcceptanceFlow* acceptanceFlow(NSData* token, NSString* address, NSString* port, int protocol)
{
    AcceptanceFlow* flow = (AcceptanceFlow*)class_createInstance(AcceptanceFlow.class, 0);
    flow.sourceAppAuditToken = token;
    flow.remoteEndpoint = [NWHostEndpoint endpointWithHostname:address port:port];
    flow.socketProtocol = protocol;
    flow.socketFamily = [address containsString:@":"] ? AF_INET6 : AF_INET;
    flow.direction = NETrafficDirectionOutbound;
    return flow;
}
