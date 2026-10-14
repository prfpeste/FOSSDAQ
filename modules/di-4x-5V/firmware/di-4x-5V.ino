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

String ID = "di-4x-5V_";   // ID prefix of the specific Arduino. The '_' at the end is necessary!

// declare your own global constants here

const byte HALL_PIN_0 = 2;
const byte HALL_PIN_1 = 3;
const byte HALL_PIN_2 = 8;
const byte HALL_PIN_3 = 12;

const unsigned long MEASUREMENT_TIME_MS = 1000;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// declare your own global variables here

#include <SPI.h>
#include <EEPROM.h>

// Pulse counters for the four digital inputs
volatile unsigned long pulseCount0 = 0;
volatile unsigned long pulseCount1 = 0;
volatile unsigned long pulseCount2 = 0;
volatile unsigned long pulseCount3 = 0;


// Card-specific function declarations
void countPulse0();
void countPulse1();
void countPulse2();
void countPulse3();

int measureFrequencyX100(volatile unsigned long &pulseCounter);

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
                        // Indexing starts at 0.
                        // The value zero must be overwritten if settings are used.
int checksum = 0;       // Checksum for verifying the settings



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



void setup() {

  Serial.begin(9600);    // Initialize serial interface with a baud rate of 9600.
  while (!Serial);       // Wait until the serial interface is fully initialized.

  pinMode(LED_BUILTIN, OUTPUT);    // Initialize builtin LED
  digitalWrite(LED_BUILTIN, LOW);  // Turn OFF builtin LED
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



void loop() {

while (ERROR == 1) {

  if (Serial.available() > 0) {

    String received = Serial.readStringUntil('\n');
    received.trim();

    startInit(received);
  }
}


switch (initStatus) {


  //=======================================================================================================================================================================
  // The microcontroller always starts in case 0 after boot.
  //=======================================================================================================================================================================

  case 0:

    if (Serial.available() > 0) {

      String received = Serial.readStringUntil('\n');
      received.trim();

      if (received == "ERROR") {

        errorStatus();
        return;
      }

      startInit(received);
    }

    break;



  //=======================================================================================================================================================================
  // Wait for 'initStart'
  //=======================================================================================================================================================================

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
  // Wait for settings or 'initEnd'
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
  // Complete initialization
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


      for (int i = 0; i < N; i++) {

        checksum += settings[i];
      }


      Serial.println(checksum, DEC);


    } else {

      Serial.println("noSettings");
    }


    initStatus = 4;


    //=====================================================================================================================================================================
    // ### Insert card-specific setup code here ###
    //---------------------------------------------------------------------------------------------------------------------------------------------------------------------

    // Configure Hall-effect sensor inputs
    pinMode(HALL_PIN_0, INPUT);
    pinMode(HALL_PIN_1, INPUT);
    pinMode(HALL_PIN_2, INPUT);
    pinMode(HALL_PIN_3, INPUT);


    // Attach interrupts to count rising signal edges
    attachInterrupt(digitalPinToInterrupt(HALL_PIN_0), countPulse0, RISING);
    attachInterrupt(digitalPinToInterrupt(HALL_PIN_1), countPulse1, RISING);
    attachInterrupt(digitalPinToInterrupt(HALL_PIN_2), countPulse2, RISING);
    attachInterrupt(digitalPinToInterrupt(HALL_PIN_3), countPulse3, RISING);

    //=====================================================================================================================================================================

    break;



  //=======================================================================================================================================================================
  // Normal operation
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

        // Not used by this input card.

        break;


      case 1:

        // Not used by this input card.

        break;


      case 2:

        // Not used by this input card.

        break;


      case 3:

        // Not used by this input card.

        break;


      case 4:

        // Not used by this input card.

        break;


      case 5:

        // Not used by this input card.

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



// The function 'measure()' is intended for reading inputs.
//
// The Raspberry Pi sends one integer value from 0 to 3.
//
// Channel assignment:
//
// 0 -> Channel 1 -> D2
// 1 -> Channel 2 -> D3
// 2 -> Channel 3 -> D8
// 3 -> Channel 4 -> D12
//
// The Arduino counts rising edges for one second.
// The resulting frequency is transmitted as Hz x 100.
//
// Example:
//
// 73.40 Hz -> 7340
//
// The Arduino does NOT convert the frequency into flow rate.
// Sensor-specific conversion is performed later in Node-RED.

void measure() {


  if (Serial.available() > 0) {


    String received = Serial.readStringUntil('\n');

    received.trim();


    if (received == "ERROR") {

      errorStatus();

      return;
    }


    startInit(received);


    int measureingIndex = received.toInt();


    int measurement = 0;


    switch (measureingIndex) {


      case 0:

        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 0 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 1
        // Digital input D2
        measurement = measureFrequencyX100(pulseCount0);

        //=================================================================================================================================================================

        break;



      case 1:

        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 1 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 2
        // Digital input D3
        measurement = measureFrequencyX100(pulseCount1);

        //=================================================================================================================================================================

        break;



      case 2:

        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 2 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 3
        // Digital input D8
        measurement = measureFrequencyX100(pulseCount2);

        //=================================================================================================================================================================

        break;



      case 3:

        //=================================================================================================================================================================
        // ### Insert specific code to read the measurement value from sensor 3 here ###
        //-----------------------------------------------------------------------------------------------------------------------------------------------------------------

        // Housing channel 4
        // Digital input D12
        measurement = measureFrequencyX100(pulseCount3);

        //=================================================================================================================================================================

        break;



      default:

        Serial.println("ERROR: invalid index");

        errorStatus();

        return;
    }


    Serial.println(measurement, DEC);
  }
}



//=========================================================================================================================================================================
//#########################################################################################################################################################################
//=========================================================================================================================================================================



// The error function 'errorStatus()' is always called when an error is detected.

void errorStatus() {


  ERROR = true;


  //=======================================================================================================================================================================
  // ### Insert card-specific settings here to ensure a constant safe state ###
  //-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

  // This card only reads digital inputs.
  // No outputs have to be switched to a safe state.

  //=======================================================================================================================================================================


  digitalWrite(LED_BUILTIN, HIGH);


  return;
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


    int rand;

    int adresse = 0;


    byte highByteValue = EEPROM.read(adresse);

    byte lowByteValue = EEPROM.read(adresse + 1);


    if (highByteValue == 255 && lowByteValue == 255) {


      randomSeed(analogRead(A0));


      rand = random(0, 32768);


      EEPROM.write(adresse, highByte(rand));

      EEPROM.write(adresse + 1, lowByte(rand));
    }


    else {


      rand = word(highByteValue, lowByteValue);
    }



    String ID_rand = ID + String(rand);


    Serial.println(ID_rand);


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
// ### Card-specific interrupt functions ###
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// Each interrupt function increments the pulse counter of one input channel.
//
//=========================================================================================================================================================================

void countPulse0() {

  pulseCount0++;
}


void countPulse1() {

  pulseCount1++;
}


void countPulse2() {

  pulseCount2++;
}


void countPulse3() {

  pulseCount3++;
}



//=========================================================================================================================================================================
// ### Card-specific frequency measurement function ###
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// Counts the pulses of the selected channel during the measurement interval.
//
// The measured frequency is returned as Hz x 100.
//
// Example:
//
// 73.40 Hz -> 7340
//
// This allows two decimal places to be transmitted as an integer.
//
//=========================================================================================================================================================================

int measureFrequencyX100(volatile unsigned long &pulseCounter) {


  // Reset selected pulse counter
  noInterrupts();

  pulseCounter = 0;

  interrupts();



  // Start measurement interval
  unsigned long startTime = micros();


  delay(MEASUREMENT_TIME_MS);


  unsigned long endTime = micros();



  // Copy pulse counter safely
  noInterrupts();

  unsigned long pulses = pulseCounter;

  interrupts();



  // Calculate actual measurement time
  unsigned long elapsedTime = endTime - startTime;



  // Calculate frequency in Hz
  float frequencyHz =
      ((float)pulses * 1000000.0) / (float)elapsedTime;



  // Scale frequency by 100 for integer transmission
  int frequencyX100 =
      (int)round(frequencyHz * 100.0);



  return frequencyX100;
}