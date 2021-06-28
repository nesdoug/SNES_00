;macros for easySNES, for ca65, versions later than 2017


;mesen-s can use wdm is as a breakpoint
;for debugging purposes
.macro WDM_BREAK
	.byte $42, $00
.endmacro


;compile time calculation of a map address
;add this to the map base address to get the
;vram address of a tile
.define MAP_OFFSET(tile_x,tile_y) (((tile_y)<<5)+(tile_x))



.macro A8
	sep #$20
.endmacro

.macro A16
	rep #$20
.endmacro

.macro AXY8
	sep #$30
.endmacro

.macro AXY16
	rep #$30
.endmacro

.macro XY8
	sep #$10
.endmacro

.macro XY16
	rep #$10
.endmacro






;the if statements work if .smart is set


;-----------------------------
;only do these if forced blank
;-----------------------------

.macro SET_BG_MODE  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl BG_Mode
.endmacro


.macro SET_BG3_PRI  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl BG3_Priority
.endmacro


.macro SET_BG_TILESIZE  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl BG_Tilesize
.endmacro


;steps of 1000
.macro SET_BG1_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 12)
	jsl BG1_Tile_Addr
.endmacro


;steps of 1000
.macro SET_BG2_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif 
	lda #(address >> 8)
	jsl BG2_Tile_Addr
.endmacro


;steps of 1000
.macro SET_BG3_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 12)
	jsl BG3_Tile_Addr
.endmacro


;steps of 1000
.macro SET_BG4_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl BG4_Tile_Addr
.endmacro


;steps of 400
.macro SET_BG1_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl BG1_Map_Addr
.endmacro


;steps of 400
.macro SET_BG2_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl BG2_Map_Addr
.endmacro


;steps of 400
.macro SET_BG3_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl BG3_Map_Addr
.endmacro


;steps of 400
.macro SET_BG4_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif 
	lda #(address >> 8)
	jsl BG4_Map_Addr
.endmacro


.macro SET_BG1_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl BG1_Map_Size
.endmacro


.macro SET_BG2_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl BG2_Map_Size
.endmacro


.macro SET_BG3_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl BG3_Map_Size
.endmacro


.macro SET_BG4_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl BG4_Map_Size
.endmacro




;first set VRAM_Addr and VRAM_Inc
;dst_address is in the WRAM
.macro READ_FROM_VRAM  dst_address, length
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(dst_address)
	ldx #^dst_address
	ldy #length
	jsl VRAM_Read
.endmacro


;first set VRAM_Addr and VRAM_Inc
.macro DMA_TO_VRAM  src_address, length
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	ldy #length
	jsl DMA_VRAM
.endmacro


;first set VRAM_Addr and VRAM_Inc
; length is a variable not a constant #
.macro SET_VRAM_DMA2  src_address, length
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	ldy length
	jsl DMA_VRAM
.endmacro


;first set vram_adr and vram_inc
;decompresses rle files AND copy to vram
.macro UNPACK_TO_VRAM  src_address
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl Unrle
	jsl DMA_VRAM
.endmacro


;---------------------------------
;end of things that need to be in forced blank
;---------------------------------


;decompresses rle files to WRAM
;but don't copy to the vram
.macro UNPACK_ONLY  src_address
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl Unrle
.endmacro




;do any time. copies 256 colors to a buffer.
.macro COPY_PAL_ALL  src_address
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30 
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl Pal_All
.endmacro


;do any time. copies 128 colors to a buffer.
.macro COPY_PAL_BG  src_address
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30 
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl Pal_BG
.endmacro


;do any time. copies 128 colors to a buffer.
.macro COPY_PAL_SP  src_address
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl Pal_Spr
.endmacro


;do any time. copies 16 colors to a buffer.
;row is 0-15
.macro COPY_PAL_ROW  src_address, row
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	ldy #row
	jsl Pal_Row
.endmacro


;do any time. sets 1 color in a buffer.
;value is 0-$7fff, index is 0-255
;the function will double the index
.macro SET_ONE_COLOR  value, index
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #value
	ldx #index*2
	sta a:PAL_BUFFER, x
	inc pal_update
.endmacro


;do any time. 
;value = 0-15
;0 = all black, 15 = full brightness
.macro SET_BRIGHT  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl Pal_Bright
.endmacro


;do any time
;value 0-15, 0 = 1x1, F = 16x16
;this has it affect all BG layers
.macro SET_MOSAIC  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl Set_Mosaic
.endmacro


;a8 = fade to value 0-15
;0 = all black, 15 = full brightness
;do any time. uses all the cpu time.
.macro BRIGHT_FADE_TO  final
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #final
	jsl Pal_Fade
.endmacro


;a8 = fade to value 0-15
;do any time. uses all the cpu time.
.macro MOSAIC_FADE_TO  final
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #final
	jsl Mosaic_Fade
.endmacro



;a8 = Delay value 0-255, 0 = 256.
;in frames, max about 4 seconds.
.macro DELAY_FOR  frames
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #frames
	jsl Delay
.endmacro


;do any time
;steps of 2000
.macro SET_OAM_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 13)
	jsl OAM_Tile_Addr
.endmacro


;do any time
;use defined constants, like OAM_8_16
.macro SET_OAM_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl OAM_Size
.endmacro


.macro SET_VRAM_INC  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	sta $2115
.endmacro





; memcpy, block move
;for WRAM to WRAM data transfers (can't be done with DMA)
.macro BLOCK_MOVE  length, src_addr, dst_addr
;mnv changes the data bank register, need to preserve it
	phb
.if .asize = 8
	rep #$30 ; needs a16
.elseif .isize = 8
	rep #$30
.endif
	lda #(length-1)
	ldx #.loword(src_addr)
	ldy #.loword(dst_addr)	
;	mvn src_bank, dst_bank
	.byte $54, ^dst_addr, ^src_addr
	plb
.endmacro
;originally, the ca65 assembler, mvn assembled
;its operands backwards from standard syntax mvn src,dst
;Fixed in July 27, 2018 build of ca65
;I opted to use a .byte directive to make sure no
;errors from different versions of ca65



; clear a section of $7e0000-7effff wram
; value should be 8 bit. the A register can be 16, because 
; 1 extra byte of LDA is better than 2 extra bytes of sep $20
; don't clear the stack
.macro CLEAR_7E  value, addr, length
;see note about A size
.if .isize = 8
	rep #$10
.endif
	lda #value
	ldx #.loword(addr)
	ldy #length	
	jsl WRAM_Fill_7E
.endmacro


; clear a section of $7f0000-7fffff wram
; value should be 8 bit. the A register can be 16, because 
; 1 extra byte of LDA is better than 2 extra bytes of sep $20
; note, length of 0 = $10000
.macro CLEAR_7F  value, addr, length
;see note about A size
.if .isize = 8
	rep #$10
.endif
	lda #value
	ldx #.loword(addr)
	ldy #length	
	jsl WRAM_Fill_7F
.endmacro



;to turn on the screen
.macro SET_MAIN_SCR  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(value)
;	jsl Set_Main_Screen
	sta r212c
.endmacro


;set the sub screen, for color math
.macro SET_SUB_SCR  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(value)
;	jsl Set_Sub_Screen
	sta r212d
.endmacro



;set interrupts
.macro SET_INTERRUPT  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(value)
	sta r4200
	sta $4200
.endmacro
; the r4200 is for the music code, which
; turns off all interrupts when loading







