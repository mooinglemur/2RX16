.include "x16.inc"
.include "macros.inc"

.segment "INTRO"
entry:
	jmp titlecard



.proc titlecard
	; write all Fs to first 64 of palette
	VERA_SET_ADDR $1FA00, 1
	ldx #64
	lda #$ff
	ldy #$0f
whitepal:
	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	dex
	bne whitepal

	; show no layers
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	sta Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; 320x240
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 21)
	sta Vera::Reg::DCVStop

	; set bitmap mode for layer 0
	lda #%00000111
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	stz Vera::Reg::L0HScrollH ; palette offset

	; load static image
	LOADFILE "TITLECARD.VBM", 0, $0000, 0
	LOADFILE "TITLECARD.PAL", 0, $0400 ; put palette in golden RAM

	; show bitmap layers
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$10
	sta Vera::Reg::DCVideo

	; split xRGB values out of the first 64 palette entries
	ldx #0
	ldy #0
palexpand:
	lda $0400,x
	and #$0f
	sta $0600,y
	iny
	lda $0400,x
	lsr
	lsr
	lsr
	lsr
	sta $0600,y
	inx
	iny
	bne palexpand

	; make the palette shadow all F's
	ldx #0
palshadow:
	lda #$f0
	sta $0700,x
	inx
	sta $0700,x
	inx
	sta $0700,x
	inx
	stz $0700,x
	inx
	bne palshadow


	lda #16
	sta paliter
	; fade palette in
palloop:
	; subtract 1/16 the difference from white from the shadow
	ldx #0
	ldy #0
innerpal:
	lda #$0f
	sec
	sbc $0600,x
	sta DT1

	lda $0700,x
	sbc #$ff
DT1 = * - 1
	sta $0700,x
	lsr
	lsr
	lsr
	lsr
	sta $0400,y
	inx

	; skip high nibble in palette word
	tya
	lsr
	bcs nohigh

	lda #$0f
	sec
	sbc $0600,x
	sta DT2

	lda $0700,x
	sbc #$ff
DT2 = * - 1
	sta $0700,x
	and #$f0
	ora $0400,y
	sta $0400,y
nohigh:
	iny
	inx
	bne innerpal

	lda #4
	sta vsync_count
:	WAITVSYNC
	dec vsync_count
	bne :-

	; write palette shadow to VERA
	VERA_SET_ADDR $1FA00, 1
	ldx #128
shadowpal:
	lda $0400-128,x
	sta Vera::Reg::Data0
	inx
	bne shadowpal

	dec paliter
	bne palloop


	lda #0
	sta X16::Reg::ROMBank
	jsr X16::Kernal::PRIMM
	.byte "INTRO SCENE",13,0

	rts
paliter:
	.byte 0
vsync_count:
	.byte 0
.endproc
