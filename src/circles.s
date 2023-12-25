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

	LOADFILE "CIRCLES2.VTS", 0, $8000, 0 ; $08000 VRAM

.ifndef SKIP_TUNNEL
	MUSIC_SYNC $34
.endif

	jsr circles12_dance

	; disable layer 1
	lda #$20
	trb Vera::Reg::DCVideo

	rts

; tables for tile maps

.include "circles.inc"

.proc circles12_dance
	WAITVSYNC

	; set the palette
	VERA_SET_ADDR (Vera::VRAM_palette), 1
	ldx #0
palloop:
	lda initial_palette,x
	sta target_palette,x
	sta Vera::Reg::Data0
	inx
	cpx #64
	bcc palloop

	lda #0
	jsr setup_palette_fade

	; show layer 1
	lda #$20
	tsb Vera::Reg::DCVideo


main_dance:
	ldx l0_offset

	clc
	lda #96-50
	adc sinmap1_x,x
	sta Vera::Reg::L0HScrollL
	lda #0
	adc #0
	sta Vera::Reg::L0HScrollH

	lda #156-50
	adc sinmap1_y,x
	sta Vera::Reg::L0VScrollL
	lda #0
	adc #0
	sta Vera::Reg::L0VScrollH

	ldx l1_offset

	lda #96-50
	adc sinmap2_x,x
	sta Vera::Reg::L1HScrollL
	lda #0
	adc #0
	sta Vera::Reg::L1HScrollH

	lda #156-50
	adc sinmap2_y,x
	sta Vera::Reg::L1VScrollL
	lda #0
	adc #0
	sta Vera::Reg::L1VScrollH

	WAITVSYNC
	lda #1
	ldx #6
	jsr cycle_palette

	; cycle l1 palette less often

	lda l0_offset
	and #3
	bne :+

	lda #1+16
	ldx #6
	jsr cycle_palette
:	jsr flush_palette

	inc l0_offset ; wraps around to 256
	lda l1_offset
	inc
	cmp #199
	bcc :+
	lda #0
:	sta l1_offset

	lda syncval
	cmp #$40
	bcc main_dance

	lda paliter
	cmp #16
	bne apply_step
	; set up the fade to white

	ldx #62
:   lda #$0f
	sta target_palette+1,x
	dex
	lda #$ff
	sta target_palette+1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

apply_step:
	jsr apply_palette_fade_step
	jsr flush_palette
	dec paliter
	jne main_dance

	rts
l0_offset:
	.byte 64
l1_offset:
	.byte 150
paliter:
	.byte 16


initial_palette:
	; for layer 0
	.word $0000,$0fff,$0bbb,$0888,$0555,$0000,$0222,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	; for layer 1
	.word $0000,$0eae,$0969,$0c9c,$0868,$0a7a,$0757,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
.endproc

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

sin50tbl:
