/*
  iCalEventsPlugin.h
  iCal Events

  Created by Ben Kazez in May 2005.
  Copyright 2007 Dan Charney. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "IEPCommon.h"

/***** Constants representing iCalendar format keys *****/
#define RECURRENCE_RULE @"RRULE"
#define START_DATE @"DTSTART"

@interface iCalEventsPlugin : NSObject {
	IEPCalendarStore *_calendarStore;
	
	NSDateFormatter *dateFormatter;
	NSDateFormatter *timeFormatter;
}

- (BOOL)loadCalendars;

// Returns calendar events (including repeating events) between two given dates from the given calendars (IEPArraySeparator-separated). NOTE: empties _currentCalendarEvents
- (BOOL)loadCalendarEventsFromCalendarsWithKeys:(NSString *)calendarKeys lowerDateBound:(double)lowerDateBoundMilliseconds upperDateBound:(double)upperDateBoundMilliseconds;

- (NSString *)serializeArray:(NSArray *)array; // joins elements by some character
- (NSArray *)unserializeString:(NSString *)string; // separates elements by some character

- (id)eventValueForProperty:(NSString *)propertyName ofEventAtIndex:(int)i; // in current calendar
- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarAtIndex:(int)i;
- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarWithKey:(NSString *)key;
- (NSString *)defaultSelectedCalendars; // returns calendars in where Selection = 1
- (int)numCalendars;
- (int)numEvents; // in current calendar
- (NSString *)arraySerializerSeparator;
- (void)widgetDidFinishDisplayingEvents; // kind of an accessor

- (NSString *)formattedRelativeDateWithMilliseconds:(double)milliseconds;
- (NSString *)formattedDateWithMilliseconds:(double)milliseconds;
- (NSString *)formattedTimeWithMilliseconds:(double)milliseconds;
- (NSCalendarDate *)calendarDateFromJsMilliseconds:(double)milliseconds;

- (NSString *)birthdaysCalendarName;
- (void)setBirthdaysCalendarName:(NSString *)value;

- (NSString *)birthdayEventName;
- (void)setBirthdayEventName:(NSString *)value;

@end
