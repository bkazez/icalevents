//
// iCalEvents.js
// Copyright 2007 Ben Kazez
//
// Main JavaScript file for iCal Events widget. Note: Please do not reuse the
// included iCalEventsPlugin without my permission.
//
// Special thanks to Matt Gemmell for his colored checkbox graphics, which
// I used on the back.

var VERSION_NUMBER = "2.3";
var MAX_EVENT_NAME_LENGTH = MAX_DESCRIPTION_LENGTH = 1000;
var MAX_CALENDAR_NAME_LENGTH = 35; // limit for back so it looks like a list.
var MILLISECONDS_PER_DAY = 86400000;
var DEBUG_MODE = 0;

var infoButton;
var updateTimer;
var updateDelay = 600000; // Update in 10 m = 600000 ms.
var calendarKey;
var calendarKeys;
var dateRange;
var IEPArraySeparator;
var onshowHandlerValid = false;
var mainScrollbar, mainScrollArea;

function getLocalizedString(key) {
    try {
        var ret = localizedStrings[key];
        if (ret === undefined) {
            ret = key;
        }
        return ret;
    } catch(ex) {}
    
    return key;
}

function serializeArray(arr) {
	if (!arr)
		return "";
	if (arr.length > 0)
		return arr.join(IEPArraySeparator);
	else
		return "";
}

function unserializeArray(string) {
	return string.split(IEPArraySeparator);
}

function setup() {
	if (!iCalEventsPlugin) {
		alert("Unable to load iCalEventsPlugin");
		document.getElementById("paper").innerHTML = "<p>" + getLocalizedString("Unable to load iCal Events plugin") + "</p>";
		return false;
	}

	iCalEventsPlugin.setBirthdaysCalendarName(getLocalizedString("Birthdays"));
	iCalEventsPlugin.setBirthdayEventName(getLocalizedString("%@’s Birthday"));
	
	IEPArraySeparator = iCalEventsPlugin.arraySerializerSeparator();

	// Text fields.
	document.getElementById("calendarsLabel").innerHTML = getLocalizedString("Calendars:");
	document.getElementById("dateRangePopupLabel").innerHTML = getLocalizedString("Show events happening within the next:");
	
	// Reverse side.
	document.getElementById("iCalEventsText").innerHTML = "iCal Events " + VERSION_NUMBER; // Not localized.
	document.getElementById("checkVersion").innerHTML = "<span>" + getLocalizedString("Check for new version") + "</span>";

	// Load preference values.
	calendarKey = preferenceForKey("calendarKey");
	// Backwards compatibility.
	if (calendarKey) {
		calendarKeys = calendarKey;
		setPreferenceForKey(null, "calendarKey");
	}
	calendarKeys = preferenceForKey("calendarKeys");
	dateRange = preferenceForKey("dateRange");
	window.resizeTo(preferenceForKey("windowWidth"), preferenceForKey("windowHeight"));

	// Scroller.
	mainScrollbar = new AppleVerticalScrollbar(document.getElementById("myScrollBar"));
	mainScrollArea = new AppleScrollArea(document.getElementById("paperWrapper"), mainScrollbar);
	mainScrollArea.scrollsHorizontally = false;
	
	var doneButton = new AppleGlassButton(document.getElementById("done"), getLocalizedString("Done"), hidePrefs);
	
	infoButton = new AppleInfoButton(document.getElementById("infoButton"), document.getElementById("front"), "white", "white", showPrefs);

	// If onshow gets called and updates the data, we don't have to do so here.
	// See note below about this hack.
	if (!onshowHandlerValid)
		setTimeout("updateData();", 0); // So display redraws first.
	
	return true;
}

function createKey(key) {
	return widget.identifier + "-" + key;
}

Date.prototype.datePart = function() {
	var datePart = new Date(this);
	if (datePart) {
		datePart.setHours(0);
		datePart.setMinutes(0);
		datePart.setSeconds(0);
		datePart.setMilliseconds(0);
		return datePart;
	} else {
		return null;
	}
}

Date.prototype.addDay = function() {
	// Ensure that we get over the one-hour daylight saving time offset.
	this.setTime(this.getTime() + MILLISECONDS_PER_DAY + MILLISECONDS_PER_DAY/2);
	this.setTime(this.datePart().getTime());
	return this;
}

function datePartEqual(date1, date2) {
	if (!date1 || !date2)
		return false;
	return date1.datePart().getTime() == date2.datePart().getTime();
}

function runAppleScript(script) {
	if (window.widget) {
		var escapedScript = script.replace(/\'/, /\\\'/); //'
		var cmd = "/usr/bin/osascript -e '" + escapedScript + "'";
		widget.system(cmd, null);
	}
}

function showInIcal(calendarUID, eventUID) {
	var calendarTitle = iCalEventsPlugin.calendarValueForPropertyWithKey("Title", calendarUID);
	var appleScript;
	if (calendarTitle) {
		calendarTitle = calendarTitle.replace(/\"/, "\\\"");

		appleScript =
			"tell application \"iCal\"\n"
			+ "	set myCalendar to first calendar whose title is \"" + calendarTitle + "\"\n"
			+ "	show first event of myCalendar whose uid is \"" + eventUID + "\"\n"
			+ "end tell";
	}
	
	widget.openApplication("com.apple.iCal");
	
	if (appleScript) {
		runAppleScript(appleScript);
	}
}

var IEPHex = "0123456789abcdef";
function hex2dec(hexIn) { // 2-digit hex only
	if (!hexIn)
		return 0;
	hexIn = hexIn.toLowerCase();
	var dec = IEPHex.indexOf(hexIn[0]) * 16 + IEPHex.indexOf(hexIn[1]);
	return dec;
}

// Truncate color to something medium dark if it's too dark.
function truncateColor(color) {
	var THRESHOLD = 25;
	if (!color)
		return color;
	if ((hex2dec(color.substring(1,3)) + hex2dec(color.substring(3,5)) +
		hex2dec(color.substring(5,7))) / 3.0 < THRESHOLD) {
		return "#333";
	} else {
		return color;
	}
}

String.prototype.truncate = function(maxLength) {
	var string = new String(this);
	if (this.length > maxLength) {
		string = string.substr(0, maxLength) + "&hellip;";
	}
	return string;
}

// Single-quotes the string, escaping any special literal characters.
String.prototype.jsRepresentation = function() {
	var js = "'" + this.replace(/'/g, "\\'").replace(/\n/g, "\\n") + "'"; //'
	return js;
}

function updateData() {
	iCalEventsPlugin.loadCalendars();

	if (!calendarKeys) {
		alert("updateData: No calendar keys.");
		return false;
	}

	var numEvents;

	// Get date boundaries (24 hrs into future).
	var lowerDateBound = new Date();
	var upperDateBound = new Date();
	upperDateBound.setTime(lowerDateBound.getTime()	+ MILLISECONDS_PER_DAY * (parseInt(dateRange) + 1));
	upperDateBound = upperDateBound.datePart();
	
	if (preferenceForKey("showAllCurrentDayEvents"))
		lowerDateBound = lowerDateBound.datePart();
	
	// Set title bar of widget.
	var title;
	if (preferenceForKey("oldHeader")) {
		title = "iCal Events"; // not localized
	} else {
		title = iCalEventsPlugin.formattedDateWithMilliseconds(new Date().getTime());
	}
	var header = document.getElementById("header")
	if (header) header.innerHTML = title;
	
	// If no calendars checked, return with nice message.
	if (calendarKeys.length == 0) {
		paper.innerHTML = "<p>" + getLocalizedString("No calendars selected.") + "</p>";
	} else if (!iCalEventsPlugin.loadCalendarEventsFromCalendarsWithKeys(serializeArray(calendarKeys), lowerDateBound.getTime(), upperDateBound.getTime())) {
		paper.innerHTML = "<p>" + getLocalizedString("Unable to load calendar events.") + "</p>";
	} else {
		numEvents = iCalEventsPlugin.numEvents();
		paper = document.getElementById("paper");
		var paperHTML = "";
		if (numEvents > 0) {
			// Set "paper" area of calendar.
			paperHTML += '<table cellspacing="0" cellpadding="0">';

			var startDate, endDate;
			var currentDayStart, currentDayEnd;
			var i;
			var firstEventConsidered = 0;
			var allDay, displayTime, firstDayDisplayed = true, dateHeaderPrinted = false;
			var startDate_getTime, endDate_getTime, currentDayStart_getTime, currentDayEnd_getTime;
			
			for (var currentDayStart = lowerDateBound; currentDayStart.getTime() < upperDateBound.getTime(); currentDayStart = currentDayStart.datePart().addDay()) {
				currentDayEnd = currentDayStart.datePart().addDay(); // advance loop counter

				for (var i = firstEventConsidered; i < numEvents; ++i) {
					startDate = new Date(iCalEventsPlugin.eventValueForProperty("DTSTART", i));
					endDate = new Date(iCalEventsPlugin.eventValueForProperty("DTEND", i));
					allDay = iCalEventsPlugin.eventValueForProperty("X-IEP-ALL-DAY-EVENT", i) == "TRUE";
					eventUID = iCalEventsPlugin.eventValueForProperty("UID", i);
					if (!eventUID)
						eventUID = "__noUID";
					
					// Cache getTime() values.
					startDate_getTime = startDate.getTime();
					endDate_getTime = endDate.getTime();
					currentDayStart_getTime = currentDayStart.getTime();
					currentDayEnd_getTime = currentDayEnd.getTime();

					// If the event has already ended, don't display anything and don't consider this event again.
					// Else if it's starting on currentDay, display time.
					// Else if it's in progress, display as all day.
					
					if (allDay)
						displayTime = false;
					else if ((startDate.datePart() == endDate.datePart()) || // not multi-day
							(startDate_getTime >= currentDayStart.datePart().getTime() && // start day is currentDay
							 currentDayEnd_getTime > startDate_getTime))
						displayTime = true;
					else
						displayTime = false;

					if (currentDayStart_getTime >= endDate_getTime) {
						// TODO: optimization here using firstEventConsidered.
					} else if ((startDate_getTime >= currentDayStart_getTime && currentDayEnd_getTime > startDate_getTime) ||
							  (startDate_getTime < currentDayStart_getTime && endDate_getTime > currentDayStart_getTime)) {
						// Print date header if necessary.
						if (!dateHeaderPrinted) {
							// Localized so that relative date strings are localized.
							paperHTML += '</table><div class="dateHeader">' + getLocalizedString(iCalEventsPlugin.formattedRelativeDateWithMilliseconds(currentDayStart_getTime)) + '</div><table cellspacing="0" cellpadding="0">';
							dateHeaderPrinted = true;
						}
						
						// Create table row (inlined for performance).
						var parentCalendarKey = iCalEventsPlugin.eventValueForProperty("X-IEP-CALENDAR-KEY", i);
						var location = iCalEventsPlugin.eventValueForProperty("LOCATION", i);
						var summary = iCalEventsPlugin.eventValueForProperty("SUMMARY", i);
						var description = iCalEventsPlugin.eventValueForProperty("DESCRIPTION", i);
						if (!description)
							description = "";
						description = description.truncate(MAX_DESCRIPTION_LENGTH);

						// Set calendar color square; ignore alpha (last two characters).
						var color = truncateColor(iCalEventsPlugin.calendarValueForPropertyWithKey("ThemeColor", parentCalendarKey).substring(0,7));

						var formattedTimeRange = iCalEventsPlugin.formattedTimeWithMilliseconds(startDate.getTime()) + " &ndash; " + iCalEventsPlugin.formattedTimeWithMilliseconds(endDate.getTime());
						
						summary = summary.truncate(MAX_EVENT_NAME_LENGTH);
						paperHTML += "<tr><td><a title=\"" + (displayTime ? formattedTimeRange : "") + "\" class=\"eventTime\">";
					
						if (displayTime)
							paperHTML += iCalEventsPlugin.formattedTimeWithMilliseconds(startDate.getTime());

						paperHTML += "</a></td><td><a title=\"" + iCalEventsPlugin.calendarValueForPropertyWithKey("Title", parentCalendarKey) + "\" class=\"calendarColor\"";
						if (color)
							paperHTML += " style=\"background-image:url(Images/calendar_color_overlay.png);background-color:" + color + "";
						paperHTML += "\"></a></td><td class=\"eventSummary\"";
						if (description) {
							description = description.replace(/"/g, "&quot;"); //"
							paperHTML += " title=\"" + description + "\"";
						}
						
						var calendarUID = iCalEventsPlugin.calendarValueForPropertyWithKey("Key", parentCalendarKey)
						paperHTML += " onclick=\"showInIcal('" + calendarUID + "', '" + eventUID + "');\"";
					
						if (location)
							paperHTML += " onmouseover=\"showLocation(" + location.jsRepresentation() + ");\" onmouseout=\"hideLocation();\"";
					
						paperHTML += ">";
						if (summary)
							paperHTML += summary;
						paperHTML += "</td></tr>";
						
					} else {
						break; // A future event; don't consider any more.
					}
				}
				dateHeaderPrinted = false;
				firstDayDisplayed = false;
			}
			paperHTML += '</table>';
		} else {
			// No events.
			paperHTML += '<p>' + getLocalizedString('No events today or in the next %i day(s).').replace('%i', dateRange) + '</p><p><a href="javascript:widget.openApplication(\'com.apple.iCal\');">' + getLocalizedString("Open iCal") + '</a></p>';
		}
		
		paper.innerHTML = paperHTML;
		
		iCalEventsPlugin.widgetDidFinishDisplayingEvents();
	}
	
	refreshScrollbar();
	
	// Set timer so it updates again.
	if (updateTimer != null) {
		clearInterval(updateTimer);
		updateTimer = null;
	}
	updateTimer = setInterval("updateData();", updateDelay);
}

function refreshScrollbar() {
	mainScrollArea.refresh();
	if (mainScrollbar.hidden) {
		document.getElementById("paper").style.right = "0";
	} else {
		document.getElementById("paper").style.right = "21px";
	}

	if (preferencesChanged) {
		mainScrollArea.verticalScrollTo(0);
	}
}

function showLocation(location) {
	document.getElementById("location").innerHTML = "<span id=\"locationLabel\">" + getLocalizedString("Location: ") + "</span><span id=\"locationText\">" + location + "</span>";
}

function hideLocation(location) {
	document.getElementById("location").innerHTML = "";
}

function onhide() {
	clearInterval(updateTimer);
	updateTimer = null;
	onshowHandlerValid = true;
}

function onshow() {
	reloadPreferences();
	savePreferences();

	// Refreshing the widget requires a data update,
	// but this does not send the onshow event.
	if (onshowHandlerValid) {
		// Update now and set timer for future update.
		setTimeout("updateData();", 0); // so display redraws when refreshing widget
	}
}

function onremove() {
	clearInterval(updateTimer);
	updateTimer = null;

	widget.setPreferenceForKey(null, createKey("calendarKey"));
	widget.setPreferenceForKey(null, createKey("calendarKeys"));
	widget.setPreferenceForKey(null, createKey("dateRange"));
}

function gotoURL(url) {
	widget.openURL(url);
}

widget.onremove = onremove;
widget.onhide = onhide;
widget.onshow = onshow;
