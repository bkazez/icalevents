/*
  iCalEventsPlugin.m
  iCal Events

  Created by Ben Kazez in May 2005.
  Copyright 2007 Dan Charney. All rights reserved.
*/

#import "IEPCalendarStore.h"
#import "iCalEventsPlugin.h"
#import "NSColor_IEPAdditions.h"
#import "NSCalendarDate_DCExtraCalendarInfo.h"

static NSString *IEPArraySerializerSeparator = @"\n";

@implementation iCalEventsPlugin

// initWithWebView: called when the widget plugin is first loaded as the
// widget's web view is first initialized
- (id)initWithWebView:(WebView *)webView {
	if ((self = [super init])) {
		/*
		// spin before doing anything serious
		// this will buy us time to attach with gdb
		int spin = 1;
		while (spin == 1) {
			usleep(1000);
		}
		*/

		// Date formatter instance for the whole class to use
		dateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"" allowNaturalLanguage:NO];
		[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[dateFormatter setDateStyle:NSDateFormatterFullStyle];
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle]; // don't display the time
		[dateFormatter setLocale:[NSLocale currentLocale]];

		// Time formatter instance for the whole class to use
		timeFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"" allowNaturalLanguage:NO];
		[timeFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[timeFormatter setDateStyle:NSDateFormatterNoStyle]; // don't display the date
		[timeFormatter setTimeStyle:NSDateFormatterShortStyle];
		[dateFormatter setLocale:[NSLocale currentLocale]];
		
		_calendarStore = [[IEPCalendarStore calendarStore] retain];

		if (![_calendarStore loadCalendars]) {
			ERROR(@"Unable to load calendars.");
		}
	}
	return self;
}

- (void)dealloc {
	[_calendarStore release];
	[timeFormatter release];
	[dateFormatter release];
	[super dealloc];
}

#pragma mark -
#pragma mark WebScripting Protocol

// windowScriptObjectAvailable: gives you the object that you use to bridge between the
// Obj-C world and the JavaScript world.  Use setValue:forKey: to give
// the object the name it's refered to in the JavaScript side.
- (void)windowScriptObjectAvailable:(WebScriptObject*)wso {
	[wso setValue:self forKey:@"iCalEventsPlugin"];
}

// webScriptNameForSelector: This method lets you offer friendly names for methods that normally 
// get mangled when bridged into JavaScript.
+ (NSString *)webScriptNameForSelector:(SEL)aSel {
	NSString *retval = nil;

	if (aSel == @selector(calendars)) {
		retval = @"calendars";
	} else if (aSel == @selector(loadCalendars)) {
		retval = @"loadCalendars";
	} else if (aSel == @selector(eventValueForProperty:ofEventAtIndex:)) {
		retval = @"eventValueForProperty";
	} else if (aSel == @selector(calendarValueForProperty:ofCalendarAtIndex:)) {
		retval = @"calendarValueForProperty";
	} else if (aSel == @selector(calendarValueForProperty:ofCalendarWithKey:)) {
		retval = @"calendarValueForPropertyWithKey";
	} else if (aSel == @selector(loadCalendarEventsFromCalendarWithKey:lowerDateBound:upperDateBound:)) {
		retval = @"loadCalendarEventsFromCalendarWithKey";
	} else if (aSel == @selector(loadCalendarEventsFromCalendarsWithKeys:lowerDateBound:upperDateBound:)) {
		retval = @"loadCalendarEventsFromCalendarsWithKeys";
	} else if (aSel == @selector(numCalendars)) {
		retval = @"numCalendars";
	} else if (aSel == @selector(numEvents)) {
		retval = @"numEvents";
	} else if (aSel == @selector(setBirthdayEventName:)) {
		retval = @"setBirthdayEventName";
	} else if (aSel == @selector(birthdayEventName)) {
		retval = @"birthdayEventName";
	} else if (aSel == @selector(setBirthdaysCalendarName:)) {
		retval = @"setBirthdaysCalendarName";
	} else if (aSel == @selector(birthdaysCalendarName)) {
		retval = @"birthdaysCalendarName";
	} else if (aSel == @selector(formattedDateWithMilliseconds:)) {
		retval = @"formattedDateWithMilliseconds";
	} else if (aSel == @selector(loadICalPreferences)) {
		retval = @"loadICalPreferences";
	} else if (aSel == @selector(formattedRelativeDateWithMilliseconds:)) {
		retval = @"formattedRelativeDateWithMilliseconds";
	} else if (aSel == @selector(formattedTimeWithMilliseconds:)) {
		retval = @"formattedTimeWithMilliseconds";
	} else if (aSel == @selector(arraySerializerSeparator)) {
		retval = @"arraySerializerSeparator";
	} else if (aSel == @selector(defaultSelectedCalendars)) {
		retval = @"defaultSelectedCalendars";
	} else if (aSel == @selector(widgetDidFinishDisplayingEvents)) {
		retval = @"widgetDidFinishDisplayingEvents";
	}

	return retval;
}

// isSelectorExcludedFromWebScript: lets you filter which methods in your plugin are 
// accessible to the JavaScript side.
+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSel {	
	return NO;
}

// Allows prevention of direct key access from JavaScript.
+ (BOOL)isKeyExcludedFromWebScript:(const char *)key {
	return NO;
}

// Warning: array's (string) elements can't contain IEPArraySerializerSeparator
- (NSString *)serializeArray:(NSArray *)array {
	return [array componentsJoinedByString:IEPArraySerializerSeparator];
}

- (NSArray *)unserializeString:(NSString *)string {
	return [string componentsSeparatedByString:IEPArraySerializerSeparator];
}

- (NSString *)arraySerializerSeparator {
	return IEPArraySerializerSeparator;
}

#pragma mark -
#pragma mark IEPCalendarStore

- (int)numCalendars {
	return [_calendarStore numCalendars];
}

- (int)numEvents {
	return [_calendarStore numEvents];
}

- (void)widgetDidFinishDisplayingEvents {
	[_calendarStore widgetDidFinishDisplayingEvents];
}

- (BOOL)loadCalendars {
	return [_calendarStore loadCalendars];
}

- (BOOL)loadCalendarEventsFromCalendarsWithKeys:(NSString *)calendarKeys lowerDateBound:(double)lowerDateBoundMilliseconds upperDateBound:(double)upperDateBoundMilliseconds {
	NSArray *desiredCalendars = [calendarKeys componentsSeparatedByString:IEPArraySerializerSeparator];

	// Set time zone of date formatters so dates are displayed correctly.
	NSTimeZone *timeZone = [_calendarStore displayedTimeZone];
	[dateFormatter setTimeZone:timeZone];
	[timeFormatter setTimeZone:timeZone];
	
	NSCalendarDate *lowerDateBound = [self calendarDateFromJsMilliseconds:lowerDateBoundMilliseconds];
	NSCalendarDate *upperDateBound = [self calendarDateFromJsMilliseconds:upperDateBoundMilliseconds];

	return [_calendarStore loadCalendarEventsFromCalendarsWithKeys:desiredCalendars lowerDateBound:lowerDateBound upperDateBound:upperDateBound];
}

- (id)eventValueForProperty:(NSString *)propertyName ofEventAtIndex:(int)i {
	return [_calendarStore eventValueForProperty:propertyName ofEventAtIndex:i];
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarAtIndex:(int)i {
	id value = [_calendarStore calendarValueForProperty:propertyName ofCalendarAtIndex:i];
	if ([value isKindOfClass:[NSColor class]]) {
		// Convert to 8-digit hex (6 RGB plus alpha value).
		value = [(NSColor *)value hexEquivalent];
	}
	return (NSString *)value;
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarWithKey:(NSString *)key {
	id value = [_calendarStore calendarValueForProperty:propertyName ofCalendarWithKey:key];
	if ([value isKindOfClass:[NSColor class]]) {
		// Convert to 8-digit hex (6 RGB plus alpha value).
		value = [(NSColor *)value hexEquivalent];
	}
	return (NSString *)value;
}

- (NSString *)defaultSelectedCalendars {
	return [self serializeArray:[_calendarStore defaultSelectedCalendars]];
}

- (NSString *)birthdaysCalendarName {
    return [_calendarStore birthdaysCalendarName];
}

- (void)setBirthdaysCalendarName:(NSString *)newBirthdaysCalendarName {
    [_calendarStore setBirthdaysCalendarName:newBirthdaysCalendarName];
}

- (NSString *)birthdayEventName {
    return [_calendarStore birthdayEventName];
}

- (void)setBirthdayEventName:(NSString *)newBirthdayEventName {
	[_calendarStore setBirthdayEventName:newBirthdayEventName];
}

#pragma mark -
#pragma mark Date Formatters

- (NSString *)formattedDateWithMilliseconds:(double)milliseconds {
	NSString *ret;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(milliseconds/1000.0)];

	ret = [dateFormatter stringFromDate:date];
	return ret;
}

- (NSString *)formattedRelativeDateWithMilliseconds:(double)milliseconds {
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(milliseconds/1000.0)];
	NSCalendarDate *today = [NSCalendarDate calendarDate];

	// Set today to today at midnight
	NSDateComponents *todayComponents = [[NSDateComponents alloc] init];
	[todayComponents setYear:[today yearOfCommonEra]];
	[todayComponents setMonth:[today monthOfYear]];
	[todayComponents setDay:[today dayOfMonth]];
	[todayComponents setHour:0];
	[todayComponents setMinute:0];
	[todayComponents setSecond:0];

	today = [[[NSCalendar currentCalendar] dateFromComponents:todayComponents] dateWithCalendarFormat:nil timeZone:nil];
	
	NSCalendarDate *tomorrow = [today dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0]; // 1 day
	NSCalendarDate *dayAfterTomorrow = [tomorrow dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0]; // 1 day

	// Use relative date for today or tomorrow (JavaScript code takes care of localization)
	// date >= today && date < tomorrow
	NSString *ret;
	if ([date compare:today] != NSOrderedAscending && [date compare:tomorrow] == NSOrderedAscending) {
		ret = @"Today";
	} else if ([date compare:tomorrow] != NSOrderedAscending && [date compare:dayAfterTomorrow] == NSOrderedAscending) {
		ret = @"Tomorrow";
	} else {
		// No relative date
		ret = [dateFormatter stringFromDate:date];
	}

	[todayComponents release];
	return ret;
}

- (NSString *)formattedTimeWithMilliseconds:(double)milliseconds {
	return [timeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:(milliseconds/1000.0)]];
}

- (NSCalendarDate *)calendarDateFromJsMilliseconds:(double)milliseconds {
	// dateWithTimeIntervalSince1970 requires seconds, not milliseconds
	NSCalendarDate *date = (NSCalendarDate *)[NSCalendarDate dateWithTimeIntervalSince1970:(NSTimeInterval)(milliseconds / 1000.0)];
	return date;
}

@end
