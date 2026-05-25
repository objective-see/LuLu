//
//  RulesMenuController.h
//  LuLu
//
//  Created by Patrick Wardle on 1/30/24.
//  Copyright © 2024 Objective-See. All rights reserved.
//

#ifndef RulesMenuController_h
#define RulesMenuController_h

@import Foundation;

@interface RulesMenuController : NSObject

/* METHODS */

-(void)addRule;
-(void)showRules;
-(void)exportRules;

// async: completion is called on the main queue with BOOL success (or NO on cancel/error)
-(void)importRulesWithCompletion:(void(^)(BOOL imported))completion;

// async: completion is called on the main queue with number of deleted rules
// (-1 on error, 0 if user cancelled)
-(void)cleanupRulesWithCompletion:(void(^)(NSInteger deletedRules))completion;

@end

#endif /* RulesMenuController_h */
