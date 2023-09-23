.include "x16.inc"
.include "macros.inc"

.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.segment "INTRO"
entry:
	jmp titlecard


.proc titlecard

	ldx #128
blackpal:
	stz target_palette-128,x
	inx
	bne blackpal

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 3

	; load BG tiles
	LOADFILE "TITLEBG.VTS", 0, $0000, 0
	LOADFILE "TITLEBG.PAL", 0, target_palette

	; show no layers 
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	sta Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; 320x240
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; set up layer 0 as tilemap
	lda #%00010010 ; 4bpp 64x32
	sta Vera::Reg::L0Config
	lda #%00000011 ; $00000 16x16
	sta Vera::Reg::L0TileBase
	; mapbase is at $0D000
	lda #($0D000 >> 9)
	sta Vera::Reg::L0MapBase


	; put the tiles in place
	VERA_SET_ADDR $D000, 1

	ldy #64
tbgtloopi:
	lda #<400
	sta Vera::Reg::Data0
	lda #>400
	sta Vera::Reg::Data0
	dey
	bne tbgtloopi

	stz tileno
	stz tileno+1

tbgtloop0:
	ldy #40
tbgtloop1:
	lda tileno
	sta Vera::Reg::Data0
	lda tileno+1
	sta Vera::Reg::Data0
	inc tileno
	bne :+
	inc tileno+1
:	dey
	bne tbgtloop1
	ldy #24
	lda tileno+1
	beq tbgtloop3
	lda tileno
	cmp #<400
	bcc tbgtloop3
	ldy #0
tbgtloop2:
	lda #<400
	sta Vera::Reg::Data0
	lda #>400
	sta Vera::Reg::Data0
	dey
	bne tbgtloop2
	bra tbgtloop4
tbgtloop3:
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	dey
	bne tbgtloop3
	bra tbgtloop0
tbgtloop4:


	WAITVSYNC ; prevent showing glitched previous state of layer

	; enable layer 0 + sprites
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$50
	sta Vera::Reg::DCVideo


	; first few text cards go here

	MUSIC_SYNC $06

	lda #0
	jsr setup_palette_fade

	; slow scroll during fade-in

tbgscrollloop:
	WAITVSYNC
	inc frameno

	lda frameno
	and #3
	bne nopal

	jsr apply_palette_fade_step
	jsr flush_palette

nopal:
	lda frameno
	and #7
	bne noscroll
	; should we scroll?
	lda Vera::Reg::L0HScrollH
	and #$0f
	beq doscroll
	lda Vera::Reg::L0HScrollL
	cmp #<320
	bcs noscroll
doscroll:
	inc Vera::Reg::L0HScrollL
	bne noscroll
	inc Vera::Reg::L0HScrollH
noscroll:


	lda syncval
	cmp #$0e 	
	bne tbgscrollloop
	; MUSIC_SYNC $0E

	; write all Fs to first 64 of palette
	ldx #128
	
whitepal:
	lda #$ff
	sta target_palette-128,x
	inx
	lda #$0f
	sta target_palette-128,x
	inx
	bne whitepal

	lda #0
	jsr setup_palette_fade

	lda #16
	sta FW

	; this doesn't fade correctly in current ROM (R44)
	; if it's the beginning of the demo because
	; the VERA palette and backing VRAM are divergent
fadetowhite:
	WAITVSYNC
	WAITVSYNC
	WAITVSYNC
	jsr apply_palette_fade_step
	jsr flush_palette
	dec FW
	lda #$ff
FW = * - 1
	bne fadetowhite

	MUSIC_SYNC $0F

	; set bitmap mode for layer 1
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L1Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L1TileBase
	stz Vera::Reg::L1HScrollH ; palette offset

	; load static image
	LOADFILE "TITLECARD.VBM", 0, $0000, 0
	LOADFILE "TITLECARD.PAL", 0, target_palette

	; show bitmap layer
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$20
	sta Vera::Reg::DCVideo

	lda #0 ; set up first 64 palette entries to fade
	jsr setup_palette_fade

	PALETTE_FADE 5

	rts
tileno:
	.res 2
frameno:
	.res 0
.endproc
