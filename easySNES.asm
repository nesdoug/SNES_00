; easySNES - written by Doug Fraker, 2020
; ver 2.0 June 2021
; based on neslib by Shiru and others
; for SNES game development, for ca65 assembler

; always jsl to these subroutines
; DON'T CHANGE THE DIRECT PAGE, assume 0000 always 
; see usage.txt

; things not covered
; hdma
; windows
; color math
; mode 7
; expansion chips
; irq h/v timers


.p816
.smart

;.include "defines.asm"
;.include "macros.asm"



UNPACK_ADR = $7f0000


.segment "ZEROPAGE"
; don't use these temps, reserved for the library
temp1: .res 2 
temp2: .res 2
temp3: .res 2
temp4: .res 2
temp5: .res 2
temp6: .res 2

r2100: .res 1
r2100b: .res 1
r2101: .res 1
r2105: .res 1
r2106: .res 1
r2107: .res 1
r2108: .res 1
r2109: .res 1
r210a: .res 1
r210b: .res 1
r210c: .res 1
r212c: .res 1
r212d: .res 1
r4200: .res 1 ; for music code

sprid: .res 1
spr_x: .res 2 ; for sprite setting code
spr_y: .res 1
spr_c: .res 1 ; tile #
spr_a: .res 1 ; attributes
spr_sz: .res 1 ; sprite size

spr_x2:	.res 2 ; for meta sprite code
spr_h:	.res 1


pal_update: .res 2
vram_update: .res 2
vb_ptr_index: .res 2
vb_data_index: .res 2
frame_count: .res 2

bg1_scroll_x: .res 2
bg1_scroll_y: .res 2
bg2_scroll_x: .res 2
bg2_scroll_y: .res 2
bg3_scroll_x: .res 2
bg3_scroll_y: .res 2
bg4_scroll_x: .res 2
bg4_scroll_y: .res 2

bg1_map_base: .res 2 ; where in VRAM the map starts
bg2_map_base: .res 2
bg3_map_base: .res 2
bg4_map_base: .res 2

pad1: .res 2
pad1_new: .res 2
pad2: .res 2
pad2_new: .res 2

src_address_vb: .res 2 ;vram buffer
dst_address_vb: .res 2
num_bytes_vb: .res 2
fade_from: .res 1
fade_to: .res 1
rand:	.res 4

obj1x: .res 1 ; x
obj1w: .res 1 ; width
obj1y: .res 1 ; x
obj1h: .res 1 ; height
obj2x: .res 1 ; x
obj2w: .res 1 ; width
obj2y: .res 1 ; y
obj2h: .res 1 ; height
collision: .res 1

frame_ready: .res 1
hdma_active: .res 1


.segment "BSS"
; put an a: in front of all these when in use to force 16-bit address
PAL_BUFFER: .res 512
OAM_BUFFER: .res 512 ;low table
OAM_BUFFER2: .res 32 ;high table
VB_PTRS: .res 256 ; list of pointers to vram buffer data
SCRATCHPAD:	.res 256

.segment "BSS7E"
; put a f: in front to force a 24-bit address
VB_DATA: .res $2000 ; vram buffer data to be transfered





.global RESET, NMI, IRQ, IRQ_end, DMA_OAM, DMA_Palette, VRAM_Update_System, BG_Mode
.global BG3_Priority, BG_Tilesize, BG1_Tile_Addr, BG2_Tile_Addr, BG3_Tile_Addr
.global BG4_Tile_Addr, BG1_Map_Addr, BG1_Map_Size, BG2_Map_Addr, BG2_Map_Size
.global BG3_Map_Addr, BG3_Map_Size, BG4_Map_Addr, BG4_Map_Size, Map_Offset
.global Map_Offset6464, OAM_Clear, OAM_Size, OAM_Tile_Addr, OAM_Spr
.global Pad_Poll, VB_Buffer_H, VB_Buffer_V, VRAM_Addr, VRAM_Inc
.global VRAM_Put, VRAM_Fill, DMA_VRAM, WRAM_Fill_7E, WRAM_Fill_7F
.global Pal_All, Pal_Row, Pal_Col, Pal_Bright, PAL_BUFFER, OAM_BUFFER
.global PPU_Wait_NMI, Delay, PPU_Off, PPU_On, Set_Mosaic, Multiply, Divide
.global Reset_VRAM_System, Pal_BG, Pal_Spr, Set_Main_Screen, Set_Sub_Screen
.global Pal_Fade, Mosaic_Fade, VRAM_Fill2, SCRATCHPAD, Multiply_Fast
.global Rand16, Seed_Rand, Copy_To_VB, OAM_Meta_Spr, VRAM_Read
.global Unrle

.globalzp r2100, r2100b, r2101, r2105, r2106, r2107, r2108, r2109, r210a
.globalzp r210b, r210c, sprid, spr_x, spr_y, spr_c, spr_a, spr_h, spr_sz, pal_update
.globalzp vram_update, frame_count, bg1_scroll_x, bg1_scroll_y
.globalzp bg2_scroll_x, bg2_scroll_y, bg3_scroll_x, bg3_scroll_y 
.globalzp bg4_scroll_x, bg4_scroll_y, bg1_map_base, bg2_map_base
.globalzp bg3_map_base, bg4_map_base, pad1, pad1_new, pad2, pad2_new
.globalzp vb_ptr_index, vb_data_index, src_address_vb, dst_address_vb, num_bytes_vb
.globalzp r212c, r212d, fade_from, fade_to, r4200, frame_ready
.globalzp obj1x, obj1y, obj1w, obj1h, obj2x, obj2y, obj2w, obj2h, collision



.segment "CODE"
; this needs to be in bank 0 !!


NMI:
.a16
.i16
	rep #$30 ;axy16
	phb
	pha
	phx
	phy
	phd

	phk ; is zero
	plb ; set data bank to zero (in case it was 7e or 7f)
	lda #$0000
	tcd
	
	sep #$20 ; a8
	
	bit $4210
	; it is required to read this register
	; in the NMI handler
	
	lda frame_ready
	beq @not_ready	
	lda r2100
;	#$80 ; is this forced blank?
	bpl @do_update	
@not_ready:	
	jmp @skip_all
@do_update:
; a8 xy16
;	stz $420c ; make sure hdma doesn't conflict with dma
	
	jsr OAM_DMA
	
	lda pal_update
	beq @update_vram
	stz pal_update
	jsr DMA_Palette
	
@update_vram:
	lda vram_update
	beq @skip_update
	stz vram_update
	jsl VRAM_Update_System

@skip_update:
; A is still 8 bit
	lda r2101
	sta $2101 ; sprite size and tile address

	lda r2105
	sta $2105 ; bg mode

	lda r2106
	sta $2106 ; mosaic
	
	lda r212c 
	sta $212c ; main screen
	
	lda r212d
	sta $212d ; sub screen
	
; write twice registers
	lda bg1_scroll_x
	sta $210d
	lda bg1_scroll_x+1
	sta $210d
	
	lda bg1_scroll_y
	sta $210e
	lda bg1_scroll_y+1
	sta $210e
	
	lda bg2_scroll_x
	sta $210f
	lda bg2_scroll_x+1
	sta $210f
	
	lda bg2_scroll_y
	sta $2110
	lda bg2_scroll_y+1
	sta $2110
	
	lda bg3_scroll_x
	sta $2111
	lda bg3_scroll_x+1
	sta $2111
	
	lda bg3_scroll_y
	sta $2112
	lda bg3_scroll_y+1
	sta $2112

	lda bg4_scroll_x
	sta $2113
	lda bg4_scroll_x+1
	sta $2113
	
	lda bg4_scroll_y
	sta $2114
	lda bg4_scroll_y+1
	sta $2114
	
@skip_all:
; restore registers
	
	sep #$20 ;A8
	lda r2100
	ora r2100b ; brightness
	sta $2100
	
	lda hdma_active
	sta $420c
;all of the dma is done on channel 0
;recommend you only use channels 1-7 for hdma
	
	rep #$30 ;axy16
	inc frame_count ; 16 bit
	
	pld
	ply
	plx
	pla
	plb
; plp not needed, rti does that already
	rti
	
	
IRQ:
	bit $4211
; this register is required to be read
; in the IRQ handler
	
; handler is blank	
; IRQ can be used for mid-screen effects
; using the H or V timers $4207-a

IRQ_end:	
	rti
; restores processor flags
	
	
OAM_DMA:
.a8
.i16
; used by nmi. copies oam buffer to OAM
	ldx #0
	stx $2102 ; oam address
	stz $4300 ; transfer mode
	lda #4
	sta $4301 ; destination, oam data
	ldx #OAM_BUFFER
	stx $4302 ; source
	stz $4304 ; bank
	ldx #544
	stx $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	rts
	
	
DMA_Palette:
.a8
.i16
; used by nmi. copies pal buffer to palette
	stz $2121 ; cg address
	stz $4300 ; transfer mode ; zero is fine.
	lda #$22
	sta $4301 ; destination, pal data
	ldx #PAL_BUFFER
	stx $4302 ; source
	stz $4304 ; bank
	ldx #512
	stx $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	rts
	
	
	

VRAM_Update_System:
.a8
.i16
; used by nmi. copies vram buffer to VRAM

; 1st byte = vram increment mode, or...ff = end of set
; 2-3 bytes = wram address (always 7e bank)
; 4-5 bytes = vram address
; 6-7 bytes = length

	lda #1
	sta $4300 ; transfer mode, 2 registers 1 write
	lda #$18
	sta $4301 ; destination, vram data
	lda #$7e
	sta $4304 ; src bank, always 7e
	ldy #0
@loop:
	lda a:VB_PTRS, y
	cmp #$ff
	beq @done
	sta $2115 ; vram increment mode, first byte of every set
	iny
	
	ldx a:VB_PTRS, y ; src address
	stx $4302 ; and 3
	iny
	iny
	ldx a:VB_PTRS, y ; destination address in vram
	stx $2116 ; and 2117
	iny
	iny
	ldx a:VB_PTRS, y ; size of transfer
	stx $4305 ; and 6
	iny
	iny
	
	lda #1
	sta $420b ; start dma, channel 0
	bra @loop
	
@done:
	lda #$ff
	sta a:VB_PTRS ; cleared
	lda #V_INC_1 ; back to standard
	sta $2115 ; VRAM_Inc mode
;	rtl
; fall through

	

Reset_VRAM_System:
; call once per frame, if using the auto-dma system.
.a16
	php
	rep #$20 ;a16
	stz vram_update
	stz vb_ptr_index
	stz vb_data_index
	lda #$ffff
	sta a:VB_PTRS
	plp
	rtl

	
	
	
	
	
	

BG_Mode:
.a8
.i16
; a = 0-7 =  mode
	and #7
	sta temp1
	lda r2105
	and #$f8
	ora temp1
	sta r2105
	rtl



BG3_Priority:
.a8
.i16
; if A = 0, bg 3on bottom
; if A = 8, bg 3 on top
	and #8
	sta temp1
	lda r2105
	and #$f7
	ora temp1
	sta r2105
	rtl
	
	

BG_Tilesize:
.a8
.i16
; A = 0 for 8x8
; A = $f0 for 16x16 for all maps
; 4321 ---- 1 bit per layer
	and #$f0
	sta temp1
	lda r2105
	and #$0f
	ora temp1
	sta r2105
	rtl

	
	
BG1_Tile_Addr:
.a8
.i16
; do during forced blank	
; a8 = 0-7 = 0-7000, layer 1 tiles
; steps of 1000
	and #7
	sta temp1
	lda r210b
	and #$70
	ora temp1
	sta r210b
	sta $210b
	rtl
	

	
BG2_Tile_Addr:
.a8
.i16
; do during forced blank	
; a8 = 00-70 = 0-7000, layer 2 tiles
; steps of 1000
	and #$70
	sta temp1
	lda r210b
	and #7
	ora temp1
	sta r210b
	sta $210b
	rtl	

	
	
BG3_Tile_Addr:
.a8
.i16
; do during forced blank	
; a8 = 0-7 = 0-7000, layer 3 tiles
; steps of 1000
	and #7
	sta temp1
	lda r210c
	and #$70
	ora temp1
	sta r210c
	sta $210c
	rtl
	
	

BG4_Tile_Addr:
.a8
.i16
; do during forced blank	
; a8 = 00-70 = 0-7000, layer 4 tiles
; steps of 1000
	and #$70
	sta temp1
	lda r210c
	and #7
	ora temp1
	sta r210c
	sta $210c
	rtl		
	
	

BG1_Map_Addr:	
.a8
.i16
; do during forced blank	
; a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg1_map_base+1
	stz bg1_map_base
	lda r2107
	and #3
	ora bg1_map_base+1
	sta r2107
	sta $2107
	rtl


			
BG1_Map_Size:
.a8
.i16
; do during forced blank	
; a8 = map size constant 0-3
	and #3
	sta temp1
	lda r2107
	and #$fc
	ora temp1
	sta r2107
	sta $2107
	rtl
	
	

BG2_Map_Addr:	
.a8
.i16
; do during forced blank	
; a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg2_map_base+1
	stz bg2_map_base
	lda r2108
	and #3
	ora bg2_map_base+1
	sta r2108
	sta $2108
	rtl

	
	
BG2_Map_Size:
.a8
.i16
; do during forced blank	
; a8 = map size constant 0-3
	and #3
	sta temp1
	lda r2108
	and #$fc
	ora temp1
	sta r2108
	sta $2108
	rtl
	
	

BG3_Map_Addr:
.a8
.i16	
; do during forced blank	
; a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg3_map_base+1
	stz bg3_map_base
	lda r2109
	and #3
	ora bg3_map_base+1
	sta r2109
	sta $2109
	rtl
	
	
	
BG3_Map_Size:
.a8
.i16
; do during forced blank	
; a8 = map size constant 0-3
	and #3
	sta temp1
	lda r2109
	and #$fc
	ora temp1
	sta r2109
	sta $2109
	rtl
	
	

BG4_Map_Addr:	
.a8
.i16
; do during forced blank	
; a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg4_map_base+1
	stz bg4_map_base
	lda r210a
	and #3
	ora bg4_map_base+1
	sta r210a
	sta $210a
	rtl

	
	
BG4_Map_Size:
.a8
.i16
; do during forced blank	
; a8 = map size constant 0-3
	and #3
	sta temp1
	lda r210a
	and #$fc
	ora temp1
	sta r210a
	sta $210a
	rtl
	
	
	
Map_Offset: 
.a16
.i16
; A should be 16 bit
; XY size doesn't matter - JUST LEAVE IT 16 bit, if it saves bytes

; converts pixel coordinates in a map to tile address offset
; the idea is that you add this value to the map_base
; works for 32x32,64x32,and 32x64 maps
; x -L = tile's x position, 0-31 [0-63 large map]
; y -L = tile's y position, 0-31 [0-63 large map]
; y max 27 if non-scrolling and screen size 224 pixel tall 
; to convert pixels to tiles >> 3 (if 16x16 tile size >> 4)

; returns a16 = vram address offset (add it to the base address)
	php
	rep #$20 ;a16
;	sep #$10 ;xy8 ;size doesn't matter
	tya
	and #$0020
	sta temp1
	txa
	and #$0020
	ora temp1 ; if either high bit is set, offset + $400
	beq @zero
	lda #$400
@zero:
	sta temp1 
	
offset_common:	
	tya
	and #$001f
	asl a
	asl a
	asl a
	asl a
	asl a
	ora temp1
	sta temp1
	txa
	and #$001f
	ora temp1
; returns a = map offset
	plp
	rtl

	
	
Map_Offset6464: 
.a16
.i16
; A should be 16 bit
; XY size doesn't matter - JUST LEAVE IT 16 bit, if it saves bytes

; works for 64x64 maps only
; x -L = tile's x position, 0-63 large map
; y -L = tile's y position, 0-63 large map
; y max 27 if non-scrolling and screen size 224 pixel tall 
; to convert pixels to tiles >> 3 (if 16x16 tile size >> 4)

; returns a16 = vram address
	php
	rep #$20 ;a16
;	sep #$10 ;xy8

	stz temp1
	tya
	and #$0020
	beq @y_zero
	lda #$800
	sta temp1
@y_zero:	
	txa
	and #$0020
	beq @x_zero
	lda temp1
	ora #$400
	sta temp1
@x_zero:
	jmp offset_common

	
	
;updated 6/2021
OAM_Clear:	
.a8
.i16
;fills the buffer with 224 for low table
;and $00 for high table
	php
	A8
	XY16
	ldx #.loword(OAM_BUFFER) 
	stx $2181 ;WRAM_ADDR_L
	stz $2183 ;WRAM_ADDR_H
	
	ldx #$8008 ;fixed transfer to WRAM data 2180
	stx $4300
	ldx	#.loword(SpriteEmptyVal)
	stx $4302 ; and 4303
	lda #^SpriteEmptyVal ;bank #
	sta $4304
	ldx #$200 ;size 512 bytes
	stx $4305 ;and 4306
	lda #1
	sta $420B ; DMA_ENABLE start dma, channel 0

	ldx	#.loword(SpriteUpperEmpty)
	stx $4302 ; and 4303
	lda #^SpriteUpperEmpty ;bank #
	sta $4304
	ldx #$0020 ;size 32 bytes
	stx $4305 ;and 4306
	lda #1
	sta $420B ; DMA_ENABLE start dma, channel 0
	plp
	rtl
	
SpriteUpperEmpty: ;my sprite code assumes hi table of zero
.word $0000

SpriteEmptyVal:
.byte 224	
	


OAM_Size:
.a8
.i16
; do any time, copied to register in nmi	
; ---- -111 = base address
; a8 = mode in 111- ---- bits
; NOTE, in 64x64 mode, large sprites can't hide at the bottom
; so OAM_Clear won't work right, they will wrap to the top.
	and #$e0
	sta temp1
	lda r2101
	and #$1f
	ora temp1
	sta r2101
	rtl
	
	
	
OAM_Tile_Addr:
.a8
.i16	
; do any time, copied to register in nmi	
; ---- --11 = base address
; a8 = H vram address 0-$6000 in 2000 steps
; the "name select" is assumed to be zero
; so the 256-511 tiles for sprite will be
; immediately above the 0-255 tiles.
	and #3 ; 0-3
	sta temp1
	lda r2101
	and #$fc
	ora temp1
	sta r2101
	rtl

	
	
OAM_Spr:
.a8
.i16
; to put one sprite on screen
; copy all the sprite values to these 8 bit variables
; spr_x - x (9 bit)
; spr_y - y (8 bit)
; spr_c - tile # (8 bit)
; spr_a - attributes, flip, palette, priority
; spr_sz = sprite size, 0 or 2

	php
	rep #$30 ;axy16
	lda sprid
	and #$007f
	tax
	asl a
	asl a ; 0-511
	tay
	
	txa
	sep #$20 ;a8
	lsr a
	lsr a ; 0-31
	tax
	lda spr_x ;x low byte
	sta a:OAM_BUFFER, y
	lda spr_y ;y
	sta a:OAM_BUFFER+1, y
	lda spr_c ;tile
	sta a:OAM_BUFFER+2, y
	lda spr_a ;attribute
	sta a:OAM_BUFFER+3, y
	
; handle the high table
; two bits, shift them in
; this is slow, so if this is zero, skip it, it was
; zeroed in oam_clear

	lda spr_x+1 ;9th x bit
	and #1 ;we only need 1 bit
	ora spr_sz ;size
	beq @end
	sta spr_h
	
	lda sprid
	and #3
	beq @zero
	dec a
	beq @one
	dec a
	beq @two
	bne @three
	
@zero:
	lda spr_h
	sta a:OAM_BUFFER+$200, x
	bra @end
	
@one:
	lda spr_h
	asl a
	asl a
	ora a:OAM_BUFFER+$200, x
	sta a:OAM_BUFFER+$200, x
	bra @end
	
@two:
	lda spr_h
	asl a
	asl a
	asl a
	asl a
	ora a:OAM_BUFFER+$200, x
	sta a:OAM_BUFFER+$200, x
	bra @end

@three:
	lda spr_h
	lsr a ; 0000 0001 c
	ror a ; 1000 0000 c
	ror a ; 1100 0000 0
	ora a:OAM_BUFFER+$200, x
	sta a:OAM_BUFFER+$200, x	
	
@end:
	lda sprid
	inc a
	and #$7f ; keep it 0-127
	sta sprid
	plp
	rtl
	
	
	
OAM_Meta_Spr:	
.a16
.i16
;update 6/2021
; to put multiple sprites on screen
; copy all the sprite values to these variables
; spr_x = x (9 bit)
; spr_y = y (8 bit)

; A16 = metasprite data address
; X = bank of metasprite data

; format (5 bytes per sprite)
; relative x, relative y, tile #, attributes, size
; end in 128

	php
	rep #$30 ;axy16
	sta temp1 ;address of metasprite
	stx temp2
	
	ldy #$0000
	sty temp3 ;clear these
	sty temp4 ;high table index
	sty temp5
	sty temp6
	
	lda spr_x ;16 bits
	and #$01ff ;9 bits
	sta spr_x2
	
	sep #$20 ;a8
	lda sprid
	and #3
	sta temp3
	lda #3
	sec
	sbc temp3
	sta temp3 ;loop counter
	
	lda sprid
	lsr a
	lsr a ; 0-31
	sta temp4 ;high table index
	
	lda sprid
	rep #$20 ;a16
	and #$007f
	asl a
	asl a ; 0-511
	tax ;x = low table index
	
@loop:
	sep #$20 ; a8
	lda [temp1], y
	cmp #128 ; end of data
	beq @done
;first byte is rel x (signed)	
	rep #$20 ;a16
	and #$00ff
	cmp #$0080 ;is negative?
	bcc @pos_x
@neg_x:
	ora #$ff00 ; extend the sign
@pos_x:
	clc
	adc spr_x2
;the high byte holds the X 9th bit
	sep #$20 ;a8
	sta a:OAM_BUFFER, x
;keep that high byte 9th x
	iny
	lda [temp1], y ;y byte
	clc
	adc spr_y	
	sta a:OAM_BUFFER+1, x
	iny
	lda [temp1], y ;tile
	sta a:OAM_BUFFER+2, x
	iny
	lda [temp1], y ;attributes
	sta a:OAM_BUFFER+3, x
	iny
	lda [temp1], y ;size
	iny
	sta spr_h
	xba ;that 9th x bit
	and #1
	ora spr_h
	phx ;save for later
	ldx temp3
	sta temp5, x
	plx
	
	inx
	inx
	inx
	inx
	inc sprid
	
	dec temp3 ;loop counter
	bpl @loop
; we have 4, push them to the high table now
	phx ;save for later
	ldx temp4
	lda temp5
	asl a
	asl a
	ora temp5+1
	asl a
	asl a
	ora temp5+2
	asl a
	asl a
	ora temp5+3
	ora a:OAM_BUFFER+$200, x
	sta a:OAM_BUFFER+$200, x
	inc temp4

	ldx #$0000
	stx temp5
	stx temp6
	
	plx
;overflow check	
	cpx #$0200
	bcc @ok
	ldx #$0000 ;low table index
	stz sprid
	stz temp4 ;high table index
@ok:
	
	lda #3
	sta temp3 ;loop counter
	bra @loop
	
@done:
.a8
.i16
	inc temp3
	beq @exit
;handle one more high table byte.
	ldx temp4
	lda temp5
	asl a
	asl a
	ora temp5+1
	asl a
	asl a
	ora temp5+2
	asl a
	asl a
	ora temp5+3
	ora a:OAM_BUFFER+$200, x
	sta a:OAM_BUFFER+$200, x
	
@exit:	
	plp
	rtl
	




Pad_Poll:
.a8
.i16
; reads both controllers to pad1, pad1_new, pad2, pad2_new
; auto controller reads done, call this once per main loop
; copies the current controller reads to these variables
; pad1, pad1_new, pad2, pad2_new (all 16 bit)
	php
	sep #$20 ;a8
@wait:
; wait till auto-controller reads are done
	lda $4212
	lsr a
	bcs @wait
	
	rep #$30 ;axy16
	
	lda pad1
	sta temp1 ; save last frame
	lda $4218 ; controller 1
	sta pad1
	eor temp1
	and pad1
	sta pad1_new
	
	lda pad2
	sta temp1 ; save last frame
	lda $421a ; controller 2
	sta pad2
	eor temp1
	and pad2
	sta pad2_new
	plp
	rtl



Rand16: ; returns random 16 bit # in A
.a8
.i8
; borrowed from https://github.com/cc65/cc65/blob/master/libsrc/common/rand.s
; Written and donated by Sidney Cadot - sidney@ch.twi.tudelft.nl
; 2016-11-07, modified by Brad Smith
; 2019-10-07, modified by Lewis "LRFLEW" Fox
	php
	sep #$30 ;axy8
; 8 bit routine
	lda rand
	clc
	adc #$B3
	sta rand
	adc rand+1
	sta rand+1
	adc rand+2
	sta rand+2
	xba
	lda rand+2
	adc rand+3
	sta rand+3
	plp
	rtl		 
	; return 16 bit rnd # in A
	; The best 8 bits, 24-31 are returned in the
	; low byte A to provide the best entropy.

	
		
Seed_Rand: 
.a16
.i16
; seed the random number gererator
; a16 and x16 have the seed value.
	php
	rep #$30 ;axy16
	sta rand	  
	stx rand+2	  
	plp
	rtl
	
	
	
	
; auto DMA system / vram system	
	
; to write to the screen WITHOUT setting
; forced blank, we buffer it, and set up
; an automated dma, to be executed at
; the next v-blank, in the nmi code.


Copy_To_VB:
.a16
.i16
; this copies some data to a buffer.
; and sets num_bytes_vb and src_address_vb
; you need to, separately, set dst_address_vb
; and then call either VB_Buffer_H or VB_Buffer_V
; a16 = source address
; x -L = source bank
; y16 = # of bytes
	php
	rep #$30 ;axy16
	sta temp1
	stx temp2
	sty temp3
	sty num_bytes_vb
	ldy #$0000
	ldx vb_data_index
	txa
	clc
	adc #.loword(VB_DATA)
	sta src_address_vb
@loop:
	sep #$20 ; a8
	lda [temp1], y
	sta f:VB_DATA, x
	iny
	inx
	rep #$20 ; a16
	dec temp3 ; 16 bit dec
	bne @loop
	stx vb_data_index
	sep #$20 ;A8
	inc vram_update
	plp
	rtl

	

VB_Buffer_H:
.a8
.i16
; set pointers to the data in the vram buffer
; set src_address_vb, num_bytes_vb, dst_address_vb
; then call VB_Buffer_H or VB_Buffer_V
; horizontal write buffer.
	php
	sep #$20 ;a8
	rep #$10 ;xy16
	ldy vb_ptr_index
	lda #V_INC_1 ; vram increment 1
	sta a:VB_PTRS, y
	
VB_PTRS_common:
	lda #$ff
	sta a:VB_PTRS+7, y
	
	rep #$20 ;A16
	lda src_address_vb
	sta a:VB_PTRS+1, y
	lda dst_address_vb
	sta a:VB_PTRS+3, y
	lda num_bytes_vb
	sta a:VB_PTRS+5, y

	tya
	clc
	adc #7
	sta vb_ptr_index
	
;	inc vram_update ;already done in Copy_To_VB
	plp
	rtl

	
	
VB_Buffer_V:
.a8
.i16
; vertical write buffer. like as VB_Buffer_H above.
	php
	sep #$20 ;a8
	rep #$10 ;xy16
	ldy vb_ptr_index
	lda #V_INC_32 ; vram increment 32
	sta a:VB_PTRS, y
	bra VB_PTRS_common


; --------------------------------	
	

VRAM_Read:
.a16
.i16
; do during forced blank	
; first set VRAM_Addr and VRAM_Inc
; a = destination
; x = destination bank
; y = length in bytes (should be even)
	php
	rep #$30 ;axy16
	sta temp1
	stx temp2
	tya
	lsr a ; Divide 2
	tax ; count with x
	lda $2139 ; 1 dummy read
	ldy #$0000
@loop:
	lda $2139
	sta [temp1], y
	iny
	iny
	dex
	bne	@loop
	plp
	rtl

	

DMA_VRAM:
.a16
.i16
; do during forced blank	
; first set VRAM_Addr and VRAM_Inc
; a = source
; x = source bank
; y = length in bytes
	php
	rep #$30 ;axy16
	sta $4302 ; source and 4303
	sep #$20 ;a8
	txa
	sta $4304 ; bank
	lda #$18
	sta $4301 ; destination, vram data
	sty $4305 ; length, and 4306
	lda #1
	sta $4300 ; transfer mode, 2 registers, write once = 2 bytes
	sta $420b ; start dma, channel 0
	plp
	rtl
	
	
	
; OAM_DMA
; DMA_Palette
; see above, by nmi code.
; they are automatically sent every nmi.	

	

WRAM_Fill_7E:
.a8
.i16
; to fill WRAM in the $7e0000 bank
; a-L = 8 bit fill value (0 to clear)
; x16 = start address
; y16 = size in bytes
; CAUTION, DON'T USE THIS TO CLEAR STACK $1f00-1fff
	php
	sep #$20 ;a8
	rep #$10 ;xy16
@loop:	
	sta f:$7e0000, x
	inx
	dey
	bne @loop
	plp
	rtl

	
	
WRAM_Fill_7F:
.a8
.i16
; to fill WRAM in the $7f0000 bank
; a -L = 8 bit fill value (0 to clear)
; x16 = start address
; y16 = size in bytes, 0 for $10000
	php
	sep #$20 ;a8
	rep #$10 ;xy16
@loop:	
	sta f:$7f0000, x
	inx
	dey
	bne @loop
	plp
	rtl

	

VRAM_Fill: 
.a16
.i16
; do in forced blank
; write a fixed value, 8 bit, to the vram
; first set VRAM_Addr and VRAM_Inc
; a = fill value -L 8 bit
; y = length in bytes (note, 0 = $10000 bytes)
	php
	rep #$30 ;axy16
	sta temp1
	lda #.loword(temp1)
	sta $4302 ; and 4303
	sep #$20 ;a8
	lda #^temp1
	sta $4304 ; bank
	lda #$18
	sta $4301 ; destination, vram data
	sty $4305 ; length, and 4306
	lda #9 ; 1 fixed transfer...
	sta $4300 ; transfer mode, 2 registers, write once = 2 bytes
	lda #1
	sta $420b ; start dma, channel 0
	plp
	rtl
	
	

VRAM_Fill2: 
.a16
.i16
; do in forced blank
; write a fixed value, 16 bit, to the vram
; first set VRAM_Addr and VRAM_Inc
; a = fill value 16 bit
; y = 0001 - 8000, length in words not bytes ! 
; (Divide byte length by 2)
	php
	rep #$30 ;axy16
@loop:
	sta a:$2118 ; vram_data
	dey
	bne @loop
	plp
	rtl	
	
	

; pal_fill:
; there is an automated system that copies from a buffer
; to the CGRAM during NMI. If you need to zero the palette
; do this...
; jsr Clear_Palette (has an rts)



Pal_All:
.a16
.i16
; do any time
; copy 512 bytes, all palettes to color buffer
; load A HL with pointer to data
; load X -L with bank of data
	php
	rep #$30 ;axy16
	sta temp1
	stx temp2
	ldy #0
@loop:
	lda [temp1], y
	sta a:PAL_BUFFER, y
	iny
	iny
	cpy #$200
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl
	
	
	
Pal_BG:
.a16
.i16
; do any time
; copy 256 bytes, bg palettes to color buffer
; load A HL with pointer to data
; load X -L with bank of data
	php
	rep #$30 ;axy16
	sta temp1
	stx temp2
	ldy #0
@loop:
	lda [temp1], y
	sta a:PAL_BUFFER, y
	iny
	iny
	cpy #$100
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl	
	
	
	
Pal_Spr:
.a16
.i16
; do any time
; copy 256 bytes, sprite palettes to color buffer
; load A HL with pointer to data
; load X -L with bank of data
	php
	rep #$30 ;axy16
	sta temp1
	stx temp2
	ldy #0
@loop:
	lda [temp1], y
	sta a:PAL_BUFFER+$100, y
	iny
	iny
	cpy #$100
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl	
	
	

Pal_Row:
.a16
.i16
; do any time
; copy 32 bytes, 16 colors to color buffer
; load A HL with pointer to data
; load X -L with bank of data
; load Y -L with color row, 0-15	
	php
	rep #$30 ;axy16
	sta temp1
	stx temp2
	tya
	and #$000f
	xba
	lsr a
	lsr a
	lsr a
	clc
	adc #.loword(PAL_BUFFER)
	sta temp3
	ldy #0
@loop:
	lda [temp1], y
	sta (temp3), y
	iny
	iny
	cpy #$20
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl


	
Pal_Col:
.a16
.i16
; do any time
; copy 2 bytes, 1 color to color buffer
; load A HL with color 0-$7fff
; load X -L with index of the color 0-255
	php
	rep #$30 ;axy16
	pha
	txa
	and #$00ff
	asl a ; color index * 2
	tax
	pla
	sta a:PAL_BUFFER, y
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl
	


Pal_Bright:
.a8
; change screen brightness 0 dark to 15 full bright
; load A -L with brightness
;	php
	sep #$20 ; a8
	and #$0f
	sta r2100b
;	plp
	rtl
	
	
	
Set_Mosaic:
.a8
; a = 0-15
; change screen mosaic, 0 = 1x1, F = 16x16
; load A -L with mosaic value
; this has it affect all BG layers
;	php
	sep #$20 ; a8
	asl a
	asl a
	asl a
	asl a
	sta temp1
	lda r2106
	and #$0f
	ora temp1
	sta r2106
;	plp
	rtl	
	
	
	
Pal_Fade:
; a8 = fade brightness to value 0-15
; 0 dark to 15 full bright
.a8
.i8
	php
	sep #$30 ;axy8
	sta fade_to
	lda r2100b
	sta fade_from
	
@loop:
	lda fade_from
	cmp fade_to
	beq @end ; error check
	bcc @go_up
	
@go_down:
	dec a
	sta fade_from
	bra @both
	
@go_up:
	inc a
	sta fade_from
	
@both:
	and #$0f
	sta r2100b
	lda #4
	jsl Delay
	bra @loop

@end:	
	plp
	rtl
	
	
	
Mosaic_Fade:
; a8 = fade mosaic to value 0-15
; 0 = 1x1, F = 16x16
.a8
.i8
	php
	sep #$30 ;axy8
	sta fade_to
	lda r2106
	sta fade_from
	
@loop:
	lda fade_from
	cmp fade_to
	beq @end ; error check
	bcc @go_up
	
@go_down:
	dec a
	sta fade_from
	bra @both
	
@go_up:
	inc a
	sta fade_from
	
@both:
	jsl Set_Mosaic
	lda #4
	jsl Delay
	bra @loop

@end:	
	plp
	rtl	
	
	
	
PPU_Wait_NMI:
.a8
; wait till the next frame
; only works if NMI interrupts are ON
; this can't change X, used by Delay
	php
ppu_wait_nmi2:	
	sep #$20 ;A8
	inc frame_ready ;vram_update
	lda frame_count
@1:
	cmp frame_count
	beq @1
	plp
	rtl

	
	
Delay:
.a8
; a8 is # of frames to wait max 255 (about 4 seconds)
; 0 is 256
; only works if NMI interrupts are ON
	php
	sep #$30 ;axy8
	tax

@loop:	
	jsl PPU_Wait_NMI ; doesn't change X
	dex
	bne @loop

	plp
	rtl
	
	
	
PPU_Off:
.a8
; start forced blank
; only works if NMI interrupts are ON
; note: nmi's will still fire.
	php
	sep #$20 ;a8
	lda #$80
	sta r2100
	jmp ppu_wait_nmi2
	
	
	
PPU_On:
.a8
; end forced blank
; only works if NMI interrupts are ON
	php
	sep #$20 ;a8
	stz r2100
	jmp ppu_wait_nmi2
	
	

Multiply:
.a16
.i8
; in a16 xy8
; in x and y have 8 bit multipliers
; out a16 = result
	php
	rep #$20 ;a16
	sep #$10 ;xy8
	stx $4202
	sty $4203
	nop	; wait for the calculation
	nop
	nop
	nop
	lda $4216 ; and 4217
	plp
	rtl
	
	
		
;Multiply_Fast:
;removed.
	

	
Divide:
.a16
.i8
; in a16 xy8
; in a16 = dividend
; in x8 = divisor
; out a16 = quotient
; out x8 = remainder
	php
	rep #$20 ;a16
	sep #$10 ;xy8
	sta $4204 ; and 4205
	stx $4206
	nop
	nop
	nop
	nop
	
	nop ; division is a longer wait
	nop ; to do the calculation
	nop
	nop
	lda $4214 ; and 4215
	ldx $4216
	plp
	rtl	

	
	
Set_Main_Screen:
.a8
; a8 = which layers are on main screen
	sta r212c
	rtl
	
	
	
Set_Sub_Screen:
.a8
; a8 = which layers are on sub screen
	sta r212d
	rtl	

	

;----------------
; Unrle
;----------------
; updated 6/2021
; used with R8C.py RLE or any output 
; RLE file from M1TE or SPEZ
; this assumes screen is OFF
; and a VRAM address has been set
; a16 = address of the compressed data
; x16 = bank of the compressed data
; will automatically decompress to
; 7f0000 and then copy to the VRAM

; one byte header ----
; MM CCCCCC
; M - mode, C - count (+1)
; 0 - literal, C+1 values (1-64)
; 1 - rle run, C+1 times (1-64)
; 2 - rle run, add 1 each pass, C+1 times (1-64)
; 3 - extend the value count to 2 bytes
; 00 lit, 40 rle, 80 plus, F0 special

; two byte header ----
; 11 MM CCCC (high) CCCCCCCC (low)
; M - mode (as above), C - count (+1)
; count 1-4096
; c0 lit big, d0 = rle big, e0 = plus big
; F0 - end of data, non-planar
; FF - end of data, planar

;----------------
; UNRLE
;----------------
; used with R8C.py RLE or any output 
; RLE file from M1TE or SPEZ
; this assumes screen is OFF

; First set VRAM address and inc mode
; a = address of the compressed data
; x = bank of the compressed data
; jsl Unrle
; will automatically decompress to
; 7f0000 and then copy to the VRAM
; UNPACK_ADR = $7f0000 see above
; returns y = size of unpacked data
; and ax = address of UNPACK_ADR
; then call vram_dma to send data to vram

; one byte header ----
; MM CCCCCC
; M - mode, C - count (+1)
; 0 - literal, C+1 values (1-64)
; 1 - rle run, C+1 times (1-64)
; 2 - rle run, add 1 each pass, C+1 times (1-64)
; 3 - extend the value count to 2 bytes
; 00 lit, 40 rle, 80 plus, F0 special

; two byte header ----
; 11 MM CCCC (high) CCCCCCCC (low)
; M - mode (as above), C - count (+1)
; count 1-4096
; c0 lit big, d0 = rle big, e0 = plus big
; F0 - end of data, non-planar
; FF - end of data, planar


Unrle:
.a16
.i16
	rep #$30 ; axy16
	sta temp1
	stx temp2
	stz temp4 ;index to dst
	ldy #0
@loop:	
	sep #$20 ; a8
	lda #0 ;clear the upper byte for later
	xba
; read header byte
	lda [temp1], y
	cmp #$f0
	bcs @done
	and #$c0 ;get mode
	bne @1
	jmp @lit_short ;00
@1:
	cmp #$40
	bne @2
	jmp @rle_short ;40
@2:
	cmp #$80
	bne @3
	jmp @plus_short ;80
@3:
	
;2 byte header, get 1st byte
	lda [temp1], y
	and #$30
	bne @4
	jmp @lit_long ;c0
@4:
	cmp #$10
	bne @5
	jmp @rle_long ;d0
@5:
	jmp @plus_long ;e0
	

@done:	
; see if planar
	and #$0f
	bne @planar ;ff
@standard: ;f0

@exit:	
	rep #$30 ;axy16
	lda #.loword(UNPACK_ADR)
	ldx #^UNPACK_ADR
	ldy temp4 ;size
	rtl


	
@planar:
.a8
; interleave the bytes
	rep #$30 ;axy16
	lda #.loword(UNPACK_ADR)
	ldy #^UNPACK_ADR
	sta temp1
	lda temp4 ;size
		pha ;save size
	clc
	adc temp1
	sta temp5
		pha ;save address
	lda temp4 ;size
	lsr a ;half
	tax ;half size as counter
	clc
	adc temp1
	sta temp3 ;full size, start of output buffer
	sty temp2 ;bank bytes
	sty temp4
	sty temp6
;temp1 points to start of buffer, temp3 points to halfway point
	sep #$20 ;a8
	ldy #0
@loop2:
	lda [temp3], y ;high byte
	xba
	lda [temp1], y ;low byte
	rep #$20 ;a16
	sta [temp5], y ;combined byte
	iny
	inc temp5 ;16 bit inc
	sep #$20 ;a8
	dex
	bne @loop2

@exit2:
	rep #$30 ;axy16
	;lda #.loword(UNPACK_ADR)
	pla ;output address
	ldx #^UNPACK_ADR
	ply ;size
	rtl
	
	
	
@lit_short:
.a8
.i16
	;upper byte should be clear
	lda [temp1], y ; get repeat count
	and #$3f 
	;note register size mismatch
	tax ;loop count
	iny
	bra @literal
	
@lit_long:	
	rep #$20 ;a16
	lda [temp1], y ; get repeat count
	xba ;the bytes are in reverse order
	and #$0fff
	tax
	iny
	iny ;2 byte header
	sep #$20 ;a8
	;fall through, x = repeat count
@literal: ;copy literal bytes
.a8
	inx ;repeat +1
	stx temp3 ;count
	ldx temp4 ;index to dst
@loop4:
	sep #$20 ;a8
	lda [temp1], y
	sta f:UNPACK_ADR, x
	iny
	inx
	rep #$20 ;a16
	dec temp3 ;count 16 bit
	bne @loop4
	;sep #$20 ;a8 - done at top of @loop
	stx temp4 ;index to dst
	jmp @loop


@rle_short:
.a8
.i16
	;upper byte should be clear
	lda [temp1], y ; get repeat count
	and #$3f
	;note register size mismatch
	tax ;loop count
	iny
	bra @do_rle
@rle_long:	
	rep #$20 ;a16
	lda [temp1], y ; get repeat count 
	xba ;the bytes are in reverse order
	and #$0fff
	tax
	iny
	iny ;2 byte header
	sep #$20 ;a8
	;fall through, x = repeat count
@do_rle:
.a8
	inx ;repeat +1
	lda [temp1], y ;the value to repeat
	iny
	phy
	txy ;use y as counter
	ldx temp4 ;index to dst
@loop5:
	sta f:UNPACK_ADR, x
	inx
	dey
	bne @loop5
	
	ply
	;sep #$20 ;a8 - done at top of @loop
	stx temp4 ;index to dst
	jmp @loop

@plus_short:
.a8
.i16
	;upper byte should be clear
	lda [temp1], y ; get repeat count
	and #$3f
	;note register size mismatch
	tax ;loop count
	iny
	bra @do_plus
@plus_long:	
	rep #$20 ;a16
	lda [temp1], y ; get repeat count 
	xba ;the bytes are in reverse order
	and #$0fff
	tax
	iny
	iny ;2 byte header
	sep #$20 ;a8
	;fall through, x = repeat count
@do_plus:
.a8
	inx ;repeat +1
	lda [temp1], y ;the value to repeat
	iny
	phy
	txy ;use y as counter
	ldx temp4 ;index to dst
@loop6:
	sta f:UNPACK_ADR, x
	inc a ;increase the value each loop
	inx
	dey
	bne @loop6
	
	ply
	;sep #$20 ;a8 - done at top of @loop
	stx temp4 ;index to dst
	jmp @loop
	
	
	
	
Check_Collision:
.a8
.i16
;copy each object's value to these varibles and jsr here.
;obj1x: .res 1 ; x
;obj1w: .res 1 ; width
;obj1y: .res 1 ; x
;obj1h: .res 1 ; height
;obj2x: .res 1 ; x
;obj2w: .res 1 ; width
;obj2y: .res 1 ; y
;obj2h: .res 1 ; height
;collision: .res 1
;returns collision = 1 or 0
	php
	sep #$20 ;A8
;first check if obj1 R (obj1 x + width) < obj2 L

	lda obj1x
	clc
	adc obj1w
	cmp obj2x
	bcc @no
		
;now check if obj1 L > obj2 R (obj2 x + width)

	lda obj2x
	clc
	adc obj2w
	cmp obj1x
	bcc @no

;first check if obj1 Bottom (obj1 y + height) < obj2 Top
	
	lda obj1y
	clc
	adc obj1h
	cmp obj2y
	bcc @no
		
;now check if obj1 Top > obj2 Bottom (obj2 y + height)

	lda obj2y
	clc
	adc obj2h
	cmp obj1y
	bcc @no
	
@yes:
	lda #1
	sta collision
	plp
	rtl
	
@no:
	stz collision
	plp
	rtl	
	





	