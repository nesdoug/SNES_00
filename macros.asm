;macros for easySNES, for ca65, versions later than 2017


;mesen-s can use wdm is as a breakpoint
.macro WDM_BREAK
	.byte $42, $00
.endmacro



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



;reset_vram_system can be any size

;these work if .smart is set

;-----------------------------
;only do these if forced blank
;-----------------------------

.macro SET_BG_MODE  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl bg_mode
.endmacro


.macro SET_BG3_PRI  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl bg3_priority
.endmacro


.macro SET_BG_TILESIZE  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl bg_tilesize
.endmacro


;steps of 1000
.macro SET_BG1_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 12)
	jsl bg1_tile_addr
.endmacro


;steps of 1000
.macro SET_BG2_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif 
	lda #(address >> 8)
	jsl bg2_tile_addr
.endmacro


;steps of 1000
.macro SET_BG3_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 12)
	jsl bg3_tile_addr
.endmacro


;steps of 1000
.macro SET_BG4_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl bg4_tile_addr
.endmacro


;steps of 400
.macro SET_BG1_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl bg1_map_addr
.endmacro


;steps of 400
.macro SET_BG2_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl bg2_map_addr
.endmacro


;steps of 400
.macro SET_BG3_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 8)
	jsl bg3_map_addr
.endmacro


;steps of 400
.macro SET_BG4_MAP_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif 
	lda #(address >> 8)
	jsl bg4_map_addr
.endmacro


.macro SET_BG1_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl bg1_map_size
.endmacro


.macro SET_BG2_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl bg2_map_size
.endmacro


.macro SET_BG3_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl bg3_map_size
.endmacro


.macro SET_BG4_MAP_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl bg4_map_size
.endmacro


;first set vram_adr and vram_inc
;dst_address is in the WRAM
.macro READ_FROM_VRAM  dst_address, length
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(dst_address)
	ldx #^dst_address
	ldy #length
	jsl vram_read
.endmacro


;first set vram_adr and vram_inc
.macro DMA_TO_VRAM  src_address, length
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	ldy #length
	jsl vram_dma
.endmacro


;first set vram_adr and vram_inc
; length is a variable not a constant #
.macro SET_VRAM_DMA2  src_address, length
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	ldy length
	jsl vram_dma
.endmacro






;---------------------------------
;end of things that need to be in forced blank
;---------------------------------


;do any time. copies 256 colors to a buffer.
.macro COPY_PAL_ALL  src_address
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl pal_all
.endmacro

;do any time. copies 128 colors to a buffer.
.macro COPY_PAL_BG  src_address
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl pal_bg
.endmacro

;do any time. copies 128 colors to a buffer.
.macro COPY_PAL_SP  src_address
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #.loword(src_address)
	ldx #^src_address
	jsl pal_spr
.endmacro

;do any time. copies 16 colors to a buffer.
;row is 0-15
.macro COPY_PAL_ROW  src_address, row
	php
.if .asize = 8
	rep #$20
.endif
.if .isize = 16
	sep #$10 ; needs XY8
.endif
	lda #.loword(src_address)
	ldx #^src_address
	ldy #row
	jsl pal_row
	plp ;because XY8 is unusual
.endmacro

;do any time. sets 1 color in a buffer.
;value is 0-$7fff, index is 0-255
;the function will double the index
.macro SET_ONE_COLOR  value, index
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #value
	ldx #index
	jsl pal_col
.endmacro


;do any time. 
;value = 0-15
;0 = all black, 15 = full brightness
.macro SET_BRIGHT  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl pal_bright
.endmacro


;do any time
;value 0-15, 0 = 1x1, F = 16x16
;this has it affect all BG layers
.macro SET_MOSAIC  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #value
	jsl set_mosaic
.endmacro


;a8 = fade to value 0-15
;0 = all black, 15 = full brightness
;do any time. uses all the cpu time.
.macro BRIGHT_FADE_TO  final
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #final
	jsl pal_fade
.endmacro


;a8 = fade to value 0-15
;do any time. uses all the cpu time.
.macro MOSAIC_FADE_TO  final
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #final
	jsl mosaic_fade
.endmacro



;a8 = delay value 0-255, 0 = 256.
;in frames, max about 4 seconds.
.macro DELAY_FOR  frames
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #frames
	jsl delay
.endmacro


;do any time
;steps of 2000
.macro SET_OAM_TILE_ADDR  address
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(address >> 13)
	jsl oam_tile_addr
.endmacro


;do any time
;use defined constants, like OAM_8_16
.macro SET_OAM_SIZE  size
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #size
	jsl oam_size
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
	rep #$30
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
; value should be 8 bit. the A register is 16, because 1 extra
; byte of LDA is better than 2 extra bytes of sep $20
; don't clear the stack
.macro CLEAR_7E  value, addr, length
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #value
	ldx #.loword(addr)
	ldy #length	
	jsl wram_fill_7e
.endmacro


; clear a section of $7f0000-7fffff wram
; value should be 8 bit. the A register is 16, because 1 extra
; byte of LDA is better than 2 extra bytes of sep $20
; note, length of 0 = $10000
.macro CLEAR_7F  value, addr, length
.if .asize = 8
	rep #$30
.elseif .isize = 8
	rep #$30
.endif
	lda #value
	ldx #.loword(addr)
	ldy #length	
	jsl wram_fill_7f
.endmacro



;to turn on the screen
.macro SET_MAIN_SCR  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(value)
	jsl set_main_screen
.endmacro


;set the sub screen, for color math
.macro SET_SUB_SCR  value
.if .asize = 16
	sep #$20 ; needs A8
.endif
	lda #(value)
	jsl set_sub_screen
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


