//
//  NSColor_IEPAdditions.m
//  iCalEventsPlugin
//
//  Created by Ben Kazez on 10/30/07.
//

#import "NSColor_IEPAdditions.h"


@implementation NSColor (IEPAdditions)

- (NSString *)hexEquivalent {
	float r, g, b, a;
	[self getRed:&r green:&g blue:&b alpha:&a];
	
	NSString *hex = [NSString stringWithFormat:@"#%02x%02x%02x%02x", (int)round(r * 255.0), (int)round(g * 255.0), (int)round(b * 255.0), (int)round(a * 255.0)];
	return hex;
}

@end
