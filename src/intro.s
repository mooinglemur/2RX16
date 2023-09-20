.include "x16.inc"
.include "macros.inc"

.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.segment "INTRO"
entry:
	jmp titlecard


.proc titlecard
	; write all Fs to first 64 of palette
	ldx #128
	
	
whitepal:
	lda #$ff
	sta target_palette-128,x
	inx
	lda #$0f
	sta target_palette-128,x
	inx
	bne whitepal

	lda #0
	jsr setup_palette_fade

	lda #16
	sta FW

	; this doesn't fade correctly in current ROM (R44)
	; if it's the beginning of the demo because
	; the VERA palette and backing VRAM are divergent
fadetowhite:
	WAITVSYNC
	WAITVSYNC
	WAITVSYNC
	jsr apply_palette_fade_step
	jsr flush_palette
	dec FW
	lda #$ff
FW = * - 1
	bne fadetowhite

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
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop

	; set bitmap mode for layer 1
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L1Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L1TileBase
	stz Vera::Reg::L1HScrollH ; palette offset

	; load static image
	LOADFILE "TITLECARD.VBM", 0, $0000, 0
	LOADFILE "TITLECARD.PAL", 0, target_palette

	; show bitmap layer
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$20
	sta Vera::Reg::DCVideo

	lda #16
	sta paliter

	lda #0 ; set up first 64 palette entries to fade
	jsr setup_palette_fade

	PALETTE_FADE 6	

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
