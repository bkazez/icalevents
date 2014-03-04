/*
 *  HelperFunctions.h
 *  iCalEventsPlugin
 *
 *  Created by drmoose on 5/23/07.
 *  Copyright 2007 drmoose.net. All rights reserved.
 *
 */

#ifndef DRMOOSE_DOT_NET__HelperFunctions_h
#define DRMOOSE_DOT_NET__HelperFunctions_h

#include <Cocoa/Cocoa.h>

#pragma mark Some crash-shafe parsing routines
int DCAtoI(char const * pointer);

	
#pragma mark -
#pragma mark NSObject comparison shorthand

BOOL DCGreater(id a, id b);
BOOL DCGreaterEqual(id a, id b);
BOOL DCLess(id a, id b);
BOOL DCLessEqual(id a, id b);

id DCMin(id a, id b);
id DCMax(id a, id b);

#endif
