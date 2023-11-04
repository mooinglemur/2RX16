.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette
.import cycle_palette

.import target_palette

.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "CIRCLES"
entry:

	jsr circles_init

	LOADFILE "CIRCLES1.VBM", 0, $0000, 0 ; $00000 VRAM

	MUSIC_SYNC $32

	jsr circles1_palette_cycle

	MUSIC_SYNC $34

	; overlapping

	MUSIC_SYNC $40

	; fade to white

	ldx #32
:   lda #$0f
	sta target_palette-1,x
	dex
	lda #$ff
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1


	rts


.proc circles1_palette_cycle
	lda #$8b
	sta target_palette+2
	lda #$49
	sta target_palette+4

	lda #0
	jsr setup_palette_fade

fade_in_loop:
	WAITVSYNC
	lda #1
	ldx #6
	jsr cycle_palette
	jsr apply_palette_fade_step
	jsr flush_palette

	WAITVSYNC
	lda #1
	ldx #6
	jsr cycle_palette
	jsr flush_palette

	dec fade_in
	bne fade_in_loop
hold_loop:
	WAITVSYNC
	lda #1
	ldx #6
	jsr cycle_palette
	jsr flush_palette

	dec hold
	bne hold_loop

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

fade_out_loop:
	WAITVSYNC
	lda #1
	ldx #6
	jsr cycle_palette
	jsr apply_palette_fade_step
	jsr flush_palette

	WAITVSYNC
	lda #1
	ldx #6
	jsr cycle_palette
	jsr flush_palette

	dec fade_out
	bne fade_out_loop

	rts
palette_offset:
	.byte 0
fade_in:
	.byte 16
fade_out:
	.byte 16
hold:
	.byte 108
.endproc


.proc circles_init
	; turn FX off

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	; set bitmap mode for layer 1
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L1Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L1TileBase
	lda #0
	sta Vera::Reg::L1HScrollH ; palette offset

	VERA_SET_ADDR (Vera::VRAM_palette), 1

	ldx #0
:   stz target_palette,x
	stz Vera::Reg::Data0
	inx
	bpl :-


	rts
.endproc
