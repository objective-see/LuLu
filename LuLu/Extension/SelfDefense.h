//
//  SelfDefense.h
//  Extension
//
//  Protects LuLu (the app) from being terminated/paused by other programs,
//  via an Endpoint Security client that authorizes signals sent to it
//

@import Foundation;

#import "consts.h"

@interface SelfDefense : NSObject

//start
// no-op if already active, so can be called again (e.g. once full disk access is granted)
-(SelfDefenseStatus)start;

//stop
-(void)stop;

//current status
-(SelfDefenseStatus)status;

@end
