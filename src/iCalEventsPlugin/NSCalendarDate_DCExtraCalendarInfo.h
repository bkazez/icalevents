/*
  NSCalendarDate_DCExtraCalendarInfo.h
  iCalEventsPlugin

  Created by Dan Charney on 5/24/07.
  Copyright 2007 drmoose.net. All rights reserved.
*/

#ifndef DRMOOSE_DOT_NET__NSCalendarDate_h
#define DRMOOSE_DOT_NET__NSCalendarDate_h

#include <Cocoa/Cocoa.h>

@interface NSCalendarDate(DCExtraCalendarInfo)

- (int)daysInMonth;
- (int)daysTillEndOfMonth;

- (int)daysInYear;
- (int)daysTillEndOfYear;

@end
#endif
