//
//  IEPCalendarStoreTiger.m
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//

#import <AddressBook/AddressBook.h>
#import "IEPCalendarStoreTiger.h"
#import "HelperFunctions.h"


static NSCalendar *IEPSystemCalendar;

static NSCharacterSet *BKEmptyCharacterSet;
static NSCharacterSet *IEPDurationUnitsCharacterSet;

static NSString *BKWebScriptCalendarFormat = @"%B %d, %Y %H:%M:%S";
static NSString *IEPWeekDayKey = @"WeekDay";
static NSString *IEPWeekRelativeIndexKey = @"WeekRelativeIndex";
static NSString *IEPEventDurationKey = @"X-IEP-DURATION";
static NSString *IEPAllDayEventKey = @"X-IEP-ALL-DAY-EVENT";

@implementation IEPCalendarStoreTiger

- (id)init {
	if ((self = [super init])) {
		BKEmptyCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@""] retain];
		IEPDurationUnitsCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"WHMSD"] retain];
		IEPSystemCalendar = [[NSCalendar currentCalendar] retain];
		
		_iCalSupportDirectory = [[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/iCal"] retain];
		_calendars = [[NSMutableArray alloc] init];
		_currentCalendarEvents = [[NSMutableArray alloc] init];
		_birthdaysCalendarName = [[NSString alloc] initWithString:@"Birthdays"];
		_birthdayEventName = [[NSString alloc] initWithString:@"%@\\U2019s Birthday"];
		
	}
	return self;
}

- (void)dealloc {
	[_birthdaysCalendarName release];
	[_birthdayEventName release];
	[_iCalPreferences release];
	[_currentCalendarEvents release];
	[_calendars release];
	[BKEmptyCharacterSet release];
	[IEPDurationUnitsCharacterSet release];
	[super dealloc];
}

- (int)numCalendars {
	return [_calendars count];
}

- (int)numEvents {
	return [_currentCalendarEvents count];
}

- (void)widgetDidFinishDisplayingEvents {
	// Remove all events to decrease memory use.
	[_currentCalendarEvents removeAllObjects];
	
	// Remove iCal preferences so that they can change while the widget is open.
	[_iCalPreferences release];
	_iCalPreferences = nil;
}

- (BOOL)loadCalendars {
	NSString *nodesPath, *extraInfoPath;
	NSDictionary *extraCalendarInfo;
	NSMutableDictionary *calendar;
	NSArray *nodes;
	BOOL deleteMe = NO;
	NSEnumerator *calEnum;
	
	// (Birthdays calendar), and add the Title key and other keys from Info.plist to the right dictionary.
	nodesPath = [NSString stringWithFormat:@"%@/nodes.plist", _iCalSupportDirectory];
	
	// Get nodes as an array
	nodes = [[NSDictionary dictionaryWithContentsOfFile:nodesPath] objectForKey:@"List"]; // only calendar list, not other junk
	
	// Clear existing calendars and add new nodes recursively
	[_calendars release];
	_calendars = [[self loadCalendarsFromNodes:nodes] retain];
	
	// Delete any calendars that don't have Info.plist files, .ics files, or titles
	calEnum = [_calendars objectEnumerator];
	while ((calendar = [calEnum nextObject])) {
		extraInfoPath = [NSString stringWithFormat:@"%@/Sources/%@.calendar/Info.plist", _iCalSupportDirectory, [calendar objectForKey:@"Key"]];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:extraInfoPath]) {
			extraCalendarInfo = [NSDictionary dictionaryWithContentsOfFile:extraInfoPath];
			
			if (extraCalendarInfo) {
				[calendar addEntriesFromDictionary:extraCalendarInfo];
			} else {
				// No Info.plist => no title => remove from dictionary
				ERROR(@"Unable to load additional calendar information from %@", extraInfoPath);
				deleteMe = YES;
			}
		} else {
			// No Info.plist => remove from dictionary.
			// This may occur if the calendar is empty.
			deleteMe = YES;
		}
		
		// Check for birthdays calendar, if enabled.
		if ([self iCalShowsBirthdaysCalendar] && [[calendar objectForKey:@"Type"] isEqualToString:@"com.apple.ical.sources.birthdays"]) {
			[calendar setObject:[self birthdaysCalendarName] forKey:@"Title"];
		} else {
			// It must have a .ics file or else we can't add it.
			if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Sources/%@.calendar/corestorage.ics", _iCalSupportDirectory, [calendar objectForKey:@"Key"]]]) {
				deleteMe = YES;
			}
		}
		
		// Delete this calendar if no title
		if ([calendar objectForKey:@"Title"] == nil) {
			deleteMe = YES;
		}
		
		if (deleteMe)
			[_calendars removeObject:calendar];
		
		deleteMe = NO;
	}

	// Load iCal invitations (for Bonnie Wan).
#ifdef DCInvitationsCalendar
	NSString *path = [NSHomeDirectory() stringByAppendingString:@"/Library/Caches/com.apple.iCal/Inbox.calendar/corestorage.ics"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSString *tempStr = [@"file://" stringByAppendingString:path];
		[_calendars addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
							   tempStr, @"Key",
							   [[NSArray alloc] init], @"Publishers",
							   [NSNumber numberWithInt:1], @"Selection",
							   tempStr, @"SourceKey",
							   @"#555555FF", @"ThemeColor",
							   @"com.apple.ical.caches.inbox", @"Title",
							   @"com.apple.ical.sources.naivereadwrite", @"Type",
							   nil
							   ]];
	}
#endif
	
	return YES;
}	

- (NSArray *)calendarEventsHavingUID:(NSString *)uid {
	NSMutableArray *ret = [NSMutableArray array];
	NSDictionary *event;
	int i, numCalendarEvents = [_currentCalendarEvents count];
	for (i = 0; i < numCalendarEvents; ++i) {
		event = [_currentCalendarEvents objectAtIndex:i];
		if ([[event objectForKey:@"UID"] isEqualToString:uid]) {
			[ret addObject:event];
		}
	}
	return (NSArray *)ret;
}

- (int)indexOfCalendarHavingKey:(NSString *)key {
	int numCalendars = [_calendars count], i;
	for (i = 0; i < numCalendars; ++i) {
		if ([[[_calendars objectAtIndex:i] objectForKey:@"Key"] isEqualToString:key]) {
			return i;
		}
	}

	// Should be unreachable.
	return -1;
}

- (id)eventValueForProperty:(NSString *)propertyName ofEventAtIndex:(int)i {
	id value = [[_currentCalendarEvents objectAtIndex:i] objectForKey:propertyName];
	
	// Convert calendar dates to milliseconds, to preserve time zone.
	if ([value isKindOfClass:[NSDate class]])
		value = [NSNumber numberWithDouble:[(NSDate *)value timeIntervalSince1970] * 1000.0];
	
	return [[value retain] autorelease];
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarWithKey:(NSString *)key {
	if (_calendars) {
		return [[[[_calendars objectAtIndex:[self indexOfCalendarHavingKey:key]] objectForKey:propertyName] retain] autorelease];
	} else {
		ERROR(@"calendarValueForProperty:ofCalendarAtIndex: called with nil calendar list");
		return nil;
	}
}

- (NSString *)calendarValueForProperty:(NSString *)propertyName ofCalendarAtIndex:(int)i {
	if (_calendars) {
		return [[[[_calendars objectAtIndex:i] objectForKey:propertyName] retain] autorelease];
	} else {
		ERROR(@"calendarValueForProperty:ofCalendarAtIndex: called with nil calendar list");
		return nil;
	}
}

- (NSArray *)defaultSelectedCalendars {
	NSMutableArray *ret = [NSMutableArray array];
	NSNumber *selected;
	unsigned i, c = [_calendars count];
	for (i = 0; i < c; ++i) {
		selected = [[_calendars objectAtIndex:i] objectForKey:@"Selection"];
		if ([selected boolValue]) {
			[ret addObject:[[_calendars objectAtIndex:i] objectForKey:@"Key"]];
		}
	}
	return ret;
}

#pragma mark -
#pragma mark iCal Preferences

- (NSDictionary *)iCalPreferences {
	if (_iCalPreferences == nil)
		[self loadICalPreferences];
	return _iCalPreferences;
}

- (void)loadICalPreferences {
	if (_iCalPreferences != nil)
		[_iCalPreferences release];
	
	_iCalPreferences = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:[NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/com.apple.iCal.plist"]]];
	
	if (!_iCalPreferences) {
		ERROR(@"Unable to load iCal preferences.");
	}
	
	[_iCalPreferences retain];
}

- (BOOL)iCalTimeZoneSupportEnabled {
	NSDictionary *iCalPreferences = [self iCalPreferences];
	
	// If no preferences, then an error occurred. Return default value.
	if (iCalPreferences)
		return [[iCalPreferences objectForKey:@"TimeZone support enabled"] boolValue];
	else
		return NO;
}

- (NSString *)iCalTimeZoneName {
	NSDictionary *iCalPreferences = [self iCalPreferences];
	
	// If no preferences, then an error occurred. Return default value.
	if (iCalPreferences)
		return [iCalPreferences objectForKey:@"lastViewsTimeZone"];
	else
		return NO;
}

- (BOOL)iCalShowsBirthdaysCalendar {
	NSDictionary *iCalPreferences = [self iCalPreferences];
	
	// If no preferences, then an error occurred. Return default value.
	if (iCalPreferences)
		return [[iCalPreferences objectForKey:@"display birthdays calendar"] boolValue];
	else
		return NO;
}

#pragma mark -
#pragma mark Calendar Loading

- (NSMutableArray *)loadCalendarsFromNodes:(NSArray *)nodes {
	// Get calendar title from Info.plist, if it exists, or delete from array
	NSMutableDictionary *calendar;
	NSMutableArray *calendars = [nodes mutableCopy];
	unsigned i, c = [calendars count];
	for (i = 0; i < c; ++i) {
		calendar = [calendars objectAtIndex:i];
		if ([[calendar objectForKey:@"Type"] isEqualToString:@"CALSourceNode"]) {
			// Single calendar
			// We need Key to be what SourceKey is now
			[calendar setObject:[calendar objectForKey:@"SourceKey"] forKey:@"Key"];
		} else if ([[calendar objectForKey:@"Type"] isEqualToString:@"CALNamedGroupNode"]) { // calendar group; parse subnodes
			[calendars addObjectsFromArray:[self loadCalendarsFromNodes:[calendar objectForKey:@"Subnodes"]]];
		}
	}
	
	return [calendars autorelease];
}

#pragma mark -
#pragma mark iCalendar Parsing

- (void)scanUntilNextEventUsingScanner:(NSScanner *)scanner {
	NSString *sk1, *sk2, *sk3;
	// Must do these separately so that we don't accidentally skip an entire VEVENT
	if ([scanner scanString:@"BEGIN:VEVENT\r\n" intoString:&sk1]) // If we're already at a BEGIN:VEVENT line, don't skip it!
	{
		BKLog(@"sk1 = %@", sk1);
	} else {
		[scanner scanUpToString:@"BEGIN:VEVENT\r\n" intoString:&sk2]; // Skip lines until next event
		[scanner scanString:@"BEGIN:VEVENT\r\n" intoString:&sk3];
	}
}

- (NSString *)unescapeString:(NSString *)escapedString {
	NSScanner *scanner = [NSScanner scannerWithString:escapedString];
	NSMutableString *ret = [[NSMutableString alloc] init];
	NSString *skipped = nil;
	[scanner setCharactersToBeSkipped:BKEmptyCharacterSet]; // Don't skip anything
	
	while (![scanner isAtEnd]) {
		// Scan over text preceding next backslash, if there is any
		if ([scanner scanUpToString:@"\\" intoString:&skipped]) {
			// It didn't skip anything if it was the first character in the field.
			if (skipped)
				[ret appendString:skipped];
		}
		
		// If there's a backslash, skip over it and interpret the escape code
		if (![scanner isAtEnd] && [scanner scanString:@"\\" intoString:nil]) {
			// Get escape code
			if ([scanner scanString:@"n" intoString:nil] || [scanner scanString:@"N" intoString:nil])
				[ret appendString:@"\n"];
			else if ([scanner scanString:@"," intoString:nil])
				[ret appendString:@","];
			else if ([scanner scanString:@"," intoString:nil])
				[ret appendString:@","];
			else if ([scanner scanString:@";" intoString:nil])
				[ret appendString:@";"];
			else if ([scanner scanString:@"\\" intoString:nil])
				[ret appendString:@"\\"];
			else if ([scanner scanString:@"\"" intoString:nil])
				[ret appendString:@"\""];
			else {
				ERROR(@"Invalid escape sequence.");
				// The rest of the text will be added on next iteration.
				[ret appendString:@"\\"];
			}
		}
	}
	BKLog(@"processed string=%@", ret);
	return (NSString *)[ret autorelease];
}

- (NSCalendarDate *)dateWithICalendarString:(NSString *)str isAllDay:(BOOL *)allDay {
	// Parses date/time. Sample format: TZID=US/Central:20050429T060000
	unsigned year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
	NSScanner *scanner = [NSScanner scannerWithString:str];
	NSString *dateTimeStr = @"", *timeZoneStr = @"";
	unsigned strLen;
	NSCalendarDate *calendarDate;
	
	// Don't skip anything
	[scanner setCharactersToBeSkipped:BKEmptyCharacterSet];
	
	if ([scanner scanString:@"TZID=" intoString:nil] &&
		// Read timezone
		[scanner scanUpToString:@":" intoString:&timeZoneStr])
	{
		[scanner scanString:@":" intoString:nil];
	} else if ([scanner scanString:@"VALUE=" intoString:nil]) {
		[scanner scanString:@"DATE:" intoString:nil];
	}
	
	// Get data if it's OK (everything until the Z that may be at end)
	if ([scanner scanUpToString:@"Z" intoString:&dateTimeStr] &&
		// If it's got a Z at the end, it's UTC (no offset from GMT)
		[scanner scanString:@"Z" intoString:nil])
	{
		timeZoneStr = @"UTC";
	}
	
	BKLog(@"timezone=%@, dateTime=%@", timeZoneStr, dateTimeStr);
	
	strLen = [dateTimeStr length];
	
	// If string at least specifies a date
	if (strLen >= 8) {
		year = (unsigned)[[dateTimeStr substringWithRange:NSMakeRange(0,4)] intValue];
		month = (unsigned)[[dateTimeStr substringWithRange:NSMakeRange(4,2)] intValue];
		day = (unsigned)[[dateTimeStr substringWithRange:NSMakeRange(6,2)] intValue];
		// If string also specifies a time (iCal format only!)
		// TODO: Allow all date/time formats in iCalendar RFC
		if (strLen >= 15) {
			// Not an all-day event
			if (allDay)
				*allDay = NO;
			hour = (unsigned)[[dateTimeStr substringWithRange:NSMakeRange(9,2)] intValue];
			minute = (unsigned)[[dateTimeStr substringWithRange:NSMakeRange(11,2)] intValue];
			second = (unsigned)[[dateTimeStr substringWithRange:NSMakeRange(13,2)] intValue];
		} else {
			// All-day event
			if (allDay)
				*allDay = YES;
		}
	}
	
	calendarDate = [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:[NSTimeZone timeZoneWithName:timeZoneStr]];
	/*
	 if ([self iCalTimeZoneSupportEnabled])
	 [calendarDate setTimeZone:[NSTimeZone timeZoneWithName:[self iCalTimeZoneName]]];
	 else
	 [calendarDate setTimeZone:[NSTimeZone systemTimeZone]];
	 */	
	return calendarDate;
}

// used for sorting; returns NSOrderedSame if value at key context can't accept the compare method or if there is no value for the key context
int compareEvents(NSDictionary *event1, NSDictionary *event2, void *context) {
	NSComparisonResult result;
	
	//	BKLog(@"comparing");
	//	BKLog(@" event1 = %@", event1);
	//	BKLog(@" event2 = %@", event2);
	result = [(NSCalendarDate *)[event1 objectForKey:@"DTSTART"] compare:[event2 objectForKey:@"DTSTART"]];
	
	if (result == NSOrderedSame) {
		BKLog(@" DTSTART comparison: same");
		result = [(NSCalendarDate *)[event1 objectForKey:@"DTSTAMP"] compare:[event1 objectForKey:@"DTSTAMP"]];
		if (result == NSOrderedSame) {
			// All-day events should always show up first
			BOOL allDayEvent1 = [[event1 objectForKey:IEPAllDayEventKey] isEqualToString:@"TRUE"];
			BOOL allDayEvent2 = [[event2 objectForKey:IEPAllDayEventKey] isEqualToString:@"TRUE"];
			if (allDayEvent1 && allDayEvent2) {
				return NSOrderedSame;
			} else if (allDayEvent1) {
				return NSOrderedAscending;
			} else if (allDayEvent2) {
				return NSOrderedDescending;
			} else {
				return NSOrderedSame;
			}
		} else {
			// I added this else block to get rid of a "control reaches end of non-void function" warning. Since I'm not entirely certain yet how this function works, I have no way of knowing whether it was the right thing to do -- DNC
			BKLog(@"compareEvents's Line of Mystery has been called");
			return result;
		}
	} else {
		BKLog(@" DTSTART comparison: %i", result);
		return result;
	}
}

- (NSDictionary *)parseWeekDay:(NSString *)byWeekDayOptionValue {
	NSScanner *scanner = [NSScanner scannerWithString:byWeekDayOptionValue];
	NSString *numStr = nil, *weekDay = nil;
	NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
	
	// Get number.
	if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-123456789"] intoString:&numStr]) {
		[ret setObject:[NSNumber numberWithInt:atoi([numStr cString])] forKey:IEPWeekRelativeIndexKey];
	} else {
		[ret setObject:[NSNumber numberWithInt:0] forKey:IEPWeekRelativeIndexKey];
	}
	
	if ([scanner scanCharactersFromSet:[NSCharacterSet uppercaseLetterCharacterSet] intoString:&weekDay]) {
		[ret setObject:[[weekDay copy] autorelease] forKey:IEPWeekDayKey];
	} else {
		[ret setObject:@"" forKey:IEPWeekDayKey];
	}
	
	return (NSDictionary *)[ret autorelease];
}

#pragma mark -
#pragma mark Recurrence Rules

- (NSDictionary *)recurOptionsFromString:(NSString *)str {
	NSScanner *scanner = [NSScanner scannerWithString:str];
	NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
	NSString *optionName, *optionValue;
	NSMutableArray *byDayOptionsParsed;
	
	// BYxxx options get stored in an NSMutableDictionary
	[options setObject:[NSMutableDictionary dictionary] forKey:@"X-IEP-BY-OPTIONS"];
	while (![scanner isAtEnd]) {
		// Get option name
		[scanner scanUpToString:@"=" intoString:&optionName];
		[scanner scanString:@"=" intoString:nil];
		
		// Get option value
		[scanner scanUpToString:@";" intoString:&optionValue];
		[scanner scanString:@";" intoString:nil];
		
		BKLog(@"optionName = %@, optionValue = %@", optionName, optionValue);
		if ([optionName isEqualToString:@"UNTIL"]) {
			[options setObject:[self dateWithICalendarString:optionValue isAllDay:nil] forKey:optionName];
			[options setObject:[[optionValue copy] autorelease] forKey:@"X-IEP-UNTIL-ORIG"]; // Used for expanding BYxxx options
		} else if ([optionName isEqualToString:@"BYMONTH"] ||	// Note: To implement new BYxxx options, must add to this list
				   [optionName isEqualToString:@"BYMONTHDAY"]) {
			// "BYMONTHDAY=1,2,19" becomes "BYMONTHDAY : ( 1, 2, 19 )"
			[[options objectForKey:@"X-IEP-BY-OPTIONS"] setObject:[optionValue componentsSeparatedByString:@","] forKey:optionName];
		} else if ([optionName isEqualToString:@"BYDAY"]) {
			NSArray *byDayOptions = [optionValue componentsSeparatedByString:@","];
			BKLog(@"byDayOptions = %@", byDayOptions);
			byDayOptionsParsed = [[NSMutableArray alloc] init];
			
			// Parse each piece of the BYDAY option
			unsigned i, c = [byDayOptions count];
			for (i = 0; i < c; ++i) {
				[byDayOptionsParsed addObject:[self parseWeekDay:[byDayOptions objectAtIndex:i]]];
			}
			[[options objectForKey:@"X-IEP-BY-OPTIONS"] setObject:byDayOptionsParsed forKey:@"BYDAY"];
			[byDayOptionsParsed release];
		} else {
			[options setObject:optionValue forKey:optionName];
		}
	}
	
	BKLog(@"options returned = %@", options);
	return [options autorelease];
}

- (NSMutableArray *)expandRruleInEvent:(NSDictionary *)unexpandedEvent lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound {
	NSDictionary *options = nil;
	NSMutableArray *expandedEvents = [[NSMutableArray alloc] init]; // NSDictionary objects that will be returned to represent expanded event
	NSDate *startDate = [unexpandedEvent objectForKey:@"DTSTART"];
	NSDateComponents *frequency = [[NSDateComponents alloc] init];
	NSArray *daysOfWeek = [NSArray arrayWithObjects:@"SU",@"MO",@"TU",@"WE",@"TH",@"FR",@"SA", nil];
	NSTimeInterval duration = [[unexpandedEvent objectForKey:IEPEventDurationKey] doubleValue];
	NSCalendarDate *until;
	NSString *intervalStr;
	NSString *countStr;
	NSCalendarDate *currentExpandedDate;
	
	BKLog(@"expandRruleInEvent: unexpandedEvent = %@, lowerDateBound = %@, upperDateBound = %@", unexpandedEvent, lowerDateBound, upperDateBound);
	
	// No processing necessary if there is no RRULE
	if ([unexpandedEvent objectForKey:@"RRULE"] == nil) {
		if ([self showEventWithStartDate:startDate endDate:[startDate addTimeInterval:duration] lowerDateBound:lowerDateBound upperDateBound:upperDateBound])
		{
			[expandedEvents addObject:[[unexpandedEvent copy] autorelease]];
		}
	} else {
		// Otherwise, process event.
		BKLog(@"Processing RRULE in event.");
		options = [unexpandedEvent objectForKey:@"RRULE"];
		
		// If UNTIL < lowerDateBound or DTSTART > upperDateBound, we can return the empty array
		until = [options objectForKey:@"UNTIL"];
		BKLog(@"Comparing UNTIL=%@ to lowerDateBound=%@", until, lowerDateBound);
		if ((until != nil && [until compare:lowerDateBound] == NSOrderedAscending) ||
			(startDate != nil && [startDate compare:upperDateBound] == NSOrderedDescending)) {
			BKLog(@"UNTIL (%@) or DTSTART (%@) is out of bounds; returning empty array", until, startDate);
			[frequency release];
			return [NSArray array];
		}
		
		// If no INTERVAL specified, INTERVAL = 1
		intervalStr = [options objectForKey:@"INTERVAL"];
		int interval = (intervalStr == nil ? 1 : atoi([intervalStr cString]));
		
		NSString *freqStr = [options objectForKey:@"FREQ"];
		if ([freqStr isEqualToString:@"DAILY"]) {
			[frequency setDay:interval];
		} else if ([freqStr isEqualToString:@"WEEKLY"]) {
			[frequency setWeek:interval];
		} else if ([freqStr isEqualToString:@"MONTHLY"]) {
			[frequency setMonth:interval];
		} else if ([freqStr isEqualToString:@"YEARLY"]) {
			[frequency setYear:interval];
		}
		
		countStr = [options objectForKey:@"COUNT"];
		
		int maxCount = INT_MAX; // no maximum
		if (countStr != nil) {
			maxCount = atoi([countStr cString]);
			BKLog(@"Maximum number of occurrences is %i", maxCount);
		}
		
		currentExpandedDate = [[startDate copy] autorelease]; // autoreleased because it gets reassigned
		[currentExpandedDate setCalendarFormat:BKWebScriptCalendarFormat];
		NSMutableDictionary *newEvent = [unexpandedEvent mutableCopy];
		[newEvent removeObjectForKey:@"RRULE"];
		
		NSString *weekStart = [options objectForKey:@"WKST"];
		/*
		 if (weekStart != nil && ![weekStart isEqualToString:@"SU"]) {
		 BKLog(@"Failed parsing event with WKST not equal to SU; returning false");
		 return NO;
		 }
		 */
		if (weekStart == nil) {
			weekStart = @"MO"; // default value is MO according to RFC
		}
		
		NSMutableDictionary *byOptions = [options objectForKey:@"X-IEP-BY-OPTIONS"];
		
		NSCalendarDate *tmpDate = nil, *endDate = nil;
		NSEnumerator *enumerator = nil;
		
		/*************** BYxxx Options ***************/
		
		NSArray *byMonth = [byOptions objectForKey:@"BYMONTH"],
		*byMonthDay = [byOptions objectForKey:@"BYMONTHDAY"],
		*byDay = [byOptions objectForKey:@"BYDAY"];
		
		if (byMonth != nil && [byMonth count] > 0) {
			BKLog(@"By month");
			
			NSString *monthNumberStr;
			int monthNumber;
			enumerator = [[byOptions objectForKey:@"BYMONTH"] objectEnumerator];
			while ((monthNumberStr = [enumerator nextObject])) {
				BKLog(@"monthNumberStr: %@", monthNumberStr);
				
				// Check range
				monthNumber = atoi([monthNumberStr cString]);
				if (monthNumber >= 1 && monthNumber <= 12) {
					// Compute new date corresponding to the intValue
					tmpDate = [NSCalendarDate dateWithYear:[currentExpandedDate yearOfCommonEra] month:monthNumber day:[currentExpandedDate dayOfMonth] hour:[currentExpandedDate hourOfDay] minute:[currentExpandedDate minuteOfHour] second:[currentExpandedDate secondOfMinute] timeZone:[currentExpandedDate timeZone]];
					[tmpDate setCalendarFormat:BKWebScriptCalendarFormat];
				} else {
					ERROR(@"Range of month (%i) is out of bounds.", monthNumber);
				}
				
				// Set up variables in tmpEvent and call recursively, but if the new date isn't after or at the start date, make an exception so it's not added when it shouldn't be
				NSMutableDictionary *tmpEvent = [unexpandedEvent mutableCopy];
				if ([startDate compare:tmpDate] == NSOrderedAscending || [startDate compare:tmpDate] == NSOrderedSame) {
					BKLog(@"tmpDate (%@) is after or same as tmpDate (%@)", tmpDate, startDate);
				} else {
					if ([tmpEvent objectForKey:@"EXDATE"] != nil) {
						[[tmpEvent objectForKey:@"EXDATE"] addObject:tmpDate];
					} else {
						[tmpEvent setObject:[NSMutableArray arrayWithObject:tmpDate] forKey:@"EXDATE"];
					}
				}
				[[[tmpEvent objectForKey:@"RRULE"] objectForKey:@"X-IEP-BY-OPTIONS"] removeObjectForKey:@"BYMONTH"]; // don't need to expand BYMONTH again
				
				[tmpEvent setObject:[[tmpDate copy] autorelease] forKey:@"DTSTART"];
				
				[expandedEvents addObjectsFromArray:[self expandRruleInEvent:tmpEvent lowerDateBound:lowerDateBound upperDateBound:upperDateBound]];
				[tmpEvent release];
			}
		} else if (byMonthDay != nil && [byMonthDay count] > 0) {
			NSString *monthDayNumberStr;
			unsigned int monthDayNumber;
			enumerator = [byMonthDay objectEnumerator];
			while ((monthDayNumberStr = [enumerator nextObject])) {
				// Check range
				monthDayNumber = atoi([monthDayNumberStr cString]);
				NSRange validRange = [IEPSystemCalendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:currentExpandedDate];
				if (monthDayNumber >= 1 && monthDayNumber <= validRange.length) {
					// Compute new date corresponding to the intValue
					tmpDate = [NSCalendarDate dateWithYear:[currentExpandedDate yearOfCommonEra] month:[currentExpandedDate monthOfYear] day:monthDayNumber hour:[currentExpandedDate hourOfDay] minute:[currentExpandedDate minuteOfHour] second:[currentExpandedDate secondOfMinute] timeZone:[currentExpandedDate timeZone]];
					
					// Set up variables in tmpEvent and call recursively, but if the new date isn't after or at the start date, make an exception so it's not added when it shouldn't be
					NSMutableDictionary *tmpEvent = [unexpandedEvent mutableCopy];
					if ([startDate compare:tmpDate] == NSOrderedAscending || [startDate compare:tmpDate] == NSOrderedSame) {
						BKLog(@"tmpDate (%@) is after or same as startDate (%@)", tmpDate, startDate);
					} else {
						if ([tmpEvent objectForKey:@"EXDATE"] != nil) {
							[[tmpEvent objectForKey:@"EXDATE"] addObject:tmpDate];
						} else {
							[tmpEvent setObject:[NSMutableArray arrayWithObject:tmpDate] forKey:@"EXDATE"];
						}
					}
					
					BKLog(@"1");
					
					[[[tmpEvent objectForKey:@"RRULE"] objectForKey:@"X-IEP-BY-OPTIONS"] removeObjectForKey:@"BYMONTHDAY"]; // don't need to expand BYMONTHDAY again
					BKLog(@"2");
					[tmpEvent setObject:[[tmpDate copy] autorelease] forKey:@"DTSTART"];
					
					BKLog(@"tmpEvent is now: %@", tmpEvent);
					[expandedEvents addObjectsFromArray:[self expandRruleInEvent:tmpEvent lowerDateBound:lowerDateBound upperDateBound:upperDateBound]];
					BKLog(@"Done recursing.");
					[tmpEvent release];
				} else {
					ERROR(@"Month day (%i) is out of bounds", monthDayNumber);
				}
			}
			
		} else if (byDay != nil && [byDay count] > 0 // byDay contains items that aren't relative (note: tests only first item now! it's invalid if it contains both relative and non-relative items)
				   && [[[byDay objectAtIndex:0] objectForKey:IEPWeekRelativeIndexKey] intValue] == 0) {
			NSDictionary *dayOption;
			enumerator = [byDay objectEnumerator];
			while ((dayOption = [enumerator nextObject])) {
				// Step through all possible dates, day by day, looking for next occurrence of dayItem (a day of the week)
				NSDateComponents *increment = [[NSDateComponents alloc] init];
				
				tmpDate = [[currentExpandedDate copy] autorelease];

				// We must start tmpDate out at the BEGINNING of the week
				[increment setDay:-1];
				while (![weekStart isEqualToString:[daysOfWeek objectAtIndex:[tmpDate dayOfWeek]]])
				{
					tmpDate = [[IEPSystemCalendar dateByAddingComponents:increment toDate:tmpDate options:0] dateWithCalendarFormat:BKWebScriptCalendarFormat timeZone:[currentExpandedDate timeZone]];
				}
				
				[increment setDay:1];
				if ([daysOfWeek containsObject:[dayOption objectForKey:IEPWeekDayKey]]) {
					// Find the date having the desired weekday
					NSString *weekDay = [NSString stringWithString:[dayOption objectForKey:IEPWeekDayKey]];
					while (![weekDay isEqualToString:[daysOfWeek objectAtIndex:[tmpDate dayOfWeek]]]) {
						tmpDate = [[IEPSystemCalendar dateByAddingComponents:increment toDate:tmpDate options:0] dateWithCalendarFormat:BKWebScriptCalendarFormat timeZone:[currentExpandedDate timeZone]];
						BKLog(@"Trying tmpDate = %@", tmpDate);
					}
				} else { // Unknown day of the week
					tmpDate = nil;
				}
				
				BKLog(@"Found date %@", tmpDate);
				
				// Set up variables in tmpEvent and call recursively, but if the new date isn't after or at the start date, make an exception so it's not added when it shouldn't be
				NSMutableDictionary *tmpEvent = [unexpandedEvent mutableCopy];
				if ([startDate compare:tmpDate] == NSOrderedAscending || [startDate compare:tmpDate] == NSOrderedSame) {
					BKLog(@"tmpDate (%@) is after or same as tmpDate (%@)", tmpDate, startDate);
				} else {
					if ([tmpEvent objectForKey:@"EXDATE"] != nil) {
						[[tmpEvent objectForKey:@"EXDATE"] addObject:tmpDate];
					} else {
						[tmpEvent setObject:[NSMutableArray arrayWithObject:tmpDate] forKey:@"EXDATE"];
					}
				}
				[[[tmpEvent objectForKey:@"RRULE"] objectForKey:@"X-IEP-BY-OPTIONS"] removeObjectForKey:@"BYDAY"]; // don't need to expand BYDAY again
				
				// Set start date and end date
				[tmpEvent setObject:[[tmpDate copy] autorelease] forKey:@"DTSTART"];
				
				[expandedEvents addObjectsFromArray:[self expandRruleInEvent:tmpEvent lowerDateBound:lowerDateBound upperDateBound:upperDateBound]];
				[tmpEvent release];
				[increment release];
			} // done looping through BYWEEKDAY options
			
		} else {
			// Base case: No BYxxx options; expand based on DTSTART and UNTIL, INTERVAL, COUNT, and also on BYDAY if it's relative
			
			// Note: Must add to expandedEvents array before incrementing currentExpandedDate bec.
			// we must include the original unexpandedEvent so that we know if the EXDATE(s) exclude it
			
			int i = 0, oldMonth, relativeVal, monthLength;
			NSString *weekDay;
			NSDictionary *dayOption = nil;
			NSDateComponents *dayIncrement = [[NSDateComponents alloc] init], *weekIncrement = [[NSDateComponents alloc] init];
			
			do {
				++i; // i must start out at 1 and get incremented after the while () condition
				// We don't compute new currentExpandedDate yet because we have to include it as
				// the first occurrence
				
				if ([byDay count] > 0) {
					dayOption = [byDay objectAtIndex:0]; // We do the first one here and compute the rest recursively
					relativeVal = [[dayOption objectForKey:IEPWeekRelativeIndexKey] intValue];
					if (relativeVal != 0) {
						monthLength = [IEPSystemCalendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:currentExpandedDate].length;
						
						// First, we set tmpDate to the first or last day of the next month.
						currentExpandedDate = [NSCalendarDate dateWithYear:[currentExpandedDate yearOfCommonEra]
																	 month:[currentExpandedDate monthOfYear]
																	   day:(relativeVal > 0) ? 1 : monthLength
																	  hour:[currentExpandedDate hourOfDay]
																	minute:[currentExpandedDate minuteOfHour]
																	second:[currentExpandedDate secondOfMinute]
																  timeZone:[currentExpandedDate timeZone]];
						[currentExpandedDate setCalendarFormat:BKWebScriptCalendarFormat];
						
						// Then, we find the first occurrence of the day we're looking for (code duplicated from other BYDAY section)
						// If the relative index was negative, we search backwards (since we started at the end of the month)
						[dayIncrement setDay:((relativeVal < 0) ? -1 : 1)];

						weekDay = [NSString stringWithString:[dayOption objectForKey:IEPWeekDayKey]];

						while (![weekDay isEqualToString:[daysOfWeek objectAtIndex:[currentExpandedDate dayOfWeek]]]) {
							currentExpandedDate = [[IEPSystemCalendar dateByAddingComponents:dayIncrement toDate:currentExpandedDate options:0] dateWithCalendarFormat:BKWebScriptCalendarFormat timeZone:[currentExpandedDate timeZone]];
							BKLog(@"- Trying currentExpandedDate = %@", currentExpandedDate);
						}
						
						// Now that we've found the first or last occurrence of this weekday in the month, we must jump
						// to the proper one. Since dateByAddingComponents can change the month if weekIncrement is large,
						// we store the old month value and check to be sure the month hasn't changed.
						oldMonth = [currentExpandedDate monthOfYear];
						// since we've already gotten to the first occurrence, we subtract 1 from the magnitude of relativeVal
						[weekIncrement setWeek:(relativeVal < 0 ? -1 : 1) * (abs(relativeVal) - 1)];					
						currentExpandedDate = [[IEPSystemCalendar dateByAddingComponents:weekIncrement toDate:currentExpandedDate options:0] dateWithCalendarFormat:BKWebScriptCalendarFormat timeZone:[currentExpandedDate timeZone]];
						
						// If the month has changed, the BYDAY must have been invalid and thus we
						// ignore this rule. There are more efficient ways of doing this.
						if ([currentExpandedDate monthOfYear] != oldMonth)
							currentExpandedDate = nil;
						
						// Now we've found the right date (it'll get added below)
						
						// In order to add the rest of the BYDAY items if they exist, we do a recursive call with the current BYDAY item removed
						NSMutableDictionary *tmpEvent = [newEvent mutableCopy];
						NSMutableDictionary *tmpByOptions = [[tmpEvent objectForKey:@"RRULE"] objectForKey:@"X-IEP-BY-OPTIONS"];
						[[tmpByOptions objectForKey:@"BYDAY"] removeObjectAtIndex:0];
						
						// Only recurse if there's more stuff to process
						if ([tmpByOptions count] > 0) {
							[[tmpEvent objectForKey:@"RRULE"] setObject:[NSString stringWithFormat:@"%i",(maxCount-1)] forKey:@"COUNT"];
							// [tmpEvent setObject:currentExpandedDate forKey:@"DTSTART"];
							
							[expandedEvents addObjectsFromArray:[self expandRruleInEvent:tmpEvent lowerDateBound:lowerDateBound upperDateBound:upperDateBound]];
						}
						[tmpEvent release];
					}
				}
				
				// If the expanded date is past the upper bound, break out of the loop.
				if ([currentExpandedDate compare:upperDateBound] != NSOrderedAscending)
					break;
				
				// If the current date and until are in bounds, add the event
				endDate = [currentExpandedDate addTimeInterval:duration];
				if ([self showEventWithStartDate:currentExpandedDate endDate:endDate lowerDateBound:lowerDateBound upperDateBound:upperDateBound] && (!until || (until && [until compare:currentExpandedDate] == NSOrderedDescending)))
				{
					if (![[unexpandedEvent objectForKey:@"EXDATE"] containsObject:currentExpandedDate]) {
						[newEvent setObject:[[currentExpandedDate copy] autorelease] forKey:@"DTSTART"];
						[newEvent setObject:endDate forKey:@"DTEND"];
						
						[newEvent setObject:@"TRUE" forKey:@"X-IEP-RRULE-EXPANDED"];
						[expandedEvents addObject:[[newEvent copy] autorelease]]; // add event
					}
				}
				
				// Compute new date, keeping it in the same time zone as DTSTART
				currentExpandedDate = [[IEPSystemCalendar dateByAddingComponents:frequency toDate:currentExpandedDate options:0] dateWithCalendarFormat:BKWebScriptCalendarFormat timeZone:[[unexpandedEvent objectForKey:@"DTSTART"] timeZone]];
			} while (i < maxCount && // Use <, not <=, because i is incremented before the comparison
					 (!until ||
					  (until && [until compare:currentExpandedDate] == NSOrderedDescending)) // until > currentExpandedDate
					 );
			/********* end do/while loop ***********/
			[dayIncrement release];
			[weekIncrement release];
		}
		
		[newEvent release];
	} // if RRULE expansion necessary
	
	NSMutableArray *expandedEventsToBeKept = [[NSMutableArray alloc] init];
	until = [options objectForKey:@"UNTIL"];
	int count = DCAtoI((char const *)[options objectForKey:@"COUNT"]);
	if (count <= 0) count = INT_MAX;
	NSEnumerator *enumerator = [expandedEvents objectEnumerator];
	id current;
	while ((current = [enumerator nextObject])) {
		if (count < 0) break;
		if (until != nil && DCGreater([current objectForKey:@"DSTART"], until)) 
			break;
		[expandedEventsToBeKept addObject:current];		
		count--;
	}
	[expandedEvents release];
	
	BKLog(@"Returning from expandRruleInEvent: %@", expandedEventsToBeKept);
	[frequency release];
	return [expandedEventsToBeKept autorelease];
}


- (BOOL)removeRecurringEventsFrom:(NSMutableArray **)processedEvents withRecurrenceIDEvents:(NSArray *)recurrenceIDEvents {
	// Remove the corresponding recurrence event for each detached event by finding events with a RECURRENCE-ID property,
	// searching for the event with X-IEP-RRULE-EXPANDED=TRUE and having the same UID as the detached event, and deleting the
	// found event.
	NSMutableArray *ret = [*processedEvents mutableCopy];
	NSEnumerator *enumerator1;
	NSDictionary *event1;
	NSCalendarDate *recurrenceID;
	
	if (processedEvents != nil && recurrenceIDEvents != nil) {
		// Search all events to find the event whose DTSTART matches recurrenceID and X-IEP-RRULE-EXPANDED=TRUE
		// If we find it, we don't want to keep this event
		NSEnumerator *enumerator2;
		NSDictionary *event2;
		
		enumerator1 = [recurrenceIDEvents objectEnumerator];
		while ((event1 = [enumerator1 nextObject])) {
			// If this event in recurrenceIDEvents does indeed contain a recurrence ID, search for the corresponding
			// event in processedEvents
			recurrenceID = [event1 objectForKey:@"RECURRENCE-ID"]; 
			if (recurrenceID != nil) {
				enumerator2 = [*processedEvents objectEnumerator];
				while ((event2 = [enumerator2 nextObject])) {
					if ([[event2 objectForKey:@"DTSTART"] isEqualToDate:recurrenceID] &&
						[[event2 objectForKey:@"X-IEP-RRULE-EXPANDED"] isEqualToString:@"TRUE"] &&
						[[event2 objectForKey:@"UID"] isEqualToString:[event1 objectForKey:@"UID"]])
					{
						[ret removeObject:event2];
					}
				}
			}
		}
		
		// Get rid of old processed events
		[*processedEvents release];
		*processedEvents = ret;
		
		return YES;
	} else {
		ERROR(@"processedEvents or recurrenceIDEvents is nil");
		[ret release];
		return NO;
	}
}

#pragma mark -
#pragma mark General Event Loading

- (BOOL)showEventWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound {
	// If start date is in bounds
	
	if ([lowerDateBound compare:startDate] == NSOrderedAscending && [startDate compare:upperDateBound] == NSOrderedAscending) {
		return YES;
	} else if ([startDate compare:lowerDateBound] == NSOrderedAscending && [endDate compare:lowerDateBound] == NSOrderedDescending) {
		// startDate before lowerDateBound and endDate after lowerDateBound
		return YES;
	}
	
	return NO;
}

- (NSDateComponents *)dateComponentsFromICalendarDuration:(NSString *)durationStr {
	// Note: only supports one duration string (no comma-separated stuff)
	NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
	NSString *valuePartStr, *durationUnit;
	int valuePart;
	
	NSScanner *scanner = [NSScanner scannerWithString:durationStr];
	int sign = 1;
	
	// Initialize dateComponents
	[dateComponents setYear:0];
	[dateComponents setMonth:0];
	[dateComponents setDay:0];
	[dateComponents setHour:0];
	[dateComponents setMinute:0];
	[dateComponents setSecond:0];
	[dateComponents setWeek:0];
	[dateComponents setWeekday:0];
	
	// Skip over an initial + if it's there; doesn't make a difference
	[scanner scanString:@"+" intoString:nil];
	
	// Check for negative duration
	if ([scanner scanString:@"-" intoString:nil]) {
		sign = -1;
	}
	
	[scanner scanString:@"P" intoString:nil]; // not helpful
	
	while (![scanner isAtEnd]) {
		[scanner scanString:@"T" intoString:nil]; // not helpful to us
		if ([scanner scanUpToCharactersFromSet:IEPDurationUnitsCharacterSet // all possible units
									intoString:&valuePartStr]) {
			valuePart = atoi([valuePartStr cString]);
			
			if ([scanner scanCharactersFromSet:IEPDurationUnitsCharacterSet
									intoString:&durationUnit]) {
				switch ([durationUnit characterAtIndex:0]) {
					case 'W':
						[dateComponents setWeek:sign*valuePart];
						break;
					case 'H':
						[dateComponents setHour:sign*valuePart];
						break;
					case 'M':
						[dateComponents setMinute:sign*valuePart];
						break;
					case 'S':
						[dateComponents setSecond:sign*valuePart];
						break;
					case 'D':
						[dateComponents setDay:sign*valuePart];
						break;
					default:
						ERROR(@"Invalid duration part unit in \"%@\"", durationStr);
				}
			}
		}
	}
	
	return [dateComponents autorelease];
}

- (BOOL)shouldAddEventHavingStartDate:(NSCalendarDate *)theStartDate key:(NSString *)theKey toEvents:(NSArray *)theEvents {
	NSDictionary *event = nil;
	
	// If this event wasn't expanded from an RRULE, there's never a need to add an event at the start date
	if ([event objectForKey:@"X-IEP-RRULE-EXPANDED"] == nil)
		return NO;
	// TODO: Optimization: Assume theEvents are sorted, and stop looking for events
	// once the current event's start date is after theStartDate
	unsigned i, c = [theEvents count];
	for (i = 0; i < c; ++i) {
		// If the event has the same start date and UID, we've found an event at the start date
		// and thus shouldn't add it.
		if ([(NSString *)[[theEvents objectAtIndex:i] objectForKey:@"UID"] isEqualTo:theKey] &&
			[(NSCalendarDate *)[[theEvents objectAtIndex:i] objectForKey:@"DTSTART"] isEqualTo:theStartDate])
			return NO;
	}
	
	// We haven't found an event at the start date.
	return YES;
}

- (BOOL)loadCalendarEventsFromCalendarWithKey:(NSString *)calendarKey lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound {
	if (!calendarKey) {
		ERROR(@"No calendarKey specified in loadCalendarEventsFromCalendarWithKey.");
		return NO;
	}
	
	NSCharacterSet *PropertyValueSeparators = [NSCharacterSet characterSetWithCharactersInString:@":;"];
	NSString *filePath;
	NSString *fileContents;
	NSError *error;
	
	// Check that dates exist and that lowerDateBound < upperDateBound
	if (lowerDateBound && upperDateBound && [lowerDateBound compare:upperDateBound] == NSOrderedAscending) {
		if ([[self calendarValueForProperty:@"Type" ofCalendarAtIndex:[self indexOfCalendarHavingKey:calendarKey]] isEqualToString:@"com.apple.ical.sources.birthdays"]) {
			NSArray *abPeople = [[ABAddressBook sharedAddressBook] people];
			
			unsigned i, c = [abPeople count];
			for (i = 0; i < c; ++i) {
				NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
				
				ABPerson *person = [[[ABAddressBook sharedAddressBook] people] objectAtIndex:i];
				
				// Event start date. For some reason the birthday is always set to noon on that day.
				NSCalendarDate *personBirthdayNoon = [[person valueForProperty:kABBirthdayProperty] dateWithCalendarFormat:nil timeZone:[NSTimeZone systemTimeZone]];
				
				// Some people don't have birthdays.
				if (!personBirthdayNoon)
					continue;
				
				// Set the birthday to midnight instead of noon.
				NSCalendarDate *personBirthday = [NSCalendarDate dateWithYear:[personBirthdayNoon yearOfCommonEra] month:[personBirthdayNoon monthOfYear] day:[personBirthdayNoon dayOfMonth] hour:0 minute:0 second:0 timeZone:[NSTimeZone systemTimeZone]];
				
				[event setValue:personBirthday forKey:@"DTSTART"];
				
				// Event name.
				NSString *firstName = [person valueForProperty:kABFirstNameProperty];
				NSString *lastName = [person valueForProperty:kABLastNameProperty];
				
				NSString *personName = nil;
				if (firstName) {
					if (lastName)
						personName = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
					else
						personName = [NSString stringWithString:firstName];
				} else {
					if (lastName)
						personName = [NSString stringWithString:lastName];
				}
				if (!personName)
					continue;
				
				[event setValue:[NSString stringWithFormat:[self birthdayEventName], personName] forKey:@"SUMMARY"];
				
				// Event end date.
				[event setValue:[personBirthday dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0] forKey:@"DTEND"];
				
				// Duration = 1 day.
				[event setObject:[NSNumber numberWithDouble:60.0*60.0*24.0] forKey:IEPEventDurationKey];
				
				// Recurrence rule.
				[event setValue:[self recurOptionsFromString:@"FREQ=YEARLY;INTERVAL=1"] forKey:@"RRULE"];
				
				// Other attributes.
				[event setValue:@"TRUE" forKey:@"X-IEP-ALL-DAY-EVENT"];
				[event setValue:calendarKey forKey:@"X-IEP-CALENDAR-KEY"];
				
				[_currentCalendarEvents addObjectsFromArray:[self expandRruleInEvent:event lowerDateBound:lowerDateBound upperDateBound:upperDateBound]];
				[event release];
			}
		} else {
			NSMutableArray *eventsWithRecurrenceIDs = [[NSMutableArray alloc] init];
			
			/***** Get the ICS data *****/
			// First, check whether we're supposed to be getting it from the web
			if ([calendarKey hasPrefix:@"http://"] || [calendarKey hasPrefix:@"ftp://"] || [calendarKey hasPrefix:@"file://"]) {
				// Customized versions get calendars from online sources -- DNC
				filePath = calendarKey;
				fileContents = [NSString stringWithContentsOfURL:[NSURL URLWithString:filePath] encoding:NSUTF8StringEncoding error:&error];
			} else { 
				// Get path to desired corestorage.ics file
				filePath = [NSString stringWithFormat:@"%@/Sources/%@.calendar/corestorage.ics", _iCalSupportDirectory, calendarKey];

				// Load fileContents with the file as a UTF-8 string
				fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
			}
			
			
			if (!fileContents) {
				ERROR(@"Unable to load contents of file at path %@: %@", filePath, error);
				return NO;
			}
			
			/****** Parse file ********/
			
			NSScanner *scanner = [NSScanner scannerWithString:fileContents];
			[scanner setCharactersToBeSkipped:BKEmptyCharacterSet]; // Don't skip anything
			
			NSString *propertyName, *valuePart, *scannedPropertyValueSeparator;
			NSMutableString *value = [[NSMutableString alloc] init];
			
			[self scanUntilNextEventUsingScanner:scanner];
			
			// Now that we're past the header, we can begin scanning
			NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
			while (![scanner isAtEnd]) {
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				// Get next property and skip separators
				if (!([scanner scanUpToCharactersFromSet:PropertyValueSeparators intoString:&propertyName] &&
					  [scanner scanCharactersFromSet:PropertyValueSeparators intoString:&scannedPropertyValueSeparator])) {
					ERROR(@"Failed to get next property or skip property/value separators; continuing");
					// Skip until next line to try to recover from error.
					[scanner scanUpToString:@"\r\n" intoString:nil];
					[scanner scanString:@"\r\n" intoString:nil];
				} else {
					// If property (inside this event's description) is BEGIN, we don't know how to handle it (journals, alarms, etc.). Skip until corresponding END.
					NSString *skipped2;
					if ([propertyName isEqualToString:@"BEGIN"]) {
						if ([scanner scanUpToString:@"\r\nEND:" intoString:nil] &&
							// Skip initial newline
							[scanner scanString:@"\r\n" intoString:nil] &&
							// Skip till end of actual line
							[scanner scanUpToString:@"\r\n" intoString:&skipped2])
						{
							[scanner scanString:@"\r\n" intoString:nil]; // Skip final newline
							[pool release];
							continue;
						}
					}
					
					// Quick fix for CHARSET=... (unexpected attribute parameters) bug: If it's
					// DESCRIPTION, SUMMARY, or LOCATION, and the scanned separator was a ; instead
					// of a :, scan up to the colon and discard what was scanned.
					if ([scannedPropertyValueSeparator isEqualToString:@";"] &&
						([propertyName isEqualToString:@"DESCRIPTION"] ||
						 [propertyName isEqualToString:@"SUMMARY"] ||
						 [propertyName isEqualToString:@"LOCATION"])) {
						if ([scanner scanUpToString:@":" intoString:nil])
							[scanner scanString:@":" intoString:nil];
					}
					
					// Now we start building value
					[value setString:@""];
					
					// Append first line (may be the only line) of value to value
					valuePart = nil;
					[scanner scanUpToString:@"\r\n" intoString:&valuePart]; // empty values are allowed
					[scanner scanString:@"\r\n" intoString:nil]; // ignore newline
					if (valuePart == nil)
						valuePart = [NSString string];
					
					[value appendString:valuePart];
					
					// Append lines to value while the next line begins with a space or tab
					while (![scanner isAtEnd] && ([scanner scanString:@" " intoString:nil] || [scanner scanString:@"\t" intoString:nil])) {
						valuePart = nil;
						[scanner scanUpToString:@"\r\n" intoString:&valuePart]; // Scan until newline
						[scanner scanString:@"\r\n" intoString:nil]; // Skip newline
						if (valuePart != nil)
							[value appendString:valuePart];
					}
					
					// Add event to calendars array if finished
					if ([propertyName isEqualToString:@"END"] && [(NSString *)value isEqualToString:@"VEVENT"]) {
						// Add a property to show what calendar this event was in
						[event setObject:[[calendarKey copy] autorelease] forKey:@"X-IEP-CALENDAR-KEY"];
						
						NSCalendarDate *startDate = [event objectForKey:@"DTSTART"];
						
						// Parse duration, if it exists. Note: This means that DURATION overrides DTEND, if it exists.
						NSString *durationStr = [event objectForKey:@"DURATION"];
						if (durationStr != nil) {
							NSDateComponents *duration = [self dateComponentsFromICalendarDuration:durationStr];
							[event setObject:[startDate dateByAddingYears:[duration year]
																   months:[duration month]
																	 days:[duration day]
																	hours:[duration hour]
																  minutes:[duration minute]
																  seconds:[duration second]] forKey:@"DTEND"];
						}
						
						NSCalendarDate *endDate = [event objectForKey:@"DTEND"];
						
						// Format like "October 12, 1988 13:14:00" for JavaScript
						[startDate setCalendarFormat:BKWebScriptCalendarFormat];
						
						// If there's no end date, then arbitrarily set end date to the start date.
						// Note that the DURATION property is taken care of above (and the end date is set accordingly)
						if (endDate == nil) {
							endDate = [[startDate copy] autorelease]; // to match what objectForKey returns (see above)
							[event setObject:endDate forKey:@"DTEND"]; // pointer changed
						} else {
							[endDate setCalendarFormat:BKWebScriptCalendarFormat]; // just in case there's ever an option to display DTEND
						}
						
						// If there's no summary, set it to the empty string
						if ([event objectForKey:@"SUMMARY"] == nil)
							[event setObject:@"" forKey:@"SUMMARY"];
						
						// Calculate and store the event's duration, so that recurrence rule thing can calculate
						// the end date based on the start date it has calculated.
						NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
						
						[event setObject:[NSNumber numberWithDouble:duration] forKey:IEPEventDurationKey];
						
						NSString *recurrenceID = [event objectForKey:@"RECURRENCE-ID"];
						if (recurrenceID != nil)
							[eventsWithRecurrenceIDs addObject:[[event mutableCopy] autorelease]];
						
						// Don't process unless start date is before the end of lowerDateBound
						if ([upperDateBound compare:(NSCalendarDate *)[event objectForKey:@"DTSTART"]] != NSOrderedAscending) {
							NSMutableArray *expandedEvents = [self expandRruleInEvent:event lowerDateBound:lowerDateBound upperDateBound:upperDateBound];
							// Clean up event
							NSMutableDictionary *newEvent = [event mutableCopy];
							if ([newEvent objectForKey:@"RRULE"] != nil)
								[newEvent setObject:@"TRUE" forKey:@"X-IEP-RRULE-EXPANDED"];					
							newEvent = [[newEvent autorelease] mutableCopy];
							[newEvent removeObjectForKey:@"RRULE"];
							
							// Add the start date if it wasn't added by expandRruleInEvent:::'s (strictly theoretically correct) recurrence expansion
							if ([self shouldAddEventHavingStartDate:(NSCalendarDate *)[event objectForKey:@"DTSTART"]
																key:[event objectForKey:@"UID"]
														   toEvents:expandedEvents]) {
								[expandedEvents addObjectsFromArray:[self expandRruleInEvent:newEvent lowerDateBound:lowerDateBound upperDateBound:upperDateBound]]; // use recursive method to verify that it's in bounds; TODO: find a faster way
							}
							
							[_currentCalendarEvents addObjectsFromArray:expandedEvents];
							
							[newEvent release];
						}
						[event removeAllObjects];
						
						// Skip up to next event
						[self scanUntilNextEventUsingScanner:scanner];
					} else {
						// Make event dictionary
						// Properties having TEXT values: Unescape string
						if ([propertyName isEqualToString:@"DESCRIPTION"] ||
							[propertyName isEqualToString:@"SUMMARY"] ||
							[propertyName isEqualToString:@"LOCATION"])
						{
							// TEXT field
							[value setString:[self unescapeString:value]];
						}
						
						// If there's a special behavior for adding to dictionary, do it; otherwise, just add normally.
						// Separate this if from previous one!
						if ([propertyName isEqualToString:@"DTSTART"] ||  // Properties having single DATE-TIME values
							[propertyName isEqualToString:@"DTEND"] ||
							[propertyName isEqualToString:@"DTSTAMP"] ||
							[propertyName isEqualToString:@"RECURRENCE-ID"]) {
							BOOL allDay;
							
							[event setObject:[self dateWithICalendarString:value isAllDay:&allDay] forKey:propertyName];
							if ([propertyName isEqualToString:@"DTSTART"]) { // we only care about this for start date
								if (allDay) {
									[event setObject:@"TRUE" forKey:IEPAllDayEventKey];
								} else {
									[event setObject:@"FALSE" forKey:IEPAllDayEventKey];
								}
								
								// Stop scanning this event if its start date is after upperDateBound
								if ([upperDateBound compare:(NSCalendarDate *)[event objectForKey:@"DTSTART"]] == NSOrderedAscending) {
									[event removeAllObjects];
									[self scanUntilNextEventUsingScanner:scanner];
								}
							}
						} else if ([propertyName isEqualToString:@"EXDATE"]) {
							if ([event objectForKey:@"EXDATE"] == nil) {
								[event setObject:[NSMutableArray array] forKey:@"EXDATE"];
							}
							[(NSMutableArray *)[event objectForKey:@"EXDATE"] addObject:[self dateWithICalendarString:value isAllDay:nil]];
						} else if ([propertyName isEqualToString:@"RRULE"]) {
							[event setObject:[self recurOptionsFromString:value] forKey:@"RRULE"];
						} else {
							[event setObject:[[value copy] autorelease] forKey:propertyName];
						}
					}
					
					[value setString:@""]; // reset it so we can go around again
				}
				[pool release];
			}
			
			[value release];
			[event release];
			
			[self removeRecurringEventsFrom:&_currentCalendarEvents withRecurrenceIDEvents:eventsWithRecurrenceIDs];
			[eventsWithRecurrenceIDs release];
		} // if it's not the birthdays calendar
		
		[_currentCalendarEvents sortUsingFunction:compareEvents context:nil];
		return YES;
	} else {
		ERROR(@"Invalid date range specified");
		return NO;
	}
}

- (BOOL)loadCalendarEventsFromCalendarsWithKeys:(NSArray *)desiredCalendars lowerDateBound:(NSDate *)lowerDateBound upperDateBound:(NSDate *)upperDateBound {
	// Empty calendar events first, because this method is called when updating
	[_currentCalendarEvents removeAllObjects];
	
	BOOL allFailed = YES;
	
	unsigned i, c = [desiredCalendars count];
	for (i = 0; i < c; ++i) {
		if (![self loadCalendarEventsFromCalendarWithKey:[desiredCalendars objectAtIndex:i] lowerDateBound:lowerDateBound upperDateBound:upperDateBound]) {
			ERROR(@"Failed loading events from calendar key %@", [desiredCalendars objectAtIndex:i]);
		} else {
			allFailed = NO;
		}
	}
	
	// Only complain if we couldn't load any calendars.
	return !allFailed;
}

- (NSTimeZone *)displayedTimeZone {
	return ([self iCalTimeZoneSupportEnabled] ? [NSTimeZone timeZoneWithName:[self iCalTimeZoneName]] : [NSTimeZone systemTimeZone]);
}

- (NSArray *)calendars {
	return [self calendars];
}

- (NSString *)birthdaysCalendarName {
    return [[_birthdaysCalendarName retain] autorelease];
}

- (void)setBirthdaysCalendarName:(NSString *)newbirthdaysCalendarName {
    if (_birthdaysCalendarName != newbirthdaysCalendarName) {
        [_birthdaysCalendarName release];
        _birthdaysCalendarName = [newbirthdaysCalendarName copy];
    }
}

- (NSString *)birthdayEventName {
    return [[_birthdayEventName retain] autorelease];
}

- (void)setBirthdayEventName:(NSString *)newbirthdayEventName {
    if (_birthdayEventName != newbirthdayEventName) {
        [_birthdayEventName release];
        _birthdayEventName = [newbirthdayEventName copy];
    }
}

@end
