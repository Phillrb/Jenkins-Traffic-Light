//
//  AppDelegate.m
//  JenkinsTrafficLight
//
//  Created by Phillip Riscombe-Burton on 01/04/2013.
//  Copyright (c) 2013 Phillip Riscombe-Burton. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "AppDelegate.h"
#import "ORSSerialPortManager.h"

@implementation AppDelegate

//Arduino
const int baudRate = 9600;
#define kArduinoSerialPortPrefix @"usbmodem"

//Port manager
#define kAvailablePorts @"availablePorts"

//URL to jenkins builds
#define kRSSPromptTitle @"Jenkins Job RSS URL"
#define kURLKey @"kURLKey"
#define kBuildKey @"kBuildKey"
#define kJobKey @"kJobKey"
#define kBuildURLKey @"kBuildURLKey"
#define kJobURLKey @"kJobURLKey"
#define kBuildMessageKey @"kBuildMessageKey"

//Default to 'unknown state'
enum trafficLightState status = initState;
enum trafficLightState lastStatus = initState;
NSString *lastBuildNumber;

@synthesize serialPortManager = _serialPortManager;
@synthesize serialPort = _serialPort;
@synthesize timer = _timer;
@synthesize redBox = _redBox, yellowBox = _yellowBox, greenBox = _greenBox;
@synthesize buildLabel = _buildLabel;
@synthesize statusBarIcon = _statusBarIcon;
@synthesize rssNameMenuItem = _rssNameMenuItem;
@synthesize buildMenuItem = _buildMenuItem;
@synthesize statusBarMenu = _statusBarMenu;
@synthesize windowController = _windowController;
@synthesize progress = _progress;

//TODO add audio alert

- (void)applicationWillTerminate:(NSNotification *)notification
{
    //Close all the ports on close
	NSArray *ports = [[ORSSerialPortManager sharedSerialPortManager] availablePorts];
	for (ORSSerialPort *port in ports) { [port close]; }
    
    //stop the timer
    if(_timer)
    {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //Setup status bar menu
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    _statusBarIcon = [bar statusItemWithLength:NSVariableStatusItemLength];
    [_statusBarIcon setHighlightMode:YES];
    [_statusBarIcon setMenu:_statusBarMenu];
    
    //Create a window controller to open the traffic light window later if it's closed
    _windowController =[[NSWindowController alloc] initWithWindow:_window];
    
    //Setup port manager
    _serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
    
    //Listen to port notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(serialPortsWereConnected:) name:ORSSerialPortsWereConnectedNotification object:nil];
    [nc addObserver:self selector:@selector(serialPortsWereDisconnected:) name:ORSSerialPortsWereDisconnectedNotification object:nil];
    
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
    //Only available from Mountain Lion onwards
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
#endif
    
    
    
    /* 
     Look for an attached Arduino via USB (serial port)
     */
    
    bool foundArduino = false;
    
    //Test all the current ports to see if it's connected to an Arduino
    for (ORSSerialPort *port in self.serialPortManager.availablePorts)
    {
        //Test port - if it's connected to an Arduino it will be assigned
        //and the first build state will be requested
        if ([self testPort:port]) {
            foundArduino = true;
            break;
        }
    }
    
    //Just update UI locally if there's no Arduino
    if(!foundArduino)
    {
        [self showLight];
        [self updateArduinoWithJenkinsState];
    }
    
    
    //If you've no internet connection and just want to see each possible state
    //just uncomment the below and it'll cycle through each state
//    int numberOfStates = 5;
//    for (int tempState = numberOfStates - 1; tempState >= 0; tempState--) {
//        [self performSelector:@selector(test:) withObject:[NSNumber numberWithInt:tempState] afterDelay:(tempState + 1) * 2.0f];
//    }
}

//A simple test function to force change the state
//Good to see the app and arduino in every possible state
-(void)test:(NSNumber*)stateNum{
    
    status = stateNum.intValue;
    [self showLight];
    
}



#pragma mark - Serial Ports
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if ([string length] == 0) return;
	
    NSLog(@"RECIEVED FROM ARDUINO: %@", string);
    
}

//When a new serial port connects - look to see if it is an Arduino
- (void)serialPortsWereConnected:(NSNotification *)notification
{
	NSArray *connectedPorts = [[notification userInfo] objectForKey:ORSConnectedSerialPortsKey];
	NSLog(@"Ports were connected: %@", connectedPorts);
	
    //Test all newly connected ports to see if it's an arduino
    for (ORSSerialPort *port in connectedPorts)
    {
        if([self testPort:port]) break;
    }
}

//Checks if this port is connected to an Arduino
-(bool)testPort:(ORSSerialPort *)port
{
    //Look for a connected Arduino
    if([port.name hasPrefix:kArduinoSerialPortPrefix])
    {
       //Assign the port, open it and start sending state changes
        [self setSerialPort:port];
        
        return true;
    }

    return false;
}

//If an Arduino is unplugged we need to stop attempting to send it state updates 
- (void)serialPortsWereDisconnected:(NSNotification *)notification
{
	NSArray *disconnectedPorts = [[notification userInfo] objectForKey:ORSDisconnectedSerialPortsKey];
	NSLog(@"Ports were disconnected: %@", disconnectedPorts);
    
    //Remove all Ardunio ports that were disconnected
    for (ORSSerialPort *port in disconnectedPorts)
    {
        if([port.name hasPrefix:kArduinoSerialPortPrefix])
        {
            self.serialPort = nil;
            break;
        }
    }
}

//clean up ports
- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
	// After a serial port is removed from the system, it is invalid and we must discard any references to it
	self.serialPort = nil;
}

//Setup serial port manager - listen for new ports
- (void)setSerialPortManager:(ORSSerialPortManager *)manager
{
	if (manager != _serialPortManager)
	{
		[_serialPortManager removeObserver:self forKeyPath:kAvailablePorts];
		_serialPortManager = manager;
		NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
		[_serialPortManager addObserver:self forKeyPath:kAvailablePorts options:options context:NULL];
	}
}



//Attempt to connect to an arduino that is attached by USB
//This connection is formed as a serial port connection
//The baudrate is set on the arduino software in it's 'setup()' method -> 'Serial.begin(9600);'

- (void)setSerialPort:(ORSSerialPort *)port
{
	if (port != _serialPort)
	{
        //Clean up any old port
		[_serialPort close];
		_serialPort.delegate = nil;
		
        //Set the new one
		_serialPort = port;
		_serialPort.delegate = self;
        
        //Setup defaults for comms with Arduino
         [_serialPort setBaudRate:[NSNumber numberWithInteger:baudRate]];
        
        //Open the port!
        if(!_serialPort.isOpen)
        {
           [_serialPort open];
            
            //wait a few seconds to allow arduino to accept connection
            [NSThread sleepForTimeInterval:2.0f];
        }
        
        //Send it the current state whilst we are waiting for an update (probably initState)
        [self sendCurrentState];
        
        //Schedule the repeating timer
        if(_timer)
        {
            [_timer invalidate];
            _timer = nil;
        }
        
        //Reschedule timer
        _timer = [NSTimer scheduledTimerWithTimeInterval:60.0f target:self selector:@selector(checkFeed:) userInfo:nil repeats:YES];
        [_timer fire];

	}
}

//Timer fire
-(void)checkFeed:(NSTimer*)timer{
    
    [self updateArduinoWithJenkinsState];
    
}

//Updates the state from the latest build on the RSS feed
-(void)updateLatestBuildState{
    
    //Start spinner
    [_progress startAnimation:self];
    [_rssNameMenuItem setTitle:[NSString stringWithFormat:@"Job: %@", [self getLastJobName]]];
    [_buildLabel setStringValue:[self getLastBuildNumber]];
    [_buildMenuItem setTitle:[NSString stringWithFormat:@"Build: %@", [self getLastBuildNumber]]];
    [_buildStatusMenuItem setTitle:[NSString stringWithFormat:@"State: %@",[self getLastBuildMessage]]];
    
    //Get RSS URL
    NSString *url = [self getPathToRSS];
    
    if(!url || [url isEqualToString:@""])
    {
        NSLog(@"Please provide a Jenkins Job URL. Go to 'RSS' -> 'Change Jenkins Job RSS URL' or press 'cmd + return'");
        if(status != initState)
        {
            //Go to unknown state if the state was previously set
            status = unknownState;
        }
        [self updateLightAfterStatusSet];
        return;

    }
    
    //Start a webrequest and fetch the feed as an html string
    NSURL *urlRequest = [NSURL URLWithString:url];
    NSError *err = nil;
    NSMutableString *html = [NSMutableString stringWithContentsOfURL:urlRequest encoding:NSUTF8StringEncoding error:&err];
    
    //Check for error getting feed
    if(err)
    {
        NSLog(@"Error getting RSS feed from jenkins: %@", err.localizedDescription);
        if(status != initState)
        {
            //Go to unknown state if the state was previously set
            status = unknownState;
        }
        [self updateLightAfterStatusSet];
        return;
    }
    
    
    //NB. This solution uses simple string parsing - if you would like to propose another solution utilising a simple RSS / XML parser
    //then that's great - it was just a quick and dirty solution that didn't need another framework
    NSString * trimmedString = nil;
    
    //Look for the latest job title
    NSString *titlePreMarker = @"<title>";
    NSString *titlePostMarker = @" ";
    NSString* jobTitle = nil;
    
    trimmedString = [self getTrailingStringFromString:html afterExtractionOfStringBetween:titlePreMarker and:titlePostMarker into:&jobTitle];
    if(!trimmedString || !jobTitle)
    {
        status = unknownState;
        [self updateLightAfterStatusSet];
        return;
    }
    
    //Save Job title and Update UI
    [_rssNameMenuItem setTitle:[NSString stringWithFormat:@"Job: %@", jobTitle]];
    [self setLastJobName:jobTitle];
    
    //Move on
    [html setString:trimmedString];
    
    
    //Get URL for Job
    NSString *urlPreMarker = @"href=\"";
    NSString *urlPostMarker = @"\" ";
    NSString *jobURL = nil;
    
    trimmedString = [self getTrailingStringFromString:html afterExtractionOfStringBetween:urlPreMarker and:urlPostMarker into:&jobURL];
    if(!trimmedString || !jobURL)
    {
        status = unknownState;
        [self updateLightAfterStatusSet];
        return;
    }

    //Save job url for menu press
    [self setLastJobURL:jobURL];
    
    //Move on
    [html setString:trimmedString];
    
    
    //Get build message
    NSString *buildMessagePreMarker = @" #";
    NSString *buildMessagePostMarker = @"</title>";
    NSString* message = nil;
    
    trimmedString = [self getTrailingStringFromString:html afterExtractionOfStringBetween:buildMessagePreMarker and:buildMessagePostMarker into:&message];
    if(!trimmedString || !message)
    {
        status = unknownState;
        [self updateLightAfterStatusSet];
        return;
    }
    
    
    NSLog(@"LAST BUILD: %@", message);
    
    //Get Build number from message
    NSString *buildNumber = [message substringToIndex:[message rangeOfString:@" "].location];
    NSLog(@"BUILD NUMBER: %@", buildNumber);
    
    //Save build message and update menu
    NSString *messageWithoutBuildNumber = [message substringFromIndex:[message rangeOfString:@" "].location + 1];
    [_buildStatusMenuItem setTitle:[NSString stringWithFormat:@"State: %@",messageWithoutBuildNumber]];
    [self setLastBuildMessage:messageWithoutBuildNumber];
    
    
    //Update UI, menu and save
    [_buildLabel setStringValue:buildNumber];
    [_buildMenuItem setTitle:[NSString stringWithFormat:@"Build: %@", buildNumber]];
    [self setLastBuildNumber:buildNumber];
    
    //Move on
    [html setString:trimmedString];
    
    
    //Get build url
    NSString* buildURL = nil;
    
    trimmedString = [self getTrailingStringFromString:html afterExtractionOfStringBetween:urlPreMarker and:urlPostMarker into:&buildURL];
    if(!trimmedString || !buildURL)
    {
        status = unknownState;
        [self updateLightAfterStatusSet];
        return;
    }
    
    //Save Build URL
    [self setLastBuildURL:buildURL];

    //Parse message for current status
    [self updateStateBasedOnRSSStatusString:messageWithoutBuildNumber];
        
    //Update Light
    [self updateLightAfterStatusSet];
}

-(void)updateStateBasedOnRSSStatusString:(NSString*)message{
    
    //All status messages pulled from the jenkins source code
    
    /*
     Green
     Run.Summary.Stable=stable
     Run.Summary.BackToNormal=back to normal
     
     Yellow
     Run.Summary.Unstable=unstable
     Run.Summary.Aborted=aborted //personal choice - you may wish to look at a previous state
     Run.Summary.NotBuilt=not built
     Run.Summary.TestFailures={0} {0,choice,0#test failures|1#test failure|1<test failures}
     Run.Summary.TestsStartedToFail={0} {0,choice,0#tests|1#test|1<tests}  started to fail
     Run.Summary.TestsStillFailing={0} {0,choice,0#tests are|1#test is|1<tests are} still failing
     Run.Summary.MoreTestsFailing={0} more {0,choice,0#tests are|1#test is|1<tests are} failing (total {1})
     Run.Summary.LessTestsFailing={0} less {0,choice,0#tests are|1#test is|1<tests are} failing (total {1})
     Run.Summary.Unknown=?
     
     Red
     Run.Summary.BrokenForALongTime=broken for a long time
     Run.Summary.BrokenSinceThisBuild=broken since this build
     Run.Summary.BrokenSince=broken since build {0}
     */
    
    if(
       [message rangeOfString:@"normal" options:NSCaseInsensitiveSearch].location != NSNotFound
       ||
       (
        [message rangeOfString:@"stable" options:NSCaseInsensitiveSearch].location != NSNotFound
        && [message rangeOfString:@"unstable" options:NSCaseInsensitiveSearch].location == NSNotFound
        )
       )
    {
        status = greenState;
    }
    else if([message rangeOfString:@"broken" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        status = redState;
    }
    else
    {
        status = yellowState;
    }
}


-(void)updateLightAfterStatusSet
{
    
    //Update the local traffic light
    [self showLight];
    
    //Stop spinner
    [_progress stopAnimation:self];
}

//Generic string extraction method
-(NSString*)getTrailingStringFromString:(NSString*)originalString afterExtractionOfStringBetween:(NSString*)preMarker and:(NSString*)postMarker into:(NSString **)stringHolder{
    
    NSUInteger preMarkerlocation = [originalString rangeOfString:preMarker].location;
    if(!preMarkerlocation || preMarkerlocation + preMarker.length >= originalString.length) return nil;

    NSString *trimmedString = [originalString substringFromIndex:preMarkerlocation + preMarker.length];
    NSUInteger postMarkerlocation = [trimmedString rangeOfString:postMarker].location;
    
    if(postMarkerlocation == NSNotFound) return nil;
    
    //Get string between markers
    *stringHolder = [trimmedString substringToIndex:postMarkerlocation];
    
    //Pass back the trimmed string
    return [trimmedString substringFromIndex:postMarkerlocation + postMarker.length];
}




//Show soft trafficlight
-(void)showLight
{
    NSString *stateString = nil;
    
    NSLog(@"Setting new state: %i...", status);
    switch (status) {
        case greenState:
            NSLog(@"GREEN");
            [self lightUp:_greenBox];
             [_statusBarIcon setImage:[NSImage imageNamed:@"green.png"]];
            [[NSApplication sharedApplication] setApplicationIconImage:[NSImage imageNamed:@"trafficGreen"]];
            stateString = @"green";
            break;
        case yellowState:
            NSLog(@"YELLOW");
            [self lightUp:_yellowBox];
             [_statusBarIcon setImage:[NSImage imageNamed:@"yellow.png"]];
            [[NSApplication sharedApplication] setApplicationIconImage:[NSImage imageNamed:@"trafficYellow"]];
            stateString = @"yellow";
            break;
        case redState:
            NSLog(@"RED");
            [self lightUp:_redBox];
            [_statusBarIcon setImage:[NSImage imageNamed:@"red.png"]];
            [[NSApplication sharedApplication] setApplicationIconImage:[NSImage imageNamed:@"trafficRed"]];
            stateString = @"red";
            break;
       
        default:
            NSLog(@"UNKNOWN");
            [self lightUp:nil];
            [_statusBarIcon setImage:[NSImage imageNamed:@"init.png"]];
            [[NSApplication sharedApplication] setApplicationIconImage:nil];
            stateString = @"unknown";
            break;
    }
    
    
    [self sendNotificationToUserWithStateString:stateString];
}

//Send a notification to notification center
-(void)sendNotificationToUserWithStateString:(NSString*)stateString{
    
    //Send notification
    Class userNotificationClass = NSClassFromString(@"NSUserNotification");
    if(userNotificationClass)
    {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        notification.title = [NSString stringWithFormat:@"%@ -> %@",_rssNameMenuItem.title, stateString];
        notification.informativeText = [NSString stringWithFormat:@"%@ - %@ has changed its state to %@!", _rssNameMenuItem.title , _buildMenuItem.title, stateString];
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
    
}

#pragma mark - local traffic light
//This method simply lightens the correct light and darkens the others
-(void)lightUp:(NSBox*)box{
    
    float show = 1.0f;
    float hide = 0.2f;
    
    //Possible lights
    NSArray * boxes = [NSArray arrayWithObjects:_greenBox, _yellowBox, _redBox, nil];
    
    if(box)
    {
        //Illuminate this box
        [box setAlphaValue:show];
        
        //Darken the other lights
        for(NSBox* _box in boxes)
        {
            if(_box != box)
            {
                [_box setAlphaValue:hide];
            }
        }
    }
    else
    {
        //Light up all boxes in this unknown state (no borders)
        for(NSBox* _box in boxes)
        {
            [_box setAlphaValue:show];
        }
    }

}

//Action to maually get latest status
-(IBAction)fetchStatusFromRSSNow:(id)sender{
    
    [self updateArduinoWithJenkinsState];
}

//Fired from a timer
-(void)updateArduinoWithJenkinsState{
    
    //Get an update from the RSS
    [self updateLatestBuildState];
    
    //Only send to arduino if attached
   if(self.serialPort && self.serialPort.open)
   {
        //Send new state
        if(status != lastStatus)
        {
            //Update last status
            lastStatus = status;
            
            //Send new state to traffic light
            [self sendCurrentState];
        }
        else
        {
            NSLog(@"Status unchanged");
        }
    
   }

}

//if there's a an arduino connected to a port then tell it the state!
-(void)sendCurrentState{
    
    //end current state to Arduino
    NSLog(@"Reading status for Arduino: %i", status);
    NSData *dataToSend = [[NSString stringWithFormat:@"%i",status] dataUsingEncoding:NSUTF8StringEncoding];
    
    //Attempt send
    if(self.serialPort && self.serialPort.open)
    {
        NSLog(@"Sending data...");
        [self.serialPort sendData:dataToSend];
        NSLog(@"Data sent");
    }
    else
    {
        NSLog(@"Error sending data to Ardunio over serial port: no port open");
    }
}


#pragma mark - RSS prompt
-(IBAction)launchRSSPrompt:(id)sender{
    
    NSString *newRssPath = nil;
    
    //Show prompt and take input
    NSString *rssPath = [self getPathToRSS];
    newRssPath = [self showTextInputWithTitle:kRSSPromptTitle andTextValue:rssPath];
    
    //Update path
    if([self setPathToRSS:newRssPath])
    {
        //Fetch new feed and update state locally and on Arduino
        //only if there was a change of URL
        [self updateArduinoWithJenkinsState];
    }
    
}

#pragma mark prompts
//This is a generic method to create a prompt with a text field and title
- (NSString *)showTextInputWithTitle: (NSString *)prompt andTextValue: (NSString *)defaultValue {
    NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 500, 24)];
    [[input cell] setWraps:NO];
    [[input cell] setScrollable:YES];
    [input setStringValue:defaultValue];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        return [input stringValue];
    } else if (button == NSAlertAlternateReturn) {
        return nil;
    } else {
        
        return nil;
    }
}

#pragma mark - rss path management
//Fetch and save the RSS path to NSUserDefaults
//Feel free to replace these calls with a simple Core Data DB
-(NSString*)getPathToRSS
{
    return [self getDefaultsStringWithKey:kURLKey];
}

-(BOOL)setPathToRSS:(NSString*)newRssPath
{    
    return [self setDefaultsString:newRssPath withKey:kURLKey];
}

-(NSString*)getLastJobName
{
    return [self getDefaultsStringWithKey:kJobKey];
}

-(BOOL)setLastJobName:(NSString*)jobName
{
    return [self setDefaultsString:jobName withKey:kJobKey];
}

-(NSString*)getLastBuildNumber
{
    return [self getDefaultsStringWithKey:kBuildKey];
}

-(BOOL)setLastBuildNumber:(NSString*)buildNumberString
{
    return [self setDefaultsString:buildNumberString withKey:kBuildKey];
}

-(NSString*)getLastJobURL
{
    return [self getDefaultsStringWithKey:kJobURLKey];
}

-(BOOL)setLastJobURL:(NSString*)jobURLPath
{
    return [self setDefaultsString:jobURLPath withKey:kJobURLKey];
}

-(NSString*)getLastBuildURL
{
    return [self getDefaultsStringWithKey:kBuildURLKey];
}

-(BOOL)setLastBuildURL:(NSString*)buildURLPath
{
    return [self setDefaultsString:buildURLPath withKey:kBuildURLKey];
}

-(NSString*)getLastBuildMessage
{
    return [self getDefaultsStringWithKey:kBuildMessageKey];
}

-(BOOL)setLastBuildMessage:(NSString*)buildMessage
{
    return [self setDefaultsString:buildMessage withKey:kBuildMessageKey];
}



#pragma mark - user defaults
-(NSString*)getDefaultsStringWithKey:(NSString*)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //Need to set default?
    if(![defaults objectForKey:key])
    {
        [defaults setObject:@"" forKey:key];
        [defaults synchronize];
    }
    
    return [defaults objectForKey:key];
    
}

-(BOOL)setDefaultsString:(NSString*)newString withKey:(NSString*)key{
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString *string = [defaults objectForKey:key];
    
    //Save result if changed
    if(newString && (!string || ![newString isEqualToString:string]))
    {
        [defaults setObject:newString forKey:key];
        [defaults synchronize];
        return YES;
    }
    
    return NO;
}


#pragma mark - button actions
-(IBAction)launchJobURL:(id)sender{
    
    NSString* jobURL = [self getLastJobURL];
    [self launchURL:jobURL];
    
}
-(IBAction)launchBuildURL:(id)sender{
    
    NSString* buildURL = [self getLastBuildURL];
    [self launchURL:buildURL];
}

-(void)launchURL:(NSString*)urlString{
    
    NSURL *url = [NSURL URLWithString:urlString];
    if( ![[NSWorkspace sharedWorkspace] openURL:url] ) NSLog(@"Failed to open url: %@",[url description]);
}

//Show the main window if it was closed
-(IBAction)openWindow:(id)sender{

    if(!_window.isVisible)
    {
        if(_window.windowController)
        {
            [_window.windowController showWindow:_window];
        }
    }
    
}
-(IBAction)closeWindow:(id)sender{
    
    if(_window.isVisible)
    {
        [_window performClose:self];
    }
    
}

-(IBAction)restore:(id)sender{
    
    if(_window.isMiniaturized)
    {
        [_window deminiaturize:self];
    }
    
}

#pragma mark - nsnotification delgate methods
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
	return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, object, keyPath);
	NSLog(@"Change dictionary: %@", change);
}

@end
