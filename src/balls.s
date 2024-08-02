.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import cancel_fades
.import zero_entire_palette_and_target

.import graceful_fail

.import galois16o

.import target_palette

BALLTABLE1_BANK = $30
BALLTABLE2_BANK = $20 ; $20 as a base is baked into pre-gen data in BALLTABLE1 by python code

.macpack longbranch

; ball palette = 0
; ground (tiles) palette = 1
; shadow (bitmap) palette = 2

GROUND_TILE_BASE = $1E000
GROUND_TILE_MAP = $1E800
BALL_SPRITE_BASE = $1F000

WIND_START_FRAMES = 1680
MAIN_ROTATE_FRAMES = 1700

.include "x16.inc"
.include "macros.inc"

.segment "BALLS_ZP": zeropage
frame_nr:
	.res 2
cur_ball:
	.res 1
theta_frac:
	.res 1
theta_add:
	.res 1
ptr1:
	.res 2
MADDRM:
	.res 1
speen:
	.res 2
fading:
	.res 1

.segment "BALLS_BSS"
ball_xl:
	.res 128
ball_xh:
	.res 128
ball_y:
	.res 128
ball_yfrac:
	.res 128
ball_yint:
	.res 128
ball_yshadow:
	.res 128
ball_theta:
	.res 128
ball_magnitude: ; $A0 = 0, $BF = 31
	.res 128
ball_momentum_frac:
	.res 128
ball_momentum:
	.res 128
ball_gravity:
	.res 128

.segment "BALLS"
entry:
	jsr setup_vera
	jsr setup_balls

	; fade into scene

	ldx #96
:	lda palettes-1,x
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	LOADFILE "BALLTABLE1.DAT", BALLTABLE1_BANK, $A000
	LOADFILE "BALLTABLE2.DAT", BALLTABLE2_BANK, $A000

testloop:
	jsr update_physics
	jsr apply_palette_fade_step
	WAITVSYNC
	jsr flush_palette
	jsr update_sprites
	jsr flip_and_clear

	inc frame_nr
	bne :+
	inc frame_nr+1
:	jsr global_rotate

	jsr update_shadows

	lda syncval
	cmp #$9c
	bcs check_start_fade

after_fade:
	lda frame_nr+1
	cmp #>WIND_START_FRAMES
	bcc main_choreo
	bcs wind_choreo
	lda frame_nr
	cmp #<WIND_START_FRAMES
	bcc main_choreo
wind_choreo:
	lda frame_nr
	and #$01
	bne testloop

	lda cur_ball
	and #$7f
	tax
	jsr galois16o
	sta ball_yint,x
	jsr galois16o
	sta ball_theta,x
	jsr galois16o
	and #$0f
	ora #$b0
	sta ball_magnitude,x
	jsr galois16o
	sta ball_momentum_frac,x
	eor #$80
	asl
	lda #0
	sbc #0
	sta ball_momentum,x
	stz ball_gravity,x
	inc cur_ball
	jmp testloop
check_start_fade:
	lda fading
	beq start_fade
	cmp #16
	bcs get_out
	inc fading
	jmp after_fade
start_fade:
	ldx #128
:   lda #$0f
	sta target_palette-1,x
	dex
	lda #$ff
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade
	inc fading
	jmp after_fade
main_choreo:

	lda frame_nr
	and #$07
	jne testloop

	lda cur_ball
	and #$7f
	tax
	lda #10
	sta ball_gravity,x
	lda frame_nr+1
	and #$1f
	ora #$a0
	sta ball_magnitude,x
	txa
	asl
	asl
	sta ball_theta,x
	txa
	lda #0
	sta ball_yint,x
	inc cur_ball

	jmp testloop

get_out:
	DISABLE_SPRITES
	rts

.proc update_shadows
	lda #(2 << 1)
	; put FX into 4 bit mode
	sta Vera::Reg::Ctrl
	lda #$04
	sta Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	ldy #0
loop:
	lda ball_yint,y
	beq next
	lda ball_yshadow,y
	tax
	lda ball_xh,y
	lsr
	lda ball_xl,y
	ror
	php
	adc addrl_per_row_4bit,x
	sta Vera::Reg::AddrL
	lda MADDRM
	adc addrm_per_row_4bit,x
	sta Vera::Reg::AddrM
	plp
	lda #1 ; nibble increment
	rol
	asl
	eor #$02
	sta Vera::Reg::AddrH

	lda #$66
	sta Vera::Reg::Data0
	sta Vera::Reg::Data0
	sta Vera::Reg::Data0
next:
	iny
	bpl loop

	lda #(2 << 1)
	; Clear FX 4 bit mode
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc flip_and_clear
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #$40
	sta Vera::Reg::FXCtrl

	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c
	stz Vera::Reg::Ctrl

	; double buffer flip

	; flip it
	lda MADDRM
	eor #$80
	sta MADDRM

	stz Vera::Reg::AddrL
	ora #$40
	sta Vera::Reg::AddrM

	lda #$30
	sta Vera::Reg::AddrH

	; repoint L1 bitmap
	lda Vera::Reg::L1TileBase
	eor #$40
	sta Vera::Reg::L1TileBase

	; double buffer flip complete

	; clear draw buffer

	ldy #2 ; 16kB (bottom half)
	ldx #0  ; 8kB per loop (256 * 32 w/ cache)
clearloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne clearloop
	dey
	bne clearloop

	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts


.endproc

.proc global_rotate
	; if frame_nr < MAIN_ROTATE_FRAMES
	lda frame_nr+1
	cmp #>MAIN_ROTATE_FRAMES
	bcc main_rotate
	bcs final_rotate
	lda frame_nr
	cmp #<MAIN_ROTATE_FRAMES
	bcs final_rotate
main_rotate:
	lda frame_nr+1
	lsr
	lda frame_nr
	bcc after_invert
	eor #$ff
after_invert:
	tax
	lda sin_half_range,x
	sta theta_add
	rts
final_rotate:
	; float, cancel gravity
	ldx #127
:	stz ball_gravity,x
	dex
	bpl :-
	inc speen
	bne :+
	inc speen+1
:	lda speen
	clc
	adc theta_frac
	sta theta_frac
	lda speen+1
	adc theta_add
	sta theta_add
	rts
.endproc

.proc update_physics
	ldx #0
loop:
	lda ball_gravity,x
	clc
	adc ball_momentum_frac,x
	sta ball_momentum_frac,x
	bcc :+
	inc ball_momentum,x
	clc
:	lda ball_momentum_frac,x
	adc ball_yfrac,x
	sta ball_yfrac,x
	lda ball_momentum,x
	bmi up
	adc ball_yint,x
	bcc after_bounce
	; bounce
	; negate momentum, with energy loss
	lda #80
	sec
	sbc ball_momentum_frac,x
	sta ball_momentum_frac,x
	lda #0
	sbc ball_momentum,x
	sta ball_momentum,x
	lda #$ff
after_bounce:
	sta ball_yint,x

	lda ball_theta,x
	clc
	adc theta_add
	sta ptr1
	lda ball_magnitude,x
	sta ptr1+1
	lda #BALLTABLE1_BANK ; x lsb translation
	sta X16::Reg::RAMBank
	lda (ptr1)
	sta ball_xl,x
	inc X16::Reg::RAMBank ; x msb translation
	lda (ptr1)
	sta ball_xh,x
	inc X16::Reg::RAMBank ; y shadow
	lda (ptr1)
	sta ball_yshadow,x
	inc X16::Reg::RAMBank ; page of y offset table
	lda (ptr1)
	sta PTR2+1
	inc X16::Reg::RAMBank ; bank of y offset table
	lda (ptr1)
	sta X16::Reg::RAMBank
	ldy ball_yint,x
	lda $ff00,y
PTR2 = * - 2
	sta ball_y,x
	inx
	bpl loop
	rts
up:
	adc ball_yint,x
	bcs after_bounce
ceil_bounce:
	; bounced off ceiling (huh?)
	stz ball_momentum_frac,x
	stz ball_momentum,x
	lda #0
	jmp after_bounce
.endproc

.proc update_sprites
	VERA_SET_ADDR Vera::VRAM_sprattr, 1
	ldx #0
loop1:
	lda ball_theta,x
	clc
	adc theta_add
	bpl next1
	lda #<((BALL_SPRITE_BASE) >> 5)
	sta Vera::Reg::Data0 ; sprite addr low
	lda Vera::Reg::Data0 ; skip over sprite addr high
	lda ball_xl,x
	sta Vera::Reg::Data0 ; x lsb
	lda ball_xh,x
	sta Vera::Reg::Data0 ; x msb
	lda ball_y,x
	sta Vera::Reg::Data0 ; y lsb
	stz Vera::Reg::Data0 ; y msb (always 0)
	lda Vera::Reg::Data0 ; skip flip
	lda Vera::Reg::Data0 ; skip palette
next1:
	inx
	bpl loop1
loop2:
	lda ball_theta-128,x
	clc
	adc theta_add
	bmi next2
	cmp #32
	bcc mid
	cmp #96
	bcs mid
back:
	lda #<((BALL_SPRITE_BASE + 64) >> 5)
	jmp sal
mid:
	lda #<((BALL_SPRITE_BASE + 32) >> 5)
sal:
	sta Vera::Reg::Data0 ; sprite addr low
	lda Vera::Reg::Data0 ; skip over sprite addr high
	lda ball_xl-128,x
	sta Vera::Reg::Data0 ; x lsb
	lda ball_xh-128,x
	sta Vera::Reg::Data0 ; x msb
	lda ball_y-128,x
	sta Vera::Reg::Data0 ; y lsb
	stz Vera::Reg::Data0 ; y msb (always 0)
	lda Vera::Reg::Data0 ; skip flip
	lda Vera::Reg::Data0 ; skip palette
next2:
	inx
	bne loop2
	rts
.endproc

.proc setup_balls
	ldx #127
	lda #$A0
:	stz ball_gravity,x
	stz ball_yint,x
	stz ball_yfrac,x
	stz ball_momentum,x
	stz ball_momentum_frac,x
	sta ball_magnitude,x
	dex
	bpl :-

	stz speen
	stz speen+1
	stz theta_frac

	stz fading

	stz frame_nr
	stz frame_nr+1
	stz cur_ball
	rts
.endproc

.proc setup_vera
	; set full palette to black
	jsr zero_entire_palette_and_target
	jsr cancel_fades

	; set sprite positions and attributes
	VERA_SET_ADDR (Vera::VRAM_sprattr), 1

	ldx #128
:	lda #<(BALL_SPRITE_BASE >> 5)
	sta Vera::Reg::Data0 ; Addr 12:5
	lda #>(BALL_SPRITE_BASE >> 5) & $0f; 4 bpp
	sta Vera::Reg::Data0 ; Addr 16:13
	stz Vera::Reg::Data0 ; X 7:0
	stz Vera::Reg::Data0 ; X 9:8
	lda #$ff
	sta Vera::Reg::Data0 ; Y 7:0
	stz Vera::Reg::Data0 ; Y 9:8
	lda #$0c
	sta Vera::Reg::Data0 ; mask/prio/flip
	stz Vera::Reg::Data0 ; palette offset, 8x8 sprite
	dex
	bne :-

	; set up the ball sprite
	VERA_SET_ADDR BALL_SPRITE_BASE, 1
	ldx #0
:	lda ballsprite,x
	sta Vera::Reg::Data0
	inx
	cpx #96
	bcc :-

	; set up the fadey tiles
	; we need 6 rows of 16x16 tiles or 96 pixels
	; 16x16 tiles to maximize the sprite budget
	; (has a minor effect)
	VERA_SET_ADDR GROUND_TILE_BASE, 1

	ldx #9
tile_color:
	lda background_tile_byte_count-1,x
	tay
	lda background_tile_color-1,x
tile_byte:
	sta Vera::Reg::Data0
	dey
	bne tile_byte
	dex
	bne tile_color


	; set up the tile map itself
	VERA_SET_ADDR GROUND_TILE_MAP, 1

	ldx #192
	lda #$10
:	stz Vera::Reg::Data0
	sta Vera::Reg::Data0
	dex
	bne :-

	ldy #1
tile_row:
	ldx #32
tile_loop:
	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	dex
	bne tile_loop
	iny
	cpy #9
	bcc tile_row

	; set VERA layers up
	; show layer 0, 1, and sprites
	stz Vera::Reg::Ctrl
	lda #$70
	tsb Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; 2:1 scale
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; L0 tile mode, 4bpp, 32x32 map
	lda #%00000010
	sta Vera::Reg::L0Config

	; L0 tile base, 16x16
	lda #((GROUND_TILE_BASE >> 11) << 2) | $03
	sta Vera::Reg::L0TileBase

	; L0 map base
	lda #(GROUND_TILE_MAP >> 9)
	sta Vera::Reg::L0MapBase

	; L0 scroll
	stz Vera::Reg::L0HScrollL
	stz Vera::Reg::L0HScrollH
	stz Vera::Reg::L0VScrollL
	stz Vera::Reg::L0VScrollH

	; L1 bitmap mode, 4bpp
	lda #%00000110
	sta Vera::Reg::L1Config

	; current L1 draw addr is flipped from active one
	lda #$80
	sta MADDRM

	; L1 bitmap base, 320x240
	stz Vera::Reg::L1TileBase

	; L1 bitmap palette offset
	lda #2
	sta Vera::Reg::L1HScrollH	

	rts
.endproc


ballsprite:
	.byte $01,$10,$00,$00
	.byte $12,$21,$00,$00
	.byte $12,$21,$00,$00
	.byte $01,$10,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00

ballsprite2:
	.byte $05,$50,$00,$00
	.byte $56,$65,$00,$00
	.byte $56,$65,$00,$00
	.byte $05,$50,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00

ballsprite3:
	.byte $03,$30,$00,$00
	.byte $34,$43,$00,$00
	.byte $03,$30,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00

palettes:
	.word $0000,$0466,$0699,$0344,$0455,$0355,$0577,$0f00,$0f00,$0f00,$0f00,$0f00,$0f00,$0f00,$0f00,$0f00
	.word $0000,$0111,$0222,$0333,$0444,$0555,$0666,$0777,$0888,$0999,$0aaa,$0bbb,$0ccc,$0ddd,$0eee,$0fff
	.word $0000,$0000,$0111,$0222,$0333,$0444,$0555,$0666,$0777,$0888,$0999,$0aaa,$0bbb,$0ccc,$0ddd,$0eee

sin_half_range:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01
	.byte $01,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$05,$05
	.byte $05,$05,$06,$06,$06,$07,$07,$08,$08,$08,$09,$09,$0a,$0a,$0a,$0b
	.byte $0b,$0c,$0c,$0d,$0d,$0e,$0e,$0f,$0f,$10,$10,$11,$11,$12,$12,$13
	.byte $13,$14,$14,$15,$16,$16,$17,$17,$18,$19,$19,$1a,$1b,$1b,$1c,$1c
	.byte $1d,$1e,$1e,$1f,$20,$20,$21,$22,$23,$23,$24,$25,$25,$26,$27,$28
	.byte $28,$29,$2a,$2a,$2b,$2c,$2d,$2d,$2e,$2f,$30,$30,$31,$32,$33,$34
	.byte $34,$35,$36,$37,$37,$38,$39,$3a,$3b,$3b,$3c,$3d,$3e,$3e,$3f,$40
	.byte $41,$42,$42,$43,$44,$45,$45,$46,$47,$48,$49,$49,$4a,$4b,$4c,$4c
	.byte $4d,$4e,$4f,$50,$50,$51,$52,$53,$53,$54,$55,$56,$56,$57,$58,$58
	.byte $59,$5a,$5b,$5b,$5c,$5d,$5d,$5e,$5f,$60,$60,$61,$62,$62,$63,$64
	.byte $64,$65,$65,$66,$67,$67,$68,$69,$69,$6a,$6a,$6b,$6c,$6c,$6d,$6d
	.byte $6e,$6e,$6f,$6f,$70,$70,$71,$71,$72,$72,$73,$73,$74,$74,$75,$75
	.byte $76,$76,$76,$77,$77,$78,$78,$78,$79,$79,$7a,$7a,$7a,$7b,$7b,$7b
	.byte $7b,$7c,$7c,$7c,$7d,$7d,$7d,$7d,$7d,$7e,$7e,$7e,$7e,$7e,$7f,$7f
	.byte $7f,$7f,$7f,$7f,$7f,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80


; these are read in reverse
background_tile_color:
	.byte $88,$77,$66,$55,$44,$33,$22,$11,$00
background_tile_byte_count:
	.byte <256,<256,128,96,64,48,32,16,128
