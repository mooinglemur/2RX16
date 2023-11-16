.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "CREDITS"
entry:
	; fade to white

	ldx #32
:	lda #$0f
	sta target_palette-1,x
	dex
	lda #$ff
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	; about the duration of the music
	ldy #70
	ldx #0
:	phx
	phy
	WAITVSYNC
	ply
	plx
	dex
	bne :-
	dey
	bne :-

	ldx #32
:	stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	rts
