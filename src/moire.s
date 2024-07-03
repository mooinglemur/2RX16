.import graceful_fail

.import setup_palette_fade
.import setup_palette_fade2
.import setup_palette_fade3
.import setup_palette_fade4
.import apply_palette_fade_step
.import apply_palette_fade_step2
.import apply_palette_fade_step3
.import apply_palette_fade_step4
.import flush_palette
.import flush_palette2
.import flush_palette3
.import flush_palette4

.import target_palette
.import target_palette2
.import target_palette3
.import target_palette4


.macpack longbranch

CHOREO_BANK = $20
TECHNO_MAPBASE = $10000
TECHNO_TILEBASE = $11000 ; (plus $1000 offset for each frame)

.include "x16.inc"
.include "macros.inc"

.segment "MOIRE_ZP": zeropage

sin_slope:
	.res 2
cos_slope:
	.res 2
aff_x:
	.res 3
aff_y:
	.res 3
ptr:
	.res 2
choreo_frames:
	.res 2
old_syncval:
	.res 1

.segment "MOIRE"
entry:
	; fade to white

	VERA_SET_ADDR (31+(Vera::VRAM_palette)), -1

	; set palette to white

	ldx #30
:   lda #$0f
	sta target_palette+1,x
	sta Vera::Reg::Data0
	dex
	lda #$ff
	sta target_palette+1,x
	sta Vera::Reg::Data0
	dex
	bne :-

	; set bitmap mode for layer 0
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	lda #0
	sta Vera::Reg::L0HScrollH ; palette offset

	; set up cache
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #$40
	sta Vera::Reg::FXCtrl

	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	lda #$11
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c
	stz Vera::Reg::Ctrl

	; write the whole buffer
	VERA_SET_ADDR $00000, 3

	ldy #4 ; 32kB
	ldx #0  ; 8kB per loop (256 * 32 w/ cache)
clearloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne clearloop
	dey
	bne clearloop

	; set up cache with wipe color
	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	lda #$22
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c

	; disable FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	LOADFILE "TECHNOCHOREO.DAT", CHOREO_BANK, $A000
	LOADFILE "TECHNOTILE1.DAT", 0, $2000, 1 ; $12000 VRAM
	LOADFILE "TECHNOTILE2.DAT", 0, $3000, 1 ; $13000 VRAM

	MUSIC_SYNC $41

	; do wipe 1
	lda #0
	jsr wipe

	MUSIC_SYNC $42

	; do wipe 2
	lda #80
	jsr wipe

	MUSIC_SYNC $43

	; do wipe 3
	lda #160
	jsr wipe

	MUSIC_SYNC $44

	; do wipe 4
	lda #240
	jsr wipe

	MUSIC_SYNC $45

	LOADFILE "TECHNOTILE7.DAT", 0, $8000, 1 ; $18000 VRAM
	jsr techno

	MUSIC_SYNC $4A

	jsr slide_off

	stz Vera::Reg::Ctrl
	; 2:1 scale
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	LOADFILE "PANICPIC.VBM", 0, $0000, 0 ; $00000 VRAM
	LOADFILE "PANICPIC.PAL", 0, target_palette

	VERA_SET_ADDR Vera::VRAM_palette, 1
	ldx #0
panicpal_set:
	lda target_palette,x
	sta Vera::Reg::Data0
	inx
	bne panicpal_set

	; set bitmap mode for layer 0
	lda #%00000111 ; 8bpp
	sta Vera::Reg::L0Config

	MUSIC_SYNC $4C

	jsr slide_on

	MUSIC_SYNC $4E

	WAITVSYNC

	; first frame of CRT-off effect
	; flash it to grey
	VERA_SET_ADDR Vera::VRAM_palette, 1
	lda #$bb
	sta Vera::Reg::Data0
	lda #$0b
	sta Vera::Reg::Data0
	; squish it
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda #71
	sta Vera::Reg::DCVStart
	lda #240-70
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl
	lda #$80
	sta Vera::Reg::DCVScale

	; set up fade to white (for non-background)
	ldx #0
creature_crt_fadeout:
	lda #$ff
	sta target_palette,x
	inx
	lda #$0f
	sta target_palette,x
	inx
	bne creature_crt_fadeout

	lda #2
	jsr setup_palette_fade
	lda #66
	jsr setup_palette_fade2

.repeat 4
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
.endrepeat

	WAITVSYNC
	; second frame, more squish, slightly whiter
	; background back to black
	VERA_SET_ADDR Vera::VRAM_palette, 1
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	jsr flush_palette
	jsr flush_palette2

	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda #96
	sta Vera::Reg::DCVStart
	lda #240-95
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl
	lda #$c0
	sta Vera::Reg::DCVScale

.repeat 3
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
.endrepeat

	WAITVSYNC
	; third frame, more squish, slightly whiter
	jsr flush_palette
	jsr flush_palette2

	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda #108
	sta Vera::Reg::DCVStart
	lda #240-108
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl
	lda #$e0
	sta Vera::Reg::DCVScale

.repeat 3
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
.endrepeat

	WAITVSYNC
	; fourth frame, more squish, slightly whiter
	jsr flush_palette
	jsr flush_palette2

	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda #114
	sta Vera::Reg::DCVStart
	lda #240-114
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl
	lda #$ff
	sta Vera::Reg::DCVScale

	WAITVSYNC
	; now do the CRT line thing
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda #120
	sta Vera::Reg::DCVStart
	lda #121
	sta Vera::Reg::DCVStop
	stz Vera::Reg::DCHStart
	lda #$a0
	sta Vera::Reg::DCHStop
	stz Vera::Reg::Ctrl
	lda #$80
	sta Vera::Reg::DCVScale
	lda #$20
	sta Vera::Reg::DCHScale

	VERA_SET_ADDR Vera::VRAM_palette, 1
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0

	lda #$ff
	sta Vera::Reg::Data0
	lda #$0f
	sta Vera::Reg::Data0

	lda #$44
	sta Vera::Reg::Data0
	lda #$04
	sta Vera::Reg::Data0

	jsr do_crt_line

	; fade dot out, in, out

	ldx #128
:	stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	lda #$ff
	sta target_palette+2
	sta target_palette+4
	lda #$0f
	sta target_palette+3
	sta target_palette+5

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	ldx #0
:	stz target_palette,x
	stz target_palette3,x
	inx
	bne :-

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	PALETTE_FADE_FULL 3

	MUSIC_SYNC $50

	; reset all letterboxing
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	stz Vera::Reg::DCHStart
	lda #$a0
	sta Vera::Reg::DCHStop
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	rts


.proc techno
	; initialize choreography
	stz choreo_frames
	stz choreo_frames+1

	stz old_syncval

	lda #CHOREO_BANK
	sta X16::Reg::RAMBank

	stz ptr
	lda #$a0
	sta ptr+1

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
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; 4:1 scale
	lda #$20
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; bitmap mode, 4bpp
	lda #%00000110
	sta Vera::Reg::L0Config

	; bitmap base, 320x240
	stz Vera::Reg::L0TileBase

	; set up the VERA FX MAPBASE pointer
	; and other FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #((TECHNO_MAPBASE >> 9) & $FC) | $02
	sta Vera::Reg::FXMapBase

	; mainly for reset of cache index
	stz Vera::Reg::FXMult

	stz Vera::Reg::Ctrl

	ldy #0
newframe:
	; load the starting point and angles for this frame
	jsr load_aff_parms

	; set up cache fill/write, 4 bit mode, and affine
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #%01100111
	sta Vera::Reg::FXCtrl

	; Set up FX TileBase, tile set changes every frame and loops every 8
	lda choreo_frames
	and #7
	asl
	asl
	asl
	adc #((TECHNO_TILEBASE >> 9) & $FC)
	sta Vera::Reg::FXTileBase

	; point data 0 to top of screen
	VERA_SET_ADDR $00000, 3 ; incr 4

	lda #(3 << 1)
	sta Vera::Reg::Ctrl

	; set up affine slope/direction
	; this will be constant throughout the entire frame
	lda cos_slope
	asl
	sta Vera::Reg::FXXIncrL
	lda cos_slope+1
	rol
	and #$7f
	sta Vera::Reg::FXXIncrH

	lda sin_slope
	asl
	sta Vera::Reg::FXYIncrL
	lda sin_slope+1
	rol
	and #$7f
	sta Vera::Reg::FXYIncrH

	phy
	WAITVSYNC
	ply

	ldx #100 ; row count
newline:
	; set pixel positions
	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	lda aff_x+1
	sta Vera::Reg::FXXPosL

	lda aff_x+2
	sta Vera::Reg::FXXPosH

	lda aff_y+1
	sta Vera::Reg::FXYPosL

	lda aff_y+2
	sta Vera::Reg::FXYPosH

	; set pixel subpositions
	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	lda aff_x
	sta Vera::Reg::FXXPosS

	lda aff_y
	sta Vera::Reg::FXYPosS

	; unrolled code to draw a row
.repeat 20
.repeat 8
	lda Vera::Reg::Data1
.endrepeat
	stz Vera::Reg::Data0
.endrepeat

	; we should still be addrsel = 0
	; advance to next bitmap line
	lda Vera::Reg::AddrL
	clc
	adc #80
	sta Vera::Reg::AddrL
	lda Vera::Reg::AddrM
	adc #0
	sta Vera::Reg::AddrM

	clc
	lda aff_y
	adc cos_slope
	sta aff_y
	lda aff_y+1
	adc cos_slope+1
	sta aff_y+1

	sec
	lda aff_x
	sbc sin_slope
	sta aff_x
	lda aff_x+1
	sbc sin_slope+1
	sta aff_x+1

	dex
	jne newline

	inc choreo_frames
	bne :+
	inc choreo_frames+1
:	lda choreo_frames+1
	cmp #(>2000)
	jcc newframe
	lda choreo_frames
	cmp #(<2000)
	jcc newframe

	; done with everything
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc load_aff_parms
	lda (ptr),y
	sta cos_slope
	iny
	lda (ptr),y
	sta cos_slope+1
	iny
	bne cnt1
	lda ptr+1
	inc
	cmp #$c0
	bcc :+
	sbc #$20
	inc X16::Reg::RAMBank
:	sta ptr+1
cnt1:
	lda (ptr),y
	sta sin_slope
	iny
	lda (ptr),y
	sta sin_slope+1
	iny
	bne cnt2
	lda ptr+1
	inc
	cmp #$c0
	bcc :+
	sbc #$20
	inc X16::Reg::RAMBank
:	sta ptr+1
cnt2:
	lda (ptr),y
	sta aff_x
	iny
	lda (ptr),y
	sta aff_x+1
	iny
	bne cnt3
	lda ptr+1
	inc
	cmp #$c0
	bcc :+
	sbc #$20
	inc X16::Reg::RAMBank
:	sta ptr+1
cnt3:
	lda (ptr),y
	sta aff_x+2
	iny
	lda (ptr),y
	sta aff_y
	iny
	bne cnt4
	lda ptr+1
	inc
	cmp #$c0
	bcc :+
	sbc #$20
	inc X16::Reg::RAMBank
:	sta ptr+1
cnt4:
	lda (ptr),y
	sta aff_y+1
	iny
	lda (ptr),y
	sta aff_y+2
	iny
	bne cnt5
	lda ptr+1
	inc
	cmp #$c0
	bcc :+
	sbc #$20
	inc X16::Reg::RAMBank
:	sta ptr+1
cnt5:
	rts
.endproc

.proc do_crt_line
	ldx #0
crt_line_loop:
	phx
	WAITVSYNC
	plx
	VERA_SET_ADDR $00000, 1
	jsr line1_4
	jsr line2_3
	jsr line2_3
	jsr line1_4

	inx
	cpx #42
	bcc crt_line_loop

	VERA_SET_ADDR $00000, 1
	ldx #4
dot:
	ldy #79
:	stz Vera::Reg::Data0
	dey
	bne :-

	lda #1
	sta Vera::Reg::Data0

	ldy #240
:	stz Vera::Reg::Data0
	dey
	bne :-

	dex
	bne dot

	rts
line1_4:
	lda white_indent,x
	tay
:	stz Vera::Reg::Data0
	dey
	bne :-
	lda #160
	sec
	sbc white_indent,x
	sbc white_indent,x
	tay
	lda #1
:	sta Vera::Reg::Data0
	dey
	bne :-
	lda white_indent,x
	tay
:	stz Vera::Reg::Data0
	dey
	bne :-

	ldy #160
:	stz Vera::Reg::Data0
	dey
	bne :-
	rts

line2_3:
	lda gray_indent,x
	tay
:	stz Vera::Reg::Data0
	dey
	bne :-
	lda white_indent,x
	sec
	sbc gray_indent,x
	beq white
	tay
	lda #2
:	sta Vera::Reg::Data0
	dey
	bne :-
white:
	lda #160
	sec
	sbc white_indent,x
	sbc white_indent,x
	tay
	lda #1
:	sta Vera::Reg::Data0
	dey
	bne :-
	lda white_indent,x
	sec
	sbc gray_indent,x
	beq black
	tay
	lda #2
:	sta Vera::Reg::Data0
	dey
	bne :-
black:
	lda gray_indent,x
	tay
:	stz Vera::Reg::Data0
	dey
	bne :-

	ldy #160
:	stz Vera::Reg::Data0
	dey
	bne :-
	rts

white_indent:
	.byte 9,9,9,9,9,9,10,12
	.byte 14,16,18,20,22,24,26,28
	.byte 30,32,34,36,38,40,42,44
	.byte 46,48,50,52,54,56,58,60
	.byte 62,64,66,68,70,72,74,76
	.byte 78,80
gray_indent:
	.byte 9,9,9,9,9,9,9,10
	.byte 12,14,16,18,20,22,24,26
	.byte 28,30,32,34,36,38,40,42
	.byte 44,46,48,50,52,54,56,58
	.byte 60,62,64,66,68,70,72,74
	.byte 76,78

.endproc

.proc slide_on
	ldx #0
slideloop:
	phx
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	WAITVSYNC
	jsr flush_palette
	jsr flush_palette2
	plx
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda slide_on_hstart,x
	sta Vera::Reg::DCHStart
	stz Vera::Reg::Ctrl
	inx
	cpx #32
	beq flash
	cpx #48
	bcc slideloop

	rts
flash:
	VERA_SET_ADDR Vera::VRAM_palette, 1
	ldy #128
flashloop:
	lda #$ff
	sta Vera::Reg::Data0
	lda #$0f
	sta Vera::Reg::Data0
	dey
	bne flashloop

	phx
	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	plx
	bra slideloop

slide_on_hstart:
	.byte $a0,$9c,$98,$93
	.byte $8f,$8b,$87,$82
	.byte $7e,$7a,$76,$71
	.byte $6d,$69,$65,$60
	.byte $5c,$58,$54,$4f
	.byte $4b,$47,$43,$3e
	.byte $3a,$36,$32,$2d
	.byte $29,$25,$21,$1c
	.byte $18,$14,$12,$14
	.byte $16,$17,$18,$17
	.byte $16,$14,$12,$13
	.byte $14,$15,$14,$14
.endproc

.proc slide_off
	ldx #0
slideloop:
	phx
	WAITVSYNC
	plx
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda slide_off_hstart,x
	sta Vera::Reg::DCHStart
	stz Vera::Reg::Ctrl
	inx
	cpx #35
	bcc slideloop

	rts

slide_off_hstart:
	.byte 0,1,2,3,4,5,6,8
	.byte 11,13,16,19,22,26,29,33
	.byte 38,42,47,52,58,63,69,75
	.byte 82,88,95,102,110,118,126,134
	.byte 142,151,160
.endproc


.proc wipe
	lsr
	sta xoff
	stz row

	; set target palette to white

	lda #$0f
	sta target_palette+3
	sta target_palette+5
	lda #$ff
	sta target_palette+2
	sta target_palette+4

	lda #0
	jsr setup_palette_fade

.repeat 4
	jsr apply_palette_fade_step
.endrepeat
	WAITVSYNC
	jsr flush_palette

.repeat 4
	jsr apply_palette_fade_step
.endrepeat
	WAITVSYNC
	jsr flush_palette

.repeat 4
	jsr apply_palette_fade_step
.endrepeat
	WAITVSYNC
	jsr flush_palette

.repeat 4
	jsr apply_palette_fade_step
.endrepeat
	WAITVSYNC
	jsr flush_palette

	; skyblue
	lda #$0a
	sta target_palette+3
	lda #$df
	sta target_palette+2

	; black
	stz target_palette+5
	stz target_palette+4

	lda #0
	jsr setup_palette_fade

	lda #12
	sta rowto
fadeoutloop:
.repeat 2
	jsr apply_palette_fade_step
.endrepeat
	WAITVSYNC
	jsr flush_palette

	lda rowto
	jsr wipeto
	lda rowto
	cmp #96 ; set carry each iteration at/after 96, bringing total to 200 after 16
	adc #12
	sta rowto
	cmp #201 ; stop *after* 200
	bcc fadeoutloop

	rts
rowto:
	.byte 0

wipeto:
	sta @STOP_ROW
	lda #$30
	sta Vera::Reg::AddrH

	; set up cache
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #$40
	sta Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl
@loop:
	ldx row
	lda xoff
	clc
	adc addrl_per_row_4bit,x
    sta Vera::Reg::AddrL
    lda addrm_per_row_4bit,x
	adc #0
    sta Vera::Reg::AddrM
	lda #$22
.repeat 10
	stz Vera::Reg::Data0
.endrepeat
	lda row
	inc
	sta row
	cmp #$ff
@STOP_ROW = * - 1
	bcc @loop

	; end FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl


	rts
xoff:
	.byte 0
row:
	.byte 0
.endproc
