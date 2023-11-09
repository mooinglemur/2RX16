.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "CREATURE"
entry:
	; fade to orange

	ldx #32
:   lda #$0f
	sta target_palette-1,x
	dex
	lda #$b5
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	MUSIC_SYNC $6F

	ldx #32
:   stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	rts
