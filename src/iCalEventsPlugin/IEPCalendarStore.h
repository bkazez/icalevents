//
//  IEPCalendarStore.h
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//

#import <Cocoa/Cocoa.h>
#import "IEPCommon.h"


@interface IEPCalendarStore : NSObject {
	NSString *_birthdaysCalendarName;
	NSString *_birthdayEventName;
}

+ (IEPCalendarStore *)calendarStore;

- (BOOL)loadCalendars;
- (BOOL)loadCalendarEventsFromCalendarsWithKeys:(NSArray *)calendarKeys lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound;

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarAtIndex:(int)i;
- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarWithKey:(NSString *)key;
- (id)eventValueForProperty:(NSString *)propertyName ofEventAtIndex:(int)i; // in current calendar

- (int)numCalendars;
- (int)numEvents; // in current calendar

- (NSArray *)defaultSelectedCalendars;
- (NSTimeZone *)displayedTimeZone;

- (void)widgetDidFinishDisplayingEvents;

- (NSString *)birthdaysCalendarName;
- (void)setBirthdaysCalendarName:(NSString *)value;

- (NSString *)birthdayEventName;
- (void)setBirthdayEventName:(NSString *)value;

@end
