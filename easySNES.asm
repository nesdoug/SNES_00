;easySNES - written by Doug Fraker, 2020
;ver 1.0 Jan 26 2020
;based on neslib by Shiru and others

;always jsl to these subroutines
;DON'T CHANGE THE DIRECT PAGE, assume 0000 always 
;see usage.txt

;things not covered
;hdma
;windows
;color math
;mode 7
;expansion chips
;irq h/v timers


.p816
.smart

.include "defines.asm"
.include "macros.asm"



UNPACK_ADR = $7f0000


.segment "ZEROPAGE"
; don't use these temps, reserved for the library
temp1: .res 2 
temp2: .res 2
temp3: .res 2
;temp4: .res 2

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
r4200: .res 1 ;for music code

sprid: .res 1
spr_x: .res 1 ;for sprite setting code
spr_y: .res 1
spr_c: .res 1
spr_a: .res 1
spr_h: .res 1
spr_x2:	.res 2 ;for meta sprite code
spr_y2: .res 1
spr_h2:	.res 1

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

bg1_map_base: .res 2 ;where in VRAM the map starts
bg2_map_base: .res 2
bg3_map_base: .res 2
bg4_map_base: .res 2

pad1: .res 2
pad1_new: .res 2
pad2: .res 2
pad2_new: .res 2

src_address_vb: .res 2
dst_address_vb: .res 2
num_bytes_vb: .res 2
fade_from: .res 1
fade_to: .res 1
rand:	.res 4



.segment "BSS"
;put an a: in front of all these when in use to force 16-bit address
pal_buffer: .res 512
oam_buffer: .res 544
vb_ptrs: .res 256 ;list of pointers to vram buffer data
scratchpad:	.res 256

.segment "BSS7E"
;put a f: in front to force a 24-bit address
vb_data: .res $2000 ;vram buffer data to be transfered





.global RESET, NMI, IRQ, IRQ_end, oam_dma, pal_dma, vram_update_system, bg_mode
.global bg3_priority, bg_tilesize, bg1_tile_addr, bg2_tile_addr, bg3_tile_addr
.global bg4_tile_addr, bg1_map_addr, bg1_map_size, bg2_map_addr, bg2_map_size
.global bg3_map_addr, bg3_map_size, bg4_map_addr, bg4_map_size, map_offset
.global map_offset6464, oam_clear, oam_size, oam_tile_addr, oam_spr
.global pad_poll, vb_buffer_H, vb_buffer_V, vram_adr, vram_inc
.global vram_put, vram_fill, vram_dma, wram_fill_7e, wram_fill_7f
.global pal_all, pal_row, pal_col, pal_bright, pal_buffer, oam_buffer
.global ppu_wait_nmi, delay, ppu_off, ppu_on, set_mosaic, multiply, divide
.global reset_vram_system, pal_bg, pal_spr, set_main_screen, set_sub_screen
.global pal_fade, mosaic_fade, vram_fill2, scratchpad, multiply_fast
.global rand16, seed_rand, copy_to_vb, oam_meta_spr

.globalzp r2100, r2100b, r2101, r2105, r2106, r2107, r2108, r2109, r210a
.globalzp r210b, r210c, sprid, spr_x, spr_y, spr_c, spr_a, spr_h, pal_update
.globalzp vram_update, frame_count, bg1_scroll_x, bg1_scroll_y
.globalzp bg2_scroll_x, bg2_scroll_y, bg3_scroll_x, bg3_scroll_y 
.globalzp bg4_scroll_x, bg4_scroll_y, bg1_map_base, bg2_map_base
.globalzp bg3_map_base, bg4_map_base, pad1, pad1_new, pad2, pad2_new
.globalzp vb_ptr_index, vb_data_index, src_address_vb, dst_address_vb, num_bytes_vb
.globalzp r212c, r212d, fade_from, fade_to, r4200




.segment "CODE"
;this needs to be in bank 0 !!


NMI:
.a16
.i16
	rep #$30
	phb
	pha
	phx
	phy
	phd

	phk ;is zero
	plb ;set data bank to zero (in case it was 7e or 7f)
	lda #$0000
	tcd
	
	sep #$20
	
;note, DKC3 jumps long to $80 bank here, should we ??	
	
	lda $4210
	;it is required to read this register
	;in the NMI handler
	
	lda r2100
	and #$80 ;is this forced blank?
	beq @do_update
	jmp @skip_all
@do_update:
;a8 xy16
	stz $420c ;make sure hdma doesn't conflict with dma
	
	jsr oam_dma
	
	lda pal_update
	beq @update_vram
	stz pal_update
	jsr pal_dma
	
@update_vram:
	lda vram_update
	beq @skip_update
	stz vram_update
	jsr vram_update_system

@skip_update:
;A is still 8 bit
	lda r2101
	sta $2101 ;sprite size and tile address

	lda r2105
	sta $2105 ;bg mode

	lda r2106
	sta $2106 ;mosaic
	
	lda r212c 
	sta $212c ;main screen
	
	lda r212d
	sta $212d ;sub screen
	
;write twice registers
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
;restore registers
	
	sep #$20
	lda r2100
	ora r2100b ;brightness
	sta $2100
	
	rep #$30
	inc frame_count ;16 bit
	
	pld
	ply
	plx
	pla
	plb
;plp not needed, rti does that already
	rti
	
	
IRQ:
	pha ; doesn't matter what A size is
	lda $4211
; this register is required to be read
; in the IRQ handler
	
; handler is blank	
; IRQ can be used for mid-screen effects
; using the H or V timers $4207-a

	pla
IRQ_end:	
	rti
;restores processor flags
	
	
oam_dma:
.a8
.i16
;used by nmi. copies oam buffer to OAM
	ldx #0
	stx $2102 ;oam address
	stz $4300 ;transfer mode
	lda #4
	sta $4301 ;destination, oam data
	ldx #oam_buffer
	stx $4302 ;source
	stz $4304 ;bank
	ldx #544
	stx $4305 ;length
	lda #1
	sta $420b ;start dma, channel 0
	rts
	
	
pal_dma:
.a8
.i16
;used by nmi. copies pal buffer to palette
	stz $2121 ;cg address
	stz $4300 ;transfer mode ;zero is fine.
	lda #$22
	sta $4301 ;destination, pal data
	ldx #pal_buffer
	stx $4302 ;source
	stz $4304 ;bank
	ldx #512
	stx $4305 ;length
	lda #1
	sta $420b ;start dma, channel 0
	rts
	
	
	

vram_update_system:
.a8
.i16
;used by nmi. copies vram buffer to VRAM

;1st byte = vram increment mode, or...ff = end of set
;2-3 bytes = wram address (always 7e bank)
;4-5 bytes = vram address
;6-7 bytes = length

	lda #1
	sta $4300 ;transfer mode, 2 registers 1 write
	lda #$18
	sta $4301 ;destination, vram data
	lda #$7e
	sta $4304 ;src bank, always 7e
	ldy #0
@loop:
	lda a:vb_ptrs, y
	cmp #$ff
	beq @done
	sta $2115 ;vram increment mode, first byte of every set
	iny
	
	ldx a:vb_ptrs, y ;src address
	stx $4302 ;and 3
	iny
	iny
	ldx a:vb_ptrs, y ;destination address in vram
	stx $2116 ;and 2117
	iny
	iny
	ldx a:vb_ptrs, y ;size of transfer
	stx $4305 ;and 6
	iny
	iny
	
	lda #1
	sta $420b ;start dma, channel 0
	bra @loop
	
@done:
	lda #$ff
	sta a:vb_ptrs ;cleared
	lda #V_INC_1 ;back to standard
	sta $2115 ;vram_inc mode
	rts


	

reset_vram_system:
;call once per frame, if using the auto-dma system.
.a16
	php
	rep #$20
	stz vram_update
	stz vb_ptr_index
	stz vb_data_index
	lda #$ffff
	sta a:vb_ptrs
	plp
	rtl

	
	
	
	
	
	

bg_mode:
.a8
.i16
;a = 0-7 =  mode
	and #7
	sta temp1
	lda r2105
	and #$f8
	ora temp1
	sta r2105
	rtl



bg3_priority:
.a8
.i16
;if A = 0, bg 3on bottom
;if A = 8, bg 3 on top
	and #8
	sta temp1
	lda r2105
	and #$f7
	ora temp1
	sta r2105
	rtl
	
	

bg_tilesize:
.a8
.i16
;A = 0 for 8x8
;A = $f0 for 16x16 for all maps
;4321 ---- 1 bit per layer
	and #$f0
	sta temp1
	lda r2105
	and #$0f
	ora temp1
	sta r2105
	rtl

	
	
bg1_tile_addr:
.a8
.i16
;do during forced blank	
;a8 = 0-7 = 0-7000, layer 1 tiles
;steps of 1000
	and #7
	sta temp1
	lda r210b
	and #$70
	ora temp1
	sta r210b
	sta $210b
	rtl
	

	
bg2_tile_addr:
.a8
.i16
;do during forced blank	
;a8 = 00-70 = 0-7000, layer 2 tiles
;steps of 1000
	and #$70
	sta temp1
	lda r210b
	and #7
	ora temp1
	sta r210b
	sta $210b
	rtl	

	
	
bg3_tile_addr:
.a8
.i16
;do during forced blank	
;a8 = 0-7 = 0-7000, layer 3 tiles
;steps of 1000
	and #7
	sta temp1
	lda r210c
	and #$70
	ora temp1
	sta r210c
	sta $210c
	rtl
	
	

bg4_tile_addr:
.a8
.i16
;do during forced blank	
;a8 = 00-70 = 0-7000, layer 4 tiles
;steps of 1000
	and #$70
	sta temp1
	lda r210c
	and #7
	ora temp1
	sta r210c
	sta $210c
	rtl		
	
	

bg1_map_addr:	
.a8
.i16
;do during forced blank	
;a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg1_map_base+1
	stz bg1_map_base
	lda r2107
	and #3
	ora bg1_map_base+1
	sta r2107
	sta $2107
	rtl


			
bg1_map_size:
.a8
.i16
;do during forced blank	
;a8 = map size constant 0-3
	and #3
	sta temp1
	lda r2107
	and #$fc
	ora temp1
	sta r2107
	sta $2107
	rtl
	
	

bg2_map_addr:	
.a8
.i16
;do during forced blank	
;a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg2_map_base+1
	stz bg2_map_base
	lda r2108
	and #3
	ora bg2_map_base+1
	sta r2108
	sta $2108
	rtl

	
	
bg2_map_size:
.a8
.i16
;do during forced blank	
;a8 = map size constant 0-3
	and #3
	sta temp1
	lda r2108
	and #$fc
	ora temp1
	sta r2108
	sta $2108
	rtl
	
	

bg3_map_addr:
.a8
.i16	
;do during forced blank	
;a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg3_map_base+1
	stz bg3_map_base
	lda r2109
	and #3
	ora bg3_map_base+1
	sta r2109
	sta $2109
	rtl
	
	
	
bg3_map_size:
.a8
.i16
;do during forced blank	
;a8 = map size constant 0-3
	and #3
	sta temp1
	lda r2109
	and #$fc
	ora temp1
	sta r2109
	sta $2109
	rtl
	
	

bg4_map_addr:	
.a8
.i16
;do during forced blank	
;a8 = 0-7c = tilemap address H 0-7c00, steps of 400
	and #$7c
	sta bg4_map_base+1
	stz bg4_map_base
	lda r210a
	and #3
	ora bg4_map_base+1
	sta r210a
	sta $210a
	rtl

	
	
bg4_map_size:
.a8
.i16
;do during forced blank	
;a8 = map size constant 0-3
	and #3
	sta temp1
	lda r210a
	and #$fc
	ora temp1
	sta r210a
	sta $210a
	rtl
	
	
	
map_offset: 
.a16
.i8
;A should be 16, XY size doesn't matter
;converts pixel coordinates in a map to tile address offset
;the idea is that you add this value to the map_base
;works for 32x32,64x32,and 32x64 maps
;x -L = tile's x position, 0-31 [0-63 large map]
;y -L = tile's y position, 0-31 [0-63 large map]
;y max 27 if non-scrolling and screen size 224 pixel tall 
;to convert pixels to tiles >> 3 (if 16x16 tile size >> 4)

;returns a16 = vram address offset (add it to the base address)
	php
	rep #$20
	sep #$10
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
;returns a = map offset
	plp
	rtl

	
	
map_offset6464: 
.a16
.i8
;A should be 16, XY size doesn't matter
;works for 64x64 maps only
;x -L = tile's x position, 0-63 large map
;y -L = tile's y position, 0-63 large map
;y max 27 if non-scrolling and screen size 224 pixel tall 
;to convert pixels to tiles >> 3 (if 16x16 tile size >> 4)

;returns a16 = vram address
	php
	rep #$20
	sep #$10

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

	
	
oam_clear:
.a8
.i16
;do at the start of each frame	
;clears the sprite buffer
;put all y at 224
	php
	sep #$20
	rep #$10
	stz sprid
	lda #224
	ldy #1
@loop:
;more efficient than a one lined sta
	sta a:oam_buffer, y
	sta a:oam_buffer+$40, y
	sta a:oam_buffer+$80, y
	sta a:oam_buffer+$c0, y
	sta a:oam_buffer+$100, y
	sta a:oam_buffer+$140, y
	sta a:oam_buffer+$180, y
	sta a:oam_buffer+$1c0, y
	iny
	iny
	iny
	iny
	cpy #$40 ;41, but whatever
	bcc @loop
	
;clear the high table too
;then the oam_spr code can skip the 5th byte, if zero

	ldx #30
	rep #$20
@loop2:
	stz a:oam_buffer+$200, x
	dex
	dex
	bpl @loop2
	plp
	rtl
	


oam_size:
.a8
.i16
;do any time, copied to register in nmi	
;---- -111 = base address
;a8 = mode in 111- ---- bits
;NOTE, in 64x64 mode, large sprites can't hide at the bottom
;so oam_clear won't work right, they will wrap to the top.
	and #$e0
	sta temp1
	lda r2101
	and #$1f
	ora temp1
	sta r2101
	rtl
	
	
	
oam_tile_addr:
.a8
.i16	
;do any time, copied to register in nmi	
;---- --11 = base address
;a8 = H vram address 0-$6000 in 2000 steps
;the "name select" is assumed to be zero
;so the 256-511 tiles for sprite will be
;immediately above the 0-255 tiles.
	and #3 ;0-3
	sta temp1
	lda r2101
	and #$fc
	ora temp1
	sta r2101
	rtl

	
	
oam_spr:
.a8
.i16
;to put one sprite on screen
; copy all the sprite values to these 8 bit variables
;spr_x - x
;spr_y - y
;spr_c - tile #
;spr_a - attributes, flip, palette, priority
;spr_h - 0-3, optional, keep zero if not needed
;  bit 0 = X high bit (neg)
;  bit 1 = sprite size
	php
	sep #$20
	lda sprid ;0-127
	lsr a
	lsr a
	sta temp1 ;0-31
	lda sprid
	rep #$30
	and #$007f
	asl a
	asl a ;0-511
	tay
	sep #$20
	lda spr_x
	sta a:oam_buffer, y
	lda spr_y
	sta a:oam_buffer+1, y
	lda spr_c
	sta a:oam_buffer+2, y
	lda spr_a
	sta a:oam_buffer+3, y
	
;handle the high table
;two bits, shift them in
;this is slow, so if this is zero, skip it, it was
;zeroed in oam_clear

	lda spr_h ;if zero, skip
	beq @end
	and #3 ;to be safe, we only need 2 bits
	sta spr_h
	
	lda #0
	xba ;clear that H byte, a is 8 bit
	lda temp1 ;sprid >> 2
	tay ;should be 0-31
	
	lda sprid
	and #3
	beq @zero
	cmp #1
	beq @one
	cmp #2
	beq @two
	bne @three
@zero:
	lda a:oam_buffer+$200, y
	and #$fc
	sta temp1
	lda spr_h
	ora temp1
	sta a:oam_buffer+$200, y
	bra @end
	
@one:
	lda a:oam_buffer+$200, y
	and #$f3
	sta temp1
	lda spr_h
	asl a
	asl a
	ora temp1
	sta oam_buffer+$200, y
	bra @end
	
@two:
	lda a:oam_buffer+$200, y
	and #$cf
	sta temp1
	lda spr_h
	asl a
	asl a
	asl a
	asl a
	ora temp1
	sta a:oam_buffer+$200, y	
	bra @end

@three:
	lda a:oam_buffer+$200, y
	and #$3f
	sta temp1
	lda spr_h
	lsr a ;0000 0001 c
	ror a ;1000 0000 c
	ror a ;1100 0000 0
	ora temp1
	sta a:oam_buffer+$200, y	
	
@end:	
	lda sprid
	clc
	adc #1
	and #$7f ;keep it 0-127
	sta sprid
	plp
	rtl
	
	
	
oam_meta_spr:	
.a16
.i16
;to put multiple sprites on screen
; copy all the sprite values to these 8 bit variables
;spr_x - x
;spr_y - y
;spr_h - 0-3, optional, keep zero if not needed
;  bit 0 = X high bit (neg)
;  bit 1 = sprite size
;(these values are trashed... rewrite them each use.)
;then 
;A16 = data address
;X = bank of data
;format (4 bytes per sprite)
;relative x, relative y, tile #, attributes
;end in 128
	php
	rep #$30
	;temp1 is used by oam_spr, don't use it here
	sta temp2
	stx temp3
	sep #$20
	lda spr_x
	sta spr_x2
	lda spr_y
	sta spr_y2
	lda spr_h
	and #$01 ;high x 0-1
	beq @zero
	lda #$ff ;high x = -1
@zero:	
	sta spr_x2+1
	lda spr_h
	and #$02
	sta spr_h2 ;size
	
@loop:
	sep #$30 ;axy8
	lda [temp2]
	cmp #128
	beq @done
	;a = rel x
	rep #$20 ;a16
	and #$00ff ;clear that upper byte...
;need to extend the sign for a negative rel X	
	cmp #$0080
	bcc @pos_x
@neg_x:
	ora #$ff00 ;extend the sign
@pos_x:
	clc
	adc spr_x2
	sep #$20 ;a8
	sta spr_x ;8 bit low X
	xba ;are we in range?
	cmp #$ff
	bne @check_x
;set high x	
	lda spr_h2
	ora #$01
	sta spr_h
	bra @x_done
	
@check_x:
	cmp #$01 ;too far right
	bcs @skip
;clear high x 	
	lda spr_h2
	sta spr_h
	
@x_done:
.a8
	ldy #1 ;rel y
	lda [temp2], y
	clc
	adc spr_y2
	sta spr_y

	iny ;y=2 char
	lda [temp2], y
	sta spr_c
	iny ;y=3 attributes
	lda [temp2], y
	sta spr_a
	
	jsl oam_spr ;call the 1 sprite subroutine
	
@skip:
	rep #$30
	lda #$0004
	clc
	adc temp2
	sta temp2
	bra @loop
	
@done:	
.a8
.i8
	plp
	rtl
	

	
;music_play:
;music_stop:
;music_pause:
;sfx_play:
;see music.asm



pad_poll:
.a8
.i16
;reads both controllers to pad1, pad1_new, pad2, pad2_new
;auto controller reads done, call this once per main loop
;copies the current controller reads to these variables
;pad1, pad1_new, pad2, pad2_new (all 16 bit)
	php
	sep #$20
@wait:
;wait till auto-controller reads are done
	lda $4212
	lsr a
	bcs @wait
	
	rep #$30
	
	lda pad1
	sta temp1 ;save last frame
	lda $4218 ;controller 1
	sta pad1
	eor temp1
	and pad1
	sta pad1_new
	
	lda pad2
	sta temp1 ;save last frame
	lda $421a ;controller 2
	sta pad2
	eor temp1
	and pad2
	sta pad2_new
	plp
	rtl



rand16: ;enter with rep #$20, returns random 16 bit #
.a16
.i16
;borrowed from https://github.com/cc65/cc65/blob/master/libsrc/common/rand.s
; Written and donated by Sidney Cadot - sidney@ch.twi.tudelft.nl
; 2016-11-07, modified by Brad Smith
; 2019-10-07, modified by Lewis "LRFLEW" Fox
	php
	sep #$30
;8 bit routine
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

	
		
seed_rand: 
.a16
.i16
;seed the random number gererator
;a16 and x16 have the seed value.
	php
	rep #$30
	sta rand	  
	stx rand+2	  
	plp
	rtl
	
	
	
	
; auto DMA system / vram system	
	
;to write to the screen WITHOUT setting
;forced blank, we buffer it, and set up
;an automated dma, to be executed at
;the next v-blank, in the nmi code.


copy_to_vb:
.a16
.i16
;this copies some data to a buffer.
;and sets num_bytes_vb and src_address_vb
;you need to, separately, set dst_address_vb
;and then call either vb_buffer_H or vb_buffer_V
;a16 = source address
;x -L = source bank
;y16 = # of bytes
	php
	rep #$30
	sta temp1
	stx temp2
	sty temp3
	sty num_bytes_vb
	ldy #$0000
	ldx vb_data_index
	txa
	clc
	adc #.loword(vb_data)
	sta src_address_vb
@loop:
	sep #$20 ;a8
	lda [temp1], y
	sta f:vb_data, x
	iny
	inx
	rep #$20 ;a16
	dec temp3 ;16 bit dec
	bne @loop
	stx vb_data_index
	plp
	rtl

	

vb_buffer_H:
.a8
.i16
;set pointers to the data in the vram buffer
;set src_address_vb, num_bytes_vb, dst_address_vb
;then call vb_buffer_H or vb_buffer_V
;horizontal write buffer.
	php
	sep #$20
	rep #$10
	ldy vb_ptr_index
	lda #V_INC_1 ;vram increment 1
	sta a:vb_ptrs, y
	
vb_ptrs_common:
	lda #$ff
	sta a:vb_ptrs+7, y
	
	rep #$20
	lda src_address_vb
	sta a:vb_ptrs+1, y
	lda dst_address_vb
	sta a:vb_ptrs+3, y
	lda num_bytes_vb
	sta a:vb_ptrs+5, y

	tya
	clc
	adc #7
	sta vb_ptr_index
	plp
	rtl

	
	
vb_buffer_V:
.a8
.i16
;vertical write buffer. like as vb_buffer_H above.
	php
	sep #$20
	rep #$10
	ldy vb_ptr_index
	lda #V_INC_32 ;vram increment 32
	sta a:vb_ptrs, y
	bra vb_ptrs_common


; --------------------------------	
	

vram_read:
.a16
.i16
;do during forced blank	
;first set vram_adr and vram_inc
;a = destination
;x = destination bank
;y = length in bytes (should be even)
	php
	rep #$30
	sta temp1
	stx temp2
	tya
	lsr a ;divide 2
	tax ;count with x
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

	

vram_dma:
.a16
.i16
;do during forced blank	
;first set vram_adr and vram_inc
;a = source
;x = source bank
;y = length in bytes
	php
	rep #$30
	sta $4302 ;source and 4303
	sep #$20
	txa
	sta $4304 ;bank
	lda #$18
	sta $4301 ;destination, vram data
	sty $4305 ;length, and 4306
	lda #1
	sta $4300 ;transfer mode, 2 registers, write once = 2 bytes
	sta $420b ;start dma, channel 0
	plp
	rtl
	
	
	
;oam_dma
;pal_dma
;see above, by nmi code.
;they are automatically sent every nmi.	

	

wram_fill_7e:
.a8
.i16
;to fill WRAM in the $7e0000 bank
; a-L = 8 bit fill value (0 to clear)
; x16 = start address
; y16 = size in bytes
; CAUTION, DON'T USE THIS TO CLEAR STACK $1f00-1fff
	php
	sep #$20
	rep #$10
@loop:	
	sta f:$7e0000, x
	inx
	dey
	bne @loop
	plp
	rtl

	
	
wram_fill_7f:
.a8
.i16
;to fill WRAM in the $7f0000 bank
; a -L = 8 bit fill value (0 to clear)
; x16 = start address
; y16 = size in bytes, 0 for $10000
	php
	sep #$20
	rep #$10
@loop:	
	sta f:$7f0000, x
	inx
	dey
	bne @loop
	plp
	rtl

	

vram_fill: 
.a16
.i16
;do in forced blank
;write a fixed value, 8 bit, to the vram
;first set vram_adr and vram_inc
;a = fill value -L 8 bit
;y = length in bytes (note, 0 = $10000 bytes)
	php
	rep #$30
	sta temp1
	lda #.loword(temp1)
	sta $4302 ;and 4303
	sep #$20
	lda #^temp1
	sta $4304 ;bank
	lda #$18
	sta $4301 ;destination, vram data
	sty $4305 ;length, and 4306
	lda #9 ;1 fixed transfer...
	sta $4300 ;transfer mode, 2 registers, write once = 2 bytes
	lda #1
	sta $420b ;start dma, channel 0
	plp
	rtl
	
	

vram_fill2: 
.a16
.i16
;do in forced blank
;write a fixed value, 16 bit, to the vram
;first set vram_adr and vram_inc
;a = fill value 16 bit
;y = 0001 - 8000, length in words not bytes ! 
;(divide byte length by 2)
	php
	rep #$30
@loop:
	sta a:$2118 ;vram_data
	dey
	bne @loop
	plp
	rtl	
	
	

;pal_fill:
;there is an automated system that copies from a buffer
;to the CGRAM during NMI. If you need to zero the palette
;do this...
;rep #$30
;lda #0 ;fill byte
;ldx #.loword(pal_buffer)
;ldy #$200
;jsl wram_fill_7e
;inc pal_update



pal_all:
.a16
.i16
;do any time
;copy 512 bytes, all palettes to color buffer
;load A HL with pointer to data
;load X -L with bank of data
	php
	rep #$30
	sta temp1
	stx temp2
	ldy #0
@loop:
	lda [temp1], y
	sta a:pal_buffer, y
	iny
	iny
	cpy #$200
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl
	
	
	
pal_bg:
.a16
.i16
;do any time
;copy 256 bytes, bg palettes to color buffer
;load A HL with pointer to data
;load X -L with bank of data
	php
	rep #$30
	sta temp1
	stx temp2
	ldy #0
@loop:
	lda [temp1], y
	sta a:pal_buffer, y
	iny
	iny
	cpy #$100
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl	
	
	
	
pal_spr:
.a16
.i16
;do any time
;copy 256 bytes, sprite palettes to color buffer
;load A HL with pointer to data
;load X -L with bank of data
	php
	rep #$30
	sta temp1
	stx temp2
	ldy #0
@loop:
	lda [temp1], y
	sta a:pal_buffer+$100, y
	iny
	iny
	cpy #$100
	bne @loop
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl	
	
	

pal_row:
.a16
.i8
;do any time
;copy 32 bytes, 16 colors to color buffer
;load A HL with pointer to data
;load X -L with bank of data
;load Y -L with color row, 0-15	
	php
	rep #$30
	sta temp1
	stx temp2
	tya
	and #$000f
	xba
	lsr a
	lsr a
	lsr a
	clc
	adc #.loword(pal_buffer)
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


	
pal_col:
.a16
.i16
;do any time
;copy 2 bytes, 1 color to color buffer
;load A HL with color 0-$7fff
;load X -L with index of the color 0-255
	php
	rep #$30
	pha
	txa
	and #$00ff
	asl a ;color index * 2
	tax
	pla
	sta a:pal_buffer, y
	inc pal_update ; set flag, will dma palette during nmi
	plp
	rtl
	


pal_bright:
.a8
;change screen brightness 0 dark to 15 full bright
;load A -L with brightness
	php
	sep #$20 ;a8
	and #$0f
	sta r2100b
	plp
	rtl
	
	
	
set_mosaic:
.a8
;a = 0-15
;change screen mosaic, 0 = 1x1, F = 16x16
;load A -L with brightness
;this has it affect all BG layers
	php
	sep #$20 ;a8
	asl a
	asl a
	asl a
	asl a
	sta temp1
	lda r2106
	and #$0f
	ora temp1
	sta r2106
	plp
	rtl	
	
	
	
pal_fade:
;a8 = fade brightness to value 0-15
;0 dark to 15 full bright
.a8
.i8
	php
	sep #$30
	sta fade_to
	lda r2100b
	sta fade_from
	
@loop:
	lda fade_from
	cmp fade_to
	beq @end ;error check
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
	jsl delay
	bra @loop

@end:	
	plp
	rtl
	
	
	
mosaic_fade:
;a8 = fade mosaic to value 0-15
;0 = 1x1, F = 16x16
.a8
.i8
	php
	sep #$30
	sta fade_to
	lda r2106
	sta fade_from
	
@loop:
	lda fade_from
	cmp fade_to
	beq @end ;error check
	bcc @go_up
	
@go_down:
	dec a
	sta fade_from
	bra @both
	
@go_up:
	inc a
	sta fade_from
	
@both:
	jsl set_mosaic
	lda #4
	jsl delay
	bra @loop

@end:	
	plp
	rtl	
	
	
	
ppu_wait_nmi:
.a8
;wait till the next frame
;only works if NMI interrupts are ON
;this can't change X, used by delay
	php
ppu_wait_nmi2:	
	sep #$20
	inc vram_update
	lda frame_count
@1:
	cmp frame_count
	beq @1
	plp
	rtl

	
	
delay:
.a8
;a8 is # of frames to wait max 255 (about 4 seconds)
;0 is 256
;only works if NMI interrupts are ON
	php
	sep #$30
	tax

@loop:	
	jsl ppu_wait_nmi ;doesn't change X
	dex
	bne @loop

	plp
	rtl
	
	
	
ppu_off:
.a8
;start forced blank
;only works if NMI interrupts are ON
;note: nmi's will still fire.
	php
	sep #$20
	lda #$80
	sta r2100
	jmp ppu_wait_nmi2
	
	
	
ppu_on:
.a8
;end forced blank
;only works if NMI interrupts are ON
	php
	sep #$20
	stz r2100
	jmp ppu_wait_nmi2
	
	

multiply:
.a16
.i8
;in a16 xy8
;in x and y have 8 bit multipliers
;out a16 = result
	php
	rep #$20
	sep #$10
	stx $4202
	sty $4203
	nop	;wait for the calculation
	nop
	nop
	nop
	lda $4216 ;and 4217
	plp
	rtl
	
	
		
multiply_fast:
.a16
.i8
;only works if screen mode 0-6
;not in mode 7
;in a16 xy8
;in a16 = first multiplier 16 bit
;in x8 = second multiplier 8 bit
;out a16 = result 16 bit
;out x8 = result high, if > $ffff
;note, this does a 2's compliment multiplication
;and the numbers get weird if either negative bit set
;0002 x ff (-1) = fffffe (-2)
;ffff (-1) x 02 = fffffe (-2)
;ffff (-1) x fe (-2) = 2
	php
	sep #$30 ;axy8
	sta $211b ;low byte
	xba
	sta $211b ;high byte
	stx $211c
;no wait for the calculation
	rep #$20 ;a16
	lda $2134 ;and 2135
	ldx $2136
	plp
	rtl	
	

	
divide:
.a16
.i8
;in a16 xy8
;in a16 = dividend
;in x8 = divisor
;out a16 = quotient
;out x8 = remainder
	php
	rep #$20
	sep #$10
	sta $4204 ;and 4205
	stx $4206
	nop
	nop
	nop
	nop
	
	nop ;division is a longer wait
	nop ;to do the calculation
	nop
	nop
	lda $4214 ;and 4215
	ldx $4216
	plp
	rtl	

	
	
set_main_screen:
.a8
;a8 = which layers are on main screen
	sta r212c
	rtl
	
	
	
set_sub_screen:
.a8
;a8 = which layers are on sub screen
	sta r212d
	rtl	

	



	
	

	