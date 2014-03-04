//
//  IEPCommon.h
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//  Copyright 2007 Ben Kazez. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//#define DEBUG

// Turns on the "Invitations" calendar from ~/Library/Caches, for Bonnie
//#define DCInvitationsCalendar 

// Macro for NSLog to separate errors from debug messages
#define ERROR NSLog

// Macro for NSLog for debug messages
#ifdef BKDEBUG
#define BKLog(...) NSLog(@"com.benkazez.widget.icalevents (plugin): " __VA_ARGS__)
#else
#define BKLog(...)
#endif

