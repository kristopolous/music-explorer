
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Fonts/FreeSerif9pt7b.h>
#define LEN 128

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 32 // OLED display height, in pixels

// Declaration for an SSD1306 display connected to I2C (SDA, SCL pins)
// The pins for I2C are defined by the Wire-library. 
// On an arduino UNO:       A4(SDA), A5(SCL)
// On an arduino MEGA 2560: 20(SDA), 21(SCL)
// On an arduino LEONARDO:   2(SDA),  3(SCL), ...
#define OLED_RESET     -1 // Reset pin # (or -1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3C ///< See datasheet for Address; 0x3D for 128x64, 0x3C for 128x32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup() {
  Serial.begin(9600);
  Serial.setTimeout(250);
  // SSD1306_SWITCHCAPVCC = generate display voltage from 3.3V internally
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }

  // Clear the buffer
  display.clearDisplay();
 
  display.setTextSize(1);             // Normal 1:1 pixel scale
  display.setTextColor(SSD1306_WHITE);        // Draw white text
  display.display();
  display.setCursor(0, 0);
  display.setTextWrap(false);
}

uint8_t inbuf[LEN] = {0};
const int8_t wid = 4, off = wid+4;
void loop() {
  const int8_t line[] = {7, 21, 30}, strsz = 32;
  char *start, *cmdptr, cmd;
  
  uint8_t arg, ix, bufix = 0, ttl;
  if (Serial.available() > 0){
    
    memset(inbuf, 0, LEN);
    ttl = Serial.readBytes(inbuf, LEN);
    
    for(bufix = 0; bufix < ttl;) {
      cmd = inbuf[bufix++];
      
      if(cmd == 'V') {
        arg = inbuf[bufix++];
        uint8_t height = display.height() - (display.height() * arg / 0xff);
        display.fillRect(0, height, wid, display.height(), SSD1306_WHITE);
        display.fillRect(0, 0, wid, height, SSD1306_BLACK);
        
      } else if (cmd == 'T' || cmd == '1' || cmd <= '2') {
        cmdptr = (char*)inbuf + bufix;
        bufix += strsz;
        
        for(ix = 0; ix < strsz && cmdptr[ix] == ' '; ix++);
        start = cmdptr + ix;
        
        for(ix = 0; ix < strsz && cmdptr[ix] < 127; ix++);
        if(ix != strsz) {
          display.print("invalid character");
          return;
        }
        
        if(cmd == '1') {
          display.setCursor(off, line[0]);
          display.setFont(&FreeSerif9pt7b);
          display.fillRect(off, 0, display.width(), 18, SSD1306_BLACK);
        } else if (cmd == '2'){
          display.setCursor(off, line[1]);
          display.setFont(0);
          display.fillRect(off, line[1] - 3, display.width(), 12, SSD1306_BLACK);  
          display.setCursor(off, line[1]);      
        } else if(cmd == 'T') {
          int16_t track_count, track_index;
          start[16] = 0;
          sscanf(start, "%2d:%2d", &track_index, &track_count);          
          display.drawLine(off, display.height()-1, display.width(), display.height()-1, SSD1306_BLACK);
          track_count = max(min(track_count,28),3);
          track_index = min(track_count, track_index);
         
          int16_t seg_width  = (display.width() - off) / track_count;
          int16_t line_width = (7 - track_count / 4) * seg_width / 8;
          int16_t endlen     = seg_width * track_index + off;
          for (int16_t i = off;i < endlen; i += seg_width) {
             display.drawLine(i, display.height()-1, i + line_width, display.height()-1, SSD1306_WHITE);
          }
          display.display();
        }
        if(cmd == '1' || cmd == '2') {
          display.print(start);
        }
      } else {
        display.print(cmd);
      }
    }
    display.display();
  }
}

void testdrawcircle(void) {
  display.clearDisplay();

  for(int16_t i=0; i<max(display.width(),display.height())/2; i+=2) {
    display.drawCircle(display.width()/2, display.height()/2, i, SSD1306_WHITE);
    display.display();
    delay(1);
  }

  delay(2000);
}

void testfillcircle(void) {
  display.clearDisplay();

  for(int16_t i=max(display.width(),display.height())/2; i>0; i-=3) {
    // The ERSE color is used so circles alternate white/black
    display.fillCircle(display.width() / 2, display.height() / 2, i, SSD1306_INVERSE);
    display.display(); // Update screen with each newly-drawn circle
    delay(1);
  }

  delay(2000);
}

void testdrawroundrect(void) {
  display.clearDisplay();

  for(int16_t i=0; i<display.height()/2-2; i+=2) {
    display.drawRoundRect(i, i, display.width()-2*i, display.height()-2*i,
      display.height()/4, SSD1306_WHITE);
    display.display();
    delay(1);
  }

  delay(2000);
}

void testfillroundrect(void) {
  display.clearDisplay();

  for(int16_t i=0; i<display.height()/2-2; i+=2) {
    // The INVERSE color is used so round-rects alternate white/black
    display.fillRoundRect(i, i, display.width()-2*i, display.height()-2*i,
      display.height()/4, SSD1306_INVERSE);
    display.display();
    delay(1);
  }

  delay(2000);
}

void testdrawtriangle(void) {
  display.clearDisplay();

  for(int16_t i=0; i<max(display.width(),display.height())/2; i+=5) {
    display.drawTriangle(
      display.width()/2  , display.height()/2-i,
      display.width()/2-i, display.height()/2+i,
      display.width()/2+i, display.height()/2+i, SSD1306_WHITE);
    display.display();
    delay(1);
  }

  delay(2000);
}

void testfilltriangle(void) {
  display.clearDisplay();

  for(int16_t i=max(display.width(),display.height())/2; i>0; i-=5) {
    // The INVERSE color is used so triangles alternate white/black
    display.fillTriangle(
      display.width()/2  , display.height()/2-i,
      display.width()/2-i, display.height()/2+i,
      display.width()/2+i, display.height()/2+i, SSD1306_INVERSE);
    display.display();
    delay(1);
  }

  delay(2000);
}

void testdrawchar(void) {
  display.clearDisplay();

  display.setTextSize(1);      // Normal 1:1 pixel scale
  display.setTextColor(SSD1306_WHITE); // Draw white text
  display.setCursor(0, 0);     // Start at top-left corner
  display.cp437(true);         // Use full 256 char 'Code Page 437' font

  // Not all the characters will fit on the display. This is normal.
  // Library will draw what it can and the rest will be clipped.
  for(int16_t i=0; i<256; i++) {
    if(i == '\n') display.write(' ');
    else          display.write(i);
  }

  display.display();
  delay(2000);
}

void testscrolltext(void) {
  display.clearDisplay();

  display.setTextSize(2); // Draw 2X-scale text
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(10, 0);
  display.println(F("scroll"));
  display.display();      // Show initial text
  delay(100);

  // Scroll in various directions, pausing in-between:
  display.startscrollright(0x00, 0x0F);
  delay(2000);
  display.stopscroll();
  delay(1000);
  display.startscrollleft(0x00, 0x0F);
  delay(2000);
  display.stopscroll();
  delay(1000);
  display.startscrolldiagright(0x00, 0x07);
  delay(2000);
  display.startscrolldiagleft(0x00, 0x07);
  delay(2000);
  display.stopscroll();
  delay(1000);
}
