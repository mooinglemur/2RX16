.import setup_palette_fade
.import setup_palette_fade2
.import setup_palette_fade3
.import setup_palette_fade4

.import apply_palette_fade_step
.import apply_palette_fade_step2
.import apply_palette_fade_step3
.import apply_palette_fade_step4

.import flush_palette
.import flush_palette2
.import flush_palette3
.import flush_palette4

.import target_palette
.import target_palette2
.import target_palette3
.import target_palette4

.import graceful_fail

.macpack longbranch

TILES0 = $00000
TILES1 = $08000

MAP0 = $10000
MAP1 = $18000

.include "x16.inc"
.include "macros.inc"

.segment "CREW"
entry:
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	pha ; preserve old video mode so that we can
	; restore it to 240p if we had it set that way
	; since this part of the demo is high res

	jsr blank_upper

	LOADFILE "CREW.PAL", 0, target_palette
	LOADFILE "CREWTILES0.DAT", 0, .loword(TILES0), ^TILES0
	LOADFILE "CREWTILES1.DAT", 0, .loword(TILES1), ^TILES1
	LOADFILE "CREWMAP0.DAT", 0, .loword(MAP0), ^MAP0
	LOADFILE "CREWMAP1.DAT", 0, .loword(MAP1), ^MAP1

	WAITVSYNC

	; Disable 240p, activate layers 0 and 1
	lda Vera::Reg::DCVideo
	and #%00000111
	ora #%00110000
	sta Vera::Reg::DCVideo

	; Set scale
	lda #$80
	sta Vera::Reg::DCVScale
	sta Vera::Reg::DCHScale

	; Setup L0/L1
	lda #%01100010
	sta Vera::Reg::L0Config
	sta Vera::Reg::L1Config

	lda #((TILES0 >> 11) << 2)
	sta Vera::Reg::L0TileBase

	lda #((TILES1 >> 11) << 2)
	sta Vera::Reg::L1TileBase

	lda #(MAP0 >> 9)
	sta Vera::Reg::L0MapBase

	lda #(MAP1 >> 9)
	sta Vera::Reg::L1MapBase

	lda #$38
	sta Vera::Reg::L1VScrollL

	lda #$ff
	sta Vera::Reg::L1VScrollH

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	PALETTE_FADE_FULL 1

	MUSIC_SYNC $E0

	ldx #0
:	stz target_palette,x
	stz target_palette3,x
	inx
	bne :-

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	PALETTE_FADE_FULL 1

	pla
	sta Vera::Reg::DCVideo

	stz Vera::Reg::L1VScrollL
	stz Vera::Reg::L1VScrollH

	rts

.proc blank_upper
	VERA_SET_ADDR $10000, 1

	ldy #$f9
	ldx #0
:	stz Vera::Reg::Data0
	dex
	bne :-
	dey
	bne :-
	rts
.endproc
