.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.import graceful_fail

.macpack longbranch

FXMAP = $10000
FXTILES = $18000
BMP = $00000

FX_Y_START = $0000
FX_Y_INCR_START = $0100
FX_Y_INCR_STEP = $0002
FX_X_STARTING_INCR = $0100 << 1
FX_X_INCR_STEP = $0002
;FX_X_INCR_STEP = 0
;FX_X_ROW_STEP = $0100
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
fx_x_row_step:
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

	lda #((FXTILES >> 9) & $FC)
	sta Vera::Reg::FXTileBase

	; mainly for reset of cache index
	stz Vera::Reg::FXMult

	lda #%01100111 ; cache writes and reads, affine mode, 4 bit
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
	lda fx_anim_mapbases,x
	sta Vera::Reg::FXMapBase

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
	lda sinx4,x
	clc
	adc tmp1
	sta fx_x_row+1

	sta Vera::Reg::FXXPosL

	lda #>FX_Y_START
	sta fx_y_row+1

	sta Vera::Reg::FXYPosL

	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	lda sinx4f,x
	sta fx_x_row
	sta Vera::Reg::FXXPosS

	lda #<FX_Y_START
	sta fx_y_row
	sta Vera::Reg::FXYPosS

	; this increment happens on the row stepping
	lda #<FX_Y_INCR_START
	sta fx_y_incr
	lda #>FX_Y_INCR_START
	sta fx_y_incr+1

	lda frame_nr+1
	lsr
	ldx frame_nr
	lda easing,x
	bcs :+
	eor #$ff
:	sta fx_x_row_step

	VERA_SET_ADDR (BMP+((100-66)*320)), 3

	WAITVSYNC

	ldy #66
row:

.repeat 20
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat

	lda Vera::Reg::AddrL
	clc
	adc #80
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
:

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
	adc fx_x_row_step
	sta fx_x_row
	sta Vera::Reg::FXXPosS

	lda fx_x_row+1
	adc #0
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
	cpx #32
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

	; letterbox for 160x~100
	lda #$02
	sta Vera::Reg::Ctrl
	lda #100 ; slide in
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

	rts
.endproc


palette:
	.word $000
	.word $ccf
	.word $aaf
	.word $88f
	.word $66f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f

fx_anim_mapbases:
.repeat 2
.repeat 15, i
	.byte (((FXMAP >> 11) + i) << 2) | $02
.endrepeat
.endrepeat

fx_anim_x_offsets:
.repeat 30
	.byte $00
.endrepeat
.repeat 30
	.byte $20
.endrepeat

sinx4f:
	.byte $00,$09,$27,$58,$9d,$f6,$63,$e3,$77,$1e,$d9,$a8,$8a,$80,$89,$a6
	.byte $d6,$19,$70,$da,$58,$e8,$8b,$42,$0b,$e8,$d7,$d9,$ed,$15,$4e,$9a
	.byte $f9,$69,$ec,$81,$28,$e0,$ab,$87,$74,$73,$83,$a5,$d7,$1b,$6f,$d4
	.byte $49,$cf,$65,$0b,$c1,$88,$5d,$43,$37,$3b,$4f,$71,$a2,$e1,$2f,$8b
	.byte $f6,$6e,$f4,$88,$29,$d7,$93,$5b,$30,$12,$00,$fa,$00,$12,$2f,$58
	.byte $8c,$cb,$14,$68,$c7,$30,$a2,$1f,$a5,$34,$cc,$6d,$17,$c9,$84,$46
	.byte $10,$e2,$bb,$9c,$83,$70,$65,$5f,$5f,$65,$71,$82,$98,$b2,$d1,$f5
	.byte $1d,$48,$77,$aa,$df,$18,$53,$90,$d0,$12,$55,$9a,$e0,$27,$6f,$b7
	.byte $ff,$48,$90,$d8,$1f,$65,$aa,$ed,$2f,$6f,$ac,$e7,$20,$55,$88,$b7
	.byte $e2,$0a,$2e,$4d,$67,$7d,$8e,$9a,$a0,$a0,$9a,$8f,$7c,$63,$44,$1d
	.byte $ef,$b9,$7b,$36,$e8,$92,$33,$cb,$5a,$e0,$5d,$cf,$38,$97,$eb,$34
	.byte $73,$a7,$d0,$ed,$ff,$05,$ff,$ed,$cf,$a4,$6c,$28,$d6,$77,$0b,$91
	.byte $09,$74,$d0,$1e,$5d,$8e,$b0,$c4,$c8,$bc,$a2,$77,$3e,$f4,$9a,$30
	.byte $b6,$2b,$90,$e4,$28,$5a,$7c,$8c,$8b,$78,$54,$1f,$d7,$7e,$13,$96
	.byte $06,$65,$b1,$ea,$12,$26,$28,$17,$f4,$bd,$74,$17,$a7,$25,$8f,$e6
	.byte $29,$59,$76,$7f,$75,$57,$26,$e1,$88,$1c,$9c,$09,$62,$a7,$d8,$f6
sinx4:
	.byte $00,$00,$00,$00,$00,$00,$01,$01,$02,$03,$03,$04,$05,$06,$07,$08
	.byte $09,$0b,$0c,$0d,$0f,$10,$12,$14,$16,$17,$19,$1b,$1d,$20,$22,$24
	.byte $26,$29,$2b,$2e,$31,$33,$36,$39,$3c,$3f,$42,$45,$48,$4c,$4f,$52
	.byte $56,$59,$5d,$61,$64,$68,$6c,$70,$74,$78,$7c,$80,$84,$88,$8d,$91
	.byte $95,$9a,$9e,$a3,$a8,$ac,$b1,$b6,$bb,$c0,$c5,$c9,$cf,$d4,$d9,$de
	.byte $e3,$e8,$ee,$f3,$f8,$fe,$03,$09,$0e,$14,$19,$1f,$25,$2a,$30,$36
	.byte $3c,$41,$47,$4d,$53,$59,$5f,$65,$6b,$71,$77,$7d,$83,$89,$8f,$95
	.byte $9c,$a2,$a8,$ae,$b4,$bb,$c1,$c7,$cd,$d4,$da,$e0,$e6,$ed,$f3,$f9
	.byte $ff,$06,$0c,$12,$19,$1f,$25,$2b,$32,$38,$3e,$44,$4b,$51,$57,$5d
	.byte $63,$6a,$70,$76,$7c,$82,$88,$8e,$94,$9a,$a0,$a6,$ac,$b2,$b8,$be
	.byte $c3,$c9,$cf,$d5,$da,$e0,$e6,$eb,$f1,$f6,$fc,$01,$07,$0c,$11,$17
	.byte $1c,$21,$26,$2b,$30,$36,$3a,$3f,$44,$49,$4e,$53,$57,$5c,$61,$65
	.byte $6a,$6e,$72,$77,$7b,$7f,$83,$87,$8b,$8f,$93,$97,$9b,$9e,$a2,$a6
	.byte $a9,$ad,$b0,$b3,$b7,$ba,$bd,$c0,$c3,$c6,$c9,$cc,$ce,$d1,$d4,$d6
	.byte $d9,$db,$dd,$df,$e2,$e4,$e6,$e8,$e9,$eb,$ed,$ef,$f0,$f2,$f3,$f4
	.byte $f6,$f7,$f8,$f9,$fa,$fb,$fc,$fc,$fd,$fe,$fe,$ff,$ff,$ff,$ff,$ff
easing:
	.byte $7f,$7f,$7f,$7e,$7e,$7d,$7c,$7b,$79,$78,$76,$75,$73,$71,$6f,$6d
	.byte $6a,$68,$66,$63,$60,$5e,$5b,$58,$55,$52,$4f,$4c,$49,$46,$43,$3f
	.byte $3c,$39,$36,$33,$30,$2d,$2a,$27,$24,$21,$1f,$1c,$19,$17,$15,$12
	.byte $10,$0e,$0c,$0a,$09,$07,$06,$04,$03,$02,$01,$01,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$01,$01,$02,$03,$04,$06,$07,$09,$0a,$0c,$0e,$10
	.byte $12,$15,$17,$19,$1c,$1f,$21,$24,$27,$2a,$2d,$30,$33,$36,$39,$3c
	.byte $3f,$43,$46,$49,$4c,$4f,$52,$55,$58,$5b,$5e,$60,$63,$66,$68,$6a
	.byte $6d,$6f,$71,$73,$75,$76,$78,$79,$7b,$7c,$7d,$7e,$7e,$7f,$7f,$7f
