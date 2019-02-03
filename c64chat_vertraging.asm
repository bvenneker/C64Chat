// **********************************************************************************************
// **********************************************************************************************
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
//D = debug
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
	jsr $E544; // Clear screen
        
    displayText(ssidnow,$0400)		// Text line for current SSID
    displayText(passwordnow,$0428)  // Text line for current Password
    
    sendBuffer($51)	     			// GET the ssid from the serial device    
									// Fill the TXBUFFER with  Q,0 and call rs232TX
									// $51=Q   	
	jsr rs232RX   					// reveice the response	 
	SetCursor($00,$0E)  			// Display RX buffer
	printRXBuffer()
	
	sendBuffer($41)					// Get the password from the serial device
									// Fill the TXBUFFER with  A,0 and call rs232TX
									// $41=A
	jsr rs232RX 					// receive the repsonse  
	SetCursor($01,$12)		
	printRXBuffer()  				// Display RX buffer 
	displayText(askssid,$0478)  	//Display the SSID question
	SetCursor($04,$00)  			// Now the user can type the ssid	
	lda #$57
    sta TXPREFIX       				// First character in the txbuffer should be W (so the arduino knows this is the SSID string)
	ldy #$00    					// Y = char counter = 0
	ReadUntilReturn()	
  	lda #$00    					// end the string with 0
  	sta TXBUFFER,y
  	
    			        	   	 	// at this point return was pressed.
        	    			  	  	// TXBUFFER holds the SSID Name
    	            				// Send the SSID to the serial port.
	jsr rs232TX     				// jump to the send routine
					
	
	displayText(askpassword,$04F0)		// Now Ask for the wifi Password
	
    SetCursor($07,$00)				// Now the user can type the password 						 
	lda #$50
    sta TXPREFIX       				// First character in the txbuffer should be P (so the arduino knows this is the Password)
	ldy #$00
	ReadUntilReturn()	    
  	lda #$00    					// end the string with 0
  	sta TXBUFFER,y
  	jsr rs232TX     				// jump to the send routine
  	
jmp mainprogram

// END OF SETUP WIFI ----------------------------------------------------------------------------

// **********************************************************************************************
// **********************************************************************************************
// LIST USERS
// this is a 'wizard' that lists the currently active users
// this screen is activated when F2 is pressed in the main window
!listUsers:
	jsr $E544; // Clear screen
    
	displayText(numberuserstxt,$0400)    //message: list of currently active users
	displayText(changeusertxt, $07C0)    //message: change name(F1), back (F1)
	
	//setup the loop for the list
	ldy #3
	sty cursorY
	ldx #0
	stx cursorX
	!listloop:
    sendBuffer($4C)	     			// GET the ssid from the serial device    
									// Fill the TXBUFFER with  L,0 and call rs232TX
									// $4C=L   	
	jsr rs232RX   					// reveice the response	
	lda	RXBUFFER
	cmp #00							//there are no more names
	beq !waitforinput+				//stop printing names
    SetCursorMem(cursorY,cursorX)              // cursor on the right possition
	printRXBuffer()					//print new name
		!setlistpos:
		//first see if we are on the first or second row			
		lda cursorX						
		beq !moveright+			//if the X position is on the left half of the screen, move it to the right half
		jmp !moveleft+			//else move it to the left half
		!moveright:			
		ldx #20			
		stx cursorX		//set the cursor position to the right half of the screen	
		jmp !listloop-			
		!moveleft:			
		ldx #0			
		stx cursorX		//move the cursor position to the left			
		iny				//move the cursor position one line down
		sty cursorY
		cpy #20			//if we are not at the bottom of the list yet
		bne !listloop-	//get the next name
	
    //users have been printed
    //wait for user input to either close the list, or to change nickname
    !waitforinput:
    jsr $ffe4       //read key
    beq !waitforinput-     //if no key pressed loop forever
!:  cmp #133   		// F1 pressed
    bne !+
    jmp !changename+
!:  cmp #136        // F7 pressed
    bne !+
    jmp mainprogram
!:  jmp !waitforinput-  //if a different key was pressed, ignore it and wait for more input

jmp mainprogram
// END OF LIST USERS ----------------------------------------------------------------------------

// **********************************************************************************************
// **********************************************************************************************
// this is a 'wizard' that allows the user to change his/her name
// this screen is activated when F1 is pressed in the list user window
!changename:
    jsr $E544; // Clear screen

  	// Ask the username Question
  	displayText(askyourname,$0400)
   		
   !username:   
	// Now the user can type his user name
	SetCursor($01,$00)	 
	lda #$56
    sta TXPREFIX       // // First character in the txbuffer should be V (so the arduino knows this is the user name)

	ReadUntilReturn()	  
	lda #$00    	// end the string with 0
  	sta TXBUFFER,y
  	jsr rs232TX     // jump to the send routine
  	
  	// wait for the reply (server checks if username is allready taken)
  	jsr rs232RX           // Get the response
  		
	
	// Check the buffer for errors
	// E001 = name already taken
	// A000 = all ok, carry on, nothing to see here
	ldx #$00
	lda RXBUFFER,x
	cmp #69  // if the buffer starts with E
    beq !error+
    jmp !endofsub+         
    
	!error:
	// show username error
	  
	ldx #$0A ; jsr $E9FF  // clear input line 
	displayText(errorusername,$05B8)
  	jmp !username-
	
!endofsub:

jmp mainprogram
// END OF CHANGENAME ---------------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// This is the scan Routine
// We do not use the kernal input routines for this, we want more control over the position
// of the cursor. Also we need to transmit and receive data while the user is typing.

handleLeft: 
  StoreChar() 
  cmp #00         // compare MEMP
  bne !+
  jmp !exit+
!:ldx MEMP
  dex
  stx MEMP
  lda $770,x
  sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2       //show key on the screen  
!exit:jmp readKey
  
handleRight: 
  StoreChar()
  cmp #119 // compare MEMP
  bne !+
  jmp !exit+
!:ldx MEMP
  inx
  stx MEMP
  lda $770,x
  sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2       //show key on the screen
!exit:jmp readKey

handleUp: 
  StoreChar()
  cmp #40
  bmi !exit+          // if MEMP <= 41, ignore
  sbc #40         // substract 40
  sta MEMP        // store new value
  ldx MEMP ; lda $770,x ; sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2       //show key on the screen
!exit:jmp readKey
  
handleDown:
  StoreChar()
  cmp #80         // compare MEMP
  bpl !exit+      // if MEMP >= 81, ignore
  adc #40         // add 40
  sta MEMP        // store new value
  ldx MEMP ; lda $770,x ; sta CHARBUFFER
  lda zpBuffer
  jsr $FFD2       //show key on the screen
!exit:jmp readKey
   
handleDel:   
  StoreChar() 
  cmp #00         // compare MEMP
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
  jsr $FFD2       //show key on the screen  
!exit:jmp readKey


keyscan:    
    SetCursor($16,$00)
	ldx #00
	stx MEMP
	jsr $FFCC   // CLRCHN // reset input and output to keyboard and screen
	
 
setcur:
    // display a cursor
    lda #$64
    ldx MEMP
    sta $770,x
    jmp ncol

incpg: 
    inc PRGCNT ; inc PRGCNT ; inc PRGCNT // <-----  
    lda PRGCNT
    cmp #128
    bmi setcur
    // hide the cursor
    lda CHARBUFFER
    ldx MEMP
    sta $770,x
    jmp ncol
    
readKey:	
    inc HCOUNT 
    lda HCOUNT
    cmp #00
    beq incpg

ncol:
	jsr pollrs
	jsr $ffe4       //read key
    beq readKey     //if no key pressed loop forever
    sta zpBuffer    //store the key to key buffer
    cmp #17         // Handle Cursor Down
    bne !+
    jmp handleDown
!:  cmp #145        // Handle Cursor UP
    bne !+
    jmp handleUp
!:  cmp #13			// Handle return key
    bne !+
    jmp handleReturnkey
!:  cmp #133   		// F1 pressed
    bne !+
    jmp !setupWiFi-
!:  cmp #137        // F2 pressed
    bne !+
    jmp !listUsers-
!:  cmp #136        // F7 pressed
    bne !+
    jmp autosend
!:  cmp #157        // Handle Left Cursor
    bne !+
    jmp handleLeft
!:  cmp #20         // Handle Delete
    bne !+
    jmp handleDel
    
!:  jmp handleRight  // other keys should also be handleright
      
handleReturnkey:
    StoreChar()
    cmp #80
    bpl autosend   // if MEMP >= 81, autosend
    cmp #40
    bpl Return2
    lda #40
    sta MEMP
    ldx MEMP ; lda $770,x ; sta CHARBUFFER ; lda zpBuffer
    
    jsr $FFD2       //show key on the screen
    jmp readKey

Return2:
    lda #80         // Set MEMP to postion 80
    sta MEMP
	lda zpBuffer    // Load the keybuffer
    jsr $FFD2       //show key on the screen
    jmp readKey
      
// END OF KEYSCAN ROUTINE -----------------------------------------------------------------------

// **********************************************************************************************
// **********************************************************************************************
// ShiftScreen UP
ShiftScreen:    
    ldx #$00
    !loop: 
    lda $428,x    
    sta $400,x
    inx   
    cpx #$F0		// 6 regels
    bne !loop-
    
    ldx #$00
    !loop: 
    lda $518,x    
    sta $4F0,x
    inx   
    cpx #$F0		// 6 regels
    bne !loop-    
    
    ldx #$00
    !loop: 
    lda $608,x    
    sta $5E0,x
    inx   
    cpx #$F0		// 6 regels
    bne !loop-
    
    ldx #$00
    !loop: 
    lda $6F8,x    
    sta $6D0,x
    inx   
    cpx #$78		// 3 regels
    bne !loop-
    
    // write the buffered line to the screen    
    ldx #00
    !loop:
    lda TXBUFFER,x
    
    cmp #91     // Change number 91
    bne !+      // Back to
    lda #00     // the @ sign
    
!:  sta $720,x
    inx
    cpx #$28
    bne !loop-
    
rts

// **********************************************************************************************
// **********************************************************************************************
// AUTOSEND
// When the user presses enter on the last line or when typing until the very last corner
// or when pressing F7, this routine goes off and sends the data
autosend:
    // send each line as a separate message
    // The first line will get the 'N' prefix (for new message)
    // other lines get the 'S' prefix
    
    //  ALL MESSAGES GO TO THE GROUP UNLESS IT STARTS WITH @USERNAME:  
    //  JUST SEND THE MESSAGE 'AS IS', WE WILL FIGURE OUT IN PHP WHO THE RECIEVER SHOULD BE      
       

    // hide the cursor (or else you will send it too)
    lda #32     // space
    ldx MEMP    // current cursor position
    sta $770,x
    
    // Get first line into the buffer
    
    lda #$00
    sta LINECOUNT
    lda #$4E
    sta TXPREFIX  // set prefix to 'N' for the first line          
    
!lineloop:
    readLineToTXBuffer($770)
    lda HASTEXT ;  cmp #$00 ;  beq !+    // see if the line has any text, skip next commands if empty     
    
    jsr rs232TX
    jsr rs232RX   // wait for reply
    jsr ShiftScreen
    lda #$53  
    sta TXPREFIX  // set prefix to 'S' for the next lines  
    
!:  lda LINECOUNT 			// on the first line
    cmp #$00				// look for a receiver
    bne !skip+			   	// Skip if we are not on the first line

!lookforreceiver:  
    ldx #$00
    lda TXBUFFER,x
    cmp #91
    bne !skip+
    sta RECEIVER,x
    lda #00
    sta $400,x
    inx
!lr: lda TXBUFFER,x
    sta RECEIVER,x
    sta $400,x
    inx
    cpx #$0B
    bne !lr-
    
!skip:  // shift message box
    ldx #$00
    !loop: 
    inc $d020
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
    
   	// jsr delay
  
    // clear the message lines
    ldx #$16 ; jsr $E9FF  // clear line 16(hex)
    ldx #$17 ; jsr $E9FF  // clear line 17(hex)
    ldx #$18 ; jsr $E9FF  // clear line 18(hex)
    
    // if there was a reveiver, put it in the box again:
    ldx #$00    
    lda RECEIVER,x
    cmp #91 
    bne !skip+    
    lda #00
    ldx #00
    sta $770,x
    sta RECEIVER,x         // Set the receiver back to 0
    inx
!wr:    lda RECEIVER,x
    sta $770,x
    lda #00
    sta RECEIVER,x
    inx    
    cpx #12
    bne !wr-
    
!skip:    
jmp keyscan



// END OF KEYSCAN ROUTINE -----------------------------------------------------------------------


// **********************************************************************************************
// **********************************************************************************************
// This routine sends data over rs232 to our microcontroller
// It transmits the content of TXBUFFER
rs232TX:	
pushreg()	
    OpenRS232()
	// PREPARE TO TRANSMIT
 SetBorderColor(11) 
    ldx #$02
    jsr $FFC9 				// CHKOUT
    ldx #$00
 SetBorderColor(10) 
	// TRANSMISSION
	lda TXPREFIX
	cmp #$00
	beq !loop+
	jsr $FFD2 			// CHROUT 
	!loop:
		lda TXBUFFER,X
        cmp #$00
        beq endRs232TX                              
        jsr $FFD2 			// CHROUT        
        inc $d020    		// set border color        
        inx
        bne !loop-

	endRs232TX:
	    lda #$00			// End with 0
	    jsr $FFD2 			// CHROUT  
		CloseRS232()      
        SetBorderColor(14)   // set border color to default
        lda #$00
        sta TXPREFIX       // reset the TXPREFIX
        
popreg()
rts
// END OF RS232TX Routine -----------------------------------------------------------------------

pollrs:
pushreg()
	inc $d020
	sendBuffer($44)
	jsr rs232RX
popreg()
rts

// **********************************************************************************************
// **********************************************************************************************
// Recieve data over the rs232 interface at 300 Baud
rs232RX:
      pushreg()  
		OpenRS232()
 
		inc $d020
 		ldx #$02
 		jsr $FFC6        // CHKIN
 		ldx #$00
    !skip: 			     // Skip garbage until  <STX> signs begin (transmission starts with STX STX STX)
        inc $d020 
        jsr $FFCF        // CHRIN
        cmp #$02         // <STX>
        bne !skip-
	rx:
 		inc $d020
 		jsr $FFCF        // CHRIN
 		cmp #$0D
 		beq finishbuffer 
        cmp #$02       // <STX>         // Skip the <STX> signs
        beq rx                        
 		sta RXBUFFER,x
 		inx
 		jmp rx          // jump to rx loop
 	  
  	finishbuffer:		
		lda #$00
		sta RXBUFFER,x
		CloseRS232()
        SetBorderColor(14)   // set border color to default
       popreg()
rts  

// END OF RS232 RX ------------------------------------------------------------------------------
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
	SetBorderColor(14)  // set border color to default
rts

// * = $1000
ssidnow:		.text "Current SSID:                   " // 32 chars
passwordnow:	.text "Current Password:               " // 32 chars
askssid:    	.text "Name of the wifi network (SSID):" // 32 chars
askpassword:   	.text "What is the Wifi Password?:     " // 32 chars
askyourname:    .text "What is your user name?:        " // 32 chars
errorusername:  .text "ERROR: Name allready taken      " // 32 chars      
numberuserstxt:    .text "List of connected users:        " // 32 chars      
changeusertxt:     .text "Change username (F1), Back (F7) " // 32 chars      
    
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

cursorX:		.byte $0
cursorY:		.byte $0

    


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

.macro delay1(){
pushreg()
   	ldx #$FF	 
   	loopy:
   	ldy #$FF
   	  loopx:
   	    inc $d020
   	    dey
   	    bne loopx
   	dex
	bne loopy
	SetBorderColor(14)  // set border color to default
popreg()
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
    
.macro sendBuffer(prefix){
pushreg()
	ldy #$00
   	lda #prefix
   	sta TXBUFFER,y
	iny
	lda #$00
	sta TXBUFFER,y
	jsr rs232TX   // send it
popreg()
}
   	
.macro printRXBuffer(){
pushreg()
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

.macro displayText(text,addr){
pushreg()
ldx #$00
	!showms:   
   		lda text,x     //setup message
   		sec               //case conversion
   		sbc #$60
   		bcs !showchar+
   		lda text,x
	!showchar:
   		sta addr,x
   		inx
   		cpx #$20
   		bne !showms-
popreg()
}	

.macro ReadUntilReturn(){
//pushreg()	
	!loop:     
  		jsr $FFCF     // Jump to Input routine
  		cmp #$0D      // Return (ASCII 13) pressed?
  		beq !exit+ // Yes, end.
  		sta TXBUFFER,y  // Else, store char at buffer+Y
  		iny           // Inc. char counter
  		bne !loop-     // If Y != 0, get another char.  
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
pushreg()
  lda #color
  sta $d020
popreg()
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
pushreg()
  ldx #$02
  jsr $FFC3 // CLOSE
  jsr $FFCC // CLRCHN // reset input and output to keyboard and screen
popreg()
}

.macro OpenRS232(){
pushreg()
  lda #$02
  ldx #<RS232PAR
  ldy #>RS232PAR
  jsr $FFBD // SETNAM
  lda #$02
  tax
  ldy #$00
  jsr $FFBA // SETLFS
  jsr $FFC0 // OPEN

popreg()
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

