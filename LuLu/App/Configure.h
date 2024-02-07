//
//  Configure.h
//  LuLu
//
//  Created by Patrick Wardle on 2/6/24.
//  Copyright © 2024 Objective-See. All rights reserved.
//

#ifndef Configure_h
#define Configure_h

@import Foundation;

@interface Configure : NSObject

//quit
-(void)quit;

//install
-(BOOL)install;

//upgrade
-(BOOL)upgrade;

//uninstall
-(BOOL)uninstall;

@end

#endif /* Configure_h */
