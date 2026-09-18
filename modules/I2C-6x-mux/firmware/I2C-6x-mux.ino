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

#define N 1                    // No settings needed for this board (see noSettings below) - array kept at minimal size.
#define noSettings 1           // i2c-6x-mux has no handshake-configurable settings -> 'noSettings' message is sent, settings[] stays unused.

String ID="I2C-6x-mux_";      // ID prefix of the specific Arduino. The '_' at the end is necessary!
// declare your own global constants here
#define MUX_ENABLE_PIN D2     // I2C multiplexer enable pin
#define MUX_UNUSED_PIN_1 D3
#define MUX_UNUSED_PIN_2 D4
#define MUX_UNUSED_PIN_3 D5

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// declare your own global variables here
#include <SPI.h>
#include <EEPROM.h>
#include <Wire.h>
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

int settings[N] = {0};  // Unused for this board (noSettings = 1), kept only because the base protocol expects the array to exist.
int checksum = 0;       // Checksum for verifying the settings



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



void setup() {

  // ### card-specific: enable the I2C multiplexer before anything else happens ###
  //---------------------------------------------------------------------------------------------------------------------------------------------------------------------
  pinMode(MUX_ENABLE_PIN, OUTPUT);
  digitalWrite(MUX_ENABLE_PIN, LOW);    // D2 LOW -> multiplexer powered off

  pinMode(MUX_UNUSED_PIN_1, OUTPUT);
  digitalWrite(MUX_UNUSED_PIN_1, LOW);  // D3 LOW

  pinMode(MUX_UNUSED_PIN_2, OUTPUT);
  digitalWrite(MUX_UNUSED_PIN_2, LOW);  // D4 LOW

  pinMode(MUX_UNUSED_PIN_3, OUTPUT);
  digitalWrite(MUX_UNUSED_PIN_3, LOW);  // D5 LOW
  //=========================================================================================================================================================================

  Wire.begin();           // I2C-Bus starten (Multiplexer + dahinterliegende Sensoren hängen daran)

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
  // Since noSettings = 1 for this board, no settings pairs are expected - it just waits for 'initEnd'.

  case 2:                                                                 // Case 1: Initialization started, waiting for 'initEnd' message.
    if (Serial.available() > 0) {                                         // if message received,
      String received = Serial.readStringUntil('\n');                     // then read string until newline
      received.trim();                                                    // and remove all leading and trailing whitespace, tabs, and newlines from the string
      if (received == "ERROR") {                                          // check if Node-Red flow has stopped due to error
        errorStatus();
        return;
      }

      if (startInit(received)) return;

      if (received == "initEnd") {                                        // if 'initEnd' was received,
        initStatus = 3;                                                   // then end initialization in the next iteration
        break;                                                            // and abort this iteration
      }

      // noSettings == 1 for this board -> no settings pairs are parsed here.
    }
    break;

  //=======================================================================================================================================================================
  // Case 3: since noSettings = 1, 'noSettings' is sent directly (no checksum check needed).

  case 3:
    if (noSettings == 0) {                                                // not used for this board (noSettings = 1)

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
      digitalWrite(MUX_ENABLE_PIN, HIGH);   // D2 HIGH -> multiplexer powered/enabled
    //=====================================================================================================================================================================    
    break;

  //=======================================================================================================================================================================
  // Case 4 is the loop part of the Arduino code, which is repeated continuously.
  case 4:
    //=====================================================================================================================================================================
    // ### Insert card-specific loop code here ###
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------------
    measure(); // i2c-6x-mux is a sensor-only board -> only measure(), never controll()
    //=====================================================================================================================================================================
    break;

  default:
    break;
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
// The function reads the message. It expects an integer value (0-5), selecting one of the 6 multiplexer channels.
// Each case selects the corresponding mux channel and reads its downstream I2C sensor. At the end, the integer value 'measurement' is sent as ASCII decimal.
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

    if (startInit(received)) return;
    
    int measurement = 0;                                                  // declaration of the variable where the measurement value must be written.

    switch (measureingIndex) {
      case 0:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 (mux channel 0) here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        tcaSelect(0);
        // measurement = readSensor();  // TODO: replace with the actual I2C read for the sensor on this channel
        //=================================================================================================================================================================        
        break;

      case 1:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 1 (mux channel 1) here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        tcaSelect(1);
        // measurement = readSensor();  // TODO: replace with the actual I2C read for the sensor on this channel
        //=================================================================================================================================================================        
        break;

      case 2:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 2 (mux channel 2) here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        tcaSelect(2);
        // measurement = readSensor();  // TODO: replace with the actual I2C read for the sensor on this channel
        //=================================================================================================================================================================        
        break;

      case 3:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 3 (mux channel 3) here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        tcaSelect(3);
        // measurement = readSensor();  // TODO: replace with the actual I2C read for the sensor on this channel
        //=================================================================================================================================================================        
        break;

      case 4:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 4 (mux channel 4) here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        tcaSelect(4);
        // measurement = readSensor();  // TODO: replace with the actual I2C read for the sensor on this channel
        //=================================================================================================================================================================        
        break;

      case 5:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 5 (mux channel 5) here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        tcaSelect(5);
        // measurement = readSensor();  // TODO: replace with the actual I2C read for the sensor on this channel
        //=================================================================================================================================================================        
        break;

      // If more sensors are present, add more cases. It must be documented which input corresponds to which index!

      default:
        Serial.println("ERROR: invalid index");                          // Send error message to NodeRed
        errorStatus();                                                    // Call the error function
        return;

    }
    Serial.println(measurement, DEC);                                     // send measurement (ASCII decimal, as expected by fossdaq-config.js)
  }
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



// Selects one of the 8 possible channels on a TCA9548A-style I2C multiplexer.
// Adjust MUX_I2C_ADDR to your mux's actual address if it differs from the default 0x70.
#define MUX_I2C_ADDR 0x70

void tcaSelect(uint8_t channel) {
  if (channel > 7) return;
  Wire.beginTransmission(MUX_I2C_ADDR);
  Wire.write(1 << channel);
  Wire.endTransmission();
}



//=========================================================================================================================================================================
//#########################################################################################################################################################================
//=========================================================================================================================================================================



// The error function 'errorStatus()' is always called when an error is detected. Here, it must be described what the microcontroller should do once in case of an error.
// For example: Set all outputs to FALSE.
// Finally, the current loop iteration is immediately terminated.

void errorStatus() {
  ERROR = true;                                                           // Activate error status -> Code stops in the next loop iteration.
  //=======================================================================================================================================================================
  // ### // Insert card-specific settings here to ensure a constant safe state ###
  //-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  digitalWrite(MUX_ENABLE_PIN, LOW);    // D2 LOW -> multiplexer powered off
  //=======================================================================================================================================================================
  digitalWrite(LED_BUILTIN, HIGH); // turn ON builtin LED
  return;                                                                 // Immediately terminate the loop iteration
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================

bool startInit(String received) {
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
    return true;
  }
  return false;

}
