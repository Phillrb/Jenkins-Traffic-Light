Jenkins-Traffic-Light
=====================

An OSX app with accompanying Arduino sketch to monitor a Jenkins RSS build feed and update a traffic light (either real or on-screen).

The OSX app is a lightweight tool that: 
- monitors a single Jenkins RSS feed
- updates a virtual traffic light in an NSWindow
- optionally sends the build status to an attached Arduino via USB

The Arduino sketch is a simple piece of code that:
- listens to serial data sent over USB from the OSX app
- sets 3 digital 5v pins accordingly (turning lights or LEDs on & off) 
- sounds an audio alert on state change using an attached speaker by utilising 'pitch.h' - originally written by Brett Hagman (see http://arduino.cc/en/Tutorial/tone)

OSX app features include:
- displaying build status in the OSX status bar, dock and window
- instant notifications in OSX 10.8 (Mountain Lion) and above
- quick links to the monitored Jenkins job or latest build
- configurable Jenkins Job RSS URL

Details:
- The RSS feed is pulled down every 60 seconds and parsed (feel free to change this value)
- Build status is extracted from RSS
- On a change of status a notification is displayed via Notification Center in OSX 10.8
- If an Arduino is attached by USB the build status is sent to it (as an integer) utilising the excellent ORSSerialPort class provided by Andrew R. Madsen (see githup repo: https://github.com/armadsen/ORSSerialPort)

Potential Areas Of Improvement:
- Currently uses simple string parsing to find the build status from the RSS (on the upside it's quick and doesn't need any additional frameworks)
- All settings are stored in NSUserDefaults - could use CoreData or SQLite
- Only one feed is monitored at a time
- A list of favourite Jenkins RSS job feeds could be helpful
- Please feel free to submit additions / tweaks / fixes and I'll add you to the Credits!

Suggested Use Cases:
- Hook up an Arduino to a large life-size traffic light and alert your devs when the build breaks
- Alternatively use a 5V spinning emergency light / alarm for instant escalation on failure!
- Make the soft traffic light larger and display it on a spare screen / projector in the office
