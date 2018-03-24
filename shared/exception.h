//
//  exception.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//
#import <signal.h>

//install exception/signal handlers
void installExceptionHandlers(void);

//exception handler for Obj-C exceptions
void exceptionHandler(NSException *exception);

//signal handler for *nix style exceptions
void signalHandler(int signal, siginfo_t *info, void *context);

//display error window
void displayErrorWindow(NSDictionary* errorInfo);
