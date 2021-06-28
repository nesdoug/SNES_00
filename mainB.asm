;example code, for easySNES
;updated 6/2021

.p816
.smart

.include "regs.asm"
.include "macros.asm"
.include "easySNES.asm"
.include "init.asm"
.include "MUSIC/music.asm"






.segment "ZEROPAGE"

hero_x: .res 2
hero_y: .res 2

facing:	.res 1
.define FACE_LEFT 0
.define FACE_RIGHT 1

spike_x: .res 2
spike_y: .res 2
spike_moves: .res 1

injury_delay: .res 1

count99: .res 1
count99_L:	.res 1
count99_H:	.res 1
test_array: .res 4




.segment "CODE"

;enters here in forced blank
Main:
.a16 ;just a standardized setting from init code
.i16
	phk ;push current bank, pull to data bank, to
	plb ;make sure the current bank's data is accessible
		;do this any time you jump to a different bank
		;and need to use data in that bank.
		
	AXY16
	lda #.loword(music_code)
	ldx #^music_code
	jsl SPC_Init
	
	AXY16
	lda #$0001
	jsl SPC_Stereo	


	A8 ;all these need a8
	
	SET_BG_MODE  1
	SET_BG_TILESIZE  BG_ALL_8x8
	SET_BG3_PRI  BG3_TOP
	;note, all the priority bits of bg3 map also have to be set
	;for bg3 tiles to be on top
	
	
	SET_BG1_TILE_ADDR $0000
	SET_BG2_TILE_ADDR $0000
	SET_BG3_TILE_ADDR $2000

	
	SET_BG1_MAP_ADDR $6000
;note, also copies the number $6000 to bg1_map_base for later use	
	SET_BG2_MAP_ADDR $6800
;note, also copies the number $6800 to bg2_map_base for later use	
	SET_BG3_MAP_ADDR $7000
;note, also copies the number $7000 to bg3_map_base for later use	


	SET_BG1_MAP_SIZE  MAP_32_32
	SET_BG2_MAP_SIZE  MAP_32_32
	SET_BG3_MAP_SIZE  MAP_32_32

	
	SET_OAM_SIZE  OAM_8_16
	SET_OAM_TILE_ADDR  $4000
	
	
;now load the tiles to the vram	
;+1 increment mode
	A8
	SET_VRAM_INC  V_INC_1 
	
	
;4bpp tiles for bg 1 and 2	
	AXY16
	lda #$0000
	sta VMADDL ;$2116
	UNPACK_TO_VRAM  BGTILES4 ;calls unrle
	
;2bpp tiles for bg 3
	lda #$2000
	sta VMADDL ;$2116
	UNPACK_TO_VRAM  BGTILES2

;4bpp tiles for sprites
	lda #$4000
	sta VMADDL ;$2116
	UNPACK_TO_VRAM  SPRTILES
	
	
;now load the maps to the vram
	lda bg1_map_base ;see, we did need this!
	sta VMADDL ;$2116
	UNPACK_TO_VRAM  BG1_MAP

	
	lda bg2_map_base
	sta VMADDL ;$2116
	UNPACK_TO_VRAM  BG2_MAP
	
	
	lda bg3_map_base
	sta VMADDL ;$2116
	UNPACK_TO_VRAM  BG3_MAP
	
	

	COPY_PAL_BG Test_Palette
	
; one row of sprite palette data
;	COPY_PAL_ROW Sp_Palette,8
	COPY_PAL_SP Sp_Palette

	
;nmi's should be off when loading data to the spc
	;a = address of song
	;x = bank of song
	AXY16
	lda #.loword(song1)
	ldx #^song1
	jsl SPC_Play_Song
	;re enable nmi now
;	SET_INTERRUPT below

	
	A8
	lda #ALL_ON_SCREEN ;enable main screen
	;alternate version
	;lda #(BG1_ON|BG2_ON|BG3_ON|SPR_ON)
	jsl Set_Main_Screen
	
	
	lda #FULL_BRIGHT
	jsl Pal_Bright
	

;enable NMI and auto controller reads, IRQs off
	SET_INTERRUPT  NMI_ON|AUTO_JOY_ON

	
	A8	
	jsl PPU_On ; end forced blank
	
	
;some initial values for sprite positions.	
	lda #$50
	sta hero_x
	lda #$5c
	sta hero_y
	;same
	sta spike_y
	lda #$80
	sta spike_x
	
	
	
Infinite_Loop:	
	A8
	XY16
	jsl PPU_Wait_NMI
	jsl Pad_Poll
	jsl OAM_Clear
	stz sprid


	
;move the sprites	
	A16
	XY8
	lda pad1
	and #KEY_RIGHT
	beq @skip_r
	inc hero_x
	ldy #FACE_RIGHT
	sty facing
@skip_r:	

	lda pad1
	and #KEY_LEFT
	beq @skip_l
	dec hero_x
	ldy #FACE_LEFT
	sty facing
@skip_l:

	

	lda pad1
	and #KEY_UP
	beq @skip_u
	dec hero_y
@skip_u:	

	lda pad1
	and #KEY_DOWN
	beq @skip_d
	inc hero_y
@skip_d:

	

	A16
	lda hero_x
	sta spr_x
	A8
	lda hero_y
	sta spr_y
	
	lda facing ;a8
	bne @face_right
	
@face_left:	
	
	AXY16
	lda #.loword(Meta_01)
	ldx #^Meta_01
	bra @face_both
	
@face_right:
	
	AXY16
	lda #.loword(Meta_00)
	ldx #^Meta_00

@face_both:	
	jsl OAM_Meta_Spr

	AXY16
	
	
	
	
Move_Spike:
	A8
	lda frame_count
	and #3
	bne @skip
	lda spike_moves
	inc a
	cmp #30
	bcc @ok
	lda #0
@ok:
	sta spike_moves
	
	cmp #15
	bcc @down
@up:
	dec spike_y
	bra @skip
@down:
	inc spike_y
@skip:
	
	
	
Draw_spike:
	
	A8
	lda spike_y
	sta spr_y ;(1 byte)
	AXY16
	lda spike_x
	sta spr_x ;9 bit (2 byte)
	lda #.loword(Meta_02)
	ldx #^Meta_02
	jsl OAM_Meta_Spr
	


Injury_Collision:
	A8
	lda injury_delay ;wait a little so not constant injury
	beq @ok
	dec injury_delay
	bra @injury_end
@ok:	
	A16
	lda hero_x
	and #$0100 ;negative = off screen
	bne @injury_end
	
;check collision now	
	A8
	lda hero_x
	sta obj1x
	lda hero_y
	sta obj1y
;hitbox, hero
	lda #14 ;width
	sta obj1w
	lda #28
	sta obj1h
	
	lda spike_x
	sta obj2x
	lda spike_y
	sta obj2y
;hitbox, spike
	lda #28
	sta obj2w
	sta obj2h
	jsl Check_Collision
	lda collision ;0 = no
	beq @injury_end
;injury	
	lda #60
	sta injury_delay
;play sound effect	
	AXY8
	lda #0 ;ding
	ldx #127
	ldy #7 ;last channel
	jsl SFX_Play_Center
	
	AXY16
	COPY_PAL_ROW Flash_Palette,8 ;turn hero white

	;the 8 means the 8th row (the first sprite row)
@injury_end:	
	A8
	XY16
;change color back to normal ?	
	lda injury_delay
	cmp #50
	bne @end2
	
	AXY16
	COPY_PAL_ROW Sp_Palette,8 ;turn hero back
	;the 8 means the 8th row (the first sprite row)
@end2:	
	A8
	XY16
	
	
	
;draw to BG 3, a decimal number 0-99
	lda frame_count
	and #$0f ;only do it every 16th frame
	bne @skip_number_update
;change that number	
	lda count99
	inc a
	cmp #100
	bcc @under100
	lda #0
@under100:
	sta count99
	A16
	XY8
	and #$00ff
	ldx #10
	jsl Divide ;returns a = result, x = remainder
	stx count99_L
	A8
	sta count99_H
;	XY16 ;see below
	
	lda count99_H
	bne @1
;if zero, use 10th tile, the zero tile is out of order in our tileset
	lda #10
@1:
	sta test_array ;tile1, tile #
	
	lda count99_L
	bne @2
;if zero, use 10th tile, the zero tile is out of order in our tileset
	lda #10
@2:
	sta test_array+2 ;tile2, tile #
	
	lda #TILE_PAL_1|TILE_PRIORITY
	sta test_array+1 ;tile1 attributes
	sta test_array+3 ;tile2 attributes
	
;copy test_array to a buffer...	
	AXY16
	lda #.loword(test_array)
	ldx #^test_array
	ldy #4 ;size 4 bytes
	jsl Copy_To_VB ;copy this array to an update buffer
	;that auto sets num_bytes_vb and src_address_vb
	;but, we still need to set a vram address "dst_address_vb"
;	xy size doesn't matter
;	ldx #17 ;screen x coordinate
;	ldy #2  ;screen y coordinate
;	jsl Map_Offset ;returns a16, map offset
; or we could used this one pre-calculated at assemble time
	lda #MAP_OFFSET(17, 2)
	
	
	clc
	adc bg3_map_base
	sta dst_address_vb
;and then we call this or VB_Buffer_V (top to bottom)
	jsl VB_Buffer_H ;left to right
	
	
@skip_number_update:	


;test slowdown / lag frame
;	AXY16
;	ldx #$3000
;@slow:
;	nop
;	dex
;	bne @slow
;
;	WDM_BREAK
	
	jmp Infinite_Loop
	
	
	


;relative x, relative y, tile #, attributes, size



.include "M1TE/metasprites.asm"
;is the metasprite data called
;Meta_00 right and Meta_01 left
;generated by SPEZ sprite editor

	
	
.include "header.asm"





.segment "RODATA1"

; replaced all tiles and maps with rle compressed versions.

BGTILES4:
.incbin "RLE/BG_TILES.rle"



SPRTILES:
.incbin "RLE/SPR_TILES.rle"


BGTILES2:
.incbin "RLE/ALPHA2.rle"




BG1_MAP:
.incbin "RLE/BG1_MAP.rle"

BG2_MAP:
.incbin "RLE/BG2_MAP.rle"

BG3_MAP:
.incbin "RLE/BG3_MAP.rle"

RLE_TEST:
.incbin "RLE/test.rle"

END_SEGMENT1:




.segment "RODATA2"
Test_Palette:
.incbin "M1TE/BG_TEST.pal"
Sp_Palette: 
;1 row
.incbin "M1TE/SPR_TEST.pal"

Flash_Palette: ;all white
.word $7fff, $7fff, $7fff, $7fff, $7fff, $7fff, $7fff, $7fff
.word $7fff, $7fff, $7fff, $7fff, $7fff, $7fff, $7fff, $7fff



.segment "RODATA7"
music_code:
.incbin "MUSIC/spc700.bin"

song1:
.incbin "MUSIC/music_1.bin"
;song2:
;.incbin "MUSIC/music_2.bin"




