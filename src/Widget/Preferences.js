//
// iCalEvents.js
// Copyright 2007 Ben Kazez
//
// JavaScript preferences code for iCal Events widget. Note: Please do not reuse 
// the included iCalEventsPlugin without my permission. Thank you.
//

var calendars = new Array();
var flipShown = false;
var animation = {duration:0, starttime:0, to:1.0, now:0.0, from:0.0, firstElement:null, timer:null};
var REVERSE_WIDTH = 292;
var REVERSE_HEIGHT = 201;
var preferencesChanged = false;

function preferenceForKey(key)
{
	var value = widget.preferenceForKey(createKey(key));
	
	// Try global key only for oldHeader and showAllCurrentDayEvents.
	if (value == null && (key == "oldHeader" || key == "showAllCurrentDayEvents")) {
		// Try global key, then use defaults.
		value = widget.preferenceForKey(key);
	}
	
	if (value == null) {
		if (key == "calendarKey") // backwards compatibility
			value = iCalEventsPlugin.calendarValueForProperty("Key", 0);
		else if (key == "calendarKeys")
			value = iCalEventsPlugin.defaultSelectedCalendars(); // unserialized below
		else if (key == "dateRange")
			value = 1;
		else if (key == "windowWidth")
			value = MIN_WIDTH; // of front
		else if (key == "windowHeight")
			value = MIN_HEIGHT; // of front
	}
	
	if (value == null)
		value = "";

	if (key == "calendarKeys") {
		if (value == "")
			value = new Array();
		else
			value = unserializeArray(value);
	}

	if (key == "windowWidth" && value < MIN_WIDTH)
		value = MIN_WIDTH;
	if (key == "windowHeight" && value < MIN_HEIGHT)
		value = MIN_HEIGHT;

	return value;
}

function setPreferenceForKey(value, key)
{
	// Serialize if necessary.
	if (value != null && key == "calendarKeys")
		value = serializeArray(value);
	
	widget.setPreferenceForKey(value, createKey(key));
	widget.setPreferenceForKey(value, key);
}

function savePreferences()
{
	setPreferenceForKey(calendarKeys, "calendarKeys");
	
	// Date range.
	var select = document.getElementById("dateRangePopup");
	if (select) {
		dateRange = select.options[select.selectedIndex].value;
		setPreferenceForKey(dateRange, "dateRange");
	} else {
		alert("savePreferences: Unable to save preferences; no date range pop-up.");
	}
}

// Removes all occurrences of object from array.
function removeOccurrencesFromArray(arr, obj) {
	if (!arr)
		return arr;
	var newArr = new Array();
	
	for (var i = 0; i < arr.length; i++) {
		if (arr[i] != obj)
			newArr.push(arr[i]);
	}
	return newArr;
}

function checkCheckbox(uid) {
	var check = document.getElementById("check" + uid);
	if (check)
		check.style.background = "url(Images/chkbx/check.png) no-repeat top left";
	var hidden = document.getElementById("hidden" + uid);
	if (hidden)
		hidden.value = "1";
}

function uncheckCheckbox(uid) {
	var check = document.getElementById("check" + uid);
	if (check)
		check.style.background = "none";
	var hidden = document.getElementById("hidden" + uid);
	if (hidden)
		hidden.value = "0";
}

function toggleCheckbox(uid) {
	var hiddenInput = document.getElementById("hidden" + uid); 
	if (!hiddenInput)
		return;

	if (hiddenInput.value == "1") {
		uncheckCheckbox(uid);
		calendarKeys = removeOccurrencesFromArray(calendarKeys, uid);
	} else {
		checkCheckbox(uid);
		calendarKeys.push(uid);
	}
	preferencesChanged = true;
}

function showPrefs()
{
	var front = document.getElementById("front");
	var back = document.getElementById("back");
	
	widget.prepareForTransition("ToBack");

	front.style.display = "none";
	back.style.display = "block";

	setTimeout("widget.performTransition();", 0);

	// Reload calendar keys in case they've changed.
	calendarKeys = preferenceForKey("calendarKeys");

	reloadPreferences();
}

function reloadPreferences()
{
	iCalEventsPlugin.loadCalendars();

	var numCalendars = iCalEventsPlugin.numCalendars();
	var calendarBox = document.getElementById('calendarBox');
	var element;
	var calendarKey, calendarTitle;

	calendarBox.innerHTML = "<table>";
	for (var i = 0; i < numCalendars; i++) {
		calendarKey = iCalEventsPlugin.calendarValueForProperty("Key", i);
		calendarTitle = iCalEventsPlugin.calendarValueForProperty("Title", i)
		if (!calendarTitle)
			calendarTitle = "";
		calendarTitle = calendarTitle.truncate(MAX_CALENDAR_NAME_LENGTH);
		
		if (calendarTitle == "com.apple.ical.sources.birthdays")
			calendarTitle = getLocalizedString("Birthdays");

		if (calendarTitle == "com.apple.ical.caches.inbox")
			calendarTitle = getLocalizedString("Invitations");

		// Must append to innerHTML since we refer to elements as we go.
		calendarBox.innerHTML += "<tr><td><div class=\"chkbxWrapper\" id=\"chkbx" + calendarKey + "\">" +
			"<div class=\"chkbxShadow\"><div class=\"chkbx\" onclick=\"" +
				"toggleCheckbox('" + calendarKey + "');\">" +
				"<div class=\"check\" id=\"check" + calendarKey + "\">" +
			"</div></div></div></div></td>" +
		"<td><div class=\"calendarName\" onclick=\"toggleCheckbox('" + calendarKey + "');\">" + calendarTitle + "</div></td></tr>" +
			// hidden form variable for checkbox value
			"<input type=\"hidden\" id=\"hidden" + calendarKey + "\" value=\"0\" />";
		
		// Set checkbox color; ignore alpha (last two characters).
		var chkbx = document.getElementById("chkbx" + calendarKey);
		if (chkbx)
			chkbx.style.background = iCalEventsPlugin.calendarValueForProperty("ThemeColor", i).substring(0,7) + " url(Images/chkbx/shape.png) no-repeat top left";
	}
	
	// Fill in existing values for checkboxes, updating calendarKeys array.
	for (var i = 0; i < calendarKeys.length; i++) {
		checkCheckbox(calendarKeys[i]);
	}

	// Fill in dateRangePopup.
	var dateRangePopup = document.getElementById('dateRangePopup');
	dateRangePopup.innerHTML = "";
	
	// The first one is a special case grammatically
	element = document.createElement("option");
	element.innerText = getLocalizedString("1 day");
	element.value = "1"; // value is amount to add to month date
	dateRangePopup.appendChild(element);

	for (var i = 2; i <= 14; ++i) { // first week given in days
		element = document.createElement("option");
		element.innerText = getLocalizedString("%i days").replace("%i", i);
		element.value = i;
		if (parseInt(element.value) == dateRange)
			element.selected = "selected";
		dateRangePopup.appendChild(element);
	}
}

function hidePrefs()
{
	savePreferences();

	var front = document.getElementById("front");
	var back = document.getElementById("back");
	
	widget.prepareForTransition("ToFront");
	
	back.style.display = "none";
	front.style.display = "block";
	
	setTimeout("widget.performTransition();", 0);
	setTimeout("updateData();", 0);
}

function changeDateRange(select)
{
	preferencesChanged = true;
}

function changeCalendarSelection()
{
	preferencesChanged = true;
}
