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

#define N 6                 // Number of settings. Not used by this card.
#define noSettings 1        // This card does not require settings.

String ID = "ai-4x-4to20mA_";  // ID prefix of the specific Arduino. The '_' at the end is necessary!

// declare your own global constants here
const int NUMBER_OF_SAMPLES = 10;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// declare your own global variables here
#include <SPI.h>
#include <EEPROM.h>
#include <Wire.h>
#include <Adafruit_INA219.h>


// INA219 devices

Adafruit_INA219 ina0(0x40);
Adafruit_INA219 ina1(0x41);
Adafruit_INA219 ina2(0x44);
Adafruit_INA219 ina3(0x45);


// Card-specific helper function
int readCurrent_uA(Adafruit_INA219 &sensor);

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

  case 1:
    if (Serial.available() > 0) {
      String received = Serial.readStringUntil('\n');
      received.trim();

      if (received == "ERROR") {
        errorStatus();
        return;
      }

      startInit(received);

      if (received == "initStart") {
        initStatus = 2;
      }
    }
    break;



  //=======================================================================================================================================================================
  // In case 2, the microcontroller checks if a message has been received. If a message is received, it checks if it contains the message 'initEnd'.
  // If the message contains 'initEnd', the variable 'initStatus' is set to 3 and the switch case is exited.
  //=======================================================================================================================================================================

  case 2:
    if (Serial.available() > 0) {

      String received = Serial.readStringUntil('\n');
      received.trim();

      if (received == "ERROR") {
        errorStatus();
        return;
      }

      startInit(received);

      if (received == "initEnd") {
        initStatus = 3;
        break;
      }

      if (noSettings == 0) {

        int commaIndexSet = received.indexOf(',');

        if (commaIndexSet != -1) {

          int indexSet = received.substring(0, commaIndexSet).toInt();
          int setting = received.substring(commaIndexSet + 1).toInt();

          if (indexSet < 0 || indexSet >= N) {
            Serial.println("ERROR: invalid index for settings");
            errorStatus();
            return;
          }

          switch (indexSet) {

            case 0:
              if (setting != 1 && setting != 2 && setting != 3) {
                Serial.print("ERROR: invalid setting at index: ");
                Serial.println(indexSet, DEC);
                errorStatus();
                return;
              }
              break;

            case 1:
              if (setting != 1 && setting != 2 && setting != 3) {
                Serial.print("ERROR: invalid setting at index: ");
                Serial.println(indexSet, DEC);
                errorStatus();
                return;
              }
              break;

            case 2:
              if (setting != 1 && setting != 2 && setting != 3) {
                Serial.print("ERROR: invalid setting at index: ");
                Serial.println(indexSet, DEC);
                errorStatus();
                return;
              }
              break;

            case 3:
              if (setting != 1 && setting != 2 && setting != 3) {
                Serial.print("ERROR: invalid setting at index: ");
                Serial.println(indexSet, DEC);
                errorStatus();
                return;
              }
              break;

            case 4:
              if (setting != 1 && setting != 2 && setting != 3) {
                Serial.print("ERROR: invalid setting at index: ");
                Serial.println(indexSet, DEC);
                errorStatus();
                return;
              }
              break;

            case 5:
              if (setting != 1 && setting != 2 && setting != 3) {
                Serial.print("ERROR: invalid setting at index: ");
                Serial.println(indexSet, DEC);
                errorStatus();
                return;
              }
              break;
          }

          settings[indexSet] = setting;
        }
      }
    }
    break;



  //=======================================================================================================================================================================
  // Case 3 checks if there are settings that need to be configured via NodeRed. If not, the message 'noSettings' is sent.
  //=======================================================================================================================================================================

  case 3:

    if (noSettings == 0) {

      for (int i = 0; i < N; i++) {
        if (settings[i] == 0) {
          Serial.println("ERROR: at least one setting is invalid");
          errorStatus();
          return;
        }
      }

      for (int i = 0; i < N; i++) checksum += settings[i];
      Serial.println(checksum, DEC);

    } else {
      Serial.println("noSettings");
    }

    initStatus = 4;


    //=====================================================================================================================================================================
    // ### Insert card-specific setup code here ###
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------------

    Wire.begin();


    // Initialize INA219 channel 0 - address 0x40
    if (!ina0.begin()) {
      Serial.println("ERROR: INA219 channel 0 not found");
      errorStatus();
      return;
    }
    ina0.setCalibration_32V_1A();


    // Initialize INA219 channel 1 - address 0x41
    if (!ina1.begin()) {
      Serial.println("ERROR: INA219 channel 1 not found");
      errorStatus();
      return;
    }
    ina1.setCalibration_32V_1A();


    // Initialize INA219 physical channel 2 - address 0x44
    if (!ina2.begin()) {
      Serial.println("ERROR: INA219 address 0x44 not found");
      errorStatus();
      return;
    }
    ina2.setCalibration_32V_1A();


    // Initialize INA219 physical channel 3 - address 0x45
    if (!ina3.begin()) {
      Serial.println("ERROR: INA219 address 0x45 not found");
      errorStatus();
      return;
    }
    ina3.setCalibration_32V_1A();

    //=====================================================================================================================================================================

    break;



  //=======================================================================================================================================================================
  // Case 4 is the loop part of the Arduino code, which is repeated continuously.
  //=======================================================================================================================================================================

  case 4:

    //=====================================================================================================================================================================
    // ### Insert card-specific loop code here ###
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------------

    measure();

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
// The function 'controll()' is intended for controlling outputs.
// This function is not used by this input card.
//=========================================================================================================================================================================

void controll() {

  if (Serial.available() > 0) {

    String received = Serial.readStringUntil('\n');
    received.trim();

    if (received == "ERROR") {
      errorStatus();
      return;
    }

    startInit(received);

    int commaIndex = received.indexOf(',');
    int controllIndex = received.substring(0, commaIndex).toInt();
    int command = received.substring(commaIndex + 1).toInt();

    switch (controllIndex) {

      case 0:
        //=================================================================================================================================================================
        // ### Insert specific code to control actor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Not used by this input card.
        //=================================================================================================================================================================
        break;

      case 1:
        //=================================================================================================================================================================
        // ### Insert specific code to control actor 1 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Not used by this input card.
        //=================================================================================================================================================================
        break;

      case 2:
        //=================================================================================================================================================================
        // ### Insert specific code to control actor 2 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Not used by this input card.
        //=================================================================================================================================================================
        break;

      case 3:
        //=================================================================================================================================================================
        // ### Insert specific code to control actor 3 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Not used by this input card.
        //=================================================================================================================================================================
        break;

      case 4:
        //=================================================================================================================================================================
        // ### Insert specific code to control actor 4 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Not used by this input card.
        //=================================================================================================================================================================
        break;

      case 5:
        //=================================================================================================================================================================
        // ### Insert specific code to control actor 5 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Not used by this input card.
        //=================================================================================================================================================================
        break;

      default:
        Serial.println("ERROR: invalid index");
        errorStatus();
        return;
    }
  }
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



// The function 'measure()' is intended for reading inputs. It can be called in the Loop Case 4 section.
// When the function is triggered, it first checks if a message has been received.
// If no message has been received, the function does nothing, and the loop continues.
//
// The function expects one integer value.
// The value selects the requested measurement channel:
//
// 0 -> Channel 1 -> INA219 address 0x40
// 1 -> Channel 2 -> INA219 address 0x41
// 2 -> Channel 3 -> INA219 address 0x45
// 3 -> Channel 4 -> INA219 address 0x44
//
// Channels 3 and 4 are intentionally swapped in software to match the housing labels.
//
// The measured current is returned in microamperes (uA).
// Negative INA219 readings are converted to positive values.
//
// Example:
// -4.28 mA -> 4280 uA
// 12.00 mA -> 12000 uA
// 20.00 mA -> 20000 uA
//
// Conversion from current to the physical sensor value is performed in Node-RED.

void measure() {                                                          // function to read inputs

  if (Serial.available() > 0) {                                           // if message received

    String received = Serial.readStringUntil('\n');                       // read string until newline
    received.trim();                                                      // remove leading and trailing whitespace, tabs, and newlines

    if (received == "ERROR") {                                            // check if Node-Red flow has stopped due to error
      errorStatus();
      return;
    }

    startInit(received);

    int measureingIndex = received.toInt();                               // convert string to integer

    int measurement = 0;                                                  // measured current in uA


    switch (measureingIndex) {


      case 0:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 1
        // INA219 address 0x40
        measurement = readCurrent_uA(ina0);

        //=================================================================================================================================================================
        break;


      case 1:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 1 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 2
        // INA219 address 0x41
        measurement = readCurrent_uA(ina1);

        //=================================================================================================================================================================
        break;


      case 2:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 2 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 3
        // Intentionally assigned to INA219 address 0x45
        // because channels 3 and 4 are swapped in the housing.
        measurement = readCurrent_uA(ina3);

        //=================================================================================================================================================================
        break;


      case 3:
        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 3 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 4
        // Intentionally assigned to INA219 address 0x44
        // because channels 3 and 4 are swapped in the housing.
        measurement = readCurrent_uA(ina2);

        //=================================================================================================================================================================
        break;


      default:

        Serial.println("ERROR: invalid index");
        errorStatus();
        return;
    }


    Serial.println(measurement, DEC);                                     // send measurement in uA
  }
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



// The error function 'errorStatus()' is always called when an error is detected.
// Finally, the current loop iteration is immediately terminated.

void errorStatus() {

  ERROR = true;                                                           // Activate error status -> Code stops in the next loop iteration.

  //=======================================================================================================================================================================
  // ### Insert card-specific settings here to ensure a constant safe state ###
  //-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

  // This card only reads inputs.
  // No outputs have to be switched to a safe state.

  //=======================================================================================================================================================================

  digitalWrite(LED_BUILTIN, HIGH);                                        // turn ON builtin LED

  return;                                                                 // Immediately terminate the loop iteration
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



void digitalOutPWM(int OutPin, int command, int controllIndex) {

  if (settings[controllIndex] == 2) {

    if (command <= 255 && command >= 0) {
      analogWrite(OutPin, command);
    }
    else {
      Serial.println("ERROR: invalid command");
      errorStatus();
      return;
    }
  }


  if (settings[controllIndex] == 3) {

    if (command == 1) {
      digitalWrite(OutPin, HIGH);
    }
    else if (command == 0) {
      digitalWrite(OutPin, LOW);
    }
    else {
      Serial.println("ERROR: invalid command");
      errorStatus();
      return;
    }
  }
}



//=========================================================================================================================================================================
// Start initialization and send unique card ID
//=========================================================================================================================================================================

void startInit(String received) {

  if (received == "serveID") {

    initStatus = 1;

    int rand;                                                       // will hold the device's ID (random or previously stored)
    int adresse = 0;                                                // EEPROM address where the ID is stored (2 bytes: high + low)

    byte highByteValue = EEPROM.read(adresse);                      // read high byte of stored ID from EEPROM
    byte lowByteValue = EEPROM.read(adresse + 1);                   // read low byte of stored ID from EEPROM


    if (highByteValue == 255 && lowByteValue == 255) {

      randomSeed(analogRead(A0));                                   // seed the RNG using noise from an unconnected analog pin

      rand = random(0, 32768);                                      // generate a new random ID

      EEPROM.write(adresse, highByte(rand));                        // store high byte
      EEPROM.write(adresse + 1, lowByte(rand));                     // store low byte
    }

    else {

      rand = word(highByteValue, lowByteValue);                     // reconstruct existing ID
    }


    String ID_rand = ID + String(rand);                             // build full card ID

    Serial.println(ID_rand);                                        // send ID to Raspberry Pi


    for (int i = 0; i < N; i++) {
      settings[i] = 0;
    }

    checksum = 0;

    errorStatus();

    digitalWrite(LED_BUILTIN, LOW);

    ERROR = false;
  }
}



//=========================================================================================================================================================================
// ### Card-specific helper function ###
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// Reads the INA219 current value.
// Multiple samples are averaged to reduce measurement noise.
// The result is always returned as a positive value in microamperes.
//
// Example:
// INA219 measurement: -4.28 mA
// Returned value:       4280 uA
//
//=========================================================================================================================================================================

int readCurrent_uA(Adafruit_INA219 &sensor) {

  float sumCurrent_mA = 0.0;


  // Take multiple measurements
  for (int i = 0; i < NUMBER_OF_SAMPLES; i++) {

    sumCurrent_mA += sensor.getCurrent_mA();

    delay(5);
  }


  // Calculate average current
  float averageCurrent_mA =
      sumCurrent_mA / NUMBER_OF_SAMPLES;


  // Convert negative measurements to positive values
  if (averageCurrent_mA < 0.0) {

    averageCurrent_mA = -averageCurrent_mA;
  }


  // Convert mA to uA
  int current_uA =
      (int)round(averageCurrent_mA * 1000.0);


  return current_uA;
}