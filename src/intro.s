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
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop

	; set bitmap mode for layer 0
	lda #%00000111
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	stz Vera::Reg::L0HScrollH ; palette offset

	; load static image
	LOADFILE "TITLECARD.VBM", 0, $0000, 0
	LOADFILE "TITLECARD.PAL", 0, target_palette

	; show bitmap layers
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$10
	sta Vera::Reg::DCVideo

	lda #16
	sta paliter

	lda #0 ; set up first 64 palette entries to fade
	jsr setup_palette_fade
	
pal_loop:
	jsr apply_palette_fade_step

	; this many VSYNCs in between palette fade updates
	lda #6
	sta vsync_count
:	WAITVSYNC
	dec vsync_count
	bne :-

	jsr flush_palette
	dec paliter
	bne pal_loop


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
