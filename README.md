icalevents
==========

iCal Events widget for Mac OS X Dashboard

The once-popular iCal Events widget (http://www.macworld.com/article/1045367/widgetsoftheweek004.html) is now open source. I continue to get emails from users who are excited about the widget, and I am open-sourcing it in hopes that others will take it over and continue to maintain it. There are probably a few hundred thousand users, but I do not have an exact count.

The source includes a full iCalendar parser written in Objective-C, including most recurrence rules (RRULE). Leopard and later systems use the Apple CalendarStore framework instead. I wrote much of this in 2005 as a college freshman, so the code quality may be very bad.