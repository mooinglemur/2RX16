.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.import graceful_fail

.macpack longbranch

FXMAP = $1F000
FXTILES = $10000
BMP = $00000

FX_Y_START = $8300
FX_Y_INCR_START = $0100
FX_Y_INCR_STEP = $0002
FX_X_STARTING_INCR = $0100 << 1
FX_X_INCR_STEP = $0002
;FX_X_INCR_STEP = 0
FX_X_ROW_STEP = $00C0
;FX_X_ROW_STEP = 0

.include "x16.inc"
.include "macros.inc"

.segment "SINUS_ZP": zeropage
frame_nr:
	.res 2
fx_x_row:
	.res 2
fx_y_row:
	.res 2
fx_x_incr:
	.res 2
fx_y_incr:
	.res 2
anim_nr:
	.res 1
tmp1:
	.res 1

.segment "SINUS"
entry:

	jsr setup_vera

	LOADFILE "SINUSMAP.DAT", 0, .loword(FXMAP), ^FXMAP
	LOADFILE "SINUSTILES.DAT", 0, .loword(FXTILES), ^FXTILES

	jsr blank
	jsr setup_palette
	jsr sinusfield

	MUSIC_SYNC $BC

	rts

.proc blank
	VERA_SET_ADDR BMP, 1
	ldy #32
	ldx #0
loop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne loop
	dey
	bne loop

	rts
.endproc

.proc sinusfield
	stz frame_nr
	stz frame_nr+1
	stz anim_nr

	lda #<FX_X_STARTING_INCR
	sta fx_x_incr
	lda #>FX_X_STARTING_INCR
	sta fx_x_incr+1

	; set up the VERA FX MAPBASE pointer
	; and other FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #((FXMAP >> 9) & $FC) | $02 ; 32x32 map
	sta Vera::Reg::FXMapBase

	; mainly for reset of cache index
	stz Vera::Reg::FXMult

	lda #%01100011 ; cache writes and reads, affine mode
	sta Vera::Reg::FXCtrl

	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	; high bytes are never used in a 32x32 fx tile map
	stz Vera::Reg::FXXPosH
	stz Vera::Reg::FXYPosH
new_frame:
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	ldx anim_nr
	lda fx_anim_tilebases,x
	sta Vera::Reg::FXTileBase

	lda #(3 << 1)
	sta Vera::Reg::Ctrl

	lda #<FX_X_STARTING_INCR
	sta fx_x_incr
	sta Vera::Reg::FXXIncrL

	lda #>FX_X_STARTING_INCR
	sta fx_x_incr+1
	sta Vera::Reg::FXXIncrH

	stz Vera::Reg::FXYIncrL
	stz Vera::Reg::FXYIncrH

	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	lda fx_anim_x_offsets,x
	sta tmp1

	lda frame_nr+1
	lsr
	lda frame_nr
	bcc :+
	eor #$ff
:	tax
	lda sinx,x
	clc
	adc tmp1
	sta fx_x_row+1

	sta Vera::Reg::FXXPosL

	lda #>FX_Y_START
	sta fx_y_row+1

	sta Vera::Reg::FXYPosL

	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	lda sinxf,x
	sta fx_x_row
	sta Vera::Reg::FXXPosS

	lda #<FX_Y_START
	sta fx_y_row
	sta Vera::Reg::FXYPosS

	; this one happens in between ros
	lda #<FX_Y_INCR_START
	sta fx_y_incr
	lda #>FX_Y_INCR_START
	sta fx_y_incr+1

	VERA_SET_ADDR (BMP+((200-66)*320)), 3

	WAITVSYNC

	ldy #66
row:

.repeat 80
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat

; end of row
	sec

	lda #(3 << 1)
	sta Vera::Reg::Ctrl

	lda fx_x_incr
	sbc #<FX_X_INCR_STEP
	sta fx_x_incr
	sta Vera::Reg::FXXIncrL

	lda fx_x_incr+1
	sbc #>FX_X_INCR_STEP
	sta fx_x_incr+1
	sta Vera::Reg::FXXIncrH

	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	clc
	lda fx_x_row
	adc #<FX_X_ROW_STEP
	sta fx_x_row
	sta Vera::Reg::FXXPosS

	lda fx_x_row+1
	adc #>FX_X_ROW_STEP
	sta fx_x_row+1
	tax

	clc
	lda fx_y_row
	adc fx_y_incr
	sta fx_y_row
	sta Vera::Reg::FXYPosS

	lda fx_y_row+1
	adc fx_y_incr+1
	sta fx_y_row+1

	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	stx Vera::Reg::FXXPosL
	lda fx_y_row+1
	sta Vera::Reg::FXYPosL

	sec
	lda fx_y_incr
	sbc #<FX_Y_INCR_STEP
	sta fx_y_incr
	bcs :+
	dec fx_y_incr+1
:

	dey
	jne row
end_frame:
	inc frame_nr
	bne :+
	inc frame_nr+1
:

	lda frame_nr
	and #3
	bne scrolling

	lda anim_nr
	inc
	cmp #60
	bcc :+
	lda #0
:	sta anim_nr

scrolling:
	lda #(1 << 1)
	sta Vera::Reg::Ctrl

	lda syncval
	cmp #$BC
	bcs scroll_off

	lda Vera::Reg::DCVStart
	cmp #21
	jcc new_frame
	dec Vera::Reg::DCVStart
	jmp new_frame

scroll_off:
	inc Vera::Reg::DCVStart
	lda Vera::Reg::DCVStart
	cmp #100
	jcc new_frame

	; clear FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl

	stz Vera::Reg::Ctrl

	rts
.endproc

.proc setup_palette
	VERA_SET_ADDR Vera::VRAM_palette, 1
	ldx #0
:	lda palette,x
	sta Vera::Reg::Data0
	inx
	cpx #96
	bcc :-

	rts
.endproc

.proc setup_vera
	; set full palette to black

	VERA_SET_ADDR Vera::VRAM_palette, 1

	ldx #0
:	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	dex
	bne :-

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
	lda #100 ; slide in
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; 2:1 scale
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; bitmap mode, 8bpp
	lda #%00000111
	sta Vera::Reg::L0Config

	; bitmap base, 320x240
	stz Vera::Reg::L0TileBase

	rts
.endproc


palette:
	.word $000
	.word $809
	.word $80a
	.word $81a
	.word $70a
	.word $71a
	.word $70b
	.word $71b

	.word $70c
	.word $71c
	.word $60c
	.word $60d
	.word $61d
	.word $51d
	.word $50e
	.word $41e

	.word $40e
	.word $41e
	.word $40e
	.word $31e
	.word $30e
	.word $21f
	.word $20f
	.word $10f

	.word $00f
	.word $01f
	.word $11f
	.word $12f
	.word $22f
	.word $23f
	.word $33f
	.word $34f

	.word $44f
	.word $45f
	.word $55f
	.word $56f
	.word $66f
	.word $67f
	.word $77f
	.word $78f

	.word $88f
	.word $89f
	.word $99f
	.word $9af
	.word $aaf
	.word $abf
	.word $bbf
	.word $ccf

fx_anim_tilebases:
.repeat 2
.repeat 15, i
	.byte ((FXTILES >> 11) + 2*i) << 2
.endrepeat
.repeat 15, i
	.byte ((FXTILES >> 11) + 2*(14-i)) << 2
.endrepeat
.endrepeat

fx_anim_x_offsets:
.repeat 30
	.byte $00
.endrepeat
.repeat 30
	.byte $20
.endrepeat

sinxf:
	.byte $00,$02,$09,$16,$27,$3d,$58,$78,$9d,$c7,$f6,$2a,$62,$a0,$e2,$29,$75,$c6,$1c,$76,$d6,$3a,$a2,$10,$82,$fa,$75,$f6,$7b,$05,$93,$26,$be,$5a,$fb,$a0,$4a,$f8,$aa,$61,$1d,$dc,$a0,$69,$35,$06,$db,$b5,$92,$73,$59,$42,$30,$22,$17,$10,$0d,$0e,$13,$1c,$28,$38,$4b,$62,$7d,$9b,$bd,$e2,$0a,$35,$64,$96,$cc,$04,$40,$7e,$c0,$04,$4b,$96,$e3,$32,$85,$da,$31,$8c,$e8,$47,$a9,$0d,$73,$db,$45,$b2,$21,$91,$04,$78,$ee,$67,$e0,$5c,$d9,$57,$d7,$59,$dc,$60,$e6,$6c,$f4,$7d,$07,$92,$1d,$aa,$37,$c6,$54,$e4,$74,$04,$95,$26,$b8,$49,$db,$6d,$ff,$92,$24,$b6,$47,$d9,$6a,$fb,$8b,$1b,$ab,$39,$c8,$55,$e2,$6d,$f8,$82,$0b,$93,$19,$9f,$23,$a6,$28,$a8,$26,$a3,$1f,$98,$11,$87,$fb,$6e,$de,$4d,$ba,$24,$8c,$f2,$56,$b8,$17,$73,$ce,$25,$7a,$cd,$1c,$69,$b4,$fb,$3f,$81,$bf,$fb,$33,$69,$9b,$ca,$f5,$1d,$42,$64,$82,$9d,$b4,$c7,$d7,$e3,$ec,$f1,$f2,$ef,$e8,$dd,$cf,$bd,$a6,$8c,$6d,$4a,$24,$f9,$ca,$96,$5f,$23,$e2,$9e,$55,$07,$b5,$5f,$04,$a5,$41,$d9,$6c,$fa,$84,$09,$8a,$05,$7d,$ef,$5d,$c5,$29,$89,$e3,$39,$8a,$d6,$1d,$5f,$9d,$d5,$09,$38,$62,$87,$a7,$c2,$d8,$e9,$f6,$fd
sinx:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$05,$05,$05,$06,$06,$07,$08,$08,$09,$09,$0a,$0a,$0b,$0c,$0c,$0d,$0e,$0f,$0f,$10,$11,$12,$13,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f,$20,$21,$22,$23,$24,$25,$26,$27,$28,$2a,$2b,$2c,$2d,$2e,$30,$31,$32,$33,$35,$36,$37,$38,$3a,$3b,$3c,$3e,$3f,$40,$42,$43,$45,$46,$47,$49,$4a,$4c,$4d,$4f,$50,$51,$53,$54,$56,$57,$59,$5a,$5c,$5d,$5f,$60,$62,$63,$65,$67,$68,$6a,$6b,$6d,$6e,$70,$71,$73,$75,$76,$78,$79,$7b,$7c,$7e,$7f,$81,$83,$84,$86,$87,$89,$8a,$8c,$8e,$8f,$91,$92,$94,$95,$97,$98,$9a,$9c,$9d,$9f,$a0,$a2,$a3,$a5,$a6,$a8,$a9,$ab,$ac,$ae,$af,$b0,$b2,$b3,$b5,$b6,$b8,$b9,$ba,$bc,$bd,$bf,$c0,$c1,$c3,$c4,$c5,$c7,$c8,$c9,$ca,$cc,$cd,$ce,$cf,$d1,$d2,$d3,$d4,$d5,$d7,$d8,$d9,$da,$db,$dc,$dd,$de,$df,$e0,$e1,$e2,$e3,$e4,$e5,$e6,$e7,$e8,$e9,$ea,$eb,$ec,$ec,$ed,$ee,$ef,$f0,$f0,$f1,$f2,$f3,$f3,$f4,$f5,$f5,$f6,$f6,$f7,$f7,$f8,$f9,$f9,$fa,$fa,$fa,$fb,$fb,$fc,$fc,$fc,$fd,$fd,$fd,$fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

