//
//  IEPCalendarStoreLeopard.h
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//

#import <Cocoa/Cocoa.h>
#import "IEPCalendarStore.h"


@class CalCalendar;

@interface IEPCalendarStoreLeopard : IEPCalendarStore {
	id _calendarStore;
	NSArray *_calendars;
	NSArray *_events;
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendar:(CalCalendar *)calendar;

@end
