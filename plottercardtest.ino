//
//  drive the bench test of the 5806223 card replacement that is the controller
//  for the IBM 1627 plotter models 1 or 2, as well as the Calcomp 565 and 563
//
//  uses direct port access for the digital writes to operate fast enough
//  to bitbang the memory access cycles from the IBM 1130 computer
//  that occur to drive the card with commands to the plotter
//  or sense requests, interrupt resets and overall card resets
//
//  designed for an Arduino Uno - if a different controller used,
//  port mapping may change and need to be reflected in the code 
//
//
// port D bits 2 to 7 below
#define T6 2
#define XIOS 3
#define XIOS15 4
#define DCRESET 5
#define B0 6
#define B1 7
// port B bits 0 to 5 below
#define B2 8
#define B3 9
#define B4 10
#define B5 11
#define XIOW 12
#define A5 13
// reuse analog inputs as digital inputs for buttons 
#define resetit A0
#define doup A1
#define doraise A2
#define sense A3
#define sensereset A4
#define doboth 19

// digital pin direct access snippets
// inserted into bit manipulation statemens
// against PORTD or PORTB to control outputs
#define PIN2 (1 << 2)
#define PIN3 (1 << 3)
#define PIN4 (1 << 4)
#define PIN5 (1 << 5)
#define PIN6 (1 << 6)
#define PIN7 (1 << 7)
#define PIN8 (1 << 0)
#define PIN9 (1 << 1)
#define PIN10 (1 << 2)
#define PIN11 (1 << 3)
#define PIN12 (1 << 4)
#define PIN13 (1 << 5)

void setup() {
  // set the state of the digital pins 2-13
  // and the five analog pins A0-A5 (14-19)
  pinMode (XIOW, OUTPUT);
  pinMode (A5, OUTPUT);
  pinMode (T6, OUTPUT);
  pinMode (XIOS, OUTPUT);
  pinMode (XIOS15, OUTPUT);
  pinMode (DCRESET, OUTPUT);
  pinMode (B0, OUTPUT);
  pinMode (B1, OUTPUT);
  pinMode (B2, OUTPUT);
  pinMode (B3, OUTPUT);
  pinMode (B4, OUTPUT);
  pinMode (B5, OUTPUT);

  // set the states of the six button inputs
  // that request specific actions from this code
  pinMode (resetit, INPUT_PULLUP);
  pinMode (doup, INPUT_PULLUP);
  pinMode (doraise, INPUT_PULLUP);
  pinMode (sense, INPUT_PULLUP);
  pinMode (sensereset, INPUT_PULLUP);
  pinMode (doboth, INPUT_PULLUP);

  // begin with card in reset state (inverted logic)
  digitalWrite(DCRESET, LOW);

  // now set the output initial states
  // below control inputs are standard, true when high
  digitalWrite(XIOW, LOW);
  digitalWrite(A5, LOW);
  digitalWrite(T6, LOW);
  digitalWrite(XIOS, LOW);
  digitalWrite(XIOS15, LOW);
  // below control inputs are inverted, true when low
  digitalWrite(B0, HIGH);
  digitalWrite(B1, HIGH);
  digitalWrite(B2, HIGH);
  digitalWrite(B3, HIGH);
  digitalWrite(B4, HIGH);
  digitalWrite(B5, HIGH);
  delay(500);

  // release the reset from the board
  digitalWrite(DCRESET, HIGH);

  // open diagnostic serial link
  Serial.begin(9600);
  Serial.println("Testbed ready"); 
}

void loop() {
  // process any button pushes 
  if (digitalRead(resetit) == HIGH) {
    // hold reset for half a second then release
    digitalWrite(DCRESET, LOW);
    delay(500);
    digitalWrite(DCRESET, HIGH);
    Serial.println("card reset");
    delay (1500);      // debounce time for my finger on button
  } else if (digitalRead(sense) == HIGH) {
    // simulate the 1130 executing an XIO Sense Device for plotter
    // one memory cycle (8 T clock steps)
    PORTD |= PIN3; // XIOS
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD &= ~PIN3; // ~XIOS
    PORTB &= ~PIN13; // ~A5
    Serial.println("Sense");
    delay (2000);      // debounce time for my finger on button
  } else if (digitalRead(sensereset) == HIGH) {
    // simulate an XIO Sense Device with reset bit 15 turned on
    // one memory cycle (8 T clock steps)
    PORTD |= PIN3; // XIOS
    PORTB |= PIN13; // A5
    PORTD |= PIN4; // XIOS15
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD &= ~PIN3; // ~XIOS
    PORTD &= ~PIN4; // ~XIOS15
    PORTB &= ~PIN13; // ~A5
    Serial.println("Sense Reset 15");
    delay (2000);      // debounce time for my finger on button
  } else if (digitalRead(doup) == HIGH) {
    // simulate an XIO Write with B Bit 2 set (move drumup)
    // one memory cycle but only activates at T6 clock step
    PORTB |= PIN12; // XIOW
    PORTB |= PIN13; // A5
    PORTB &= ~PIN8; // ~B2
    PORTB &= ~PIN8; // ~B2
    PORTB &= ~PIN8; // ~B2
    PORTB &= ~PIN8; // ~B2
    PORTD |= PIN2; // T6
    PORTD &= ~PIN2; // ~T6
    PORTB &= ~PIN13; // ~A5
    PORTB &= ~PIN12; // ~XIOW
    PORTB |= PIN8; // B2
    // wait 1 millisecond then execute XIO Sense Device
    delay(1);
    PORTD |= PIN3; // XIOS
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD &= ~PIN3; // ~XIOS
    PORTB &= ~PIN13; // ~A5
    Serial.println("Drum up");
    delay (2000);      // debounce time for my finger on button
  } else if (digitalRead(doraise) == HIGH) {
    // simulate an XIO Write with B Bit 5 set (raise pen off paper)
    // one memory cycle but only activates at T6 clock step
    PORTB |= PIN12; // XIOW
    PORTB |= PIN13; // A5
    PORTB &= ~PIN11; // ~B5
    PORTB &= ~PIN11; // ~B5
    PORTB &= ~PIN11; // ~B5
    PORTB &= ~PIN11; // ~B5
    PORTD |= PIN2; // T6
    PORTD &= ~PIN2; // ~T6
    PORTB &= ~PIN13; // ~A5
    PORTB &= ~PIN12; // ~XIOW
    PORTB |= PIN11; // B5
    // wait 1 millisecond then execute XIO Sense Device
    delay(1);
    PORTD |= PIN3; // XIOS
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD &= ~PIN3; // ~XIOS
    PORTB &= ~PIN13; // ~A5
    Serial.println("Raise pen");
    delay (2000);      // debounce time for my finger on button
  } else if (digitalRead(doboth) == HIGH) {    
    // simulate an XIO Write with two B bits set
    // B Bit 0 (lower pen on paper) and B Bit 1 (move pen right)
    // one memory cycle but only activates at T6 clock step
    PORTB |= PIN12; // XIOW
    PORTB |= PIN13; // A5
//    PORTD &= ~PIN6; // ~B0
    PORTD &= ~PIN7; // ~B1
    PORTD &= ~PIN7; // ~B1
    PORTD |= PIN2; // T6
    PORTD &= ~PIN2; // ~T6
    PORTB &= ~PIN13; // ~A5
    PORTB &= ~PIN12; // ~XIOW
    PORTD |= PIN6; // B0
    PORTD |= PIN7; // B1
    delayMicroseconds(3900);
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD |= PIN3; // XIOS
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD &= ~PIN3; // ~XIOS
     PORTB &= ~PIN13; // ~A5
    delayMicroseconds(2200);
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD |= PIN3; // XIOS
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTB |= PIN13; // A5
    PORTD &= ~PIN3; // ~XIOS
     PORTB &= ~PIN13; // ~A5
   Serial.println("Pen right and lowered");
    delay (2000);      // debounce time for my finger on button
  } // do nothing if none of the buttons were pushed
}
