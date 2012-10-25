/*
 * Change color of an RGB LED based on the angle of rotation
 * of y/x from an accelerometer, so as to move through the full
 * color spectrum as the accelerometer turns 180 degrees.
 *
 * Used with an ADXL335 analog three-pin three-axis accelerometer.
 *
 * Based on the Sleeping Arduino sketch by Ed Halley.
 * (The Pummer RGB interpolation class is unchanged.)
 *
 * Released (cc) Creative Commons Attribution Only
 * Kathryn Killebrew
 * 
 */

#include 

/* Pummer:
 * A simple RGB color-interpolating helper class.
 *
 * When creating one, tell it which three output pins to drive PWM signals.
 * If your RGB device is common-anode, it can reverse the PWM for you.
 * Don't forget to limit current to each LED with a resistor (e.g., 220ohm).
 *
 * At any time, tell it what color to become by calling the goal() method,
 * and how fast to transition to that color.
 *
 * Call the pummer's loop() method occasionally to let it set the PWM
 * outputs to the LEDs.
 */
class Pummer
{
    byte lR, lG, lB;
    byte nR, nG, nB;
    byte wR, wG, wB;
    int pR, pG, pB;
    unsigned long last, when;
    boolean reverse;

public:
    Pummer(int pinR, int pinG, int pinB, boolean anode=false)
    {
        pinMode(pR = pinR, OUTPUT);
        pinMode(pG = pinG, OUTPUT);
        pinMode(pB = pinB, OUTPUT);
        nR = nG = nB = 0;
        reverse = anode;
        show();
        goal(255, 255, 255);
    }

    void show()
    {
        analogWrite(pR, reverse? (255-nR) : nR);
        analogWrite(pG, reverse? (255-nG) : nG);
        analogWrite(pB, reverse? (255-nB) : nB);
    }

    boolean done() { return last == when; }

    void goal(byte r, byte g, byte b, unsigned long speed = 500)
    {
        lR = nR; lG = nG; lB = nB;
        wR = r; wG = g; wB = b;
        last = millis();
        when = last + speed;
    }

    void loop()
    {
        unsigned long now = millis();
        if (now > when)
        {
            if (last == when)
                return;
            nR = wR; nG = wG; nB = wB;
            last = when;
        }
        else
        {
            nR = map(now, last, when, lR, wR);
            nG = map(now, last, when, lG, wG);
            nB = map(now, last, when, lB, wB);
        }
        show();
    }
};

/* Accelerometer:
 * Receive input from a 3-axis device, and perform some useful calculations.
 *
 * Specify the three axis pins using analog pin numbers.
 * These are usually adjacent on the common breakout boards.
 *
 * Call the accelerometer's update() method occasionally to update the
 * current values from the hardware.
 */
 
#define ANALOG0 14

class Accelerometer
{
    int p[3]; // which analog pins
    int a[3]; // acceleration, zero-based
    int b[3]; // acceleration bias/calibration information
    float r;  // angle of rotation

public:
    Accelerometer(int pinX, int pinY, int pinZ)
    {
        pinMode((p[0] = pinX) + ANALOG0, INPUT);
        pinMode((p[1] = pinY) + ANALOG0, INPUT);
        pinMode((p[2] = pinZ) + ANALOG0, INPUT);
        
        for (int i = 0; i < 3; i++) {
            b[i] = 512;
        }
        
        r = 0;
    }

    void update()
    {
        for (int i = 0; i < 3; i++) {
             a[i] = analogRead(p[i]) - b[i];
        }
        
        r = 0;
    }

    void dump()
    {
        Serial.print(  "x="); Serial.print(a[0]);
        Serial.print("\ty="); Serial.print(a[1]);
        Serial.print("\tz="); Serial.print(a[2]);
        Serial.print("\troll="); Serial.print(roll());
        Serial.println();
    }

    int accel(int axis)
    {
        if (axis < 0 || axis > 3) return 0;
        return a[axis];
    }

    float roll()
    {
        if (r != 0) return r;
        r = atan2(a[1], a[0]); // rotation of y / x
        return r;
    }
};

void loop() { ; } // we do our own loop below

void setup()
{
    Serial.begin(9600);
    
    byte newColor[3] = {0,0,0}; // RGB values, 0 - 255
    float angle;                // angle of rotation, in radians
    int colorPlace;             // angle mapped to range of color values
    int rainbowState;           // which state of change color is in
    byte incColor;               // if adding color to mix, how much
    byte decColor;               // if removing color from mix, how much
    int div = 0;                // counter for averaging angle readings
    int numReads = 8;           // number of readings to average
    
    float rollReads = 0.0;      // running total of rotation angle readings
    
    // initialize with pin numbers for LED colors and accelerometer axes
    Pummer pummer = Pummer(4, 3, 2, true);            
    Accelerometer accel = Accelerometer(A0, A4, A2);
    
    while (1)
    {
        delay(20);
        
        accel.update(); // read accelerometer axes
        
        angle = accel.roll(); // get a rotation angle reading
        angle = abs(angle); // show full spectrum in 180 deg. (have angle in radians, ranges from -pi to pi)
        rollReads += angle; // accrue readings for average
        
        if (--div <= 0) { 
          
         angle = rollReads / numReads; // get the average angle reading
         rollReads = 0;
         
        // map angle to range of color values with floating-point math
        colorPlace = (int)( angle * 1535.0 / M_PI + 1 ); 
        // what in-built map function does, with int math
         //(x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
        
        colorPlace = map(colorPlace, 0, 1535, 1535, 0); // reverse range for red at bottom, violet at top

        
        rainbowState = colorPlace / 256; // bin color number into change state
        incColor = colorPlace % 256;     // remainder is amount of partial color to fade in
        decColor = map(incColor, 0, 255, 255, 0); // reverse partial color range for fading out
        
        // make a rainbow
        if (rainbowState == 0) {
          // red to orange
          newColor[0] = 255;
          newColor[1] = incColor;
          newColor[2] = 0;
        } else if (rainbowState == 1) {
          // orange to green
          newColor[0] = decColor;
          newColor[1] = 255;
          newColor[2] = 0;          
        } else if (rainbowState == 2) {
          // green to teal
          newColor[0] = 0;
          newColor[1] = 255;
          newColor[2] = incColor;
        } else if (rainbowState == 3) {
          // teal to blue
          newColor[0] = 0;
          newColor[1] = decColor;
          newColor[2] = 255;
        } else if (rainbowState == 4) {
          // blue to purple
          newColor[0] = incColor;
          newColor[1] = 0;
          newColor[2] = 255;
        } else if (rainbowState == 5) {
          // purple to red
          newColor[0] = 255;
          newColor[1] = 0;
          newColor[2] = decColor;
        } else {
          // red
          newColor[0] = 255;
          newColor[1] = 0;
          newColor[2] = 0;
        }        
        
        // show colors
        pummer.loop();
        if (pummer.done())
        {
          pummer.goal(newColor[0], newColor[1], newColor[2], 100);
        } 
          
        // reset counter for readings
        div = numReads; 
          
        // print values
        accel.dump();
        }         
    }
}
