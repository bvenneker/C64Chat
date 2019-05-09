// EEPROM
// 01 = marker voor username
// 03 = marker for SSID
// 04 = marker for password
// 11 .. 20 = username
// 21 .. 24 = Message ID
// 31 .. 60 = SSID
// 61 .. 90 = Password
//
// Usefull information about the display
// https://www.instructables.com/id/Converting-Images-to-Flash-Memory-Iconsimages-for-/
// https://github.com/STEMpedia/eviveProjects/blob/master/imageToFlashMemoryIconsForTFT/
// Don't forget to change User_Setup.h inside TFT_eSPI library !

String versionstr = "1.001";

#include <TFT_eSPI.h>
TFT_eSPI tft = TFT_eSPI();   // Invoke library
#include <Wire.h>
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>


#include <EEPROM.h>

#define TFT_DC D4
#define TFT_CS D2

#define C64BLACK  0
#define C64WHITE  0xFFFF
#define C64RED    0xf800
#define C64CYAN   0x07ff
#define C64PURPLE 0x780f
#define C64GREEN  0x07e0
#define C64BLUE   ConvertRGB(0,0,200)
#define C64YELLOW 0xffe0
#define C64ORANGE fca0
#define C64BROWN  0x8200
#define C64GRAY   0x7bef
#define C64LGREEN 0x07e0
#define C64LBLUE  ConvertRGB(170,200,255)
#define C64LGRAY  0xC618



String line0, line1, line2, line3, line4, line5, line6, line7, userid;
word scolor, bcolor, tcolor;

// WiFi parameters to be configured
char wssid[20] ;
char wpassword[20] ;
char msgbuffer[45];
char rxmsgbuffer[45];
int  fetchFlag = 0;
char username[11];
char receiver[11];
char messageLine[42];
const int http_port = 80;
bool debug = false;
unsigned long messageID ;
bool autofetch = false;

HTTPClient http;

void setup(void) {
  EEPROM.begin(512);
  //EEPROMWritelong(21, 0); // set messageID to zero
  // First use setup:

  if (EEPROM.read(100) != 9) {
    // this pcb has never been used
    EEPROM.write(100, 9);
    EEPROMWritelong(21, 0); // set messageID to zero
    strcpy(username, "Yourname");
    storeInEEPROM(11, 20, 1, username, 8);

  }
  //EEPROMWritelong(21, 800); // set messageID to zero
  Serial.begin(300); // serial connection to C64 is at 300 baud.

  scolor = C64BLUE ;
  bcolor = C64LBLUE;
  tcolor = C64LBLUE;

  tft.begin();     // initialize a ST7789 chip
  tft.setSwapBytes(true); // Swap the byte order for pushImage() - corrects endianness
  tft.setTextWrap(false);

  // tft.fillScreen(bcolor);
  setBorder(bcolor);

  tft.fillRect(10, 30, 220, 180, scolor );
  tft.setTextSize(2);
  tft.setTextColor(tcolor, scolor  );
  tft.setCursor(12, 32);
  tft.println("COMMODORE 64 CHAT");
  tft.setCursor(12, 52);
  tft.println("NOT CONNECTED");
  blinkborder(15, 1);
  tft.setCursor(12, 72);
  tft.println("READY.");

  delay(500);

  // SETUP WIFI
  WiFi.mode(WIFI_STA);
  getPasswordFromEEPROM();
  getSsidFromEEPROM();

  WiFi.begin(wssid, wpassword);

  WaitForWifiConnection();
  addLine("Wifi:" + (String)wssid);

  userid = WiFi.macAddress();
  userid.replace(":", "");

  tft.setCursor(12, 72);
  tft.println("                  ");
  // tft.setCursor(12, 72);
  // tft.println("Wifi:" + (String)wssid);

  messageID = EEPROMReadlong(21);
  getUserFromEEPROM();

  http.setReuse(true);
  registerID();

  tft.setCursor(12, 52);
  tft.println("                  ");
  tft.setCursor(12, 112);
  tft.println("READY.");

  countNewMessages();
}

int standbycounter = 0;
int loopcounter = 0;
bool stnd = false;
void loop(void) {
  // we never get here until wifi is connected.
  // but if we disconnect from wifi, we should fix that
  if (WiFi.status() != WL_CONNECTED) {
    // todo
  }

  if (loopcounter++ > 600) {
    tft.begin(); // reset the tft, because spi gets out of sync sometimes.
    loopcounter = 0;
    if (inStandby()) {
      countNewMessages();
      blinkborder(10, 1);
    }
  }

  if (inStandby()) {
    scolor = C64BLACK ;
    bcolor = C64BLACK;
    tcolor = C64WHITE;
    if (!stnd) updateLCD(true) ;

    stnd = true;
  } else {
    scolor = C64BLUE ;
    bcolor = C64LBLUE;
    tcolor = C64LBLUE;
    if (stnd) {
      updateLCD(true) ;
      blinkborder(40, 1); // blink border long if we come out of standby
      // tft.begin();
    }

    stnd = false;

  }


  delay(500);
  // line7 = "MessageId=" + (String)messageID;
  updateLCD(false) ;
  blinkCursor(10, 132);



  if (Serial.available()) {  // serial available main loop
    char c = petscii2Ascii(Serial.read());
    if (c == 'W' || c == 'w') rxCodeW(); // Get Wifi ssid from serial
    if (c == 'P' || c == 'p') rxPassword(); // Get Wifi password from serial
    if (c == 'V' || c == 'v') rxCodeV(); // Set UserName
    if (c == 'Q' || c == 'q') rxCodeQ(); // Send wifi ssid to c64
    if (c == 'A' || c == 'a') rxCodeA(); // Send wifi password to c64
    if (c == 'L' || c == 'l') rxCodeL(); // Fetch User from list
    if (c == 'S' || c == 's' || c == 'N' || c == 'n') rxCodeS(c); // Store (new) message line;
    if (c == 'F' || c == 'f' ) rxCodeF(); // Fetch message please.
    if (c == 'R' || c == 'r') rxReset(); // Reset
  }

}

void setBorder(uint16_t color) {
  for (int x = 0; x < 30; x++) tft.drawFastHLine(0, x, 240, color  );
  for (int y = 20; y < 210 ; y = y + 20) {
    for (int x = y; x < y + 20 ; x++)  drawBlocks(x, color, 0);
  }
  for (int x = 210; x < 240; x++) tft.drawFastHLine(0, x, 320, color );
}

void drawBlocks(int x, uint16_t color, bool randomize) {
  // this is to draw the short parts (left and right) of the border
  if (randomize) {
    color = random(0xFFFF);
  }
  tft.drawFastHLine(0, x, 10, color );
  tft.drawFastHLine(230, x, 240, color );
}

void blinkborder(int repeat, bool resetToBlue) {
  int16_t color = random(0xFFFF);
  for (int c = 0; c < repeat; c++) {
    for (int x = 0; x < 30; x++) {
      color = random(0xFFFF);
      tft.drawFastHLine(0, x, 240, color );
      delay(1);
    }
    for (int y = 30; y < 210 ; y = y + 20) {
      for (int x = y; x < y + 20 ; x++)  drawBlocks(x, color, 1);
      delay(1);
    }
    for (int x = 210; x < 240; x++) {
      color = random(0xFFFF);
      tft.drawFastHLine(0, x, 240, color );
      delay(1);
    }
  }
  if (resetToBlue) setBorder(bcolor);
}

void updateLCD(bool fullrefresh) {
  if (fullrefresh) {
    tft.setTextColor(tcolor, scolor);
    tft.fillRect(10, 30, 220, 180, scolor );
    setBorder(bcolor);
    tft.setCursor(12, 32);
    tft.println("COMMODORE 64 CHAT");
  }
  String l = line0;
  l.trim();
  l = l + "                     ";
  l = l.substring(0, 18);
  tft.setCursor(12, 52);  tft.print(l);
  tft.setCursor(12, 72);  tft.print(line1);
  tft.setCursor(12, 92); tft.print(line2);
  tft.setCursor(12, 112); tft.print(line3);
  tft.setCursor(12, 132); tft.print(line4);
  tft.setCursor(12, 152); tft.print(line5);
  tft.setCursor(12, 172); tft.print(line6);
  tft.setCursor(12, 192); tft.print(line7);
}

void addLine(String Line) {

  Line = Line + "                     ";
  Line = Line.substring(0, 18);
  line7 = line6;
  line6 = line5;
  line5 = line4;
  line4 = line3;
  line3 = line2;
  line2 = line1;
  line1 = Line;
  updateLCD(false);
}

word ConvertRGB( byte R, byte G, byte B) {
  return ( ((R & 0xF8) << 8) | ((G & 0xFC) << 3) | (B >> 3) );
}

void blinkCursor(int x, int y) {
  uint16_t color;
  static bool showhide;

  if (showhide) {
    color = scolor;
    showhide = false;
  } else {
    color = tcolor;
    showhide = true;
  }
  tft.fillRect(x, y, 12, 15, color );
}

void WaitForWifiConnection() {
  bool isb = false;
  line1 = "WAITING FOR WIFI.";
  updateLCD(false);
  delay(500);
  while (WiFi.status() != WL_CONNECTED) {
    if (Serial.available()) {
      char c = petscii2Ascii(Serial.read());
      if (c == 'W' || c == 'w') rxCodeW(); // Set the ssid
      if (c == 'P' || c == 'p') rxPassword(); // Set the password
      if (c == 'Q' || c == 'q') rxCodeQ(); // Get wifi ssid to c64
      if (c == 'A' || c == 'a') rxCodeA(); // Get wifi password to c64
      if (c == 'R' || c == 'r') rxReset(); // Reset
    }
    delay(600); // give the wifi chip some time to connect
    blinkCursor(10, 52);

    if (isb) {
       if (!inStandby()) {
        isb=false;
        rxReset();
        }
    } 
    
    if (inStandby()) isb = true;
  }
  tft.fillRect(10, 52, 12, 15, C64BLUE );
  line1 = "";
  updateLCD(false);
}

void rxReset() {
  delay(1000);
  ESP.reset() ;
}


void FetchMessage() {
  fetchFlag = 0;
  if (debug) addLine("Fetch");
  String strmes = httpGET("http://bartvenneker.nl/c64chat/chat.php?r=" + (String)userid + "&m=" + (String)messageID  );
  // message is like:  123>hello world~
  // first part is the id, last part is message (messageID)
  // > is just a separator
  // ~ is the end marker
  char c = 0;
  int d = 0; // decimal value of char
  int m = 10; // multiplier
  int i = 0; // message itterator
  int bi = 0; // buffer itterator
  unsigned long tm = 0; // temp message id
  if (strmes.charAt(0) == '0') {
    // no message..
    rxmsgbuffer[0] = 0;
  } else {
    while (c != '>') {
      c =  strmes.charAt(i++) ;
      if (c > 47 && c < 58) {
        d = c - 48;
        tm = tm * m;
        tm = tm + d;
      }
      messageID = tm;
      EEPROMWritelong(21, messageID);

    }

    // get the rest of the message (the real message)
    while (c != '~') {
      c =  strmes.charAt(i++);
      rxmsgbuffer[bi++] = c;
    }

    rxmsgbuffer[bi] = 0;
    if (debug) addLine("id=" + (String)  messageID);
    //countNewMessages();
  }
}

void rxCodeL() {
  static int userlistit = 0;
  String userlist = "-error-";
  int len;
  // ignore the rest of the serial data
  ClearRXBuffer();

  if (debug) addLine("Got L");
  else delay(200);


  // Get the list of users from the website
  userlist = httpGET("http://bartvenneker.nl/c64chat/chat.php?l=" + String(userlistit, DEC) );
  len = userlist.length();
  if (userlist != "!nomore!") {
    sendSTX();
    for (int x = 0; x <= len; x++) {
      char c =  userlist.charAt(x) ;
      Serial.print(toPetscii(c));
    }
    userlistit++;
    Serial.write(255);
  } else {
    sendSTX();
    Serial.write(0);
    Serial.write(255);
    userlistit = 0;
  }
}
void rxCodeF() {

  // ClearRXBuffer(); NO !!

  // Fetch a message
  FetchMessage();

  if (rxmsgbuffer[0] == 0) {
    // no message for you
    if (loopcounter > 120) {
      countNewMessages(); // to update the clock
      loopcounter = 0;
      blinkborder(15, 1);
    }
  } else {
    Serial.write(250); Serial.write(250); Serial.write(250);
    for (int x = 0; x <= 44; x++) {
      // loop the rxmessage buffer until we find zero
      // and send it
      char c = rxmsgbuffer[x];

      if (c == 0 || c == '~') {
        break;
      }
      Serial.write(toScreenCode(rxmsgbuffer[x]));
    }

    Serial.write(0);
    Serial.write(255);
    if (debug) addLine("Send line");
  }


}

void rxCodeS(char c) {

  String mtype = "&type=0";
  if (c == 'N' || c == 'n') {
    if (debug) addLine("Got N");
    mtype = "&type=1";
  } else {
    if (debug) addLine("Got S");
  }
  // get the rest of the message
  int i = 0;
  rxDataTimeout(50);
  while (Serial.available()) {
    c = ScreenCode(Serial.read());
    if (c != 13 & c != 10 ) {
      if (c == ' ') c = '~';
      msgbuffer[i++] = c;
      if (c == 0) break;
      rxDataTimeout(50);
    }
  }
  msgbuffer[i] = 0; // end of string
  ClearRXBuffer();
  delay(50);
  String response = httpGET("http://bartvenneker.nl/c64chat/chat.php?s=" + userid + mtype + "&m=" + (String)msgbuffer) ;
  if (response == "E_NO_USER") {
    sendSTX();
    Serial.write (254);
    Serial.write (255);
  } else {
    sendSTX();
    Serial.write (0);
    Serial.write (255);
  }

}

void rxCodeW() {
  if (debug)  addLine("Set SSID");
  // Set the WiFi SSID
  int i = 0;
  rxDataTimeout(50);
  while (Serial.available()) {
    char c = petscii2Ascii(Serial.read());
    if (c != 13 & c != 10) {
      wssid[i++] = c;
      rxDataTimeout(50);
    }
  }
  wssid[i++] = 0; // einde van de string
  addLine(wssid);
  addLine("Wifi SSID");

  // Save ssid in eeprom
  storeInEEPROM(31, 60, 3, wssid, i);

  // Send a response
  sendSTX();
  Serial.write(0);
  Serial.write(255);
}

void rxPassword() {
  // receive the WiFi Password from C64
  int i = 0;
  delay(50);
  while (Serial.available()) {
    char c = petscii2Ascii(Serial.read());
    if (c != 13 & c != 10) {
      wpassword[i++] = c;      
      rxDataTimeout(50);
    }
  }
  wpassword[i++] = 0; // einde van de string
  addLine(wpassword);
  addLine("Wifi Password");
  // Save password in eeprom
  storeInEEPROM(61, 90, 4, wpassword, i);
  // Send a response
  sendSTX();
  Serial.write(0);
  Serial.write(255);
  rxReset();
}



  
void rxCodeQ() {
  // Send wifi ssid to C64
  ClearRXBuffer();
  if (debug) addLine("Got Q");
  int i = 0;
  char c = toPetscii(wssid[i]);
  //char c = wssid[i];
  delay(50);
  //delay(5);
  sendSTX();
  while (c != 0) {
    Serial.print(c);
    i++;
    //c = wssid[i];
    c = toPetscii(wssid[i]);
  }
  Serial.write(255);
}

void rxCodeA() {
  // Send wifipassword to C64
  ClearRXBuffer();
  if (debug) addLine("Got A");
  int i = 0;
  char c = toPetscii(wpassword[i]);
  delay(50);
  //delay(5);
  sendSTX();
  //  Serial.print(">>>");
  while (c != 0) {
    Serial.print(c);
    i++;
    c = toPetscii(wpassword[i]);
  }
  Serial.write(255);

}

void rxCodeV() {
  // get username from serial
  if (debug)  addLine("Got V");
  int i = 0;
  delay(50);
  while (Serial.available()) {
    char c = petscii2Ascii(Serial.read());
    if (c != 13 & c != 10 & c != ' ') {
      username[i++] = c;
      rxDataTimeout(50);
    }
  }
  username[i++] = 0; // einde van de string

  //  Now check if that username is available
  //  http://bartvenneker.nl/c64chat/chat.php?reg=1&name=Bartje&version=1.000

  String response = httpGET("http://bartvenneker.nl/c64chat/chat.php?reg=" + userid + "&name=" + (String)username + "&version=" + versionstr) ;
  delay(50);
  sendSTX();
  Serial.print(response);
  Serial.write(255);

  // if there was no error, store the username and reset the device

  if (response.charAt(0) != 'E') {
    addLine(username);
    addLine("Your name:");

    // Save username in eeprom
    storeInEEPROM(11, 20, 1, username, i);
    rxReset();
  }
}

void storeInEEPROM(int startAddress, int endAddress, int markerAddress, char data[], int dataLength) {
  for (int a = startAddress; a < endAddress + 1; a++) EEPROM.write(a, 0); // Clear eeprom
  EEPROM.write(markerAddress, 9);
  for (int a = 0; a < dataLength; a++) EEPROM.write(startAddress + a, data[a]);
  EEPROM.commit();
}

void EEPROMWritelong(int address, long value) {
  //Decomposition from a long to 4 bytes by using bitshift.
  //One = Most significant -> Four = Least significant byte
  byte four = (value & 0xFF);
  byte three = ((value >> 8) & 0xFF);
  byte two = ((value >> 16) & 0xFF);
  byte one = ((value >> 24) & 0xFF);

  //Write the 4 bytes into the eeprom memory.
  EEPROM.write(address, four);
  EEPROM.write(address + 1, three);
  EEPROM.write(address + 2, two);
  EEPROM.write(address + 3, one);
  EEPROM.commit();
}

long EEPROMReadlong(long address) {
  //Read the 4 bytes from the eeprom memory.
  long four = EEPROM.read(address);
  long three = EEPROM.read(address + 1);
  long two = EEPROM.read(address + 2);
  long one = EEPROM.read(address + 3);

  //Return the recomposed long by using bitshift.
  return ((four << 0) & 0xFF) + ((three << 8) & 0xFFFF) + ((two << 16) & 0xFFFFFF) + ((one << 24) & 0xFFFFFFFF);
}

void getPasswordFromEEPROM() {
  // Get the wifi password from eeprom
  if (EEPROM.read(4) != 9) {
    wpassword[0] = 'P'; wpassword[1] = 0;
  } else {
    // Password is stored in EEPROM at 61 .. 90
    for (int x = 61; x < 91; x++) {
      wpassword[x - 61] = EEPROM.read(x);
      if (wpassword[x - 61] < 32) break;
    }
  }
}

void getUserFromEEPROM() {
  if (EEPROM.read(1) == 9) {
    for (int a = 11; a < 21; a++) {
      username[a - 11] = EEPROM.read(a);
    }
    //Serial.print("f");
    //Serial.println(username);
    addLine("You:" + (String)username);
  } else {
    //Serial.println("fEMPTY");
  }

}
void getSsidFromEEPROM() {
  // Get the wifissid from eeprom
  if (EEPROM.read(3) != 9) {
    wssid[0] = 'S'; wssid[1] = 0;
  } else {
    // SSID ia stored in EEPROM at 31 .. 60
    for (int x = 31; x < 61; x++) {
      wssid[x - 31] = EEPROM.read(x);
      if (wssid[x - 31] < 32 ) break;
    }
  }
}

void sendSTX() {
  Serial.write(2); Serial.write(2);
}
void ClearRXBuffer() {
  delay(50);
  while (Serial.available()) {
    rxDataTimeout(50);
    char c = Serial.read();
  }
}

char petscii2Ascii(char i) {
  // https://dflund.se/~triad/krad/recode/petscii_c64en_lc.txt
  // Translate PETSCII (in shifted mode) to ASCII

  // Below 32 there is only 13 (carriage return)
  // Line feed (Ascii 10) does not exist in Petscii
  if (i == 0)   return 0;
  if (i == 13)  return 13;
  if (i == 164) return 95;   // Underscore
  if (i == 91)  return 91;   // left square bracket
  if (i == 92)  return 163;  // Pound sign
  if (i == 93)  return 93;   // right square bracket
  if (i == 94)  return 94;   // arrow up key = ^
  if (i == 126) return 93;   // right square bracket
  if (i == 95)  return 126;  // key left arrow is replaced by ~  
  
  // from 32 to 64, no change
  if (i >= 32 && i <= 64) return i;

  // from 65 to 90, add 32 (a..z)
  if (i >= 65 && i <= 90) return i + 32;

  // from 97 to 122, substract 32 (A..Z)
  if (i >= 97 && i <= 122) return i - 32;

  // From 193 to 218, substract 128 (A .. Z)
  if (i >= 193 && i <= 218) return i - 128;

  // If noting fits, return space
  return 32;
}

char toPetscii(char i) {
  // Translate ASCII to PETSCII
  // Below 32 there is only 13 (carriage return)
  // Line feed (Ascii 10) does not exist in Petscii
  if (i == 0)  return 0;
  if (i == 13) return 13;
  if (i == 95) return 164;   // Underscore is 95 in ascii but 164 in petsci
  if (i == 124) return 221;  // Pipe symbol is 124 in ascii but 221 in petsci
  if (i == 93) return 93;    // right square bracket
  if (i == 94) return 94;    // ^ translates to arrow up
  if (i == 126) return 95;   // We replace arrow left for tilde (~)
  

  // from 32 to 64, no change
  if (i >= 32 && i <= 64) return i;

  // From 65 to 90, add 128 (A .. Z)
  if (i >= 65 && i <= 90) return i + 32;

  // from 97 to 122, substract 32
  if (i >= 97 && i <= 122) return i - 32;

  if (i == 91) return 91; // left square bracket
  if (i == 163) return 92; // Pound sign
  if (i == 93) return 93; // right square bracket

  // If noting fits, return space
  return 32;
}

char toScreenCode(char i) {
  if (i == '@') return 91;
  if (i == '_') return 100;
  if (i == 0)  return 0;
  if (i == 32) return 32;
  if (i >= 97 && i <= 122) return i - 96; // small letters
  if (i >= 187 && i <= 95) return i - 64;
  if (i == 95)  return 64;
  if (i > 32 && i <= 63) return i;
  if (i >= 65 && i <= 90) return i;

  return 32;
}


char ScreenCode(char i) {
  // Screen codes are different again, they follow the order of the character set:
  // https://www.c64-wiki.de/images/1/1a/Zeichensatz-c64-poke1k.jpg

  if (i == 0)  return 0;

  if (i == 91)  return 64;  // 64 = @
  if (i ==100) return 95 ;  // underscore screen code =100

  if (i >= 1 && i <= 26) return i + 96; // small letters

  if (i >= 27 && i <= 31) return i + 64;

  if (i >= 32 && i <= 63) return i;

  if (i == 64)  return 95;

  if (i >= 65 && i <= 90) return i;

  /*
    0 = @    = 64
    1 = a    = 97
    26 = z    = 122

    27 = [    = 91
    28 = pound = \ = 92
    29 = ]    = 93
    30 = pijl up = 94
    31 = pijl left = 95

    32 = space = 32
    33 = ! = 33
    34 = " = 34
    35 = # = 35
    36 = $ = 36
    37 = % = 37
    38 = & = 38
    39 = ' = 39
    40 = ( = 40
    41 = ) = 41
    42 = * =
    43 = +
    44 = ,
    45 = -
    46 = . = 46
    47 = / = 47
    48 = 0 = 48
    57 = 9 = 57
    58 = : = 58
    59 = ;
    60 = <
    61 = =
    62 = >
    63 = ? = 63
    
    65 = A = 65
    90 = Z = 90
  */
  // If noting fits, return space
  return 32;
}

void registerID() {
  // http://bartvenneker.nl/c64chat/chat.php?reg=1&name=Bartje&ver=1.000
  httpGET("http://bartvenneker.nl/c64chat/chat.php?reg=" + userid + "&name=" + (String)username + "&ver=" + versionstr);

}

void countNewMessages() {
  WiFiClient client;
  if (http.begin(client, "http://bartvenneker.nl/c64chat/chat.php?q=" + userid + "&m=" + (String)messageID )) {
    int httpCode = http.GET();
    if (httpCode > 0) {
      if (httpCode == HTTP_CODE_OK || httpCode == HTTP_CODE_MOVED_PERMANENTLY) {
        line0 = http.getString();
        updateLCD(false);
      }
    }
    http.end();
  }


}

String httpGET(String url) {
  String Result = "-error-";
  WiFiClient client;
  if (http.begin(client, url)) {
    int httpCode = http.GET();
    if (httpCode > 0) {
      if (httpCode == HTTP_CODE_OK || httpCode == HTTP_CODE_MOVED_PERMANENTLY) {
        Result = http.getString();
      } else Result = "-error-";
    }
    else Result = "-error-";
    http.end();
  }
  Result.trim();
  return Result;
}

bool inStandby() {
  // if we get 5 volt from the C64, that means standby is off
  // the the C64 is switched off, we are in standby mode
  int y = analogRead(A0);
  //   Serial.println(y);
  return (y < 800);



}

void rxDataTimeout(int t){
  int x=0;
  while (not Serial.available() && (x < t)) {
    delay(1);
    x++;    
    }  
  }
