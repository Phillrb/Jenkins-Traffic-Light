//
//  AppDelegate.h
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

#import <Cocoa/Cocoa.h>
#import "ORSSerialPort.h"

@class ORSSerialPortManager;

enum trafficLightState {
    greenState = 0,
    yellowState = 1,
    redState = 2,
    initState = 3, //The very first state - can display some nice chasing pattern during this stage
    unknownState = 4 //Didn't get data from the feed - can display all blinking
    };

#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_7)
@protocol NSUserNotificationCenterDelegate <NSObject>
@end
#endif

@interface AppDelegate : NSObject <NSApplicationDelegate, ORSSerialPortDelegate, NSUserNotificationCenterDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSBox *redBox;
@property (assign) IBOutlet NSBox *yellowBox;
@property (assign) IBOutlet NSBox *greenBox;
@property (assign) IBOutlet NSTextField *buildLabel;
@property (assign) IBOutlet NSProgressIndicator *progress;

@property (assign) IBOutlet NSMenu *statusBarMenu;
@property (assign) IBOutlet NSMenuItem *rssNameMenuItem;
@property (assign) IBOutlet NSMenuItem *buildMenuItem;
@property (assign) IBOutlet NSMenuItem *buildStatusMenuItem;

@property (nonatomic, strong) ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSStatusItem * statusBarIcon;
@property (nonatomic, strong) NSWindowController *windowController;

-(IBAction)launchRSSPrompt:(id)sender;
-(IBAction)fetchStatusFromRSSNow:(id)sender;
-(IBAction)launchJobURL:(id)sender;
-(IBAction)launchBuildURL:(id)sender;
-(IBAction)openWindow:(id)sender;
-(IBAction)closeWindow:(id)sender;

@end
