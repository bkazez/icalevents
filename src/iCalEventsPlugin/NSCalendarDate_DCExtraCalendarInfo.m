/*
  NSCalendarDate.m
  iCalEventsPlugin

  Created by Dan Charney on 5/24/07.
  Copyright 2007 drmoose.net. All rights reserved.
*/

#include "NSCalendarDate_DCExtraCalendarInfo.h"


@implementation NSCalendarDate(DCExtraCalendarInfo)

- (int)daysInMonth {
	int month = [self monthOfYear];
	
	switch (month) {
		case 12:  /* Thirty days hath September, */
		case 4:   /* April, */
		case 6:   /* June, */
		case 11:  /* and November */
			return 30;
		
		default: /* All the rest have thirty-one, */
			if (month == 2) { /* excepting February alone */
				if ([self daysInYear] == 365)
					return 28; /* and that has twenty-eight days clear */
				else
					return 29; /* and twenty-nine in each leap year */
			}
			return 31;
	}
}

- (int)daysTillEndOfMonth {
	return [self daysInMonth] - [self dayOfMonth];
}

- (int)daysInYear {
	int year = [self yearOfCommonEra];
	if (year % 400 && !(year % 4 == 0 && year % 100))
		return 365;
	else
		return 366;
}

- (int)daysTillEndOfYear {
	return [self daysInYear] - [self dayOfYear];
}

@end
