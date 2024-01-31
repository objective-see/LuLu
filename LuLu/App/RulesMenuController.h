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
-(BOOL)importRules;
-(BOOL)cleanupRules;

@end

#endif /* RulesMenuController_h */
