//
//  file: main.m
//  project: lulu (config app)
//  description: main interface, for config (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

/* FUNCTION DECLARATIONS */

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action);

//determine if launched by macOS (on (re)login)
BOOL autoLaunched(void);

#endif /* main_h */
