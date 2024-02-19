.import graceful_fail

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

	MUSIC_SYNC $4A

	jsr slide_off

	LOADFILE "PANICPIC.VBM", 0, $0000, 0 ; $00000 VRAM
	LOADFILE "PANICPIC.PAL", 0, target_palette

	VERA_SET_ADDR Vera::VRAM_palette, 1
	ldx #0
panicpal_set:
	lda target_palette,x
	sta Vera::Reg::Data0
	inx
	bne panicpal_set

	; set bitmap mode for layer 0
	lda #%00000111 ; 8bpp
	sta Vera::Reg::L0Config

	MUSIC_SYNC $4C

	jsr slide_on

	MUSIC_SYNC $50

	ldx #0
:   stz target_palette,x
	inx
	bne :-

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2


	PALETTE_FADE_1_2 1

	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	stz Vera::Reg::DCHStart
	stz Vera::Reg::Ctrl

	rts

.proc slide_on
	ldx #0
slideloop:
	phx
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	WAITVSYNC
	jsr flush_palette
	jsr flush_palette2
	plx
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda slide_on_hstart,x
	sta Vera::Reg::DCHStart
	stz Vera::Reg::Ctrl
	inx
	cpx #32
	beq flash
	cpx #48
	bcc slideloop

	rts
flash:
	VERA_SET_ADDR Vera::VRAM_palette, 1
	ldy #128
flashloop:
	lda #$ff
	sta Vera::Reg::Data0
	lda #$0f
	sta Vera::Reg::Data0
	dey
	bne flashloop

	phx
	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	plx
	bra slideloop

slide_on_hstart:
	.byte $a0,$9c,$98,$93
	.byte $8f,$8b,$87,$82
	.byte $7e,$7a,$76,$71
	.byte $6d,$69,$65,$60
	.byte $5c,$58,$54,$4f
	.byte $4b,$47,$43,$3e
	.byte $3a,$36,$32,$2d
	.byte $29,$25,$21,$1c
	.byte $18,$14,$12,$14
	.byte $18,$1c,$1a,$18
	.byte $16,$14,$12,$13
	.byte $14,$15,$14,$14
.endproc

.proc slide_off
	ldx #0
slideloop:
	phx
	WAITVSYNC
	plx
	lda #(1 << 1) ; DCSEL=1
	sta Vera::Reg::Ctrl
	lda slide_off_hstart,x
	sta Vera::Reg::DCHStart
	stz Vera::Reg::Ctrl
	inx
	cpx #35
	bcc slideloop

	rts

slide_off_hstart:
	.byte 0,1,2,3,4,5,6,8
	.byte 11,13,16,19,22,26,29,33
	.byte 38,42,47,52,58,63,69,75
	.byte 82,88,95,102,110,118,126,134
	.byte 142,151,160
.endproc


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
