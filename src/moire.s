.import graceful_fail

.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "MOIRE"
entry:
	; fade to white

	VERA_SET_ADDR (31+(Vera::VRAM_palette)), -1

	; set palette to white

	ldx #30
:   lda #$0f
	sta target_palette+1,x
	sta Vera::Reg::Data0
	dex
	lda #$ff
	sta target_palette+1,x
	sta Vera::Reg::Data0
	dex
	bne :-

	; set bitmap mode for layer 0
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	lda #0
	sta Vera::Reg::L0HScrollH ; palette offset

	; set up cache
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #$40
	sta Vera::Reg::FXCtrl

	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	lda #$11
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c
	stz Vera::Reg::Ctrl

	; write the whole buffer
	VERA_SET_ADDR $00000, 3

	ldy #4 ; 32kB
	ldx #0  ; 8kB per loop (256 * 32 w/ cache)
clearloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne clearloop
	dey
	bne clearloop

	; set up cache with wipe color
	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	lda #$22
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c

	; disable FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	MUSIC_SYNC $41
	
	; do wipe 1
	lda #0
	jsr wipe

	MUSIC_SYNC $42
	
	; do wipe 2
	lda #80
	jsr wipe

	MUSIC_SYNC $43
	
	; do wipe 3
	lda #160
	jsr wipe

	MUSIC_SYNC $44
	
	; do wipe 4
	lda #240
	jsr wipe



	LOADFILE "PLACEHOLDER_MOIRE.VBM", 0, $0000, 0 ; $00000 VRAM

	MUSIC_SYNC $45

	LOADFILE "PLACEHOLDER_MOIRE.PAL", 0, target_palette

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	MUSIC_SYNC $50

	ldx #32
:   stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1


	rts


.proc wipe
	lsr
	sta xoff
	stz row

	; set target palette to white

	lda #$0f
	sta target_palette+3
	sta target_palette+5
	lda #$ff
	sta target_palette+2
	sta target_palette+4

	lda #0
	jsr setup_palette_fade

.repeat 4
	jsr apply_palette_fade_step
.endrepeat    
	WAITVSYNC
	jsr flush_palette

.repeat 4
	jsr apply_palette_fade_step
.endrepeat    
	WAITVSYNC
	jsr flush_palette

.repeat 4
	jsr apply_palette_fade_step
.endrepeat    
	WAITVSYNC
	jsr flush_palette

.repeat 4
	jsr apply_palette_fade_step
.endrepeat    
	WAITVSYNC
	jsr flush_palette

	; skyblue
	lda #$0a
	sta target_palette+3
	lda #$df
	sta target_palette+2

	; black
	stz target_palette+5
	stz target_palette+4

	lda #0
	jsr setup_palette_fade  

	lda #12
	sta rowto
fadeoutloop:
.repeat 2
	jsr apply_palette_fade_step
.endrepeat
	WAITVSYNC
	jsr flush_palette

	lda rowto
	jsr wipeto
	lda rowto
	cmp #96 ; set carry each iteration at/after 96, bringing total to 200 after 16
	adc #12
	sta rowto
	cmp #201 ; stop *after* 200
	bcc fadeoutloop

	rts
rowto:
	.byte 0

wipeto:
	sta @STOP_ROW
	lda #$30
	sta Vera::Reg::AddrH

	; set up cache
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #$40
	sta Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl
@loop:
	ldx row
	lda xoff
	clc
	adc addrl_per_row_4bit,x
    sta Vera::Reg::AddrL
    lda addrm_per_row_4bit,x
	adc #0
    sta Vera::Reg::AddrM
	lda #$22
.repeat 10
	stz Vera::Reg::Data0
.endrepeat
	lda row
	inc
	sta row
	cmp #$ff
@STOP_ROW = * - 1
	bcc @loop

	; end FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl


	rts
xoff:
	.byte 0
row:
	.byte 0
.endproc
