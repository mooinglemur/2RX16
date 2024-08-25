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

SECTION_COUNT = 5

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
section_idx:
	.res 1
anim_nr:
	.res SECTION_COUNT
anim_step:
	.res SECTION_COUNT
buff:
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
	stz buff

	; set up the VERA FX TILEBASE pointer
	; and other FX state
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #((FXTILES >> 9) & $FC)
	sta Vera::Reg::FXTileBase

	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	; high bytes are never used in a 32x32 fx tile map
	stz Vera::Reg::FXXPosH
	stz Vera::Reg::FXYPosH

	; initialize anim_step/anim_nr
	lda #0
	ldx #SECTION_COUNT
:	inc
	sta anim_step-1,x
	stz anim_nr-1,x
	dex
	bne :-

new_frame:
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; mainly for reset of cache index
	stz Vera::Reg::FXMult

	lda #%01100111 ; cache writes and reads, affine mode, 4 bit, non transparent writes
	sta Vera::Reg::FXCtrl

	stz section_idx

	WAITVSYNC

	lda buff
	lsr
	sta Vera::Reg::L0TileBase
	lda buff
	eor #$80
	sta buff

	lda #$60
	sta Vera::Reg::AddrL
	lda buff
	clc
	adc #$22
	sta Vera::Reg::AddrM
	lda #$30
	sta Vera::Reg::AddrH

	lda #(6 << 1)
	sta Vera::Reg::Ctrl

	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c

	ldy #3
blacksky:
.repeat 20
	stz Vera::Reg::Data0
.endrepeat
	lda Vera::Reg::AddrL
	clc
	adc #80
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
:	dey
	bne blacksky

	lda #$66
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c

	ldy #5
horizon:
.repeat 20
	stz Vera::Reg::Data0
.endrepeat
	lda Vera::Reg::AddrL
	clc
	adc #80
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
:	dey
	bne horizon

	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #%11100111 ; cache writes and reads, affine mode, 4 bit, transparent writes
	sta Vera::Reg::FXCtrl

	ldy #0 ; section index
new_section:
	ldx anim_nr,y
	lda fx_anim_mapbases,x
	sta Vera::Reg::FXMapBase

	tya
	asl
	adc #>sintbls
	sta SINTBLF_H
	inc
	sta SINTBLI_H

	lda #(3 << 1)
	sta Vera::Reg::Ctrl

	lda x_inc_l,y
	sta fx_x_incr
	sta Vera::Reg::FXXIncrL
	lda x_inc_h,y
	sta fx_x_incr+1
	sta Vera::Reg::FXXIncrH

	stz Vera::Reg::FXYIncrL
	stz Vera::Reg::FXYIncrH

	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	lda frame_nr+1
	lsr
	lda frame_nr
	bcc :+
	eor #$ff
:	tax
	lda sintbls,x  ; integer
SINTBLI_H = * - 1
	sta fx_x_row+1
	sta Vera::Reg::FXXPosL

	lda #>FX_Y_START
	sta fx_y_row+1

	sta Vera::Reg::FXYPosL

	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	lda sintbls,x  ; fractional
SINTBLF_H = * - 1
	sta fx_x_row
	sta Vera::Reg::FXXPosS

	lda #<FX_Y_START
	sta fx_y_row
	sta Vera::Reg::FXYPosS

	; this increment happens on the row stepping
	lda y_inc_l,y
	sta fx_y_incr
	lda y_inc_h,y
	sta fx_y_incr+1

	lda times16,y
	clc
	adc anim_nr,y
	tax

	lda addr_l_start,x
	sta Vera::Reg::AddrL
	lda addr_m_start,x
	clc
	adc buff
	sta Vera::Reg::AddrM
	lda #$30
	sta Vera::Reg::AddrH

	lda lines_section,y
	tay
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

	lda #(5 << 1)
	sta Vera::Reg::Ctrl

	clc
	lda fx_x_row
	sta Vera::Reg::FXXPosS

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

	lda fx_x_row+1
	sta Vera::Reg::FXXPosL
	lda fx_y_row+1
	sta Vera::Reg::FXYPosL

	dey
	jne row

end_section:
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #%11100111 ; cache writes and reads, affine mode, 4 bit, transparent writes
	sta Vera::Reg::FXCtrl

	ldy section_idx
	lda anim_step,y
	dec
	sta anim_step,y
	bne skip_anim

	; get some entropy for the carry bit
	lda Vera::Reg::IRQLineL
	lsr
	lda #0
	adc #3
	asl
	sta anim_step,y

	lda anim_nr,y
	inc
	cmp #16
	bcc :+
	lda #0
:	sta anim_nr,y
skip_anim:

	iny
	sty section_idx
	cpy #SECTION_COUNT
	jcc new_section

end_frame:
	inc frame_nr
	bne :+
	inc frame_nr+1
:

	lda frame_nr
	and #3
	bne scrolling


scrolling:
	lda #(1 << 1)
	sta Vera::Reg::Ctrl

	lda syncval
	cmp #$BC
	bcs scroll_off

	lda Vera::Reg::DCVStart
	cmp #21
	jcc new_frame
	dec
	sta Vera::Reg::DCVStart
	jmp new_frame

scroll_off:
	lda Vera::Reg::DCVStart
	inc
	inc
	sta Vera::Reg::DCVStart
	cmp #150
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
	lda #150 ; slide in
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
	.word $33d
	.word $33c
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f
	.word $44f

fx_anim_mapbases:
.repeat 16, i
	.byte (((FXMAP >> 11) + i) << 2) | $02
.endrepeat

lines_section:
	.byte 10,20,30,30,30

times16:
	.byte $00,$10,$20,$30,$40,$50,$60,$70,$80,$90,$a0,$b0,$c0,$d0,$e0,$f0

x_inc_l:
	.byte 0,0,0,0,0
x_inc_h:
	.byte 6,5,4,2,1
y_inc_l:
	.byte 0,$80,$00,$00,$00
y_inc_h:
	.byte 2,1,1,1,1

sintbls:
	.byte $00,$03,$0d,$1d,$34,$52,$76,$a1,$d2,$0a,$48,$8d,$d8,$2a,$83,$e2
	.byte $47,$b3,$25,$9e,$1d,$a2,$2e,$c0,$59,$f8,$9d,$48,$f9,$b1,$6f,$33
	.byte $fd,$cd,$a4,$80,$62,$4a,$39,$2d,$26,$26,$2b,$37,$47,$5e,$7a,$9c
	.byte $c3,$ef,$21,$59,$95,$d8,$1f,$6b,$bd,$13,$6f,$d0,$36,$a0,$0f,$83
	.byte $fc,$7a,$fc,$82,$0d,$9d,$31,$c9,$65,$06,$aa,$53,$00,$b0,$65,$1d
	.byte $d9,$99,$5c,$22,$ed,$ba,$8b,$5f,$37,$11,$ee,$cf,$b2,$98,$81,$6c
	.byte $5a,$4b,$3e,$34,$2b,$25,$21,$1f,$1f,$21,$25,$2b,$32,$3b,$45,$51
	.byte $5f,$6d,$7d,$8e,$9f,$b2,$c6,$da,$f0,$06,$1c,$33,$4a,$62,$7a,$92
	.byte $aa,$c2,$da,$f2,$0a,$21,$38,$4f,$65,$7a,$8e,$a2,$b5,$c7,$d8,$e7
	.byte $f6,$03,$0f,$19,$22,$29,$2f,$33,$35,$35,$33,$2f,$29,$21,$16,$09
	.byte $fa,$e8,$d3,$bc,$a2,$86,$66,$43,$1e,$f5,$c9,$9a,$68,$32,$f9,$bc
	.byte $7b,$37,$f0,$a4,$55,$01,$aa,$4f,$ef,$8c,$24,$b8,$47,$d2,$59,$db
	.byte $58,$d1,$45,$b4,$1f,$84,$e5,$41,$98,$e9,$36,$7d,$bf,$fc,$33,$65
	.byte $92,$b9,$da,$f6,$0d,$1e,$29,$2e,$2e,$28,$1c,$0a,$f2,$d4,$b1,$87
	.byte $57,$21,$e5,$a3,$5b,$0c,$b8,$5d,$fc,$94,$26,$b2,$37,$b7,$2f,$a2
	.byte $0d,$73,$d2,$2a,$7c,$c7,$0c,$4b,$82,$b4,$de,$03,$20,$37,$48,$52

	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$02,$02,$02
	.byte $03,$03,$04,$04,$05,$05,$06,$06,$07,$07,$08,$09,$09,$0a,$0b,$0c
	.byte $0c,$0d,$0e,$0f,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b
	.byte $1c,$1d,$1f,$20,$21,$22,$24,$25,$26,$28,$29,$2a,$2c,$2d,$2f,$30
	.byte $31,$33,$34,$36,$38,$39,$3b,$3c,$3e,$40,$41,$43,$45,$46,$48,$4a
	.byte $4b,$4d,$4f,$51,$52,$54,$56,$58,$5a,$5c,$5d,$5f,$61,$63,$65,$67
	.byte $69,$6b,$6d,$6f,$71,$73,$75,$77,$79,$7b,$7d,$7f,$81,$83,$85,$87
	.byte $89,$8b,$8d,$8f,$91,$93,$95,$97,$99,$9c,$9e,$a0,$a2,$a4,$a6,$a8
	.byte $aa,$ac,$ae,$b0,$b3,$b5,$b7,$b9,$bb,$bd,$bf,$c1,$c3,$c5,$c7,$c9
	.byte $cb,$ce,$d0,$d2,$d4,$d6,$d8,$da,$dc,$de,$e0,$e2,$e4,$e6,$e8,$ea
	.byte $eb,$ed,$ef,$f1,$f3,$f5,$f7,$f9,$fb,$fc,$fe,$00,$02,$04,$05,$07
	.byte $09,$0b,$0c,$0e,$10,$12,$13,$15,$16,$18,$1a,$1b,$1d,$1e,$20,$21
	.byte $23,$24,$26,$27,$29,$2a,$2b,$2d,$2e,$2f,$31,$32,$33,$34,$36,$37
	.byte $38,$39,$3a,$3b,$3d,$3e,$3f,$40,$41,$42,$43,$44,$44,$45,$46,$47
	.byte $48,$49,$49,$4a,$4b,$4c,$4c,$4d,$4d,$4e,$4f,$4f,$50,$50,$51,$51
	.byte $52,$52,$52,$53,$53,$53,$54,$54,$54,$54,$54,$55,$55,$55,$55,$55

	.byte $00,$06,$1a,$3b,$69,$a4,$ec,$42,$a4,$14,$91,$1a,$b1,$55,$06,$c4
	.byte $8f,$66,$4b,$3c,$3a,$45,$5d,$81,$b2,$f0,$3a,$90,$f3,$63,$df,$67
	.byte $fb,$9b,$48,$01,$c5,$95,$72,$5a,$4d,$4d,$57,$6e,$8f,$bc,$f4,$38
	.byte $86,$df,$43,$b2,$2b,$b0,$3e,$d7,$7a,$27,$df,$a0,$6c,$41,$1f,$07
	.byte $f9,$f4,$f8,$05,$1b,$3a,$62,$92,$cb,$0c,$55,$a6,$00,$61,$ca,$3a
	.byte $b2,$32,$b8,$45,$da,$75,$17,$bf,$6e,$22,$dd,$9e,$64,$31,$02,$d9
	.byte $b5,$97,$7d,$68,$57,$4b,$43,$3f,$3f,$43,$4b,$56,$65,$77,$8b,$a3
	.byte $be,$db,$fa,$1c,$3f,$65,$8c,$b5,$e0,$0c,$39,$67,$95,$c5,$f4,$25
	.byte $55,$85,$b5,$e5,$14,$43,$71,$9e,$ca,$f4,$1d,$45,$6a,$8e,$b0,$cf
	.byte $ec,$07,$1e,$33,$45,$53,$5f,$66,$6a,$6b,$67,$5f,$53,$42,$2d,$13
	.byte $f4,$d0,$a7,$79,$45,$0c,$cc,$87,$3c,$eb,$93,$35,$d0,$64,$f2,$78
	.byte $f7,$6f,$e0,$49,$aa,$03,$55,$9e,$df,$18,$48,$70,$8f,$a5,$b2,$b6
	.byte $b1,$a2,$8b,$69,$3e,$09,$cb,$82,$30,$d3,$6c,$fa,$7e,$f8,$66,$cb
	.byte $24,$72,$b5,$ed,$1a,$3c,$52,$5d,$5c,$50,$38,$14,$e5,$a9,$62,$0e
	.byte $af,$43,$cb,$47,$b6,$19,$70,$ba,$f8,$29,$4d,$65,$6f,$6e,$5f,$44
	.byte $1b,$e6,$a4,$55,$f8,$8f,$19,$96,$05,$68,$bd,$06,$41,$6f,$90,$a4

	.byte $00,$00,$00,$00,$00,$00,$00,$01,$01,$02,$02,$03,$03,$04,$05,$05
	.byte $06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,$11,$12,$13,$15,$16,$18
	.byte $19,$1b,$1d,$1f,$20,$22,$24,$26,$28,$2a,$2c,$2e,$30,$32,$34,$37
	.byte $39,$3b,$3e,$40,$43,$45,$48,$4a,$4d,$50,$52,$55,$58,$5b,$5e,$61
	.byte $63,$66,$69,$6d,$70,$73,$76,$79,$7c,$80,$83,$86,$8a,$8d,$90,$94
	.byte $97,$9b,$9e,$a2,$a5,$a9,$ad,$b0,$b4,$b8,$bb,$bf,$c3,$c7,$cb,$ce
	.byte $d2,$d6,$da,$de,$e2,$e6,$ea,$ee,$f2,$f6,$fa,$fe,$02,$06,$0a,$0e
	.byte $12,$16,$1a,$1f,$23,$27,$2b,$2f,$33,$38,$3c,$40,$44,$48,$4c,$51
	.byte $55,$59,$5d,$61,$66,$6a,$6e,$72,$76,$7a,$7f,$83,$87,$8b,$8f,$93
	.byte $97,$9c,$a0,$a4,$a8,$ac,$b0,$b4,$b8,$bc,$c0,$c4,$c8,$cc,$d0,$d4
	.byte $d7,$db,$df,$e3,$e7,$eb,$ee,$f2,$f6,$f9,$fd,$01,$04,$08,$0b,$0f
	.byte $12,$16,$19,$1d,$20,$24,$27,$2a,$2d,$31,$34,$37,$3a,$3d,$40,$43
	.byte $46,$49,$4c,$4f,$52,$55,$57,$5a,$5d,$5f,$62,$64,$67,$69,$6c,$6e
	.byte $71,$73,$75,$77,$7a,$7c,$7e,$80,$82,$84,$86,$88,$89,$8b,$8d,$8f
	.byte $90,$92,$93,$95,$96,$98,$99,$9a,$9b,$9d,$9e,$9f,$a0,$a1,$a2,$a3
	.byte $a4,$a4,$a5,$a6,$a6,$a7,$a8,$a8,$a9,$a9,$a9,$aa,$aa,$aa,$aa,$aa

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

	.byte $00,$0d,$34,$76,$d2,$48,$d9,$84,$49,$28,$22,$35,$63,$ab,$0c,$88
	.byte $1e,$cd,$96,$79,$75,$8b,$ba,$03,$65,$e0,$74,$21,$e7,$c6,$be,$ce
	.byte $f7,$37,$90,$02,$8b,$2b,$e4,$b4,$9b,$9a,$af,$dc,$1f,$79,$e9,$70
	.byte $0c,$bf,$87,$65,$57,$60,$7d,$ae,$f5,$4f,$be,$41,$d8,$82,$3f,$0f
	.byte $f2,$e8,$f0,$0b,$37,$75,$c4,$24,$96,$18,$ab,$4d,$00,$c3,$94,$75
	.byte $65,$64,$71,$8b,$b4,$ea,$2e,$7e,$dc,$45,$bb,$3c,$c9,$62,$05,$b3
	.byte $6b,$2e,$fa,$d0,$ae,$96,$86,$7f,$7f,$87,$97,$ad,$ca,$ee,$17,$47
	.byte $7c,$b6,$f4,$38,$7f,$ca,$19,$6b,$c0,$18,$72,$ce,$2b,$8a,$e9,$4a
	.byte $aa,$0b,$6b,$cb,$29,$87,$e3,$3c,$94,$e9,$3b,$8a,$d5,$1d,$60,$9f
	.byte $d9,$0e,$3d,$66,$8a,$a7,$be,$cd,$d5,$d6,$ce,$be,$a6,$85,$5a,$27
	.byte $e9,$a1,$4f,$f3,$8b,$18,$99,$0f,$79,$d6,$26,$6a,$a0,$c9,$e4,$f1
	.byte $ef,$df,$c0,$92,$54,$07,$aa,$3c,$be,$30,$90,$e0,$1e,$4a,$64,$6c
	.byte $62,$45,$16,$d3,$7d,$13,$96,$05,$60,$a6,$d8,$f5,$fd,$f0,$cd,$96
	.byte $48,$e5,$6b,$db,$35,$78,$a5,$bb,$b9,$a0,$70,$29,$ca,$53,$c4,$1d
	.byte $5e,$86,$96,$8e,$6d,$33,$e0,$74,$f0,$52,$9a,$ca,$df,$dc,$be,$88
	.byte $37,$cc,$48,$aa,$f1,$1f,$33,$2c,$0b,$d0,$7b,$0c,$82,$de,$20,$48

	.byte $00,$00,$00,$00,$00,$01,$01,$02,$03,$04,$05,$06,$07,$08,$0a,$0b
	.byte $0d,$0e,$10,$12,$14,$16,$18,$1b,$1d,$1f,$22,$25,$27,$2a,$2d,$30
	.byte $33,$37,$3a,$3e,$41,$45,$48,$4c,$50,$54,$58,$5c,$61,$65,$69,$6e
	.byte $73,$77,$7c,$81,$86,$8b,$90,$95,$9a,$a0,$a5,$ab,$b0,$b6,$bc,$c2
	.byte $c7,$cd,$d3,$da,$e0,$e6,$ec,$f3,$f9,$00,$06,$0d,$14,$1a,$21,$28
	.byte $2f,$36,$3d,$44,$4b,$52,$5a,$61,$68,$70,$77,$7f,$86,$8e,$96,$9d
	.byte $a5,$ad,$b4,$bc,$c4,$cc,$d4,$dc,$e4,$ec,$f4,$fc,$04,$0c,$15,$1d
	.byte $25,$2d,$35,$3e,$46,$4e,$57,$5f,$67,$70,$78,$80,$89,$91,$99,$a2
	.byte $aa,$b3,$bb,$c3,$cc,$d4,$dc,$e5,$ed,$f5,$fe,$06,$0e,$17,$1f,$27
	.byte $2f,$38,$40,$48,$50,$58,$60,$68,$70,$78,$80,$88,$90,$98,$a0,$a8
	.byte $af,$b7,$bf,$c6,$ce,$d6,$dd,$e5,$ec,$f3,$fb,$02,$09,$10,$17,$1e
	.byte $25,$2c,$33,$3a,$41,$48,$4e,$55,$5b,$62,$68,$6e,$75,$7b,$81,$87
	.byte $8d,$93,$99,$9e,$a4,$aa,$af,$b5,$ba,$bf,$c4,$c9,$ce,$d3,$d8,$dd
	.byte $e2,$e6,$eb,$ef,$f4,$f8,$fc,$00,$04,$08,$0c,$10,$13,$17,$1a,$1e
	.byte $21,$24,$27,$2a,$2d,$30,$32,$35,$37,$3a,$3c,$3e,$40,$42,$44,$46
	.byte $48,$49,$4b,$4c,$4d,$4f,$50,$51,$52,$52,$53,$54,$54,$54,$55,$55

	.byte $00,$10,$41,$94,$07,$9b,$4f,$25,$1b,$33,$6a,$c3,$3c,$d6,$90,$6a
	.byte $65,$80,$bb,$17,$92,$2e,$e9,$c4,$be,$d8,$11,$6a,$e1,$78,$2d,$02
	.byte $f4,$05,$35,$82,$ed,$76,$1d,$e1,$c2,$c0,$db,$13,$67,$d7,$64,$0c
	.byte $d0,$af,$a9,$be,$ed,$38,$9c,$1a,$b2,$63,$2e,$11,$0e,$22,$4f,$93
	.byte $ef,$62,$ec,$8d,$45,$12,$f5,$ee,$fc,$1e,$55,$a1,$00,$73,$fa,$93
	.byte $3f,$fd,$cd,$ae,$a1,$a5,$ba,$de,$13,$57,$aa,$0c,$7c,$fa,$87,$20
	.byte $c6,$79,$39,$04,$da,$bc,$a8,$9f,$9f,$a9,$bd,$d9,$fd,$29,$5d,$99
	.byte $db,$23,$72,$c6,$1f,$7d,$e0,$46,$b1,$1e,$8e,$01,$76,$ec,$64,$dc
	.byte $55,$ce,$46,$bd,$34,$a9,$1b,$8c,$f9,$63,$ca,$2c,$8b,$e4,$38,$87
	.byte $cf,$11,$4c,$80,$ad,$d1,$ed,$00,$0a,$0b,$02,$ee,$d0,$a6,$71,$30
	.byte $e3,$8a,$23,$af,$2e,$9e,$00,$53,$97,$cb,$f0,$04,$08,$fb,$dd,$ad
	.byte $6b,$17,$b0,$36,$a9,$09,$54,$8b,$ae,$bc,$b5,$98,$65,$1c,$bd,$47
	.byte $bb,$17,$5b,$88,$9c,$98,$7c,$46,$f8,$8f,$0e,$72,$bc,$ec,$01,$fb
	.byte $da,$9e,$46,$d2,$43,$97,$ce,$e9,$e7,$c9,$8d,$33,$bc,$28,$75,$a4
	.byte $b5,$a8,$7c,$32,$c8,$40,$98,$d2,$ec,$e6,$c1,$7c,$17,$93,$ee,$2a
	.byte $45,$40,$1a,$d4,$6e,$e7,$3f,$77,$8e,$85,$5a,$0f,$a3,$16,$68,$9a

	.byte $00,$00,$00,$00,$01,$01,$02,$03,$04,$05,$06,$07,$09,$0a,$0c,$0e
	.byte $10,$12,$14,$17,$19,$1c,$1e,$21,$24,$27,$2b,$2e,$31,$35,$39,$3d
	.byte $40,$45,$49,$4d,$51,$56,$5b,$5f,$64,$69,$6e,$74,$79,$7e,$84,$8a
	.byte $8f,$95,$9b,$a1,$a7,$ae,$b4,$bb,$c1,$c8,$cf,$d6,$dd,$e4,$eb,$f2
	.byte $f9,$01,$08,$10,$18,$20,$27,$2f,$37,$40,$48,$50,$59,$61,$69,$72
	.byte $7b,$83,$8c,$95,$9e,$a7,$b0,$b9,$c3,$cc,$d5,$df,$e8,$f1,$fb,$05
	.byte $0e,$18,$22,$2c,$35,$3f,$49,$53,$5d,$67,$71,$7b,$85,$90,$9a,$a4
	.byte $ae,$b9,$c3,$cd,$d8,$e2,$ec,$f7,$01,$0c,$16,$21,$2b,$35,$40,$4a
	.byte $55,$5f,$6a,$74,$7f,$89,$94,$9e,$a8,$b3,$bd,$c8,$d2,$dc,$e7,$f1
	.byte $fb,$06,$10,$1a,$24,$2e,$38,$43,$4d,$57,$61,$6a,$74,$7e,$88,$92
	.byte $9b,$a5,$af,$b8,$c2,$cb,$d5,$de,$e7,$f0,$f9,$03,$0c,$14,$1d,$26
	.byte $2f,$38,$40,$49,$51,$5a,$62,$6a,$72,$7a,$82,$8a,$92,$9a,$a1,$a9
	.byte $b0,$b8,$bf,$c6,$cd,$d4,$db,$e2,$e8,$ef,$f6,$fc,$02,$08,$0f,$14
	.byte $1a,$20,$26,$2b,$31,$36,$3b,$40,$45,$4a,$4f,$54,$58,$5d,$61,$65
	.byte $69,$6d,$71,$75,$78,$7c,$7f,$82,$85,$88,$8b,$8e,$91,$93,$95,$98
	.byte $9a,$9c,$9e,$9f,$a1,$a2,$a4,$a5,$a6,$a7,$a8,$a9,$a9,$aa,$aa,$aa

	.byte $00,$13,$4e,$b1,$3b,$ed,$c6,$c6,$ee,$3d,$b3,$50,$15,$00,$13,$4c
	.byte $ad,$33,$e1,$b5,$b0,$d0,$17,$84,$17,$d0,$ae,$b2,$db,$2a,$9d,$35
	.byte $f2,$d3,$d9,$03,$50,$c1,$56,$0e,$e9,$e7,$07,$4a,$af,$36,$de,$a8
	.byte $93,$9e,$cb,$17,$83,$10,$bb,$86,$6f,$77,$9e,$e2,$44,$c3,$5e,$17
	.byte $ec,$dc,$e9,$10,$52,$af,$26,$b7,$61,$24,$00,$f4,$01,$24,$5f,$b0
	.byte $18,$96,$29,$d1,$8f,$60,$45,$3e,$4a,$68,$99,$db,$2e,$93,$08,$8d
	.byte $21,$c5,$77,$38,$06,$e1,$ca,$be,$bf,$cb,$e2,$04,$30,$65,$a3,$ea
	.byte $3a,$91,$ef,$54,$bf,$30,$a6,$21,$a1,$24,$ab,$35,$c1,$4f,$de,$6f
	.byte $ff,$90,$21,$b0,$3e,$ca,$54,$db,$5e,$de,$59,$cf,$40,$ab,$10,$6e
	.byte $c5,$15,$5c,$9a,$cf,$fb,$1d,$34,$40,$41,$35,$1e,$f9,$c7,$88,$3a
	.byte $de,$72,$f7,$6c,$d1,$24,$66,$97,$b5,$c1,$ba,$9f,$70,$2e,$d6,$69
	.byte $e7,$4f,$a0,$db,$fe,$0b,$ff,$db,$9e,$48,$d9,$50,$ad,$ef,$16,$23
	.byte $13,$e8,$a1,$3c,$bb,$1d,$61,$88,$90,$79,$44,$ef,$7c,$e8,$34,$61
	.byte $6c,$57,$21,$c9,$50,$b5,$f8,$18,$16,$f1,$a9,$3e,$af,$fc,$26,$2c
	.byte $0d,$ca,$62,$d5,$24,$4d,$51,$2f,$e8,$7b,$e8,$2f,$4f,$4a,$1e,$cc
	.byte $52,$b3,$ec,$ff,$ea,$af,$4c,$c2,$11,$39,$39,$12,$c4,$4e,$b1,$ec

	.byte $00,$00,$00,$00,$01,$01,$02,$03,$04,$06,$07,$09,$0b,$0d,$0f,$11
	.byte $13,$16,$18,$1b,$1e,$21,$25,$28,$2c,$2f,$33,$37,$3b,$40,$44,$49
	.byte $4d,$52,$57,$5d,$62,$67,$6d,$73,$78,$7e,$85,$8b,$91,$98,$9e,$a5
	.byte $ac,$b3,$ba,$c2,$c9,$d1,$d8,$e0,$e8,$f0,$f8,$00,$09,$11,$1a,$23
	.byte $2b,$34,$3d,$47,$50,$59,$63,$6c,$76,$80,$8a,$93,$9e,$a8,$b2,$bc
	.byte $c7,$d1,$dc,$e6,$f1,$fc,$07,$12,$1d,$28,$33,$3e,$4a,$55,$61,$6c
	.byte $78,$83,$8f,$9b,$a7,$b2,$be,$ca,$d6,$e2,$ee,$fb,$07,$13,$1f,$2b
	.byte $38,$44,$50,$5d,$69,$76,$82,$8f,$9b,$a8,$b4,$c1,$cd,$da,$e6,$f3
	.byte $ff,$0c,$19,$25,$32,$3e,$4b,$57,$64,$70,$7d,$89,$96,$a2,$af,$bb
	.byte $c7,$d4,$e0,$ec,$f8,$04,$11,$1d,$29,$35,$41,$4d,$58,$64,$70,$7c
	.byte $87,$93,$9e,$aa,$b5,$c1,$cc,$d7,$e2,$ed,$f8,$03,$0e,$19,$23,$2e
	.byte $38,$43,$4d,$57,$61,$6c,$75,$7f,$89,$93,$9c,$a6,$af,$b8,$c2,$cb
	.byte $d4,$dc,$e5,$ee,$f6,$ff,$07,$0f,$17,$1f,$27,$2e,$36,$3d,$45,$4c
	.byte $53,$5a,$61,$67,$6e,$74,$7a,$81,$87,$8c,$92,$98,$9d,$a2,$a8,$ad
	.byte $b2,$b6,$bb,$bf,$c4,$c8,$cc,$d0,$d3,$d7,$da,$de,$e1,$e4,$e7,$e9
	.byte $ec,$ee,$f0,$f2,$f4,$f6,$f8,$f9,$fb,$fc,$fd,$fe,$fe,$ff,$ff,$ff

addr_l_start:
	.byte $c0,$c0,$20,$20,$20,$20,$20,$c0,$c0,$c0,$60,$60,$60,$60,$60,$c0

	.byte $00,$60,$60,$60,$60,$60,$60,$60,$00,$a0,$a0,$a0,$a0,$a0,$a0,$a0

	.byte $40,$a0,$a0,$00,$00,$00,$a0,$a0,$40,$e0,$e0,$80,$80,$80,$e0,$e0

	.byte $80,$e0,$e0,$40,$40,$40,$e0,$e0,$80,$20,$20,$c0,$c0,$c0,$20,$20

	.byte $e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0

	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

addr_m_start:
	.byte $21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$22,$22,$22,$22,$22,$21

	.byte $23,$22,$22,$22,$22,$22,$22,$22,$23,$23,$23,$23,$23,$23,$23,$23

	.byte $24,$23,$23,$23,$23,$23,$23,$23,$24,$24,$24,$25,$25,$25,$24,$24

	.byte $25,$24,$24,$24,$24,$24,$24,$24,$25,$26,$26,$26,$26,$26,$26,$26

	.byte $2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

	.byte $30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30
