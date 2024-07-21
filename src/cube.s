.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette
.import graceful_fail


.macpack longbranch

CUBE_CHOREO_BANK = $20

CUBE_MAPBASE = $1E000
CUBE_TILEBASE = $18000

.include "x16.inc"
.include "macros.inc"

.segment "CUBE_ZP": zeropage
ptr1:
	.res 2
which_fbuf:
	.res 1
linewise_y_frac:
	.res 1
linewise_y_int:
	.res 1
linewise_x_frac:
	.res 1
linewise_x_int:
	.res 1
left_slope_frac:
	.res 1
left_slope_int:
	.res 1
line_xpos_frac:
	.res 1
line_xpos_int:
	.res 1
line_ypos:
	.res 1
length_frac:
	.res 1
length_int:
	.res 1
length_increment_frac:
	.res 1
length_increment_int:
	.res 1
line_count:
	.res 1
top_y_buf0:
	.res 1
bottom_y_buf0:
	.res 1
top_y_buf1:
	.res 1
bottom_y_buf1:
	.res 1
affine_y_pos_frac:
	.res 1
affine_y_pos_int:
	.res 1
affine_x_pos_frac:
	.res 1
affine_x_pos_int:
	.res 1
step:
	.res 2

.segment "CUBE"
entry:
	jsr setup_initial_vera_state
	jsr wipe_first_64k_vram
	jsr setup_fx_tile_map

	LOADFILE "CUBETILES.DAT", 0, .loword(CUBE_TILEBASE), <(.hiword(CUBE_TILEBASE))
	LOADFILE "CUBETILES.PAL", 0, $FA00, 1 ; direct to palette
	LOADFILE "CUBECHOREO.DAT", CUBE_CHOREO_BANK, $A000 ; choreography

	jsr do_cube

	MUSIC_SYNC $8C

	ldx #32
:   stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	rts

.proc do_cube
	; set initial state
	lda #<$a000
	sta ptr1
	lda #>$a000
	sta ptr1+1

	lda #CUBE_CHOREO_BANK
	sta X16::Reg::RAMBank
	stz which_fbuf

	stz step
	stz step+1
start_frame:
	; we are at frame start
	lda step
	sta $9fb9
	lda step+1
	sta $9fba
start_face:
	; set up tile base

	; set DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	INCPTR1
	lda (ptr1) ; face type
	jmi end_frame
	cmp #3
	bcc :+
	stp
:
	asl
	asl
	asl
	asl
	adc #((CUBE_TILEBASE >> 11) << 2) ; affine clip disabled
	sta Vera::Reg::FXTileBase

	; set FX params
;	lda #%01100011 ; cache fill+write, affine mode
	lda #%00000011 ; affine mode
	sta Vera::Reg::FXCtrl

	; set initial location of Addr0
	INCPTR1
	lda (ptr1) ; Y coordinate
	sta line_ypos

	INCPTR1
	lda (ptr1) ; X coordinate
	sta line_xpos_int
	lda #$80
	sta line_xpos_frac

	; set DCSEL=3
	lda #(3 << 1)
	sta Vera::Reg::Ctrl

	INCPTR1
	lda (ptr1) ; Y global increment
	sta Vera::Reg::FXYIncrL
	INCPTR1
	lda (ptr1)
	sta Vera::Reg::FXYIncrH
	INCPTR1
	lda (ptr1) ; X global increment
	sta Vera::Reg::FXXIncrL
	INCPTR1
	lda (ptr1)
	sta Vera::Reg::FXXIncrH

	; set DCSEL=5
	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	INCPTR1
	lda (ptr1) ; Y affine pos frac
	sta Vera::Reg::FXYPosS
	sta affine_y_pos_frac
	INCPTR1
	lda (ptr1) ; X affine pos frac
	sta Vera::Reg::FXXPosS
	sta affine_x_pos_frac

	; set DCSEL=4
	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	INCPTR1
	lda (ptr1) ; Y affine pos whole
	sta Vera::Reg::FXYPosL
	sta affine_y_pos_int
	INCPTR1
	lda (ptr1) ; X affine pos whole
	sta Vera::Reg::FXXPosL
	sta affine_x_pos_int
	stz Vera::Reg::FXYPosH
	stz Vera::Reg::FXXPosH

	; finished setting up face parameters
	stz Vera::Reg::Ctrl
start_section:
	INCPTR1
	lda (ptr1) ; high bit is set if there are no more sections of this poly
	jmi start_face

	INCPTR1
	lda (ptr1)
	sta linewise_y_frac

	INCPTR1
	lda (ptr1)
	sta linewise_y_int

	INCPTR1
	lda (ptr1)
	sta linewise_x_frac

	INCPTR1
	lda (ptr1)
	sta linewise_x_int

	INCPTR1
	lda (ptr1)
	sta left_slope_frac

	INCPTR1
	lda (ptr1)
	sta left_slope_int

	INCPTR1
	lda (ptr1)
	sta length_increment_frac

	INCPTR1
	lda (ptr1)
	sta length_increment_int

	INCPTR1
	lda (ptr1)
	sta line_count

	INCPTR1
	lda (ptr1)
	sta length_frac

	INCPTR1
	lda (ptr1)
	sta length_int

start_line:
	; set Data0 position
	lda line_xpos_int
	ldx line_ypos
	clc
	adc addrl_per_row_8bit,x
	sta Vera::Reg::AddrL
	lda addrm_per_row_8bit,x
	adc which_fbuf
	sta Vera::Reg::AddrM
	lda #$10
	sta Vera::Reg::AddrH

	ldx length_int
	beq end_line
	bmi end_line
:	lda Vera::Reg::Data1
	sta Vera::Reg::Data0
	dex
	bne :-
end_line:
	lda length_increment_frac
	clc
	adc length_frac
	sta length_frac
	lda length_increment_int
	adc length_int
	sta length_int

	inc line_ypos

	lda line_xpos_frac
	clc
	adc left_slope_frac
	sta line_xpos_frac
	lda line_xpos_int
	adc left_slope_int
	sta line_xpos_int

	lda #(5 << 1)
	sta Vera::Reg::Ctrl
	lda linewise_x_frac
	clc
	adc affine_x_pos_frac
	sta affine_x_pos_frac
	sta Vera::Reg::FXXPosS
	lda linewise_x_int
	adc affine_x_pos_int
	sta affine_x_pos_int
	tax

	lda linewise_y_frac
	clc
	adc affine_y_pos_frac
	sta affine_y_pos_frac
	sta Vera::Reg::FXYPosS
	lda linewise_y_int
	adc affine_y_pos_int
	sta affine_y_pos_int
	tax

	lda #(4 << 1)
	sta Vera::Reg::Ctrl
	sty Vera::Reg::FXYPosL
	stx Vera::Reg::FXXPosL

	dec line_count
	bne start_line
	jmp start_section
end_frame:
	lda which_fbuf
	bmi buf1
buf0:
	INCPTR1
	lda (ptr1) ; top row used
	sta top_y_buf0
	INCPTR1
	lda (ptr1) ; bottom row used
	sta bottom_y_buf0
	bra gowait
buf1:
	INCPTR1
	lda (ptr1) ; top row used
	sta top_y_buf1
	INCPTR1
	lda (ptr1) ; bottom row used
	sta bottom_y_buf1
gowait:
	WAITVSYNC
	; flip the buffer
	lda which_fbuf
	lsr
	sta Vera::Reg::L0TileBase

	lda which_fbuf
	eor #$80
	sta which_fbuf

	jsr clear_buffer

	lda syncval
	cmp #$8C
	bcs end
	inc step
	bne :+
	inc step+1
:	jmp start_frame
end:
	rts
.endproc


; lay out map in this pattern
; 0-15,0-15
; 16-31,16-31
; etc
; 4 times
.proc setup_fx_tile_map
	VERA_SET_ADDR CUBE_MAPBASE, 1
	jsr begin
	jsr begin
	jsr begin
begin:
	ldx #0
	ldy #16
	txa
loop1:
	sta Vera::Reg::Data0
	inc
	dey
	bne loop1
	ldy #16
	txa
loop2:
	sta Vera::Reg::Data0
	inc
	dey
	bne loop2
	ldy #16
	tax
	cpx #128
	bcc loop1
	rts
.endproc

.proc wipe_first_64k_vram
	VERA_SET_ADDR $00000, 3

	; set FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #%01000000
	sta Vera::Reg::FXCtrl

	; set FX cache contents
	lda #(6 << 1)               ; DCSEL=6
    sta Vera::Reg::Ctrl

	; Blank
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c

	stz Vera::Reg::Ctrl

	ldy #16
	ldx #0
blankloop:
.repeat 4
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne blankloop
	dey
	bne blankloop

	; clear FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl
	rts
.endproc

.proc clear_buffer
	lda #$30
	sta Vera::Reg::AddrH
	lda which_fbuf
	bmi buf1
buf0:
	ldx top_y_buf0
	clc
	adc addrm_per_row_8bit,x
	sta Vera::Reg::AddrM
	lda addrl_per_row_8bit,x
	sta Vera::Reg::AddrL
	lda bottom_y_buf0
	sec
	sbc top_y_buf0
	tay
	bra cont
buf1:
	ldx top_y_buf1
	clc
	adc addrm_per_row_8bit,x
	sta Vera::Reg::AddrM
	lda addrl_per_row_8bit,x
	sta Vera::Reg::AddrL
	lda bottom_y_buf1
	sec
	sbc top_y_buf1
	tay
cont:
	beq end

	; set FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #%01000000
	sta Vera::Reg::FXCtrl

	; set FX cache contents
	lda #(6 << 1)               ; DCSEL=6
    sta Vera::Reg::Ctrl

	; Blank
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c

	stz Vera::Reg::Ctrl
nextline:
	ldx #10
blankloop:
.repeat 4
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne blankloop
	lda Vera::Reg::AddrL
	clc
	adc #160
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
:	dey
	bne nextline
end:
	; clear FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl
	rts
.endproc


.proc setup_initial_vera_state
	; set up screen
	; set VERA layers up
	; show layer 0
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$10
	sta Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21 ; FIXME start offscreen
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; 4:1 scale
	lda #$20
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; bitmap mode, 8bpp
	lda #%00000111
	sta Vera::Reg::L0Config

	; bitmap base, 320x240
	stz Vera::Reg::L0TileBase

	; set up the VERA FX MAPBASE pointer
	; and other FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #((CUBE_MAPBASE >> 9) & $FC) | $02
	sta Vera::Reg::FXMapBase

	; mainly for reset of cache index
	stz Vera::Reg::FXMult
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc