.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette
.import cycle_palette

.import target_palette

.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.include "flow.inc"

.segment "CIRCLES"
entry:

	jsr circles_init

	LOADFILE "CIRCLES1.VTS", 0, $0000, 0 ; $00000 VRAM

.ifndef SKIP_TUNNEL
	MUSIC_SYNC $32
.endif

	jsr circles1_palette_cycle

	LOADFILE "CIRCLES2A.VTS", 0, $8000, 0 ; $08000 VRAM
	LOADFILE "CIRCLES2B.VTS", 0, $0000, 1 ; $10000 VRAM

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

; tables for tile maps

.include "circles.inc"

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

	VERA_SET_ADDR (Vera::VRAM_palette), 1

	; blank palette
	ldx #0
:   stz target_palette,x
	stz Vera::Reg::Data0
	inx
	bpl :-

	VERA_SET_ADDR $18000, 1
	
	; populate tile maps
	ldx #0
tilemaploop:
	lda map1tbl,x
MAPTBL = * - 2
	sta Vera::Reg::Data0
	inx
	bne tilemaploop
	lda MAPTBL+1
	inc
	sta MAPTBL+1
	cmp #>(map1tbl + $1000) ; 4kb
	bcc tilemaploop

	; set only layer 0 visible
	lda #$10
	tsb Vera::Reg::DCVideo
	lda #$60
	trb Vera::Reg::DCVideo

	; set tile mode for layer 0
	lda #%00000010 ; 4bpp
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 3
	sta Vera::Reg::L0TileBase

	lda #(($18000 >> 9))
	sta Vera::Reg::L0MapBase

	lda #96 ; H scroll to center
	sta Vera::Reg::L0HScrollL
	stz Vera::Reg::L0HScrollH

	lda #156 ; V scroll to center
	sta Vera::Reg::L0VScrollL
	stz Vera::Reg::L0VScrollH

	; set tile mode for layer 1
	lda #%00000010 ; 4bpp
	sta Vera::Reg::L1Config
	lda #(($08000 >> 11) << 2) | 3
	sta Vera::Reg::L1TileBase

	lda #(($18800 >> 9))
	sta Vera::Reg::L1MapBase

	stz Vera::Reg::L1HScrollL
	stz Vera::Reg::L1HScrollH

	stz Vera::Reg::L1VScrollL
	stz Vera::Reg::L1VScrollH


	rts
.endproc
