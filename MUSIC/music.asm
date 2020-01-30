;music code for snesgss
;written by Shiru
;modified to work with ca65 by Doug Fraker
;streaming audio has been removed and
;the spc code has been patched to fix a bug
;now called snesgssP.exe (p for patch)

.p816
.smart

.global spc_init, spc_load_data, spc_play_song, spc_command_asm
.global spc_stereo, spc_global_volume, spc_channel_volume, music_stop
.global music_pause, sound_stop_all, sfx_play, sfx_play_center
.global sfx_play_left, sfx_play_right

;notes
;cmdStereo, param 8 bit, 0 or 1
;cmdGlobalVolume, param L = vol 0-127, H = change speed
;cmdChannelVolume, param L = vol 0-127, H = which channel (bit field)*
;cmdMusicPlay, no param
;cmdStopAllSounds, no param
;cmdMusicStop, no param
;cmdMusicPause, param 8 bit, 0 or 1
;cmdSfxPlay, 3 params, vol, sfx #, pan
;cmdLoad, params, apu address, size, src address
;stream, removed.

;*bitfield for channel volume, if channel volume command will set
; a max volume for a specific channel
;0000 0001 channel 1
;0000 0010 channel 2
;0000 0100 channel 3
;0000 1000 channel 4
;0001 0000 channel 5
;0010 0000 channel 6
;0100 0000 channel 7
;1000 0000 channel 8


.define FULL_VOL   127
.define PAN_CENTER 128
.define PAN_LEFT   0
.define PAN_RIGHT  255


.define APU0				$2140
.define APU1				$2141
.define APU01				$2140
.define APU2				$2142
.define APU3				$2143
.define APU23				$2142

;to send a command
;although 8 bit values, A should be 16 bit when you
;lda #SCMD_INITIALIZE
.define SCMD_NONE				$00
.define SCMD_INITIALIZE			$01
.define SCMD_LOAD				$02
.define SCMD_STEREO				$03
.define SCMD_GLOBAL_VOLUME		$04
.define SCMD_CHANNEL_VOLUME		$05
.define SCMD_MUSIC_PLAY 		$06
.define SCMD_MUSIC_STOP 		$07
.define SCMD_MUSIC_PAUSE 		$08
.define SCMD_SFX_PLAY			$09
.define SCMD_STOP_ALL_SOUNDS	$0a
;.define SCMD_STREAM_START		$0b
;.define SCMD_STREAM_STOP		$0c
;.define SCMD_STREAM_SEND		$0d

.segment "ZEROPAGE"

spc_temp:			.res 2
gss_param:			.res 2
gss_command:		.res 2
save_stack:			.res 2
spc_pointer:		.res 4
spc_music_load_adr:	.res 2

.globalzp save_stack

.segment "CODE"


;notes:
; code loads to $200
; stereo, 0 is off (mono), 1 is on;
; volume 127 = max
; pan 128 = center
; music_1.bin is song 1
; and spc700.bin is the code and brr samples
; sounds.h and sounds.asm are only useful in that
; they tell you the number value of each song
; and sfx. they are meant for tools other than ca65



;nmi should be disabled
;lda # address of spc700.bin
;ldx # bank of spc700.bin
;jsl spc_init

spc_init:

;note, first 2 bytes of bin are size
;increment the data address by 2

	php
	AXY16
	sta spc_pointer ;address of music code
	stx spc_pointer+2 ;bank of music code
	
	tsx
	stx save_stack
	ldy #14 ;bytes 14-15 is the address to load the song
	lda [spc_pointer], y ;address to load the song
	sta spc_music_load_adr ;save for later
	
	lda spc_pointer+2 ;bank of music code
	pha
	lda spc_pointer ;address of music code
	inc a
	inc a ;actual code is address +2
	pha
	lda [spc_pointer] ;1st 2 bytes are the size
	pha
	lda #$0200 ;address in apu
	pha
	jsl spc_load_data
	ldx save_stack
	txs ;8
	
	lda #SCMD_INITIALIZE
	sta gss_command
	stz gss_param
	jsl spc_command_asm
	
	;default is mono
;	lda #$0001 ;stereo on
;	jsl spc_stereo
	
	plp
	rtl


;stack relative
;5 = addr in apu, last pha
;7 = size
;9 = src l
;11 = src h

spc_load_data:

	php
	AXY16
	
	sei
; make sure no irq's fire during this transfer

	A8
	lda #$aa
@1:
	cmp APU0
	bne @1

	A16
	lda 11,s				;src h
	sta spc_pointer+2
	lda 9,s					;src l
	sta spc_pointer+0
	lda 7,s					;size
	tax
	lda 5,s					;adr
	sta APU23
	
	A8
	lda #$01
	sta APU1
	lda #$cc
	sta APU0
	
@2:
	cmp APU0
	bne @2
	
	ldy #0
	
@load_loop:

	xba
	lda [spc_pointer],y
	xba
	tya
	
	A16
	sta APU01
	A8
	
@3:
	cmp APU0
	bne @3
	
	iny
	dex
	bne @load_loop
	
	xba
    lda #$00
    xba
	clc
	adc #$02
	A16
	tax
	
	lda #$0200			;loaded code starting address
	sta APU23

	txa
	sta APU01
	A8
	
@4:
	cmp APU0
	bne @4
	
	A16
@5:
	lda APU0			;wait until SPC700 clears all communication ports, confirming that code has started
	ora APU2
	bne @5
	
;	cli					;enable IRQ
;this is covered with the plp
	plp
	rtl



	
;nmi should be disabled
;lda # address of song
;ldx # bank of song
;jsl spc_play_song

;1st 2 bytes of song are size, then song+2 is address of song data

spc_play_song:

	php
	AXY16
	sta spc_pointer
	stx spc_pointer+2
	
	jsl music_stop
	
	lda #SCMD_LOAD
	sta gss_command
	stz gss_param
	jsl spc_command_asm
	
	AXY16
	tsx
	stx save_stack
	lda spc_pointer+2;#^music_code ; bank
	pha
	lda spc_pointer;#.loword(music_code)
	inc a
	inc a ;actual data at data+2
	pha
	lda [spc_pointer] ;first 2 bytes of data are size
	pha
;saved at init	
	lda spc_music_load_adr ;address in apu
	pha
	jsl spc_load_data
	ldx save_stack
	txs ;8

	stz gss_param ;zero
	lda #SCMD_MUSIC_PLAY
	sta gss_command
	jsl spc_command_asm
	plp
	rtl

	
	
;send a command to the SPC driver	
;example a16
;lda #command
;sta gss_command
;lda #parameter
;sta gss_param
;jsl spc_command_asm

spc_command_asm:

	php
	A8
@1:
	lda APU0
	bne @1

	A16
	lda gss_param
	sta APU23
	lda gss_command
	A8
	xba
	sta APU1
	xba
	sta APU0

	cmp #SCMD_LOAD	;don't wait acknowledge
	beq @3

@2:
	lda APU0
	beq @2

@3:
	plp
	rtl

	

;void spc_stereo(unsigned int stereo);
;example a16
;lda #0 (mono) or 1 (stereo)
;jsl spc_stereo

spc_stereo:

	php
	AXY16
	and #$00ff
	sta gss_param
	
	lda #SCMD_STEREO
	sta gss_command
	
	jsl spc_command_asm

	plp
	rtl
	
	
	
;void spc_global_volume(unsigned int volume,unsigned int speed);
;example axy16
;lda #speed
;ldx #volume
;jsl spc_global_volume

spc_global_volume:

	php
	AXY16	
	xba
	and #$ff00
	sta gss_param
	txa
	and #$00ff
	ora gss_param
	sta gss_param
	
	lda #SCMD_GLOBAL_VOLUME
	sta gss_command
	
	jsl spc_command_asm

	plp
	rtl
	
	
	
;void spc_channel_volume(unsigned int channels,unsigned int volume);
;example axy16
;lda #channels 0-7
;ldx #volume   0-127
;jsl spc_channel_volume

spc_channel_volume:

	php
	AXY16
	xba
	and #$ff00
	sta gss_param
	txa
	and #$00ff
	ora gss_param
	sta gss_param
	
	lda #SCMD_CHANNEL_VOLUME
	sta gss_command
	
	jsl spc_command_asm

	plp
	rtl
	
	
	
;void music_stop(void);
;jsl music_stop

music_stop:

	php
	AXY16
	
	lda #SCMD_MUSIC_STOP
	sta gss_command
	stz gss_param
	
	jsl spc_command_asm
	
	plp
	rtl
	

	
;void music_pause(unsigned int pause);
;example a16
;lda #0 (unpause) or 1 (pause)
;jsl music_pause

music_pause:

	php
	AXY16
	and #$00ff
	sta gss_param
	
	lda #SCMD_MUSIC_PAUSE
	sta gss_command
	
	jsl spc_command_asm
	
	plp
	rtl
	
	
	
;void sound_stop_all(void);
;jsl sound_stop_all

sound_stop_all:

	php
	AXY16
	
	lda #SCMD_STOP_ALL_SOUNDS
	sta gss_command
	stz gss_param
	
	jsl spc_command_asm
	
	plp
	rtl
	
	
	
	
sfx_play_center:
;axy 8 bit
;in a= sfx #
;	x= volume 0-127
;	y= sfx channel, needs to be > than max song channel
;assumes you want pan center

	php
	AXY8
	sta spc_temp
	stx spc_temp+1
	
	AXY16
	tsx
	stx save_stack
	
	lda #128 ;pan center
	pha
sfx_play_common:
	lda spc_temp+1 ;volume 0-127
	and #$00ff
	pha
	lda spc_temp ;sfx #
	and #$00ff
	pha
	tya ;channel, needs to be > the song channels
	and #$0007
	pha
	jsl sfx_play
	ldx save_stack
	txs
	plp
	rtl

	
	
sfx_play_left:
;axy 8 bit
;in a= sfx #
;	x= volume 0-127
;	y= sfx channel, needs to be > than max song channel
;assumes you want pan left

	php
	AXY8
	sta spc_temp
	stx spc_temp+1
	
	AXY16
	tsx
	stx save_stack
	
	lda #0 ;pan left
	pha
	jmp	sfx_play_common
	

	
sfx_play_right:
;axy 8 bit
;in a= sfx #
;	x= volume 0-127
;	y= sfx channel, needs to be > than max song channel
;assumes you want pan right

	php
	AXY8
	sta spc_temp
	stx spc_temp+1
	
	AXY16
	tsx
	stx save_stack
	
	lda #255 ;pan right
	pha
	jmp	sfx_play_common	



	
;void sfx_play(unsigned int chn,unsigned int sfx,unsigned int vol,int pan);
;stack relative
;5 = chn last in
;7 = volume
;9 = sfx
;11 = pan
;NOTE - use the other functions above

sfx_play:

	php
	AXY16

	lda 11,s			;pan
	bpl @1
	lda #0
@1:
	cmp #255
	bcc @2
	lda #255
@2:

	xba
	and #$ff00
	sta gss_param
	
	lda 7,s				;sfx number
	and #$00ff
	ora gss_param
	sta gss_param

	lda 9,s				;volume
	xba
	and #$ff00
	sta gss_command

	lda 5,s				;chn
	asl a
	asl a
	asl a
	asl a
	and #$00f0
	ora #SCMD_SFX_PLAY
	ora gss_command
	sta gss_command

	jsl spc_command_asm

	plp
	rtl
	






;void spc_stream_update(void);

spc_stream_update:

; couldn't find any examples of this
; just cut it.





