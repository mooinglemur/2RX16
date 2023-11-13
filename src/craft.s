.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "CRAFT"
entry:
	; fade to yellowish

	ldx #32
:   lda #$0d
	sta target_palette-1,x
	dex
	lda #$d8
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	MUSIC_SYNC $D4

	ldx #32
:   stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	rts
