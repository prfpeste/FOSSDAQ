//=========================================================================================================================================================================
// ### NOTE ###
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// The base of this code must not be modified!
// The sections where card-specific code is inserted look the same as this note segment.
// For outputs controllable by NodeRed and readable inputs, the functions 'controll()' and 'measure()' are available.
// A card can EITHER read an input OR control output! Never both!
//
//=========================================================================================================================================================================



//=========================================================================================================================================================================
// Brief description of the code
//=========================================================================================================================================================================
//  1. Arduino starts with 'initStatus' = 0 and waits for 'serverID' message from RasPI. If the message is received, the Arduino sends its ID to the RaspberryPI and sets 'initStatus' = 1
//  2. Arduino waits for 'initStart' message from RasPI
//  3. Arduino receives 'initStart' message and sets 'initStatus' = 2
//  4. Arduino receives settings as int pairs (Index, Value), which are checked for validity and stored in the 'settings[]' array -> This settings step is optional if none are needed.
//  5. Arduino receives 'initEnd' message and sets 'initStatus' = 3
//  6. If settings are provided, it checks if all settings are valid (no value = 0). A checksum is also calculated and sent to the RasPI.
//              -> If no settings are provided, the message 'noSettings' is sent
//              -> 'initStatus' is now set to 4
//              -> At the end of this block, the card-specific setup part is inserted. This completes Arduino initialization, and it is ready for operation.
//  7. 'initStatus' = 4 means normal operation. The card-specific loop part goes here.
//
//  errorStatus() function
//      Sets 'ERROR' = true. This stops the code.
//      Executes card-specific safety measures (e.g., set all outputs to LOW).
//
//  measure() function
//      Arduino receives a message with an index, which selects the corresponding input.
//      The input value is read and sent to the RasPI.
//      If index is invalid: error message and call to errorStatus()
//
//  controll() function
//      Arduino receives a message in the format 'Index,State' (e.g., '0,1') and controls the corresponding output.
//      If index is invalid: error message and call to errorStatus()
//=========================================================================================================================================================================



//=========================================================================================================================================================================
// ### Variable and constant declaration ###
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#define N 6                 // Enter the number of settings here. A setting can have many possible arguments (e.g., setting0=shape, setting1=color).
#define noSettings 0        // If no settings are required, set 'noSettings' = 1. If settings are required, set 'noSettings' = 0.

String ID="ai-8x-0to3v3_";  // ID prefex of the specific Arduino. The '_' at the end is necessary!
// declare your own global constants here

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// declare your own global variables here
#include <SPI.h>
#include <EEPROM.h>
//=========================================================================================================================================================================



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



bool ERROR = false;     // Variable for error detection and shutdown of the microcontroller

int initStatus = 0;     // Initialization status:
                        // 0 -> Initialization not started ('serveID' message from Raspberry Pi not yet received)
                        // 1 -> Initialization not started ('initStart' message from Raspberry Pi not yet received)
                        // 2 -> Initialization started ('initStart' message from Raspberry Pi received, config messages are being received)
                        // 3 -> Initialization completion ('initEnd' message from Raspberry Pi received, checksum/standard message is sent, setup part for card function)
                        // 4 -> Initialization complete (normal operation from now on)

int settings[N] = {0};  // All elements are and must be zero!
                        // Indexing starts at 0. For n=10, this means indices 0 to 9.
                        // The value zero must be overwritten! It is used to detect if a setting is missing.
int checksum = 0;       // Checksum for verifying the settings



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



void setup() {

  Serial.begin(9600);    // Initialize serial interface with a baud rate of 9600.
  while (!Serial);       // Wait until the serial interface is fully initialized.

  pinMode(LED_BUILTIN, OUTPUT);    // Initialize builtin LED
  digitalWrite(LED_BUILTIN, LOW);  // turn OFF builtin LED
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



void loop() {

while (ERROR == 1) {                                                    // Stops code execution once an error is thrown.
  if (Serial.available() > 0) {                                         // if data is waiting in the serial buffer
    String received = Serial.readStringUntil('\n');                     // read incoming string up to the newline character
    received.trim();                                                    // strip leading/trailing whitespace, tabs, and newlines
    startInit(received);
  }
}

switch (initStatus) {

  //=======================================================================================================================================================================
  // The microcontroller always starts in case 0 after boot. In this mode, the microcontroller checks if the message 'serveID' has been received.
  // As long as this exact message is not received, the microcontroller remains in case 0.
  // Once the message 'serveID' is received, the Microcontroller sends its unique ID to RaspberryPI and stets the variable 'initStatus' to 1. This causes case 1 to be used in the next loop iteration.

  case 0:
    if (Serial.available() > 0) {                                         // if data is waiting in the serial buffer
      String received = Serial.readStringUntil('\n');                     // read incoming string up to the newline character
      received.trim();                                                    // strip leading/trailing whitespace, tabs, and newlines
      if (received == "ERROR") {                                          // check if Node-Red flow has stopped due to error
        errorStatus();
        return;
      }

    startInit(received);
      
    }
    break;



  //=======================================================================================================================================================================
  // In this mode, the microcontroller checks if the message 'initStart' has been received.
  // As long as this exact message is not received, the microcontroller remains in case 1.
  // Once the message 'initStart' is received, the variable 'initStatus' is set to 2. This causes case 2 to be used in the next loop iteration.

  case 1:                                                                 // Case 0: Initialization not started. Waiting for 'initStart' message.
    if (Serial.available() > 0) {                                         // if message received
      String received = Serial.readStringUntil('\n');                     // then read string until newline
      received.trim();                                                    // and remove all leading and trailing whitespace, tabs, and newlines from the string
      if (received == "ERROR") {                                          // check if Node-Red flow has stopped due to error
        errorStatus();
        return;
      }

      startInit(received);

      if (received == "initStart") {                                      // if received message == 'initStart',
        initStatus = 2;                                                   // then start initialization
      }
    }
    break;

  //======================================================================================================================================================================= 
  // In case 2, the microcontroller checks if a message has been received. If a message is received, it checks if it contains the message 'initEnd'.
  // If the message contains 'initEnd', the variable 'initStatus' is set to 3 and the switch case is exited. In the next loop iteration, case 3 will be used,
  // and the option to make settings is no longer available.
  // If the message does not contain 'initEnd', the code expects two comma-separated int values (e.g., 1,4). These two int values are then separated.
  // Each message contains a setting, which is stored in the 'settings' array. The first int value is the index, and the second is the setting.
  // The index specifies the position in the array where the second value should be entered. The first value, for example, represents the color setting, and the second 
  // value selects blue (The interpretation of the numerical values must always be implemented individually!).
  // The send settings are checked for validity. 
  // These settings can later be retrieved using the index.

  case 2:                                                                 // Case 1: Initialization started, waiting for settings or 'initEnd' message.
    if (Serial.available() > 0) {                                         // if message received,
      String received = Serial.readStringUntil('\n');                     // then read string until newline
      received.trim();                                                    // and remove all leading and trailing whitespace, tabs, and newlines from the string
      if (received == "ERROR") {                                          // check if Node-Red flow has stopped due to error
        errorStatus();
        return;
      }

      startInit(received);

      if (received == "initEnd") {                                        // if 'initEnd' was received,
        initStatus = 3;                                                   // then end initialization in the next iteration
        break;                                                            // and abort this iteration
      }

      if (noSettings == 0) {                                              // only execute if the length of the settings array is greater than zero 
        int commaIndexSet = received.indexOf(',');                        // store the index of the comma
        if (commaIndexSet != -1) {                                        // if a comma is present, 
          int indexSet = received.substring(0, commaIndexSet).toInt();    // then split the two comma-separated integers into two integer variables
          int setting = received.substring(commaIndexSet + 1).toInt();    // then split the two comma-separated integers into two integer variables

          if (indexSet < 0 || indexSet >= N) {
            Serial.println("ERROR: invalid index for settings");           // Send error message to NodeRed
            errorStatus();
            return;
          }

          switch (indexSet) {
            case 0:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;  
            case 1:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;  
            case 2:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;  
            case 3:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;  
            case 4:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;  
            case 5:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;  
            case 6:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;
            case 7:
              if (setting != 1 && setting != 2) {                         // if sent setting is NOT valid (query every valid setting with '!=' and link them with '&&'),
                Serial.print("ERROR: invalid setting at index: ");        // then send error message to NodeRed
                Serial.println(indexSet, DEC);                            // and send index of error to NodeRed
                errorStatus();                                            // and call the error function
                return;
              }
              break;
          }
          settings[indexSet] = setting;                                   // write setting to the correct position in the settings array
        }
      }
    }
    break;

  //=======================================================================================================================================================================
  // Case 3 checks if there are settings that need to be configured via NodeRed. If not, the message 'noSettings' is sent.
  // If yes, it checks if any setting has a value of zero. If so, an error message is sent, and the error state is triggered immediately.
  // If not (no setting value == 0), all setting values are summed into a checksum and sent to NodeRed.
  // Then, 'initStatus' is set to 4. This completes the initialization.
  //
  // Since this case can only be executed once, the setup part of the Arduino code is placed here.

  case 3:
    if (noSettings == 0) {                                                // only execute if noSettings equals zero

      for (int i = 0; i < N; i++) {                                       // for-loop that iterates through the entire settings array
        if (settings[i] == 0) {                                           // If the settings array contains a null at the current position,
          Serial.println("ERROR: at least one setting is invalid");       // and send an error message
          errorStatus();                                                  // call the error function
          return;
        }
      }

      for (int i = 0; i < N; i++) checksum += settings[i];                // sum all entries of the settings array to calculate the checksum
      Serial.println(checksum, DEC);                                      // send checksum (error detection in Node-RED)

    } else {
      Serial.println("noSettings");                                       // send string 'noSettings'
      }

    initStatus = 4;                                                       // initialization will be complete in the next iteration

    //=====================================================================================================================================================================
    // ### Insert card-specific setup code here ###
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------------
    if (settings[0] == 2) pinMode(A0, INPUT);
    if (settings[1] == 2) pinMode(A1, INPUT);
    if (settings[2] == 2) pinMode(A2, INPUT);
    if (settings[3] == 2) pinMode(A3, INPUT);
    if (settings[4] == 2) pinMode(A4, INPUT);
    if (settings[5] == 2) pinMode(A5, INPUT);
    if (settings[5] == 2) pinMode(A6, INPUT);
    if (settings[5] == 2) pinMode(A7, INPUT);
    //=====================================================================================================================================================================    
    break;

  //=======================================================================================================================================================================
  // Case 4 is the loop part of the Arduino code, which is repeated continuously.
  case 4:
    //=====================================================================================================================================================================
    // ### Insert card-specific loop code here ###
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------------
    controll(); // Example line for controlling an actor
    // measure(); // Example line for reading a sensor
    //=====================================================================================================================================================================
    break;

  default:
    break;
}
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



//=========================================================================================================================================================================
// The function 'controll()' is intended for controlling outputs. It can be called in the Loop Case 3 section. When the function is triggered, it first checks
// if a message has been received.
// If no message has been received, the function does nothing, and the loop continues.
// If a message has been received, the function proceeds.
//
// The function reads the message. It expects two integer values separated by a comma. The first integer value is used in a switch case to determine
// which case is used in this iteration of the function. Each case is intended for a specific output. The second integer value is the desired state of the selected output.
// '1,1' means: output 1 (Case 1) should be set to state 1 (e.g., TRUE).
// The microcontroller thus receives a command for a specific output in the form of two integer values, selects the output via the switch case, and sets it to the
// desired state.
//
// If an invalid value is received, an error message is sent, and the microcontroller enters an error state. To resolve the error state, it must be
// restarted.

void controll() {                                                         // function to control outputs
  if (Serial.available() > 0) {                                           // if message received 
    String received = Serial.readStringUntil('\n');                       // read string until newline
    received.trim();                                                      // remove leading and trailing whitespace, tabs, and newlines from the string
    if (received == "ERROR") {                                            // check if Node-Red flow has stopped due to error
      errorStatus();
      return;
    }
    int commaIndex = received.indexOf(',');                               // index of the comma
    int controllIndex = received.substring(0, commaIndex).toInt();        // split the two comma-separated integers into two integer variables
    int command = received.substring(commaIndex + 1).toInt();             // split the two comma-separated integers into two integer variables
  
    switch (controllIndex) {
      case 0:
        //=================================================================================================================================================================
        // ### // Insert specific code to control actor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        //=================================================================================================================================================================
        break;
      // If more outputs are present, add more cases. It must be documented which output corresponds to which index!

      default:
        Serial.println("ERROR: invalid index");                           // Send error message to NodeRed
        errorStatus();                                                    // Call the error function
        return;
    }  
  }
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



// The function 'measure()' is intended for reading inputs. It can be called in the Loop Case 3 section. When the function is triggered, it first checks
// if a message has been received.
// If no message has been received, the function does nothing, and the loop continues.
// If a message has been received, the function proceeds.
//
// The function reads the message. It expects an integer value. Based on this value, a switch case determines which case is used in this iteration of the function.
// Each case is intended for a specific input. At the end, the integer value 'measurement' is sent.
// The microcontroller thus receives a request for a specific input value in the form of a single integer value, selects this input via the switch case, and
// sends the read input value as a response.
//
// If an invalid value is received, an error message is sent, and the microcontroller enters an error state. To resolve the error state, it must be
// restarted.

void measure() {                                                          // function to read inputs
  if (Serial.available() > 0) {                                           // if message received 
    String received = Serial.readStringUntil('\n');                       // read string until newline
    received.trim();                                                      // remove leading and trailing whitespace, tabs, and newlines from the string
    if (received == "ERROR") {                                            // check if Node-Red flow has stopped due to error
      errorStatus();
      return;
    }
    int measureingIndex = received.toInt();                               // convert string to integer

    int measurement = 0;                                                  // declaration of the variable where the measurement value must be written.

    switch (measureingIndex) {
      case 0:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A0); 
        //=================================================================================================================================================================        
        break;

      case 1:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A1); 
        //=================================================================================================================================================================        
        break;

      case 2:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A2); 
        //=================================================================================================================================================================        
        break;

      case 3:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A3); 
        //=================================================================================================================================================================        
        break;

      case 4:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A4); 
        //=================================================================================================================================================================        
        break;

      case 5:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A5); 
        //=================================================================================================================================================================        
        break;

      case 6:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A6); 
        //=================================================================================================================================================================        
        break;

      case 7:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        measurement = analogRead(A7); 
        //=================================================================================================================================================================        
        break;

      // If more sensors are present, add more cases. It must be documented which input corresponds to which index!

      default:
        Serial.println("ERROR: ungueltiger Index");                       // Send error message to NodeRed
        errorStatus();                                                    // Call the error function
        return;

    }
    Serial.println(measurement, DEC);                                     // send measurement
  }
}


//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



// The error function 'errorStatus()' is always called when an error is detected. Here, it must be described what the microcontroller should do once in case of an error.
// For example: Set all outputs to FALSE.
// Finally, the current loop iteration is immediately terminated.

void errorStatus() {
  ERROR = true;                                                           // Activate error status -> Code stops in the next loop iteration.
  //=======================================================================================================================================================================
  // ### // Insert card-specific settings here to ensure a constant safe state ###
  //-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Turn off all outputs
  digitalWrite(5, LOW);
  digitalWrite(6, LOW);
  digitalWrite(9, LOW);
  digitalWrite(10, LOW);
  digitalWrite(3, LOW);
  digitalWrite(11, LOW);
  //=======================================================================================================================================================================
  digitalWrite(LED_BUILTIN, HIGH); // turn ON builtin LED
  return;                                                                 // Immediately terminate the loop iteration
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================

void digitalOutPWM(int OutPin, int command, int controllIndex) {
  if (settings[controllIndex] == 2) {                                     // check if pin is set to PWM
    if (command <= 255 && command >= 0) analogWrite(OutPin, command);     // check if command is valid. If true, write command to pin
    else {                                                                // else
      Serial.println("ERROR: invalid command");                           // Send error message to NodeRed
      errorStatus();                                                      // and call the error function
      return;   
    }   
  }

  if (settings[controllIndex] == 3) {                                     // check if pin is set to digital output
    if (command == 1) digitalWrite(OutPin, HIGH);                         // if command is equal to one, set pin to high
    else if (command == 0) digitalWrite(OutPin, LOW);                     // else if command is equal to zero, set pin to low
    else {                                                                // else
      Serial.println("ERROR: invalid command");                           // Send error message to NodeRed
      errorStatus();                                                      // and call the error function
      return;
    }
  }
}

void startInit(String received) {
  if (received == "serveID") {                                            // if the command received is 'serveID'
    initStatus=1;
    int rand;                                                       // will hold the device's ID (random or previously stored)
    int adresse = 0;                                                // EEPROM address where the ID is stored (2 bytes: high + low)

    byte highByteValue = EEPROM.read(adresse);                      // read high byte of stored ID from EEPROM
    byte lowByteValue = EEPROM.read(adresse + 1);                   // read low byte of stored ID from EEPROM

    if (highByteValue == 255 && lowByteValue == 255) {              // 0xFF/0xFF means EEPROM is unwritten -> no ID assigned yet
      randomSeed(analogRead(A0));                                   // seed the RNG using noise from an unconnected analog pin
      rand=random(0,32768);                                         // generate a new random ID (0-32767, fits in 15 bits/2 bytes)
      EEPROM.write(adresse, highByte(rand));                        // store high byte of the new ID in EEPROM
      EEPROM.write(adresse + 1, lowByte(rand));                     // store low byte of the new ID in EEPROM
    } else {
      rand = word(highByteValue, lowByteValue);                     // ID already exists -> reconstruct it from the two stored bytes
    }

    String ID_rand=ID+String(rand);                                 // build the full response string, e.g. "ID12345"
    Serial.println(ID_rand);                                        // send the ID back over serial
    for (int i = 0; i < N; i++) settings[i] = 0;
    checksum = 0;
    errorStatus();
    digitalWrite(LED_BUILTIN, LOW); // turn OFF builtin LED
    ERROR = false;
  }

}
