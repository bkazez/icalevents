/*
 *  HelperFunctions.c
 *  iCalEventsPlugin
 *
 *  Created by drmoose on 5/23/07.
 *  Copyright 2007 drmoose.net. All rights reserved.
 *
 */

#include "HelperFunctions.h"
#include <Cocoa/Cocoa.h>

#pragma mark Some crash-shafe parsing routines

int DCAtoI(char const * pointer) {
	if (pointer == NULL || pointer == nil)
		return 0;
	return (int)strtol(pointer, NULL, 0);
}

	
#pragma mark -
#pragma mark NSObject comparison shorthand


BOOL DCGreater(id a, id b) {
	return [a compare:b] == NSOrderedAscending;
}

BOOL DCGreaterEqual(id a, id b) {
	return [a compare:b] != NSOrderedDescending;
}

BOOL DCLess(id a, id b) {
	return [a compare:b] == NSOrderedDescending;
}

BOOL DCLessEqual(id a, id b) {
	return [a compare:b] != NSOrderedAscending;
}

id DCMin(id a, id b) {
	return DCLess(a, b) ? a : b;
}

id DCMax(id a, id b) {
	return DCLess(a, b) ? b : a;
}

