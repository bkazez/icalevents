WidgetName=iCal Events.wdgt
Archive=build/iCalEvents.wdgt.zip
Config=Deployment
XCBP=
WidgetDir=Widget

all: archive
	open "$(WidgetName)"	

archive: wfolder
	zip -r -9 "$(Archive)" "$(WidgetName)"

wfolder: Widget/* iCalEventsPlugin/*.m iCalEventsPlugin/*.h
	cd iCalEventsPlugin; xcodebuild -configuration $(Config) $(XCBP)
	cp -r Widget/ "$(WidgetName)"
	cd "$(WidgetName)";	find . | grep -F .svn | xargs rm -rf

