//
//  IEPCalendarStore.m
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//  Copyright 2007 Ben Kazez. All rights reserved.
//

#import "IEPCalendarStore.h"
#import "IEPCalendarStoreLeopard.h"
#import "IEPCalendarStoreTiger.h"


#define BKAbstractMethod() NSLog(@"[%@ %@]: Abstract method called", NSStringFromClass([self class]), NSStringFromSelector(_cmd))

static IEPCalendarStore *_calendarStore = nil;

@implementation IEPCalendarStore

+ (IEPCalendarStore *)calendarStore {
	if (!_calendarStore) {
		NSBundle *calendarStoreBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/CalendarStore.framework"];
		if (calendarStoreBundle) {
			[calendarStoreBundle load];
			_calendarStore = [[IEPCalendarStoreLeopard alloc] init];
		} else {
			_calendarStore = [[IEPCalendarStoreTiger alloc] init];
		}
	}
	
	return _calendarStore;
}

- (void)dealloc;
{
	[_birthdaysCalendarName release];
	[_birthdayEventName release];
	[super dealloc];
}

- (BOOL)loadCalendars {
	BKAbstractMethod();
	return NO;
}

- (BOOL)loadCalendarEventsFromCalendarsWithKeys:(NSArray *)calendarKeys lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound {
	BKAbstractMethod();
	return NO;
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarAtIndex:(int)i {
	BKAbstractMethod();
	return nil;
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarWithKey:(NSString *)key {
	BKAbstractMethod();
	return nil;
}

- (id)eventValueForProperty:(NSString *)propertyName ofEventAtIndex:(int)i {
	BKAbstractMethod();
	return nil;
}

- (int)numCalendars {
	BKAbstractMethod();
	return 0;
}

- (int)numEvents {
	BKAbstractMethod();
	return 0;
}

- (NSArray *)defaultSelectedCalendars {
	BKAbstractMethod();
	return nil;
}

- (NSTimeZone *)displayedTimeZone {
	BKAbstractMethod();
	return nil;
}

- (void)widgetDidFinishDisplayingEvents {
	BKAbstractMethod();
}

- (NSString *)birthdaysCalendarName {
    return [[_birthdaysCalendarName retain] autorelease];
}

- (void)setBirthdaysCalendarName:(NSString *)value {
    if (_birthdaysCalendarName != value) {
        [_birthdaysCalendarName release];
        _birthdaysCalendarName = [value copy];
    }
}

- (NSString *)birthdayEventName {
    return [[_birthdayEventName retain] autorelease];
}

- (void)setBirthdayEventName:(NSString *)value {
    if (_birthdayEventName != value) {
        [_birthdayEventName release];
        _birthdayEventName = [value copy];
    }
}

@end
