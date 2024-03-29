;init code for SNES
;much borrowed from Damian Yerrick
;some borrowed from Oziphantom

.p816
.smart



	
.segment "CODE"	
	

RESET:
	sei			; turn off IRQs
	clc
	xce			; turn off 6502 emulation mode
	rep #$38 	;AXY16 and clear decimal mode.
	ldx #$1fff
	txs			; set the stack pointer
	phk
	plb 		;set b to current bank, 00
	
; Initialize the CPU I/O registers to predictable values
	lda #$4200
	tcd			; temporarily move direct page to S-CPU I/O area
	lda #$FF00
	sta $00
	stz $00
	stz $02
	stz $04
	stz $06
	stz $08
	stz $0A
	stz $0C

; Initialize the PPU registers to predictable values
	lda #$2100
	tcd			 ; temporarily move direct page to PPU I/O area

; first clear the regs that take a 16-bit write
	lda #$0080
	sta $00		 ; Enable forced blank
	stz $02
	stz $05
	stz $07
	stz $09
	stz $0B
	stz $16
	stz $24
	stz $26
	stz $28
	stz $2A
	stz $2C
	stz $2E
	ldx #$0030
	stx $30		 ; Disable color math
	ldy #$00E0
	sty $32		 ; Clear red, green, and blue components of COLDATA
				 ; also 0 to 2133, normal video at 224 pixels high

; now clear the regs that need 8-bit writes
	A8
	sta $15		 ; still $80: Inc VRAM pointer after high byte write
	stz $1A
	stz $21
	stz $23 ;window, 24,25 above

; The scroll registers $210D-$2114 need double 8-bit writes
	.repeat 8, I
		stz $0D+I
		stz $0D+I
	.endrepeat

; As do the mode 7 registers, which we set to the identity matrix
	; [ $0100	$0000 ]
	; [ $0000	$0100 ]
	lda #$01
	stz $1B
	sta $1B
	stz $1C
	stz $1C
	stz $1D
	stz $1D
	stz $1E
	sta $1E
	stz $1F
	stz $1F
	stz $20
	stz $20
	
	
	
	AXY16
	lda #$0000
	tcd				; return direct page to real zero page


;the next 17 lines adapted from code by Oziphantom

Clear_WRAM2:
	A16
	XY8
	stz $2181 ;WRAM_ADDR_L
	stz $2182 ;WRAM_ADDR_M
	
	lda #$8008 ;fixed transfer to WRAM data 2180
	sta $4300 ; and 4301
	lda	#.loword(DMAZero)
	sta $4302 ; and 4303
	ldx #^DMAZero ;bank #
	stx $4304
	stz $4305 ;and 4306 = size 0000 = $10000
	ldx #1
	stx $420B ; DMA_ENABLE, clear the 1st half of WRAM
	stx $420B ; DMA_ENABLE, clear the 2nd half of WRAM
	
	A8
	XY16
;all jsl, all rtl
	jsl Clear_Palette
	;it will dma at NMI
	jsl OAM_Clear
	;it will dma at NMI
	jsl Clear_VRAM
	jsl Reset_VRAM_System
	; just in case
	
;	A8
	lda #1
	sta $420d ;fastROM

	AXY16
	jml Main ;should jump into the $80 bank, fast ROM
	
;we are still in forced blank, main code will have to turn the screen on





;some code below adapted from code by Oziphantom

Clear_Palette:
;fills the buffer with zeros
	php
	A8
	XY16
	ldx #.loword(PAL_BUFFER) 
	stx $2181 ;WRAM_ADDR_L
	stz $2183 ;WRAM_ADDR_H

	ldx #$8008 ;fixed transfer to WRAM data 2180
	stx $4300 ; and 4301
	ldx	#.loword(DMAZero)
	stx $4302 ; and 4303
	lda #^DMAZero ;bank #
	sta $4304
	ldx #$200 ;512 bytes
	stx $4305 ; and 4306
	lda #1
	sta $420B ; DMA_ENABLE start dma, channel 0
	inc pal_update
	plp
	rtl ;changed for consistency
	

Clear_VRAM:
	php
	A16
	XY8
	ldx #$80
	stx $2115 ;VRAM increment mode +1, after the 2119 write
	stz $2116 ;VRAM Address 
	stz $4305 ; size $10000 bytes ($8000 words)
	lda #$1809 ;fixed transfer (2 reg, write once) to VRAM_DATA $2118-19
	sta $4300 ; and 4301
	lda	#.loword(DMAZero)
	sta $4302 ; and 4303
	ldx #^DMAZero ;bank #
	stx $4304
	ldx #1
	stx $420B ; DMA_ENABLE start dma, channel 0
	plp
	rtl ;changed for consistency
 


DMAZero:
.word $0000



