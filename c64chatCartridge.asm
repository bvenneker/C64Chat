.var CARTRIDGE_8K   = $2000
.var CARTRIDGE_16K  = $4000

.var CARTRIDGE_SIZE = CARTRIDGE_8K

.segment CARTRIDGE_FILE [start=$8000,min=$8000, max=$8000+CARTRIDGE_SIZE-1, fill,outBin="cartridge.bin"]


* = $8000

	.byte	$09, $80					// Cartridge cold-start vector = $8009
	.byte	$25, $80					// Cartridge warm-start vector = $8025
	.byte	$C3, $C2, $CD, $38, $30		// CBM8O - Autostart key


//	KERNAL RESET ROUTINE
	stx $D016							// Turn on VIC for PAL / NTSC check
	jsr $FDA3							// IOINIT - Init CIA chips
	jsr $FD50							// RANTAM - Clear/test system RAM
	jsr $FD15							// RESTOR - Init KERNAL RAM vectors
	jsr $FF5B							// CINT   - Init VIC and screen editor
	cli									// Re-enable IRQ interrupts


//	BASIC RESET  Routine

	jsr $E453							// Init BASIC RAM vectors
	jsr $E3BF							// Main BASIC RAM Init routine
	jsr $E422							// Power-up message / NEW command
	ldx #$FB
	txs									// Reduce stack pointer for BASIC
	
//	START YOUR PROGRAM HERE ($8025)
*=$8025



init:
// Do our init stuff here

   jsr $E544;   // Clear screen  
   lda #$06								// Switch to lower case
   ora $d018
   sta $d018 
   lda #$20
   sta CHARBUFFER
   lda #12
   sta BLINKSPEED
   lda #0
   ldx #0
   sta USERLIST400,x

// **********************************************************************************************
// **********************************************************************************************
// Main Loop of the program
mainprogram:
    OpenRS232()    
    jsr $E544; 							// Clear screen    
    ldx #0
    lda #111
!line:									// Draw the divider line
    sta $748,x
	inx
	cpx #40
	bne !line-
	
mainloop:
 
	jmp keyscan
	
	
		

// END OF MAIN LOOP -----------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// Main menu
!goMainMenu:
backupScreen()
!mainmenu:  
  
  jsr $E544;  		 					// Clear screen 
  displayText(starline,$0400,
    	14,$D800)    	
  displayText(mainmenuhead,$0428,
  		14,$D828)    
  displayText(starline,$0450,
    	14,$D850)
  displayText(menutext1,$04A0,
    	14,$D8A0)
  displayText(menutext2,$04C8,
    	14,$D8C8)
  displayText(menutext3,$04F0,
    	14,$D8F0)
  displayText(menutext4,$0518,
    	14,$D918)
   	
  !waitforinput:
    jsr $FFCC
    jsr $ffe4       					// read key
    beq !waitforinput-					// if no key pressed loop forever
!:  cmp #133   							// F1 pressed
    bne !+
    jmp !setupWiFi+
!:  cmp #134    						// F3 pressed
	bne !+    
	jmp !listUsers+
!:	cmp #135							// F5 pressed
	bne !+
	jmp !changename+
!:  cmp #136        					// F7 pressed
    bne !+
    jmp !exit+
!:  jmp !waitforinput-					// if a different key was pressed, ignore it and wait for more input    	

	!exit:
	jsr $E544;   // Clear screen 
	restoreScreen()
jmp keyscan  

// END OF MAIN MENU  -----------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// SETUP wifi,
// this is a 'wizard' to guide the user through the wifi setup.
// this screen is activated when F1 is pressed in the main window
!setupWiFi:
	ldy #$00
  	!clear:
  		lda #$00
  		sta ($F7),y
  		iny
  		cpy #$FF
	bne !clear-

	jsr $E544							// Clear screen
	lda #$00							// Clear TX Buffer    	
    sta TXBUFFER
        
    displayText(ssidnow,$0400,
    	14,$D800)						// Text line for current SSID
    displayText(passwordnow,
    	$0428,14,$D828)					// Text line for current Password
    
    lda #$51
    sta TXPREFIX 		  				// GET the ssid from the serial device    
										// Fill the TXBUFFER with  Q,0 and call rs232TX
										// $51=Q
    jsr !rs232TXRX+						// Send the buffer and wait for the response
		 
	SetCursor($00,$0D)  				// move cursor to first line
	printRXBuffer()						// Display RX buffer
	
	lda #$41
    sta TXPREFIX						// Get the password from the serial device
										// Fill the TXBUFFER with  A,0 and call rs232TX
										// $41=A
	jsr !rs232TXRX+						// Send the buffer and wait for the response
	SetCursor($01,$11)		    	    // move cursor
	printRXBuffer()  					// Display RX buffer 
	displayText(askssid,	
		$0478,14,$D878)					// Display the SSID question
	displayText(entertoexit,
		$04F0,14,$D8F0)					// Display message "press RETURN to skip"
	SetCursor($04,$00)  				// Now the user can type the ssid	
	
	ldy #$00    						// Y = char counter = 0
	ReadUntilReturn()	
	cpy #01								// if the y counter is still 0, user pressed Return without any input -> exit	
	bne !+								// exit if zero
	jmp !nextQuestion+
	!:	
  	lda #$00    						// end the string with 0
  	sta TXBUFFER,y
  	
    			        	   	 		// at this point return was pressed.
        	    			  	 	 	// TXBUFFER holds the SSID Name
    	            					// Send the SSID to the serial port.
    lda #$57
    sta TXPREFIX       					// First character in the txbuffer should be W (so the arduino knows this is the SSID string)
	jsr !rs232TXRX+						// Send the buffer and wait for the response
					
!nextQuestion:
	displayText(askpassword,
	            $04F0,14,$D8F0)			// Now Ask for the wifi Password
    displayText(entertoexit,
		$0568,14,$D8F0)					// Display message "press RETURN to skip"

    SetCursor($07,$00)					// Now the user can type the password 						
    jsr $FFCC
	lda #$50
    sta TXPREFIX       					// First character in the txbuffer should be P (so the arduino knows this is the Password)
	ldy #$00
	ReadUntilReturn()	
	cpy #01								// if the y counter is still 0, user pressed Return without any input -> exit	
	bne !+								// exit if zero
	jmp !exitWifiSetup+	
	!:    
  	lda #$00    						// end the string with 0
  	sta TXBUFFER,y
  	jsr !rs232TXRX+						// Send the buffer and wait for the response

!exitWifiSetup:

jmp !mainmenu-
//jmp mainprogram

// END OF SETUP WIFI ----------------------------------------------------------------------------

// **********************************************************************************************
// **********************************************************************************************
// LIST USERS
// this is a 'wizard' that lists the currently active users
// this screen is activated when F2 is pressed in the main window
!listUsers: 
	jsr $E544; // Clear screen
    
	displayText(numberuserstxt,
		$0400,14,$D800)    				// message: list of currently active users
	displayText(waituserslisttxt,
		$07C0,14,$DBC0)    				// message: Collecting users, please Wait
    ldx #0
    lda USERLIST400,x			  			// check if the list is allready stored in memory	
    cmp #0
    beq !refreshList+ 
    restoreUserlist()					// at this point the list is available in memory
    jmp !endOfList+
!refreshList:	
	//setup the loop for the list
	ldy #3
	sty CURSORY
	ldx #0
	stx CURSORX
	!listloop:
	lda #$4C							// Fill the buffer with L (4C = L)
    sta TXPREFIX 						// And send it
    jsr !rs232TXRX+	     				// And wait for the response    		
	lda	RXBUFFER						// Check if the response is empty
	cmp #00								// there are no more names
	bne !+
	jmp !endOfList+						// stop printing names
!:  SetCursorMem(CURSORY,CURSORX)		// cursor on the right possition    
	printRXBuffer()						// print new name
		!setlistpos:
										// first see if we are on the first or second row			
		lda CURSORX						
		beq !moveright+					// if the X position is on the left half of the screen, move it to the right half
		jmp !moveleft+					// else move it to the left half
		!moveright:			
		ldx #20			
		stx CURSORX						// set the cursor position to the right half of the screen	
		jmp !listloop-			
		!moveleft:			
		ldx #0			
		stx CURSORX						// move the cursor position to the left			
		iny								// move the cursor position one line down
		sty CURSORY
		cpy #20							// if we are not at the bottom of the list yet
		bne !listloop-					// get the next name
	
    									// users have been printed
    									// wait for user input to either close the list, or to change nickname
    
!endOfList:
	displayText(f7backtxt, 
		$07C0,14,$DBC0)					// message: change name(F1), back (F1)
    backupUserlist()		
    !waitforinput:
    jsr $FFCC
    jsr $ffe4       					// read key
    beq !waitforinput-					// if no key pressed loop forever
!:  cmp #136        					// F7 pressed
    bne !+
    jmp !exitlistUsers+
!:  cmp #135							// F5 pressed, refresh list
    bne !+
    lda #0
    ldx #0
    sta USERLIST400,x
    jmp !listUsers-
!:  jmp !waitforinput-					// if a different key was pressed, ignore it and wait for more input
!exitlistUsers:
jmp !mainmenu-
// END OF LIST USERS ----------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// this is a 'wizard' that allows the user to change his/her name
// this screen is activated when F1 is pressed in the list user window
!changename:
 
    jsr $E544; // Clear screen

  	// Ask the username Question
  	displayText(askyourname,
  			$0400,14,$D800)
    displayText(entertoexit,
		$0568,14,$D8F0)					// Display message "press RETURN to skip"		
   !username:   
	// Now the user can type his user name
	jsr $FFCC 
	SetCursor($01,$00)	 
	ldy #$00 
	ReadUntilReturn()	
	cpy #01								// if the y counter is still 0, user pressed Return without any input -> exit	
	bne !+								// exit if zero
	jmp !exitchangename+	
	!:      
	lda #$00    						// end the string with 0
  	sta TXBUFFER,y

    lda #$56							// Fill the buffer with L (hex 56 = V)
    sta TXPREFIX 						// And send it
    									// wait for the reply (server checks if username is allready taken)
    jsr !rs232TXRX+						// Get the response
    
	
										// Check the buffer for errors
										// E001 = name already taken
										// A000 = all ok, carry on, nothing to see here
	ldx #$00
	lda RXBUFFER,x
	cmp #69  							// if the buffer starts with E
    beq !error+
    jmp !exitchangename+         
    
	!error:								// show username error
	ldx #$01
	jsr $E9FF  							// clear input line 
	displayText(errorusername,
		$05B8,10,$D9B8)
  	jmp !username-
	
!exitchangename:
jmp !mainmenu-
// END OF CHANGENAME ---------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// This is the scan Routine
// We do not use the kernal input routines for this, we want more control over the position
// of the cursor. Also we need to receive data while the user is typing (receive needs to be non-blocking).

handleLeft: 
  StoreChar() 
  cmp #00         						// compare CursorIndex
  bne !+
  jmp !exit+
!:ldx CursorIndex
  dex
  stx CursorIndex
  lda $770,x
  sta CHARBUFFER
  lda KEYBUFFER
  jsr $FFD2       						//show key on the screen  
!exit:jmp readKey
  
handleRight: 
  StoreChar()
  cmp #119								// compare CursorIndex
  bne !+
  jmp !exit+
!:  
  ldx CursorIndex
  inx
  stx CursorIndex
  lda $770,x
  sta CHARBUFFER
  CursorToIndex()
  lda KEYBUFFER
  jsr $FFD2								//show key on the screen
!exit:jmp readKey

handleUp: 
  StoreChar()
  cmp #40
  bmi !exit+							// if CursorIndex <= 41, ignore
  sbc #40         						// substract 40
  sta CursorIndex        				// store new value
  ldx CursorIndex
  lda $770,x
  sta CHARBUFFER
  lda KEYBUFFER
  jsr $FFD2								//show key on the screen
!exit: jmp readKey
  
handleDown:
  StoreChar()
  cmp #80         						// compare CursorIndex
  bpl !exit+      						// if CursorIndex >= 81, ignore
  adc #40         						// add 40
  sta CursorIndex        				// store new value
  ldx CursorIndex
  lda $770,x
  sta CHARBUFFER
  lda KEYBUFFER
  jsr $FFD2      						//show key on the screen
!exit:jmp readKey
   
handleDel:   
  StoreChar() 
  cmp #00         						// compare CursorIndex
  bne !+
  jmp !exit+ 
!:ldx CursorIndex
  dex
  stx CursorIndex
  lda #32
  sta CHARBUFFER
  lda #157
  jsr $FFD2       						//show key on the screen  
!exit:jmp readKey

handleReturnkey:
    StoreChar()
    cmp #80
    bpl !a+ 							// if CursorIndex >= 81, autosend
    cmp #40
    bpl !+
    lda #40
    sta CursorIndex
    ldx CursorIndex
    lda $770,x
    sta CHARBUFFER
    lda KEYBUFFER    
    jsr $FFD2       					//show key on the screen
    jmp readKey
!:  lda #80         					// Set CursorIndex to postion 80
    sta CursorIndex
	lda KEYBUFFER    					// Load the keybuffer
    jsr $FFD2       					// Show key on the screen
    jmp readKey
!a: jmp autosend
    
keyscan:    
    SetCursor($16,$00)
	ldx #00
	stx CursorIndex
	jsr $FFCC   						// CLRCHN // reset input and output to keyboard and screen
	
!blinkCursor:    
	inc HCOUNT  
	lda HCOUNT
	cmp BLINKSPEED
	bne !+
	lda #0
	sta HCOUNT
    inc BLINKCOUNT     
    lda BLINKCOUNT
    cmp #1    
    beq !showcur+
    cmp #127
    beq !hidecur+
!:  jmp !innerloop+
!showcur:								
    ldx CursorIndex
    lda #$A0   
    sta $770,x        
    jmp !innerloop+
!hidecur:    
    lda CHARBUFFER
    ldx CursorIndex
    sta $770,x    
    jmp !innerloop+

    
readKey:	
    jsr $FFCC   						// reset input and output to keyboard and screen
    jmp !blinkCursor- 
!innerloop:       
    jsr !readIncomming+	
	jsr $FFCC							// reset input and output to keyboard and screen
	jsr $FFE4       					// read key
    beq readKey     					// if no key pressed loop forever
    sta KEYBUFFER    					// store the key to key buffer
    cmp #17         					// Handle Cursor Down
    bne !+
    jmp handleDown
!:  cmp #145        					// Handle Cursor UP
    bne !+
    jmp handleUp
!:  cmp #13								// Handle return key
    bne !+
    jmp handleReturnkey
!:  cmp #133   							// F1 pressed
    bne !+
    jmp !goMainMenu-   
!:  cmp #134   							// F2 pressed
    bne !+
    jmp !goMainMenu- 
!:  cmp #136    						// F7 pressed
    bne !+
    jmp autosend
!:  cmp #157							// Handle Left Cursor
    bne !+
    jmp handleLeft	
!:  cmp #20								// Handle Delete
    bne !+
    jmp handleDel
    
!:  jmp handleRight						// all other keys go to handleRight
      
      
// END OF KEYSCAN ROUTINE -----------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// ShiftScreen UP
ShiftScreen:    
    ldx #$00							// offset
!l: lda $428,x							// load the character
    sta $400,x							// write the character somewhere else
    lda $D828,x							// load the color
    sta $D800,x							// write the color somewhere else
    inx   
    cpx #$F0							// 6 lines
    bne !l-
    
    ldx #$00
!l: lda $518,x    
    sta $4F0,x
    lda $D918,x
    sta $D8F0,x
    inx   
    cpx #$F0							// 6 lines
    bne !l-    
    
    ldx #$00
!l: lda $608,x    
    sta $5E0,x
    lda $DA08,x
    sta $D9E0,x
    inx   
    cpx #$F0							// 6 lines
    bne !l-
    
    ldx #$00
!l: lda $6F8,x    
    sta $6D0,x
    lda $DAF8,x
    sta $DAD0,x
    inx   
    cpx #$50							// 2 lines
    bne !l-
    
    ldx #$14
	jsr $E9FF 							// Clear last line 
	
rts

DisplaySendMessage:    
	pushreg() 
    // write the buffered line to the screen    
    ldx #00
    ldy #01
!l: lda TXBUFFER,x
    cmp #91     						// Change number 91
    bne !+      						// Back to
    lda #00     						// the @ sign
    
!:  sta $720,x							// store the character to the screen
	tya 								// store the color value to the a register
	sta $DB20,x							// change the color of the letter
    inx
    cpx #40
    bne !l-
  
   	lda $747							// Read the end of the line
	cmp #32								// if it is NOT empty we will shift the line
	bne !exit+							// else exit this sub
			
	!shiftLine:							// shift line
	ldx #39								// to allign your messages
	!sl:								// to the right side of the screen
		lda $71F,x						
		sta $720,x
		dex
		cpx #00
	bne !sl-
	lda #32
	sta $720
	lda $747							// repeat the shift until position $747
	cmp #32								// does not equal space
	beq !shiftLine-

!exit:

	popreg()
rts

DisplayReceiveMessage:
    pushreg()							// write the received line to the screen
	ldx #00								// set x to 0
	ldy RXMESSCOL						// Load color into y
!l:	lda RXBUFFER,x						// load a character from the rxbuffer
	cmp #$00							// if the character is equal to 00
	beq !e+								// then its the end of the string, so exit the loop
	cmp #91
	bne !+
	lda #0
!:	sta $720,x							// else, output the character to the screen
	tya									// load the color code stored in Y into A			
	sta $DB20,x							// change the color of the space the letter will appear on.
	inx									// increment X for the next character
	cpx #$28							// see if x is at the end of the screen
	bne !l-								// if not go back and read the next character
!e: popreg()
rts

// **********************************************************************************************
// **********************************************************************************************
// AUTOSEND
// When the user presses enter on the last line or when pressing F7, this routine sends the data
autosend:
 
    // send each line as a separate message
    // The first line will get the 'N' prefix (for new message)
    // other lines get the 'S' prefix
    
    //  ALL MESSAGES GO TO THE GROUP UNLESS IT STARTS WITH @USERNAME:  
    //  JUST SEND THE MESSAGE 'AS IS', WE WILL FIGURE OUT IN PHP WHO THE RECIEVER SHOULD BE      
    
    lda CHARBUFFER 						// display the character under the cursor in stead of the cursor
    ldx CursorIndex    					// current cursor position
    sta $770,x
    
    // Get first line into the buffer
    
    lda #$00
    sta LINECOUNT
    lda #$4E
    sta TXPREFIX  						// set prefix to 'N' for the first line          
    
!lineloop:
    readLineToTXBuffer($770)
    lda HASTEXT   						// see if the line has any text, skip next commands if empty
    cmp #$00 
    beq !+    							         
    
    jsr !rs232TXRX+						// Send the line and wait for reply
    jsr ShiftScreen    
    lda RXBUFFER						// Check if the reply contains an error
    cmp #254							// 254 means the user does not exist!!
    bne !noerror+
    displayText(errornouser,
    	$0720,10,$DB20)					// Display the error message
    lda #$0
    sta CHARBUFFER
    jmp keyscan
!noerror:
    
    jsr DisplaySendMessage
    lda #$53  
    sta TXPREFIX  						// set prefix to 'S' for the next lines  
    
!:  lda LINECOUNT 						// on the first line
    cmp #$00							// look for a receiver
    bne !skip+			   				// Skip if we are not on the first line

!lookforreceiver:  
    ldx #$00
    lda TXBUFFER,x
    cmp #91
    bne !skip+
    sta RECEIVER,x
    //lda #00
    //sta $400,x
    inx
!l: lda TXBUFFER,x
    sta RECEIVER,x
    //sta $400,x
    cmp #$3A 							// end at :
    beq !skip+
    inx
    cpx #$0B
    bne !l-
    
!skip:  								// shift message box
    ldx #$00
!l: lda $798,x    
    sta $770,x
    inx   
    cpx #$50							// one line
    bne !l-
    ldx #$18 ; jsr $E9FF 				// clear line 18(hex)
    ldx LINECOUNT     
    inx
    cpx #03
    beq !exitloop+
    stx LINECOUNT
    jmp !lineloop-

!exitloop:
    

    // clear the message lines
    ldx #$16 
    jsr $E9FF  							// clear line 16(hex)
    ldx #$17
    jsr $E9FF  							// clear line 17(hex)
    ldx #$18
    jsr $E9FF  							// clear line 18(hex)
    
    ldx #$00    						// if there was a receiver, put it in the box again:
    lda RECEIVER,x
    cmp #91 
    bne !noreceiver+    
    lda #00
    ldx #00
    sta $770,x
    sta RECEIVER,x        	 			// Set the receiver back to 0    
    inx
!w: lda RECEIVER,x
    sta $770,x
    cmp #$3A							// end after :
    beq !s+								// skip
    lda #00
    sta RECEIVER,x    
    inx    
    cpx #12
    bne !w-    
!s:	inx									// Get the cursor back to the right place
	stx CursorIndex						// Right after the @receiver:
    txa    
    tay    								// Set column
    ldx #$16    						// Select row	
	jsr $E50C   						// Set cursor
	jsr $FFCC   						// CLRCHN // reset input and output to keyboard and screen
    jmp !showcur-
!noreceiver:
jmp keyscan

// END OF AUTOSEND ROUTINE -----------------------------------------------------------------------



// **********************************************************************************************
// **********************************************************************************************
// This routine sends data over rs232 to our microcontroller
// It transmits the content of TXBUFFER and waits for a response (BLOCKING!)
// the reponse is stored in the RX Buffer
!rs232TXRX:
	pushreg()  
	
	ldx #$02
    jsr $FFC9 							// CHKOUT
  	ldx #$00	
	lda TXPREFIX
	cmp #$00							// IF the prefix is 0, skip
	beq !l+								//
	jsr $FFD2 							// send the prefix CHROUT
!l:	lda TXBUFFER,X						// Loop to send the TX Buffer
	cmp #$00							// If the buffer char is 0
    beq !endRs232TX+					// end the sequence                              
    jsr $FFD2 							// CHROUT        
//    inc $d020	    					// set border color        
    inx
    bne !l-
	!endRs232TX:
	lda #$00							// End with 0
	jsr $FFD2							// CHROUT
	
	
	!WaitForResponse:	
	ldx #$02
 	jsr $FFC6		        			// CHKIN
 	ldx #$00
     					
!s: 
//	inc $d020							// Skip garbage until  <STX> signs begin (transmission starts with STX STX)
    jsr $FFCF							// CHRIN
    cmp #$02         					// <STX>
    bne !s-
!r:	
//	inc $d020							// Loop to receive the buffer		
 	jsr $FFCF	    	    			// CHRIN
 	cmp #$FF							// Transmission ends with FF (255)
 	beq !f+ 
    cmp #$02	    	  				// <STX>         // Skip the <STX> signs
    beq !r-								// restart loop without storing character                        
    sta RXBUFFER,x						// Store the character
 	inx					
 	jmp !r-		          				// jump to rx loop
 	  
!f:	lda #$00
	sta RXBUFFER,x
		 
    SetBorderColor(14)   				// set border color to default
	popreg()
	rts  
// END OF RS232TXRX ROUTINE -----------------------------------------------------------------------



// **********************************************************************************************
// **********************************************************************************************
!readIncomming:
pushreg()  
  
  										// See if there is any data in the RS232 receive buffer
  lda $029B 							// end index marker
  cmp $029C                 			// start index marker  
            							// if the difference is zero there is nothing
  beq !exit+ 							// so exit
  
  lda #2
  sta BLINKSPEED
  // we have data to collect
  //SetBorderColor(0)						// border goes black
  ldx #$02
  jsr $FFC6								// CHKIN
  jsr $FFCF								// CHRIN
  cmp #250								// RESET OUR BUFFER INDEX (250 is start of message)
  beq !resetBuffer+
  cmp #92
  bne !+
  ldx #13
  stx RXMESSCOL
  jmp !exit+
!: cmp #255								// Finish the buffer and display message  
  beq !finishMessage+
  ldx BUFFERPOS
  sta RXBUFFER,x
  inx
  stx BUFFERPOS
  jmp !exit+
   
  !finishMessage:  
  ldx BUFFERPOS
  lda #$00
  sta RXBUFFER,x
  jsr ShiftScreen
  jsr DisplayReceiveMessage

  
  !resetBuffer:
  ldx #5
  stx RXMESSCOL
  lda #0
  sta BUFFERPOS
  
  SetBorderColor(14)
  
  !exit:
  
  //SetBorderColor(14)
  
  inc FCOUNTER
  lda FCOUNTER
  cmp #0
  bne !+
  inc FCOUNTER2
  lda FCOUNTER2
  cmp #0
  bne !+  
  lda #150
  sta FCOUNTER2
  ReceiveON()
  lda #12
  sta BLINKSPEED
!:
popreg()
rts
// END OF readIncomming ROUTINE -----------------------------------------------------------------------	

// CONSTANTS:
ssidnow:			.text "Current SSID:                           " // 40 chars (40 chars is one full line)
passwordnow:		.text "Current Password:                       " // 40 chars
askssid:    		.text "Name of the wifi network (SSID):        " // 40 chars
askpassword:   		.text "What is the Wifi Password?:             " // 40 chars
askyourname:    	.text "What is your user name?:                " // 40 chars
errorusername:  	.text "ERROR: Name allready taken              " // 40 chars      
numberuserstxt: 	.text "List of connected users:                " // 40 chars      
f7backtxt:  		.text "[ F5 ] = Refresh     [ F7 ]  = Back     " // 40 chars      
entertoexit:		.text "Just press RETURN to skip this question " // 40 chars  
errornouser:		.text "ERROR: No user with that name!          " // 40 chars  
waituserslisttxt: 	.text "Collecting users, please Wait           " // 40 chars
starline:           .text "   *********************                " // 40 chars
mainmenuhead:       .text "   *     MAIN MENU     *                " // 40 chars
menutext1:          .text " [ F1 ]  = WiFi Setup                   " // 40 chars 
menutext2:          .text " [ F3 ]  = List Users                   " // 40 chars
menutext3:          .text " [ F5 ]  = Change User Name             " // 40 chars
menutext4:          .text " [ F7 ]  = Return to chat               " // 40 chars
RS232PAR:     		.byte %00000110,%00000000 // 300 Baud  
  

// VARIABLE BUFFERS
* = $0900 virtual
TXBUFFER:   		.fill 256,0            
RXBUFFER:   		.fill 256,0                                                 
CursorIndex:		.byte $00 				// temp buffer for cursor postion offset, also line length
BLINKCOUNT:			.byte $00 
BLINKSPEED:			.byte $0C
HCOUNT:				.byte $00
CHARBUFFER:     	.byte $20
KEYBUFFER:       	.byte $fa,$fb    
HASTEXT:        	.byte $00   
TXPREFIX:       	.byte $00
LINECOUNT:      	.byte $00
RECEIVER:       	.fill 50,0
RXMESSCOL:			.byte $05
CURSORX:			.byte $00
CURSORY:			.byte $00
BUFFERPOS:			.byte $00
FCOUNTER:			.byte $00
FCOUNTER2:			.byte $C8

CHARBLOCK400:  		.fill 256,0 // buffers to save the screen
CHARBLOCK500:   	.fill 256,0 // when going into the menu
CHARBLOCK600:   	.fill 256,0 //
CHARBLOCK700:   	.fill 256,0 //
COLBLOCK400:		.fill 256,0 // screen color information
COLBLOCK500:		.fill 256,0 // to save colors when going
COLBLOCK600:		.fill 256,0 // into the menu
COLBLOCK700:		.fill 256,0 //

USERLIST400:  		.fill 256,0 // buffers to save the screen
USERLIST500:    	.fill 256,0 // when going into the menu
USERLIST600:    	.fill 256,0 //
USERLIST700:     	.fill 256,0 //
COLUSERLIST400:		.fill 256,0 // screen color information
COLUSERLIST500:		.fill 256,0 // to save colors when going
COLUSERLIST600:		.fill 256,0 // into the menu
COLUSERLIST700:		.fill 256,0 //

    


/* MACROS  */
.macro pushreg(){
	php									// push the status register to stack
	pha									// push A to stack
	txa									// move x to a
	pha									// push it to the stack
	tya									// move y to a
	pha									// push it to the stack	               
}

.macro popreg(){
	pla									// pull the y register from the stack
	tay									// move it to the y register
	pla									// pull the x register from the stack
	tax									// move it to the x register
	pla									// pull the acimulator from the stack
	plp									// pull the the processor status from the stack
}

.macro backupUserlist(){
pushreg()
	ldx #$00							// Create a loop to store all character information
	!loop:   							// And also the color information
	lda $0400,x
	sta USERLIST400,x					// chars
	lda $D800,x
	sta COLUSERLIST400,x				// color
	lda $0500,x
	sta USERLIST500,x					// chars
	lda $D900,x
	sta COLUSERLIST500,x				// color
	lda $0600,x
	sta USERLIST600,x					// chars
	lda $DA00,x
	sta COLUSERLIST600,x				// color
	dex
	bne !loop-
	
	ldx #$00
	!loop:								// this loop is to store the last few lines
	lda $0700,x							// until, and including the devider line
	sta USERLIST700,x
	lda $DB00,x
	sta COLUSERLIST700,x
    inx
    cpx #$70
	bne !loop-
popreg()	

}

.macro restoreUserlist(){
pushreg()
	ldx #$00
	!loop:  							// Create a loop to restore all 
	lda USERLIST400,x					// character and color information
	sta $0400,x
	lda COLUSERLIST400,x
	sta $D800,x
	lda USERLIST500,x
	sta $0500,x
	lda COLUSERLIST500,x
	sta $D900,x	
	lda USERLIST600,x
	sta $0600,x
	lda COLUSERLIST600,x
	sta $DA00,x
	dex
	bne !loop-			
				
	ldx #$00
	!loop:								// this loop is to restore the last few lines
	lda USERLIST700,x
	sta $0700,x
    lda COLUSERLIST700,x
	sta $DB00,x
    inx
    cpx #$70
	bne !loop-	 
popreg()
}

.macro backupScreen(){
pushreg()
	ldx #$00							// Create a loop to store all character information
	!loop:   							// And also the color information
	lda $0400,x
	sta CHARBLOCK400,x					// chars
	lda $D800,x
	sta COLBLOCK400,x					// color
	lda $0500,x
	sta CHARBLOCK500,x					// chars
	lda $D900,x
	sta COLBLOCK500,x					// color
	lda $0600,x
	sta CHARBLOCK600,x					// chars
	lda $DA00,x
	sta COLBLOCK600,x					// color
	dex
	bne !loop-
	
	ldx #$00
	!loop:								// this loop is to store the last few lines
	lda $0700,x							// until, and including the devider line
	sta CHARBLOCK700,x
	lda $DB00,x
	sta COLBLOCK700,x
    inx
    cpx #$70
	bne !loop-
popreg()	
}

.macro restoreScreen(){
pushreg()
	ldx #$00
	!loop:  							// Create a loop to restore all 
	lda CHARBLOCK400,x					// character and color information
	sta $0400,x
	lda COLBLOCK400,x
	sta $D800,x
	lda CHARBLOCK500,x
	sta $0500,x
	lda COLBLOCK500,x
	sta $D900,x	
	lda CHARBLOCK600,x
	sta $0600,x
	lda COLBLOCK600,x
	sta $DA00,x
	dex
	bne !loop-			
				
	ldx #$00
	!loop:								// this loop is to restore the last few lines
	lda CHARBLOCK700,x
	sta $0700,x
    lda COLBLOCK700,x
	sta $DB00,x
    inx
    cpx #$70
	bne !loop-	 
popreg()	
}

.macro readLineToTXBuffer(lineaddress){
pushreg()
    ldx #$00
    stx HASTEXT        					// HASTEXT contains 00
    
    !loop:             					// Now read the line in a loop
    lda lineaddress,x
    
    cmp #$00           					// replace 0 (@ sign)
    bne !+             					// for
    lda #91            					// code 91
    
!:  cmp #32            					// is it a space?
    beq !+
    sta HASTEXT        					// HASTEXT will contain non zero if there is text on this line  
!:  sta TXBUFFER,x
    inx
    cpx #$28
    bne !loop-
    lda #$00
    sta TXBUFFER,x 						// end with zero    
popreg()
}


.macro setBufferPrefix(prefix){
pushreg()
	ldy #$00
   	lda #prefix
   	sta TXBUFFER,y
	iny
	lda #$00
	sta TXBUFFER,y
popreg()
}   
   	
.macro printRXBuffer(){
pushreg()    
    jsr $FFCC 							// CLRCHN // reset input and output to keyboard and screen
	
	ldx #$00
	!W1:	    
		lda RXBUFFER,x
		jsr $FFD2   // CHROUT
        cmp #$00
        beq !W0+
        inx
        jmp !W1-
        
    !W0:    
popreg()
}    

.macro displayText(text,addr,color,coloraddr){
pushreg()
ldx #$00
	!showms:   
   		lda text,x						// setup message
   		sec								// case conversion
   		sbc #$60
   		bcs !showchar+
   		lda text,x
	!showchar:
   		sta addr,x						// write the character
		lda #color	 					// store the color value to the a register
		sta coloraddr,x					// change the color of the character
   		inx
   		cpx #$28
   		bne !showms-
popreg()
}	

.macro ReadUntilReturn(){	
	!loop:     
  		jsr $FFCF     					// Jump to Input routine
  		cmp #$0D      					// Return (ASCII 13) pressed?
  		beq !exit+						// Yes, end.
  		sta TXBUFFER,y  				// Else, store char at buffer+Y
  		iny								// Inc. char counter
  		bne !loop-						// If Y != 0, get another char.  
	!exit: 	
}	
  	
.macro StoreChar(){
  lda CHARBUFFER
  ldx CursorIndex
  sta $770,x
  lda CursorIndex
}
 
.macro SetBorderColor(color) {
  pha									//push A to stack
  lda #color
  sta $d020
  pla									//pull the accumulator from the stack
}

// these two setcursor functions could be pushed into one, 
// but all instances of Setcursor(<val1>,<val2>) should 
// be changed to SetCursor(#<val1>,#<val2>)
.macro SetCursor(row,col){
pushreg()
    ldx #row    // Select row
	ldy #col    // Select column
	jsr $E50C   // Set cursor
popreg()
}

.macro SetCursorMem(row,col){
pushreg()
	ldx row
	ldy col
	jsr $E50C
popreg()
}

.macro CursorToIndex(){
pushreg()
   
    ldx #$16
    ldy #$00
    jsr $E50C   // Set cursor to position zero
    
    ldx #01
    !l:
    cpx CursorIndex
    beq !e+
    inx
    lda #29    
    jsr $FFD2
    jmp !l-
    !e:
popreg()
}
	
.macro CloseRS232(){
//pushreg() 
  
	lda #2
	jsr $FFC3 // CLOSE    
	jsr $FFCC // CLRCHN 				// reset input and output to keyboard and screen
	
//popreg()
}

.macro OpenRS232(){
//pushreg()
  lda #$02
  ldx #<RS232PAR
  ldy #>RS232PAR
  jsr $FFBD // SETNAM
  lda #$02
  tax
  ldy #$00
  jsr $FFBA // SETLFS
  jsr $FFC0 // OPEN
  ldx #2
  jsr $FFC6								// CHKIN.  
//popreg()
}


.macro ReceiveON(){
 pushreg()  
	
	ldx #$02
    jsr $FFC9 							// CHKOUT
  	ldx #$00	
	lda #$46							// Send 'F'
	jsr $FFD2 							// send it
	
 popreg()
}

.fill ($8000+CARTRIDGE_SIZE - *),0
