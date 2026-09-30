// Isolated collaborators for the production policy and provider acceptance tests.
#import "Process.h"
#import "Preferences.h"
#import "Alerts.h"
#import "Rules.h"
#import "BlockOrAllowList.h"
#import "FilterDataProvider.h"

extern NSMutableDictionary<NSData*, Process*>* testProcesses;
extern BOOL testProcessLookupFails;
extern BOOL testProcessesAlive;
extern BOOL testAllowListMatches;
extern NSUInteger testProcessLookups;
extern NSUInteger testPreferencesLoads;
extern NSUInteger testRulesChangedCalls;
extern NSString* testCurrentProfilePath;
extern NSMutableArray* testProfileSetPaths;
extern Preferences* preferences;
extern Alerts* alerts;
extern Rules* rules;

@interface AcceptanceFlow : NEFilterSocketFlow
@property(nonatomic, strong) NSData* sourceAppAuditToken;
@property(nonatomic, strong) NWEndpoint* remoteEndpoint;
@property(nonatomic, strong) NSString* remoteHostname;
@property(nonatomic, strong) NSURL* URL;
@property(nonatomic) int socketProtocol;
@property(nonatomic) int socketFamily;
@property(nonatomic) NETrafficDirection direction;
@end

@interface AcceptanceProvider : FilterDataProvider
@property(nonatomic, strong) NSMutableDictionary<NSValue*, NEFilterNewFlowVerdict*>* resumedVerdicts;
@end

AcceptanceProvider* acceptanceProvider(void);
void resetCollaborators(void);
NSData* acceptanceToken(pid_t pid, uint32_t version);
Process* acceptanceProcess(NSData* token, NSString* path, NSDictionary* signing);
AcceptanceFlow* acceptanceFlow(NSData* token, NSString* address, NSString* port, int protocol);
