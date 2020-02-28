.p816
.smart

.include "easySNES.asm"
.include "init.asm"
.include "MUSIC/music.asm"






.segment "ZEROPAGE"

object1x: .res 2
object1y: .res 2

facing:	.res 1
.define FACE_LEFT 0
.define FACE_RIGHT 1




.segment "CODE"

;enters here in forced blank
main:
.a16 ;just a standardized setting from init code
.i16
	phk ;push current bank, pull to data bank, to
	plb ;make sure the current bank's data is accessible
		;do this any time you jump to a different bank
		;and need to use data in that bank.


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
	sta vram_addr
	DMA_TO_VRAM  BGTILES4, $2000

	
;2bpp tiles for bg 3
	lda #$2000
	sta vram_addr
	DMA_TO_VRAM  BGTILES2, $1000
	

;4bpp tiles for sprites
	lda #$4000
	sta vram_addr
	DMA_TO_VRAM  SPRTILES, $2000

	
	
;now load the maps to the vram
	lda bg1_map_base ;see, we did need this!
	sta vram_addr
	DMA_TO_VRAM  BG1_MAP, $700
	

	
	lda bg2_map_base
	sta vram_addr
	DMA_TO_VRAM  BG2_MAP, $700

	
	
	lda bg3_map_base
	sta vram_addr
	DMA_TO_VRAM  BG3_MAP, $100

	
	

	COPY_PAL_BG Test_Palette
	
; one row of sprite palette data
	COPY_PAL_ROW Sp_Palette,8


	
;nmi's should be off when loading data to the spc
	;a = address of song
	;x = bank of song
	AXY16
	lda #.loword(song1)
	ldx #^song1
	jsl spc_play_song
	;re enable nmi now
;	A8
;	lda r4200 ;enable NMI
;	sta $4200

	
	
	
	
	A8
	lda #ALL_ON_SCREEN ;enable main screen
	;alternate version
	;lda #(BG1_ON|BG2_ON|BG3_ON|SPR_ON)
	jsl set_main_screen
	
	lda #FULL_BRIGHT
	jsl pal_bright
	
	
;enable NMI and auto controller reads, IRQs off
	SET_INTERRUPT  NMI_ON|AUTO_JOY_ON
	
	
	A8	
	jsl ppu_on ; end forced blank

	
;some initial values for sprite positions.	
	lda #$50
	sta object1x
	lda #$5c
	sta object1y
	
	
	
InfiniteLoop:	
	A8
	XY16
	jsl ppu_wait_nmi
	jsl pad_poll
	jsl oam_clear
;	jsl reset_vram_system 
	

	
;move the sprites	
	A16
	XY8
	lda pad1
	and #KEY_RIGHT
	beq @skip_r
	inc object1x
	ldy #FACE_RIGHT
	sty facing
@skip_r:	

	lda pad1
	and #KEY_LEFT
	beq @skip_l
	dec object1x
	ldy #FACE_LEFT
	sty facing
@skip_l:

	

	lda pad1
	and #KEY_UP
	beq @skip_u
	dec object1y
@skip_u:	

	lda pad1
	and #KEY_DOWN
	beq @skip_d
	inc object1y
@skip_d:

	

	
	A8
	lda object1x
	sta spr_x
	lda object1y
	sta spr_y
	
	WDM_BREAK
	
	lda #SPR_PRIOR_2
	sta spr_pri ;priority override
	
	lda object1x+1
	and #1 ;high x
	sta spr_h
	
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
	;jsl oam_meta_spr
	jsl oam_meta_spr_p ;override priority bits

	AXY16
	
;---------
	
	jmp InfiniteLoop
	
	
	


;relative x, relative y, tile #, attributes, size



.include "M1TE/metasprites.asm"
;is the metasprite data called
;Meta_00 right and Meta_01 left
	
	
.include "header.asm"





.segment "RODATA1"

BGTILES4:
.incbin "M1TE/BG_TEST.chr"



SPRTILES:
.incbin "M1TE/SPR_TEST.chr"



.segment "RODATA2"

BGTILES2:
.incbin "M1TE/ALPHA2.chr"


;each of these are 1792 bytes ($700)
BG1_MAP:
;$700
.incbin "M1TE/BG_TEST.map"


BG2_MAP:
;$700
.incbin "M1TE/BG_TEST2.map"


BG3_MAP:
;$100
.incbin "M1TE/BG_TEST3.map"




.segment "RODATA3"
Test_Palette:
.incbin "M1TE/BG_TEST.pal"
Sp_Palette: 
;1 row
.incbin "M1TE/SPR_TEST.pal"





.segment "RODATA7"
music_code:
.incbin "MUSIC/spc700.bin"

song1:
.incbin "MUSIC/music_1.bin"
;song2:
;.incbin "MUSIC/music_2.bin"




