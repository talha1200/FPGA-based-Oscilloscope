int potPin0 = A0; // Analog Input
int potPin1 = A1; // Analog Input
int potPin2 = A2; // Analog Input

int Pin1[4] = {0, 1, 2, 3};     // Output pins for Time
int Pin2[4] = {4, 5, 6, 7};     // Output pins for Voltage
int Pin3[8] = {8, 9, 10, 11, 12, 13, A3, A4}; // Output pins for Trigger

int Value1 = 0; // Time knob
int Value2 = 0; // Voltage knob
int Value3 = 0; // Trigger knob

int out1; // Mapped output for Time
int out2; // Mapped output for Voltage
int out3; // Mapped output for Trigger

int Trigger[8]; // Array to store Trigger data
int Time[4];    // Array to store Time data
int Volt[4];    // Array to store Voltage data

int N1, N2, N3, N4;
int X1, X2, X3;

// Defining Input and Output Pins of ATMEGA 328
void setup() {
  for (int i = 0; i < 4; i++) {
    pinMode(Pin1[i], OUTPUT);  // Time pins
    pinMode(Pin2[i], OUTPUT);  // Voltage pins
  }

  for (int i = 0; i < 8; i++) {
    pinMode(Pin3[i], OUTPUT);  // Trigger pins
  }

  // Defining Analog pins A3 and A4 as digital pins
  pinMode(A3, OUTPUT);
  pinMode(A4, OUTPUT);
}

void loop() {
  // Reading Analog Data
  Value1 = analogRead(potPin0); // Time knob
  Value2 = analogRead(potPin1); // Voltage knob
  Value3 = analogRead(potPin2); // Trigger knob

  // Mapping the Analog values to corresponding bits
  out1 = map(Value1, 0, 1023, 0, 15);  // 4-bit mapping for Time
  out2 = map(Value2, 0, 1023, 0, 15);  // 4-bit mapping for Voltage
  out3 = map(Value3, 0, 1023, 0, 255); // 8-bit mapping for Trigger

  // Convert and store Time and Voltage data into respective arrays
  for (N1 = 0; N1 < 4; N1++) {
    X1 = bitRead(out1, N1);  // Convert Time data into 1’s and 0’s
    X2 = bitRead(out2, N1);  // Convert Voltage data into 1’s and 0’s
    Time[N1] = X1;           // Store Time data into array
    Volt[N1] = X2;           // Store Voltage data into array
  }

  // Convert and store Trigger data into array
  for (N1 = 0; N1 < 8; N1++) {
    X3 = bitRead(out3, N1);  // Convert Trigger data into 1’s and 0’s
    Trigger[N1] = X3;        // Store Trigger data into array
  }

  // Time/division Knob output
  for (N2 = 0; N2 < 4; N2++) {
    if (Time[N2] == 1) {
      digitalWrite(Pin1[N2], HIGH); // Send HIGH signal to output
    } else {
      digitalWrite(Pin1[N2], LOW);  // Send LOW signal to output
    }
  }

  // Voltage/division Knob output
  for (N3 = 0; N3 < 4; N3++) {
    if (Volt[N3] == 1) {
      digitalWrite(Pin2[N3], HIGH); // Send HIGH signal to output
    } else {
      digitalWrite(Pin2[N3], LOW);  // Send LOW signal to output
    }
  }

  // Trigger/division Knob output
  for (N4 = 0; N4 < 8; N4++) {
    if (Trigger[N4] == 1) {
      digitalWrite(Pin3[N4], HIGH); // Send HIGH signal to output
    } else {
      digitalWrite(Pin3[N4], LOW);  // Send LOW signal to output
    }
  }
}
