.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import graceful_fail

.import target_palette

BALLTABLE1_BANK = $30
BALLTABLE2_BANK = $20 ; $20 as a base is baked into pre-gen data in BALLTABLE1 by python code

.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "BALLS"
entry:
	LOADFILE "BALLTABLE1.DAT", BALLTABLE1_BANK, $A000
	LOADFILE "BALLTABLE2.DAT", BALLTABLE2_BANK, $A000



	; fade to grey

	ldx #32
:   lda #$0a
	sta target_palette-1,x
	dex
	lda #$aa
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	MUSIC_SYNC $9C

	ldx #32
:   stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	rts
