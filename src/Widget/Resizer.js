//
// iCalEvents.js
// Copyright 2007 Ben Kazez
//
// JavaScript resizing code for iCal Events widget. Note: Please do not reuse 
// the included iCalEventsPlugin without my permission. Thank you.
//

var clickOffset;
var MIN_WIDTH = 292;
var MIN_HEIGHT = 201;
var oldSize;

function mouseDown(event) {
	oldSize = {x:window.innerWidth, y:window.innerHeight};
	var x = oldSize.x - event.x;
	var y = oldSize.y - event.y;
	clickOffset = {x:x, y:y};
		
	document.addEventListener("mousemove", mouseMove, true);
	document.addEventListener("mouseup", mouseUp, true);
	
	event.stopPropagation();
	event.preventDefault();
}

function mouseMove(event) {
	var newSize = {x: (clickOffset.x + event.x), y: (clickOffset.y + event.y)};
	if(newSize.x < MIN_WIDTH)
		newSize.x = MIN_WIDTH;
	if(newSize.y < MIN_HEIGHT)
		newSize.y = MIN_HEIGHT;
	
	if(oldSize.x != newSize.x || oldSize.y != newSize.y) {
		window.resizeTo(newSize.x, newSize.y);
		refreshScrollbar();
	}
	
	event.stopPropagation();
	event.preventDefault();
}

function mouseUp(event) {
	document.removeEventListener("mousemove", mouseMove, true);
	document.removeEventListener("mouseup", mouseUp, true); 

	setPreferenceForKey(window.innerWidth, "windowWidth");
	setPreferenceForKey(window.innerHeight, "windowHeight");

	event.stopPropagation();
	event.preventDefault();
}
