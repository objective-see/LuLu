//
//  LinkWindowController.h
//  LuLu
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "Extension.h"
#import "WelcomePages.h"
#import "XPCDaemonClient.h"

@interface WelcomeWindowController : NSWindowController

/* PROPERTIES */

//pages
@property(nonatomic, strong)WelcomeSplashPage* welcomePage;
@property(nonatomic, strong)PermissionsPage* permissionsPage;
@property(nonatomic, strong)ConfigurePage* configurePage;
@property(nonatomic, strong)SupportPage* supportPage;

//extension
// retained, as it's the delegate of the (async) activation request
@property(nonatomic, strong)Extension* extension;

//preferences
@property (nonatomic, retain)NSDictionary* preferences;

/* METHODS */

//show a page
-(void)showPage:(WelcomePage*)page;

@end
