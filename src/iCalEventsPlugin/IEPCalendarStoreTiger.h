//
//  IEPCalendarStoreTiger.h
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//

#import <Cocoa/Cocoa.h>
#import "IEPCalendarStore.h"


typedef enum _DCICalendarFrequency {
	DCYearly,
	DCMonthly,
	DCWeekly,
	DCDaily
} DCICalendarFrequency;

extern NSCharacterSet *EmptyCharacterSet;

@interface IEPCalendarStoreTiger : IEPCalendarStore {
	NSString *_iCalSupportDirectory;
	NSDictionary *_iCalPreferences;
	
	NSMutableArray *_calendars;
	NSMutableArray *_currentCalendarEvents;
}


- (NSArray *)defaultSelectedCalendars;

/* iCal Preferences */
- (NSDictionary *)iCalPreferences;
- (void)loadICalPreferences;
- (BOOL)iCalTimeZoneSupportEnabled;
- (NSString *)iCalTimeZoneName;
- (BOOL)iCalShowsBirthdaysCalendar;

// Expansion of RRULEs; doesn't return recurrences at event start dates unless it is included in the natural recurrence set
- (NSDictionary *)recurOptionsFromString:(NSString *)str;
- (NSMutableArray *)expandRruleInEvent:(NSDictionary *)unexpandedEvent lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound;

// Returns calendar events (including repeating events) between two given dates from the given calendar. NOTE: does not empty _currentCalendarEvents
- (NSMutableArray *)loadCalendarsFromNodes:(NSArray *)nodes;
- (int)indexOfCalendarHavingKey:(NSString *)key;

// Unescapes escapedString as per RFC
- (NSString *)unescapeString:(NSString *)escapedString;
// Parses date/time. Sample format: TZID=US/Central:20050429T060000
- (NSCalendarDate *)dateWithICalendarString:(NSString *)str isAllDay:(BOOL *)allDay; // sets allDay to YES iff it's all 
- (void)scanUntilNextEventUsingScanner:(NSScanner *)scanner;
//- (NSMutableDictionary *)removeRecurrencePropertiesFromDictionary:(NSDictionary *)event;
- (NSDictionary *)parseWeekDay:(NSString *)byWeekDayOptionValue; // "-2SU" => {number = -2, weekDay = SU}; "2SU" => 2; "SU" => 0
- (BOOL)removeRecurringEventsFrom:(NSMutableArray **)processedEvents withRecurrenceIDEvents:(NSArray *)recurrenceIDEvents; // Remove the corresponding recurrence event for each detached event by finding events with a RECURRENCE-ID property
- (BOOL)showEventWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound;
- (NSDateComponents *)dateComponentsFromICalendarDuration:(NSString *)durationStr;
- (NSTimeZone *)displayedTimeZone;
- (BOOL)shouldAddEventHavingStartDate:(NSCalendarDate *)theStartDate key:(NSString *)theKey toEvents:(NSArray *)theEvents;

- (NSArray *)calendars;

@end
