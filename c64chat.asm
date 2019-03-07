// **********************************************************************************************
// **********************************************************************************************
// Helpfull links:
//    http://unusedino.de/ec64/technical/project64/mapping_c64.html
//
//
// serial comunication prefixes
// this is a list of the prefix characters for comunicating to the arduino
//W = set ssid
//Q = get ssid
//P = set password
//A = get password
//V = set username
//G = check for new messages, not implemented yet
//N = send message, first line
//S = send message, subsequent lines
//L = get userlist
//F = Fetch message


// END OF PREFIXES  -----------------------------------------------------------------------------

arduino:BasicStarter(init)

init:
// Do our init stuff here

   jsr $E544; // Clear screen  
   lda #$06
   ora $d018
   sta $d018 
 

// **********************************************************************************************
// **********************************************************************************************
// Main Loop of the program
mainprogram:
    OpenRS232()    
    jsr $E544; // Clear screen
    DrawLine()
	mainloop:
 
	jmp keyscan
	
	jmp mainloop 
		

// END OF MAIN LOOP -----------------------------------------------------------------------------


  

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

	jsr $E544						// Clear screen
	lda #$00						// Clear TX Buffer    	
    sta TXBUFFER
        
    displayText(ssidnow,$0400,
    	14,$D800)					// Text line for current SSID
    displayText(passwordnow,
    	$0428,14,$D828)				// Text line for current Password
    
    lda #$51
    sta TXPREFIX 		  			// GET the ssid from the serial device    
									// Fill the TXBUFFER with  Q,0 and call rs232TX
									// $51=Q
    jsr !rs232TXRX+					// Send the buffer and wait for the response
		 
	SetCursor($00,$0E)  			// move cursor to first line
	printRXBuffer()					// Display RX buffer
	
	lda #$41
    sta TXPREFIX					// Get the password from the serial device
									// Fill the TXBUFFER with  A,0 and call rs232TX
									// $41=A
	jsr !rs232TXRX+					// Send the buffer and wait for the response
	SetCursor($01,$12)		        // move cursor
	printRXBuffer()  				// Display RX buffer 
	displayText(askssid,
		$0478,14,$D878)				// Display the SSID question
	displayText(entertoexit,
		$04F0,14,$D8F0)				// Display message "press RETURN to exit"
	SetCursor($04,$00)  			// Now the user can type the ssid	
	
	ldy #$00    					// Y = char counter = 0
	ReadUntilReturn()	
	cpy #01							// if the y counter is still 0, user pressed Return without any input -> exit	
	bne !+							// exit if zero
	jmp !exitWifiSetup+
	!:	
  	lda #$00    					// end the string with 0
  	sta TXBUFFER,y
  	
    			        	   	 	// at this point return was pressed.
        	    			  	  	// TXBUFFER holds the SSID Name
    	            				// Send the SSID to the serial port.
    lda #$57
    sta TXPREFIX       				// First character in the txbuffer should be W (so the arduino knows this is the SSID string)
	jsr !rs232TXRX+					// Send the buffer and wait for the response
					
	
	displayText(askpassword,
	            $04F0,14,$D8F0)		// Now Ask for the wifi Password
	
    SetCursor($07,$00)				// Now the user can type the password 						 
	lda #$50
    sta TXPREFIX       				// First character in the txbuffer should be P (so the arduino knows this is the Password)
	ldy #$00
	ReadUntilReturn()	    
  	lda #$00    					// end the string with 0
  	sta TXBUFFER,y
  	jsr !rs232TXRX+					// Send the buffer and wait for the response

!exitWifiSetup:
jmp mainprogram

// END OF SETUP WIFI ----------------------------------------------------------------------------

// **********************************************************************************************
// **********************************************************************************************
// LIST USERS
// this is a 'wizard' that lists the currently active users
// this screen is activated when F2 is pressed in the main window
!listUsers:
 
	jsr $E544; // Clear screen
    
	displayText(numberuserstxt,$0400,14,$D800)    //message: list of currently active users
	displayText(waituserslisttxt, $07C0,14,$DBC0)    //message: Collecting users, please Wait
	
	//setup the loop for the list
	ldy #3
	sty cursorY
	ldx #0
	stx cursorX
	!listloop:
	lda #$4C						// Fill the buffer with L (4C = L)
    sta TXPREFIX 					// And send it
    jsr !rs232TXRX+	     			// And wait for the response    		
	lda	RXBUFFER					// Check if the response is empty
	cmp #00							// there are no more names
	beq !endOfList+					// stop printing names
    SetCursorMem(cursorY,cursorX)	// cursor on the right possition
	printRXBuffer()					// print new name
		!setlistpos:
									//first see if we are on the first or second row			
		lda cursorX						
		beq !moveright+				//if the X position is on the left half of the screen, move it to the right half
		jmp !moveleft+				//else move it to the left half
		!moveright:			
		ldx #20			
		stx cursorX					//set the cursor position to the right half of the screen	
		jmp !listloop-			
		!moveleft:			
		ldx #0			
		stx cursorX					//move the cursor position to the left			
		iny							//move the cursor position one line down
		sty cursorY
		cpy #20						//if we are not at the bottom of the list yet
		bne !listloop-				//get the next name
	
    //users have been printed
    //wait for user input to either close the list, or to change nickname

!endOfList:    
  //  jsr $FFCC
  //  jsr $FFCF
    
    displayText(changeusertxt, $07C0,14,$DBC0)    //message: change name(F1), back (F1)
    !waitforinput:
    jsr $FFCC
    jsr $ffe4       				//read key
    beq !waitforinput-				//if no key pressed loop forever
!:  cmp #133   						// F1 pressed
    bne !+
    jmp !changename+
!:  cmp #136        				// F7 pressed
    bne !+
    jmp !exitlistUsers+
!:  jmp !waitforinput-				//if a different key was pressed, ignore it and wait for more input
!exitlistUsers:
jmp mainprogram
// END OF LIST USERS ----------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// this is a 'wizard' that allows the user to change his/her name
// this screen is activated when F1 is pressed in the list user window
!changename:
 
    jsr $E544; // Clear screen

  	// Ask the username Question
  	displayText(askyourname,$0400,14,$D800)
   		
   !username:   
	// Now the user can type his user name
	SetCursor($01,$00)	 
	ldy #$00 
	ReadUntilReturn()	  
	lda #$00    	// end the string with 0
  	sta TXBUFFER,y

    lda #$56						// Fill the buffer with L (46 = V)
    sta TXPREFIX 					// And send it
    								// wait for the reply (server checks if username is allready taken)
    jsr !rs232TXRX+					// Get the response
    
	
	// Check the buffer for errors
	// E001 = name already taken
	// A000 = all ok, carry on, nothing to see here
	ldx #$00
	lda RXBUFFER,x
	cmp #69  // if the buffer starts with E
    beq !error+
    jmp !exitchangename+         
    
	!error:
	// show username error
	  
	ldx #$0A ; jsr $E9FF  // clear input line 
	displayText(errorusername,$05B8,10,$D9B8)
  	jmp !username-
	
!exitchangename:
jmp mainprogram
// END OF CHANGENAME ---------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// This is the scan Routine
// We do not use the kernal input routines for this, we want more control over the position
// of the cursor. Also we need to receive data while the user is typing (receive needs to be non-blocking).

handleLeft: 
  StoreChar() 
  cmp #00         				// compare MEMP
  bne !+
  jmp !exit+
!:ldx MEMP
  dex
  stx MEMP
  lda $770,x
  sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2       				//show key on the screen  
!exit:jmp readKey
  
handleRight: 
  StoreChar()
  cmp #119						// compare MEMP
  bne !+
  jmp !exit+
!:ldx MEMP
  inx
  stx MEMP
  lda $770,x
  sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2						//show key on the screen
!exit:jmp readKey

handleUp: 
  StoreChar()
  cmp #40
  bmi !exit+					// if MEMP <= 41, ignore
  sbc #40         				// substract 40
  sta MEMP        				// store new value
  ldx MEMP
  lda $770,x
  sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2						//show key on the screen
!exit: jmp readKey
  
handleDown:
  StoreChar()
  cmp #80         				// compare MEMP
  bpl !exit+      				// if MEMP >= 81, ignore
  adc #40         				// add 40
  sta MEMP        				// store new value
  ldx MEMP
  lda $770,x
  sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2      				//show key on the screen
!exit:jmp readKey
   
handleDel:   
  StoreChar() 
  cmp #00         				// compare MEMP
  bne !+
  jmp !exit+ 
!:ldx MEMP
  dex
  stx MEMP
  //lda $770,x
  lda #32
  sta CHARBUFFER
  lda #157
  // lda zpBuffer
  jsr $FFD2       				//show key on the screen  
!exit:jmp readKey

keyscan:    
    SetCursor($16,$00)
	ldx #00
	stx MEMP
	jsr $FFCC   				// CLRCHN // reset input and output to keyboard and screen
	
!showcur:
    // display a cursor    
    ldx MEMP
    lda #$A0   
    sta $770,x        
    jmp ncol

!incpg: 
    inc PRGCNT  
    inc PRGCNT
    inc PRGCNT
    lda PRGCNT    
    cmp #128       
    bmi !showcur-				// if PRGCNT >= 128 goto !showcur  
    
!hidecur:    
    lda CHARBUFFER
    ldx MEMP
    sta $770,x    
    jmp ncol
    
readKey:	
    inc HCOUNT 
    lda HCOUNT
    cmp #00
    beq !incpg-
    cmp #64
    beq !incpg-
    cmp #128
    beq !incpg-
    cmp #192
    beq !incpg-

ncol:
   
    jsr !readIncomming+	
	jsr $FFCC
	jsr $ffe4       			//read key
    beq readKey     			//if no key pressed loop forever
    sta zpBuffer    			//store the key to key buffer
    cmp #17         			// Handle Cursor Down
    bne !+
    jmp handleDown
!:  cmp #145        			// Handle Cursor UP
    bne !+
    jmp handleUp
!:  cmp #13						// Handle return key
    bne !+
    jmp handleReturnkey
!:  cmp #133   					// F1 pressed
    bne !+
    jmp !setupWiFi-   
!:  cmp #137     				// F2 pressed
    bne !+
    jmp !listUsers-
!:  cmp #136    				// F7 pressed
    bne !+
    jmp autosend
!:  cmp #157					// Handle Left Cursor
    bne !+
    jmp handleLeft
!:  cmp #20						// Handle Delete
    bne !+
    jmp handleDel
    
!:  jmp handleRight				// other keys should also be handleRight
      
handleReturnkey:
    StoreChar()
    cmp #80
    bpl autosendjump 			// if MEMP >= 81, autosend
!:  cmp #40
    bpl Return2
    lda #40
    sta MEMP
    ldx MEMP
    lda $770,x
    sta CHARBUFFER
    lda zpBuffer    
    
    jsr $FFD2       			//show key on the screen
    jmp readKey

autosendjump:
	jmp autosend
	
Return2:
    lda #80         			// Set MEMP to postion 80
    sta MEMP
	lda zpBuffer    			// Load the keybuffer
    jsr $FFD2       			//show key on the screen
    jmp readKey
      
// END OF KEYSCAN ROUTINE -----------------------------------------------------------------------

// **********************************************************************************************
// **********************************************************************************************
// ShiftScreen UP
ShiftScreen:    
    ldx #$00					//offset
    !loop: 
    lda $428,x					//load the character
    sta $400,x					//write the character somewhere else
    lda $D828,x					//load the color
    sta $D800,x					//write the color somewhere else
    inx   
    cpx #$F0					// 6 lines
    bne !loop-
    
    ldx #$00
    !loop: 
    lda $518,x    
    sta $4F0,x
    lda $D918,x
    sta $D8F0,x
    inx   
    cpx #$F0					// 6 lines
    bne !loop-    
    
    ldx #$00
    !loop: 
    lda $608,x    
    sta $5E0,x
    lda $DA08,x
    sta $D9E0,x
    inx   
    cpx #$F0					// 6 lines
    bne !loop-
    
    ldx #$00
    !loop: 
    lda $6F8,x    
    sta $6D0,x
    lda $DAF8,x
    sta $DAD0,x
    inx   
    cpx #$50					// 2 lines
    bne !loop-
    //clear last line loop
    ldx #$00
    lda #32
    !loop:
    sta $720,x
    inx
    cpx #40
    bne !loop-
rts

DisplaySendMessage:    
pushreg() 
    // write the buffered line to the screen    
    ldx #00
    ldy #01
    !loop:
    lda TXBUFFER,x
    
    cmp #91     				// Change number 91
    bne !+      				// Back to
    lda #00     				// the @ sign
    
!:  sta $720,x					//store the character to the screen
	tya 						//store the color value to the a register
	sta $DB20,x					//change the color of the letter
    inx
    cpx #$28
    bne !loop-
popreg()
rts

DisplayReceiveMessage:
pushreg()
								// write the received line to the screen
	ldx #00						//set x to 0
	ldy RXMESSCOL				//Load color into y
	!loop:
	lda RXBUFFER,x				//load a character from the rxbuffer
	cmp #$00					//if the character is equal to 00
	beq !exit+					//then its the end of the string, so exit the loop
	cmp #91
	bne !+
	lda #0
!:	sta $720,x					//else, output the character to the screen
	tya							//load the color code stored in Y into A			
	sta $DB20,x					//change the color of the space the letter will appear on.
	inx							//increment X for the next character
	cpx #$28					//see if x is at the end of the screen
	bne !loop-					//if not go back and read the next character
!exit:
popreg()
rts

// **********************************************************************************************
// **********************************************************************************************
// AUTOSEND
// When the user presses enter on the last line or when pressing F7, this routine goes off and sends the data
autosend:
 
    // send each line as a separate message
    // The first line will get the 'N' prefix (for new message)
    // other lines get the 'S' prefix
    
    //  ALL MESSAGES GO TO THE GROUP UNLESS IT STARTS WITH @USERNAME:  
    //  JUST SEND THE MESSAGE 'AS IS', WE WILL FIGURE OUT IN PHP WHO THE RECIEVER SHOULD BE      
    
    lda CHARBUFFER 						// display the character under the cursor in stead of the cursor
    ldx MEMP    						// current cursor position
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
!lr: lda TXBUFFER,x
    sta RECEIVER,x
    //sta $400,x
    cmp #$3A 							// end at :
    beq !skip+
    inx
    cpx #$0B
    bne !lr-
    
!skip:  // shift message box
    ldx #$00
    !loop: 
   // inc $d020
    lda $798,x    
    sta $770,x
    inx   
    cpx #$50		// 1 regel
    bne !loop-
    ldx #$18 ; jsr $E9FF  // clear line 18(hex)
    ldx LINECOUNT     
    inx
    cpx #03
    beq !exitloop+
    stx LINECOUNT
    jmp !lineloop-

!exitloop:
    

    // clear the message lines
    ldx #$16 ; jsr $E9FF  // clear line 16(hex)
    ldx #$17 ; jsr $E9FF  // clear line 17(hex)
    ldx #$18 ; jsr $E9FF  // clear line 18(hex)
    
    // if there was a reveiver, put it in the box again:
    ldx #$00    
    lda RECEIVER,x
    cmp #91 
    bne !noreceiver+    
    lda #00
    ldx #00
    sta $770,x
    sta RECEIVER,x         // Set the receiver back to 0    
    inx
!wr:    lda RECEIVER,x
    sta $770,x
    cmp #$3A				// end after :
    beq !skip+
    lda #00
    sta RECEIVER,x    
    inx    
    cpx #12
    bne !wr-    
!skip:    
	inx							// Get the cursor back to the right place
	stx MEMP					// Right after the @receiver:
    txa    
    tay    						// Set column
    ldx #$16    				// Select row	
	jsr $E50C   				// Set cursor
	jsr $FFCC   				// CLRCHN // reset input and output to keyboard and screen
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
    jsr $FFC9 				// CHKOUT
  	ldx #$00	
	lda TXPREFIX
	cmp #$00				// IF the prefix is 0, skip
	beq !loop+				//
	jsr $FFD2 				// send the prefix CHROUT
	!loop:					// Loop to send the TX Buffer
		lda TXBUFFER,X
		cmp #$00			// If the buffer char is 0
        beq !endRs232TX+		// end the sequence                              
        jsr $FFD2 			// CHROUT        
        inc $d020	    	// set border color        
        inx
        bne !loop-
	!endRs232TX:
	lda #$00				// End with 0
	jsr $FFD2				// CHROUT
	
	!WaitForResponse:
	ldx #$02
 	jsr $FFC6		        // CHKIN
 	ldx #$00
    !skip: 					// Skip garbage until  <STX> signs begin (transmission starts with STX STX)
    inc $d020 
    jsr $FFCF				// CHRIN
    cmp #$02         		// <STX>
    bne !skip-
	!rx:					// Loop to receive the buffer
		inc $d020
 		jsr $FFCF	        // CHRIN
 		cmp #$FF			// Transmission ends with FF (255)
 		beq !finishbuffer+ 
        cmp #$02    	   // <STX>         // Skip the <STX> signs
    	beq !rx-			// restart loop without storing character                        
    	sta RXBUFFER,x		// Store the character
 		inx					
 		jmp !rx-          	// jump to rx loop
 	  
  	!finishbuffer:		
		lda #$00
		sta RXBUFFER,x
		 
        SetBorderColor(14)   // set border color to default
popreg()
rts  
// END OF RS232TXRX ROUTINE -----------------------------------------------------------------------



// **********************************************************************************************
// **********************************************************************************************
!readIncomming:
pushreg()  
  
  							// See if there is any data in the RS232 receive buffer
  lda $029B 				// end index marker
  cmp $029C                 // start index marker
  
            				// if the difference is zero there is nothing
  beq !exit+ 				// so exit
  
  // we have data to collect
  SetBorderColor(0)			// border goes black
  ldx #$02
  jsr $FFC6					// CHKIN
  jsr $FFCF					// CHRIN
  cmp #250					// RESET OUR BUFFER INDEX (250 is start of message)
  beq !resetBuffer+
  cmp #92
  bne !+
  ldx #13
  stx RXMESSCOL
  jmp !exit+
!: cmp #255					// Finish the buffer and display message  
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
  SetBorderColor(14)
  
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
!:
popreg()
rts
// END OF readIncomming ROUTINE -----------------------------------------------------------------------	


delay:
   	ldx #$FF	 
   	loopy:
   	ldy #$FF
   	  loopx:
   	    inc $d020
   	    dey
   	    bne loopx
   	dex
	bne loopy
	//SetBorderColor(14)  // set border color to default
rts

//* = $1000
ssidnow:			.text "Current SSID:                   " // 32 chars
passwordnow:		.text "Current Password:               " // 32 chars
askssid:    		.text "Name of the wifi network (SSID):" // 32 chars
askpassword:   		.text "What is the Wifi Password?:     " // 32 chars
askyourname:    	.text "What is your user name?:        " // 32 chars
errorusername:  	.text "ERROR: Name allready taken      " // 32 chars      
numberuserstxt: 	.text "List of connected users:        " // 32 chars      
changeusertxt:  	.text "Change username (F1), Back (F7) " // 32 chars      
entertoexit:		.text "Just press RETURN to exit       " // 32 chars  
errornouser:		.text "ERROR: No user with that name!  " // 32 chars  
waituserslisttxt: 	.text "Collecting users, please Wait   " // 32 chars

    
TXBUFFER:   	.fill 256,0            
RXBUFFER:   	.fill 256,0                                                 
LINEBUFFER:   	.fill 256,0
RS232PAR:     	.byte %00000110,%00000000 // 300 Baud  
//RS232PAR:     	.byte %00001000,%00000000 // 1200 Baud  

MEMP:           .byte $00 // temp buffer for cursor postion offset, also line length
PRGCNT:         .byte $00 
HCOUNT:			.byte $00
CHARBUFFER:     .byte $20
zpBuffer:       .byte $fa,$fb    
HASTEXT:        .byte $00   
TXPREFIX:       .byte $00
LINECOUNT:      .byte $00
RECEIVER:       .fill 50,0
RXMESSCOL:		.byte $05

cursorX:		.byte $00
cursorY:		.byte $00

BUFFERPOS:		.byte $00

FCOUNTER:		.byte $00
FCOUNTER2:		.byte $C8

    


/* MACROS  */
.macro pushreg(){
	php		//push the status register to stack
	pha		//push A to stack
	txa		//move x to a
	pha		//push it to the stack
	tya		//move y to a
	pha		//push it to the stack	               
}

.macro popreg(){
	pla		//pull the y register from the stack
	tay		//move it to the y register
	pla		//pull the x register from the stack
	tax		//move it to the x register
	pla		//pull the acimulator from the stack
	plp		//pull the the processor status from the stack
}

.macro readLineToTXBuffer(lineaddress){
pushreg()
    ldx #$00
    stx HASTEXT        	// HASTEXT contains 00
    
    !loop:             	// Now read the line in a loop
    lda lineaddress,x
    
    cmp #$00           	// replace 0 (@ sign)
    bne !+             	// for
    lda #91            	// code 91
    
!:  cmp #32            	// is it a space?
    beq !+
    sta HASTEXT        	// HASTEXT will contain non zero if there is text on this line  
!:  sta TXBUFFER,x
    inx
    cpx #$28
    bne !loop-
    lda #$00
    sta TXBUFFER,x 		// end with zero    
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
    jsr $FFCC // CLRCHN // reset input and output to keyboard and screen
	
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
   		lda text,x			// setup message
   		sec					// case conversion
   		sbc #$60
   		bcs !showchar+
   		lda text,x
	!showchar:
   		sta addr,x			// write the character
		lda #color	 		// store the color value to the a register
		sta coloraddr,x			// change the color of the character
   		inx
   		cpx #$20
   		bne !showms-
popreg()
}	

.macro ReadUntilReturn(){
//pushreg()	
	!loop:     
  		jsr $FFCF     		// Jump to Input routine
  		cmp #$0D      		// Return (ASCII 13) pressed?
  		beq !exit+			// Yes, end.
  		sta TXBUFFER,y  	// Else, store char at buffer+Y
  		iny					// Inc. char counter
  		bne !loop-			// If Y != 0, get another char.  
	!exit: 	
//popreg()
}	
  	
.macro StoreChar(){
//pushreg()
  lda CHARBUFFER
  ldx MEMP
  sta $770,x
  lda MEMP
//popreg()
}
 
.macro SetBorderColor(color) {
  pha		//push A to stack
  lda #color
  sta $d020
  pla		//pull the accumulator from the stack
}

//these two setcursor functions could be pushed into one, but all instances of Setcursor(<val1>,<val2>) should be changed to SetCursor(#<val1>,#<val2>)
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
	
.macro CloseRS232(){
//pushreg() 
  
	lda #2
	jsr $FFC3 // CLOSE    
	jsr $FFCC // CLRCHN // reset input and output to keyboard and screen
	
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
  jsr $FFC6					// CHKIN.  
//popreg()
}

.macro DrawLine(){
pushreg()
	SetCursor($15,$00)
	ldx #40
    lda #185
	line:
	jsr $FFD2   // CHROUT
	dex
	bne line
	SetCursor($16,$00)
popreg()
}

.macro ReceiveON(){
 pushreg()  
	
	ldx #$02
    jsr $FFC9 				// CHKOUT
  	ldx #$00	
	lda #$46				// Send 'F'
	jsr $FFD2 				// send it
	
 popreg()
}




.macro BasicStarter(address) {
	* = $0801 "Basic"
	.word upstartEnd  // link address
    .word 10   // line num
    .byte $9e  // sys
	.text toIntString(address)
	.byte 0
upstartEnd:
    .word 0  // empty link signals the end of the program

     
    * = $080e "Basic End"
}
// **********************************************************************************************
// **********************************************************************************************

