;init code for easySNES
;much borrowed from Damian Yerrick

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

wram_clear: 		;data bank is 7e
	tax 			; a and x are zero
@loop:
	sta f:$7e0000,x
	sta f:$7f0000,x
	inx
	inx
	bne @loop
	
	;axy is 16
	stz $2116 ;vram address 0000
	;increment mode (2115) set to $80 above +1
	;a is zero
	tay ;0 number of BYTES to write = 100000
	jsl vram_fill
	
	jsl oam_clear
	
	jsl reset_vram_system 
	
;all variables have been zeroed. Set some to a standard value
	A8
	lda #$80
	sta r2100 ;forced blank
	lda #$0f
	sta r2106 ;mosaic, affects all, 1x1
	
	
;make sure nmi is disabled when loading code or song to spc
	AXY16
	lda #.loword(music_code)
	ldx #^music_code
	jsl spc_init
	
;	AXY16
	lda #$0001
	jsl spc_stereo


	lda #1
	sta $420d ;fastROM
	
;moved to main.asm	
;	lda #$81 ;enable NMI and auto controller reads, IRQs off
;	sta r4200
;	sta $4200
	
	;cli ;if we want H or V counter IRQs, uncomment this
		 ;and enable them at $4200

	AXY16
	jml main ;should jump into the $80 bank, fast ROM
	
;we are still in forced blank, main code will have to turn the screen on












