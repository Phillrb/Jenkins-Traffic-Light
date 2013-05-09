
//  Arduino Jenkins Traffic Light
//  Listens to serial data from a PC / Mac over USB and 
//  changes 3 pins accordingly (attached to 3 LEDs / lights)
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

#include "pitches.h"

//Traffic light bulbs connected to these pins
const int redPin = 17;
const int yellowPin = 18;
const int greenPin = 19;

//Optional speaker for audio alerts on state change
const int speakerPin = 8; //uses a pwm pin 

//Available states for light
const int greenState = 0;
const int yellowState = 1;
const int redState = 2;
const int initState = 3;
const int unknownState = 4;

//Varaibles for light state
int currentState = initState;
int lastState = initState;

//Setup method is called once
void setup() 
{                
  // initialize the digital pins as output pins.
  pinMode(redPin, OUTPUT);     
  pinMode(yellowPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  
  // initialize serial connection to PC at a baud rate of 9600
  Serial.begin(9600);
}

//Main loop is continuously called
void loop()
{
 //display the status
  updateTrafficLight(currentState);
}

//Serial Event method fires when data is received from PC/Mac via USB
void serialEvent() 
{
  while (Serial.available()) {
    
    // get the new byte:
   char charState = (char)Serial.read();
   // Convert the byte to an int state
   int intState = digit_to_int(charState);
   
   //Check the state is actually valid before applying
   switch (intState)
   {
      case greenState:
      case yellowState:
      case redState:
      case initState:
      case  unknownState:
      {
        currentState = intState;
      }
      break;
      default:
      //Do nothing
      break;
   }
    
    //Confirm with the Mac/PC that status was received by echoing
    Serial.println(currentState);
  }
}

//Handy method to convert a byte to an int
int digit_to_int(char d)
{
 char str[2];

 str[0] = d;
 str[1] = '\0';
 return (int) strtol(str, NULL, 10);
}

//Play a short audio alert on the speaker
//Uses the 'pitches.h' file - probably overkill!
//Feel free to play an interesting melody - perhaps the Imperial March?! 
void playAudioAlert()
{
  tone(speakerPin,NOTE_CS7,400);
  delay(250);
  
  tone(speakerPin,NOTE_DS7,1000);
  delay(500);
}

//This is the main method that is continuously called from the Main Loop
void updateTrafficLight(int _currentState)
{
  
  //If nothing changed or there was a minor state change - just update the light
  if(_currentState == lastState || _currentState == lastState + 1 || _currentState == lastState - 1)
  {
      displayState(_currentState);
  }
  else
  {
    //If the state is Yellow, init or unknown then just light the yellow bulb
    if(_currentState == initState || _currentState == unknownState || _currentState == yellowState)
    {
      Serial.println("INIT. UNKNOWN OR YELLOW");
      displayState(_currentState);
    }
    else
    {
      //If there is a major change of status (green to red or vice versa) then
      //transition like a real traffic light
      if(_currentState == greenState)
      {
        Serial.print("BIG CHANGE TO GREEN: ");
        Serial.println(_currentState);
        
        // RED => GREEN (show yellow and red together for a few seconds)
          digitalWrite(redPin, HIGH); 
          digitalWrite(yellowPin, HIGH); 
          digitalWrite(greenPin, LOW);
      }
      else if(_currentState == redState)
      {
        // GREEN => RED - just show yellow briefly before transition to red
        Serial.print("BIG CHANGE TO RED: ");
        Serial.println(_currentState);
          displayState(yellowState);    
      }
    
        //Wait and then finally move to new state
        Serial.println("WAIT");
         delay(2000);
         displayState(_currentState);
      }
  }
  
  //Sound the audio alert - optional!
  if(_currentState != lastState)
  {
    playAudioAlert();
  }
  
    //Update lastState
    lastState = _currentState;
}

//Updates the light according to status
void displayState(int _currentState)
{
  switch (_currentState)
  {
     case yellowState :
     {
       //YELLOW LIGHT
        digitalWrite(redPin, LOW);
        digitalWrite(yellowPin, HIGH);
        digitalWrite(greenPin, LOW);
     }
     break;
     
     case redState :
     {
       //RED LIGHT
        digitalWrite(redPin, HIGH);
        digitalWrite(yellowPin, LOW);
        digitalWrite(greenPin, LOW);
     }
     break;

     case greenState :
     {
       //GREEN LIGHT
        digitalWrite(redPin, LOW);
        digitalWrite(yellowPin, LOW);
        digitalWrite(greenPin, HIGH);
     }
     break;
     
     case initState :
     {
        //Make the lights chase to signify that the status is not yet set
        displayState(greenState);
        delay(500);
        displayState(yellowState);
        delay(500);
        displayState(redState);
        delay(500);
     }
     break;
     
     //Make all the lights flash on and off
     //State is unknown
     case unknownState :
     default :
     {
        //Flash on / off
          digitalWrite(redPin, HIGH); 
          digitalWrite(yellowPin, HIGH); 
          digitalWrite(greenPin, HIGH);
          delay(1000);
          
          digitalWrite(redPin, LOW); 
          digitalWrite(yellowPin, LOW); 
          digitalWrite(greenPin, LOW);
          delay(1000);
     }
     break;
  }
  
}




