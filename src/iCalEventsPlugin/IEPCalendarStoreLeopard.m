//
//  IEPCalendarStoreLeopard.m
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//  Copyright 2007 Ben Kazez. All rights reserved.
//

#import "IEPCalendarStoreLeopard.h"
#import "IEPCalendarStore.h"

#pragma mark -
#pragma mark Tiger Support

// I hope Apple never changes this....
NSString *CalCalendarTypeBirthday = @"Birthday";

@class CalCalendar;
@interface CalCalendarStore

+ (CalCalendarStore *)defaultCalendarStore;
- (NSArray *)calendars;
- (CalCalendar *)calendarWithUID:(NSString *)UID;
+ (NSPredicate *)eventPredicateWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate calendars:(NSArray *)calendars;
- (NSArray *)eventsWithPredicate:(NSPredicate *)predicate;

@end


#pragma mark -
#pragma mark Leopard

static NSDictionary *_calendarInfoPropertyNameToLeopard = nil;
static NSDictionary *_icsPropertyNameToLeopard = nil;

@implementation IEPCalendarStoreLeopard

+ (void)initialize {
	_calendarInfoPropertyNameToLeopard = [[NSDictionary alloc] initWithObjectsAndKeys:
										  @"title", @"Title",
										  @"color", @"ThemeColor",
										  @"uid", @"Key",
										  nil];
	_icsPropertyNameToLeopard = [[NSDictionary alloc] initWithObjectsAndKeys:
								 @"startDate", @"DTSTART",
								 @"endDate", @"DTEND",
								 @"allDay", @"X-IEP-ALL-DAY-EVENT",
								 @"uid", @"UID",
								 @"calendar.uid", @"X-IEP-CALENDAR-KEY",
								 @"location", @"LOCATION",
								 @"title", @"SUMMARY",
								 @"notes", @"DESCRIPTION",
								 nil];
}
								 
- (id)init {
	if ((self = [super init])) {
		_calendarStore = [(NSObject *)[NSClassFromString(@"CalCalendarStore") defaultCalendarStore] retain];
	}
	return self;
}

- (void)dealloc {
	[_calendarStore release];
	[_calendars release];
	[super dealloc];
}

- (BOOL)loadCalendars {
	[_calendars release];
	_calendars = [[_calendarStore calendars] retain];
	return _calendars != nil;
}

- (BOOL)loadCalendarEventsFromCalendarsWithKeys:(NSArray *)calendarKeys lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound {
	// Only load from calendars that exist.
	NSMutableSet *existingKeys = [NSMutableSet setWithArray:calendarKeys];
	[self loadCalendars];
	[existingKeys intersectSet:[NSSet setWithArray:[_calendars valueForKey:@"uid"]]];
	
	NSArray *existingKeysArray = [existingKeys allObjects];
	
	// Get calendars that correspond to the requested UIDs.
	NSMutableArray *calendars = [NSMutableArray array];
	unsigned i, c = [existingKeysArray count];
	for (i = 0; i < c; i++) {
		[calendars addObject:[_calendarStore calendarWithUID:[existingKeysArray objectAtIndex:i]]];
	}
	
	NSPredicate *eventPredicate = [NSClassFromString(@"CalCalendarStore") eventPredicateWithStartDate:lowerDateBound endDate:upperDateBound calendars:calendars];

	[_events release];
	_events = [[_calendarStore eventsWithPredicate:eventPredicate] retain];
	
	return (_events != nil);
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarAtIndex:(int)i {
	return [self calendarValueForProperty:propertyName ofCalendar:[_calendars objectAtIndex:i]];
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarWithKey:(NSString *)key {
	return [self calendarValueForProperty:propertyName ofCalendar:[_calendarStore calendarWithUID:key]];
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendar:(CalCalendar *)calendar {
	NSString *leopardPropertyName = [_calendarInfoPropertyNameToLeopard objectForKey:propertyName];
	id value = [calendar valueForKeyPath:leopardPropertyName];
	
	// Convert calendar dates to milliseconds, to preserve time zone.
	if ([value isKindOfClass:[NSDate class]]) {
		value = [NSNumber numberWithDouble:[(NSDate *)value timeIntervalSince1970] * 1000.0];
	}

	if ([[calendar type] isEqualToString:CalCalendarTypeBirthday] && [leopardPropertyName isEqualToString:@"title"] && [value isEqualToString:@"Birthdays"]) {
		// We can localize more Birthdays calendar names than iCal can.
		value = [self birthdaysCalendarName];
	}

	return value;
}

- (id)eventValueForProperty:(NSString *)propertyName ofEventAtIndex:(int)i {
	NSString *leopardPropertyName = [_icsPropertyNameToLeopard objectForKey:propertyName];
	id value = [[_events objectAtIndex:i] valueForKeyPath:leopardPropertyName];

	// Convert calendar dates to milliseconds, to preserve time zone.
	if ([value isKindOfClass:[NSDate class]]) {
		value = [NSNumber numberWithDouble:[(NSDate *)value timeIntervalSince1970] * 1000.0];
	}
	
	if ([leopardPropertyName isEqualToString:@"allDay"]) {
		value = [value boolValue] ? @"TRUE" : @"FALSE";
	}
	
	return value;
}

- (int)numCalendars {
	return _calendars ? [_calendars count] : 0;
}

- (int)numEvents {
	return _events ? [_events count] : 0;
}

- (NSArray *)defaultSelectedCalendars {
	// Select all calendars by default, since we can't do any better.
	return [_calendars valueForKey:@"uid"];
}

- (NSTimeZone *)displayedTimeZone {
	return [NSTimeZone systemTimeZone];
}

- (void)widgetDidFinishDisplayingEvents {
	[_events release];
	_events = nil;
}

@end
