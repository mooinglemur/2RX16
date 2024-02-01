.include "x16.inc"
.include "macros.inc"

.include "flow.inc"

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
.feature string_escapes

TEMP_4BPP_BMP_ADDR = $18000
TILE_MAPBASE = $0D000
SHOCKWAVE_FX_TILEBASE = $19000
SHOCKWAVE_FX_TILEMAP = $18000
SCRATCH_BANK = $20

.segment "INTRO_ZP": zeropage
frameno:
	.res 1
tmpptr:
	.res 2
scratch:
	.res 1
fx_y_val:
	.res 2


.segment "INTRO_BSS"
tileno:
	.res 2
lastsync:
	.res 1
text_linger:
	.res 1
bmprow:
	.res 1
tiletmp:
	.res 2

.segment "INTRO"
entry:
	; memory init
	stz frameno

	jsr setup_vera_and_tiles
.ifdef SKIP_SONG1
	bra dotitilecard ; jump ahead to song 2 if set in main
.endif
	jsr opening_text
	jsr bgscroller_with_text
	jsr prepare_for_ship
	; do 3D ship stuff
	jsr prepare_for_praxis
	MUSIC_SYNC $0d
	jsr praxis_explosion

	MUSIC_SYNC $0F
dotitilecard:
	jmp titlecard
	; tail call

.proc setup_vera_and_tiles
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

	; load title font
	LOADFILE "TITLEFONT.VTS", 0, $0000, 1

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
	lda #20
	sta Vera::Reg::DCVStart
	lda #($f0 - 20 - 1)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::DCHStart
	lda #$a0
	sta Vera::Reg::DCHStop
	stz Vera::Reg::Ctrl

	; set up layer 0 as tilemap
	lda #%00010010 ; 4bpp 64x32
	sta Vera::Reg::L0Config
	lda #%00000011 ; $00000 16x16
	sta Vera::Reg::L0TileBase
	; mapbase is at $0D000
	lda #(TILE_MAPBASE >> 9)
	sta Vera::Reg::L0MapBase

	; put the tiles in place
	VERA_SET_ADDR TILE_MAPBASE, 1

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
	DISABLE_SPRITES

	WAITVSYNC ; prevent showing glitched previous state of layer

	; enable layer 0 + sprites
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$50
	sta Vera::Reg::DCVideo

	rts
.endproc

.proc opening_text
	; first few text cards go here

	lda syncval
	sta lastsync
prebgloop:
	WAITVSYNC
	inc frameno
	lda syncval
	cmp lastsync
	jeq nosync
	
	sta lastsync
	cmp #3
	beq card1
	cmp #4
	beq card2
	cmp #5
	jeq card3
	cmp #6
	jne nosync
	rts
card1:
	SPRITE_TEXT 1, 40, 80, 1, "A Commander X16"
	SPRITE_TEXT 18, 70, 100, 1, "and VERA FX"
	SPRITE_TEXT 36, 100, 120, 1, "showcase"
	jmp docolor
card2:
	SPRITE_TEXT 1, 35, 70, 1, "Sneak preview for"
	SPRITE_TEXT 18, 65, 90, 1, "your exclusive"
	SPRITE_TEXT 36, 83, 110, 1, "review and"
	SPRITE_TEXT 54, 93, 130, 1, "enjoyment"
	bra docolor
card3:
	SPRITE_TEXT 1, 150, 70, 1, "in"
	SPRITE_TEXT 18, 50, 100, 1, "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e"
	bra docolor
docolor:
	lda #$55
	sta target_palette+2
	lda #$05
	sta target_palette+3
	lda #$aa
	sta target_palette+4
	lda #$0a
	sta target_palette+5
	lda #$ff
	sta target_palette+6
	lda #$0f
	sta target_palette+7
	lda #16
	jsr setup_palette_fade
	lda #160
	sta text_linger
nosync:
	lda frameno
	and #1
	jne prebgloop
	jsr apply_palette_fade_step
	jsr flush_palette

	lda text_linger
	jeq prebgloop
	cmp #16
	beq text_fadeout
	dec text_linger
	jne prebgloop

	; we just faded out.  Hide sprites
	DISABLE_SPRITES
	jmp prebgloop
text_fadeout:
	dec text_linger
	; switch to fading it out
	lda #$11
	sta target_palette+2
	stz target_palette+4
	stz target_palette+6
	lda #$01
	sta target_palette+3
	sta target_palette+5
	sta target_palette+7

	lda #16
	jsr setup_palette_fade

	jmp prebgloop
.endproc

.proc bgscroller_with_text
	ldx #32
:	lda titlepal-1,x
	sta target_palette-1,x
	dex
	bne :-

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
	bcc doscroll
	; we scroll-stopped, next sub to shuffle tiles around to high VRAM
	rts
doscroll:
	inc Vera::Reg::L0HScrollL
	bne noscroll
	inc Vera::Reg::L0HScrollH
noscroll:
	lda syncval
	cmp lastsync
	jeq nosync1
	
	sta lastsync

	cmp #7
	beq card4
	cmp #8
	jeq card5
	cmp #9
	jeq card6
	cmp #$0a
	jeq card7
	cmp #$0e
	bne tbgscrollloop
	rts
card4:
	SPRITE_TEXT 1, 110, 50, 1,  "VERA FX"
	SPRITE_TEXT 18, 110, 80, 1, "JeffreyH"
	jmp docolor1
card5:
	SPRITE_TEXT 1, 128, 40, 1, "Music"
	SPRITE_TEXT 18, 82, 70, 1, "arranged by"
	SPRITE_TEXT 36, 80, 100, 1, "MooingLemur"
	jmp docolor1
card6:
	SPRITE_TEXT 1, 130, 40, 1, "Code"
	SPRITE_TEXT 18, 80, 70, 1, "MooingLemur"
	SPRITE_TEXT 36, 100, 100, 1, "JeffreyH"
	bra docolor1
card7:
	SPRITE_TEXT 1, 90, 40, 1,    "Inspired by"
	SPRITE_TEXT 18, 75, 70, 1,  "Second Reality"
	SPRITE_TEXT 37, 60, 97, 1,  "by Future Crew"
	bra docolor1
docolor1:
	lda #$55
	sta target_palette+2
	lda #$05
	sta target_palette+3
	lda #$aa
	sta target_palette+4
	lda #$0a
	sta target_palette+5
	lda #$ff
	sta target_palette+6
	lda #$0f
	sta target_palette+7
	lda #16
	jsr setup_palette_fade
	lda #160
	sta text_linger
nosync1:
	lda frameno
	and #3
	cmp #1
	jne skippal

	jsr apply_palette_fade_step
	jsr flush_palette

skippal:
	lda frameno
	and #1
	jne tbgscrollloop

	lda text_linger
	jeq tbgscrollloop
	cmp #16
	beq text_fadeout1
	dec text_linger
	jne tbgscrollloop

	; we just faded out.  Hide sprites
	DISABLE_SPRITES
	jmp tbgscrollloop
text_fadeout1:
	dec text_linger
	; switch to fading it out
	lda #$11
	sta target_palette+2
	stz target_palette+4
	stz target_palette+6
	lda #$01
	sta target_palette+3
	sta target_palette+5
	sta target_palette+7

	lda #16
	jsr setup_palette_fade

	jmp tbgscrollloop
.endproc

.proc prepare_for_ship
	; we're done with the text sprites entirely
	; but in case we're out of sync, disable the sprites
	; explicitly here
	DISABLE_SPRITES
	
	; copy the tile data for what is visible on screen now to a 4bpp bitmap
	; which can fit in just under 32k
	; We have plenty of time, so we can afford for this to take a few frames

	; point DATA1 to our destination
	lda #1
	sta Vera::Reg::Ctrl
	
	VERA_SET_ADDR TEMP_4BPP_BMP_ADDR, 3 ; we'll take advantage of cache writes

	lda #(2 << 1)
	sta Vera::Reg::Ctrl ; DCSEL=2

	lda #$60
	sta Vera::Reg::FXCtrl
	stz $9f2c ; reset cache index

	stz Vera::Reg::Ctrl

	stz bmprow
	stz tileno ; repurposing this: which tile are we on in this row
tile2bmploop:
	lda bmprow
	; divide by 16 to get tile row
	; then multiply by 64 to get tile index
	; this is collapsed to
	; - drop low nibble
	; - multiply by 4
	; multiply by 2 to get index
	and #$f0
	stz tiletmp+1
.repeat 3
	asl
	rol tiletmp+1
.endrepeat
	adc #38 ; first tile is 19 tiles (38 bytes) in on this row
	sta tiletmp
	lda tiletmp+1
	adc #0
	sta tiletmp+1

	; add this row's tile index
	lda tileno
	asl ; account for each tile idx taking two bytes
	adc tiletmp
	sta tiletmp
	lda tiletmp+1
	adc #0
	sta tiletmp+1

	; point to tilemap
	lda #<TILE_MAPBASE
	; no carry expected
	adc tiletmp
	sta Vera::Reg::AddrL
	lda #>TILE_MAPBASE
	adc tiletmp+1
	sta Vera::Reg::AddrM
	lda #(^TILE_MAPBASE | $10)
	sta Vera::Reg::AddrH

	; find the offset within the tile
	; which is bmprow mod 16
	; multiplied by 8
	lda bmprow
	and #$0f
	asl
	asl
	asl
	sta tiletmp+1

	; two dummy reads to realign the FX cache index
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	; extract the tile index
	lda Vera::Reg::Data0
	sta tiletmp
	lda Vera::Reg::Data0
	and #$03

	; multiply the tile index by 128 (8 bytes per row x 16 rows)
	; which means we can instead divide by 2
	lsr
	ror tiletmp
	lda #0
	ror
	
	; .A contains either $80 or $00
	; tile data source is $00000
	; add the offset within the tile
	adc tiletmp+1
	sta Vera::Reg::AddrL
	lda tiletmp
	; no carry expected
	sta Vera::Reg::AddrM
	lda #$10
	sta Vera::Reg::AddrH

	; copy the data
.repeat 2
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0
	stz Vera::Reg::Data1
.endrepeat

	inc tileno
	lda tileno
	cmp #20
	jcc tile2bmploop
	stz tileno
	inc bmprow
	lda bmprow
	cmp #196
	jcc tile2bmploop

	; turn off FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl ; DCSEL=2

	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	; we're done with the tile -> bitmap conversion
	WAITVSYNC

	; let's repoint layer 0 to the bitmap
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L0Config
	lda #((TEMP_4BPP_BMP_ADDR >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	lda #0
	sta Vera::Reg::L0HScrollH ; palette offset

	; also let's set VSTOP earlier so we're clear of the registar area of VRAM
	lda #%00000010  ; DCSEL=1
	sta Vera::Reg::Ctrl
   
	lda #20
	sta Vera::Reg::DCVStart
	lda #192+20-1
	sta Vera::Reg::DCVStop
	
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc prepare_for_praxis
	; now transition 4bpp bitmap to 8bpp bitmap

	VERA_SET_ADDR $00000, 1
	
	lda #1
	sta Vera::Reg::Ctrl

	VERA_SET_ADDR TEMP_4BPP_BMP_ADDR, 1

	stz Vera::Reg::Ctrl

	ldy #>32000
	ldx #<32000
bmp4to8loop:
	lda Vera::Reg::Data1
	pha
	lsr
	lsr
	lsr
	lsr
	sta Vera::Reg::Data0
	pla
	and #$0f
	sta Vera::Reg::Data0
	dex
	bne bmp4to8loop
	dey
	bne bmp4to8loop

	WAITVSYNC

	; let's repoint layers to the 8bpp bitmap

	lda #%00000111 ; 8bpp
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	lda #0
	sta Vera::Reg::L0HScrollH ; palette offset

	; now we can load the shockwave FX tiles (uncooked)
	LOADFILE "INTRO-SHOCK.VTS", SCRATCH_BANK, $A000

	; now cook the tiles
	lda #SCRATCH_BANK
	sta X16::Reg::RAMBank

	lda #<$a000
	sta tmpptr

	lda #>$a000
	sta tmpptr+1

	VERA_SET_ADDR SHOCKWAVE_FX_TILEBASE, 1
cookloop:
	lda (tmpptr)
	and #$70
	sta scratch
	lsr
	lsr
	lsr
	lsr
	ora scratch
	sta Vera::Reg::Data0

	lda (tmpptr)
	and #$07
	sta scratch
	asl
	asl
	asl
	asl
	ora scratch
	sta Vera::Reg::Data0

	inc tmpptr
	bne cookloop
	inc tmpptr+1
	lda tmpptr+1
	cmp #$b0
	bcc cookloop

	; create the 32x4 tile map (fill out the rest of the 32x32 map with zeroes)
	VERA_SET_ADDR SHOCKWAVE_FX_TILEMAP, 1

	ldx #0
shockmap_loop:
	stx Vera::Reg::Data0
	inx
	bne shockmap_loop

	ldx #0
shockmap_zeroes:
.repeat 3
	stz Vera::Reg::Data0
.endrepeat
	inx
	bne shockmap_zeroes

	rts
.endproc

.proc praxis_explosion
	WAITVSYNC

	; set palette to $ddd
	VERA_SET_ADDR (Vera::VRAM_palette), 1
	ldx #64
	ldy #$0d
	lda #$dd
:	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	dex
	bne :-	

	WAITVSYNC

	; set palette to $fff
	VERA_SET_ADDR (Vera::VRAM_palette), 1
	ldx #64
	ldy #$0f
	lda #$ff
:	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	dex
	bne :-	

	; let's copy the palette into the target
	ldx #0
pal1:
	lda praxispal,x
	sta target_palette,x
	inx
	bne pal1
pal2:
	lda praxispal+256,x
	sta target_palette3,x
	inx
	bne pal2

	; for fading back in

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	stz frameno
temploop:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	jsr apply_palette_fade_step3
	jsr apply_palette_fade_step4

	; set up FX affine stuff for next frame
	; but leave FX itself disabled
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	lda #((SHOCKWAVE_FX_TILEBASE >> 11) << 2) | $02 ; affine clip enable
	sta Vera::Reg::FXTileBase

	lda #((SHOCKWAVE_FX_TILEMAP >> 11) << 2) | $02 ; 32x32
	sta Vera::Reg::FXMapBase


	; XXX
	lda #(3 << 1) ; DCSEL = 3
	sta Vera::Reg::Ctrl
	ldy frameno
	lda shockzoom_l,y
	sta $9f29
	lda shockzoom_h,y
	sta $9f2a
	stz $9f2b
	stz $9f2c

	stz fx_y_val
	stz fx_y_val+1

	lda #(4 << 1) ; DCSEL = 4
	sta Vera::Reg::Ctrl
	; XXX
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c

	stz Vera::Reg::Ctrl


	WAITVSYNC

	jsr flush_palette
	jsr flush_palette2
	jsr flush_palette3
	jsr flush_palette4


	; enable affine helper
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; reset cache index
	stz Vera::Reg::FXMult

	lda #%01100011 ; cache fill/write, affine helper mode
	sta Vera::Reg::FXCtrl


	ldx #80
	POS_ADDR_ROW_8BIT
	lda #$30
	sta Vera::Reg::AddrH
outerloop:
	; set DCSEL=4 to return to beginning of row 
	lda #(4 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	lda fx_y_val+1
	sta $9f2b
	
	; set DCSEL=5 to return to beginning of row (subpixels) 
	lda #(5 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	; set DCSEL=2 to reset cache index
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXMult

	ldy #80
	lda #$55
innerloop:
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	sta Vera::Reg::Data0
	dey
	bne innerloop

	ldy frameno
	lda ypos_incr_l,y
	clc
	adc fx_y_val
	sta fx_y_val
	lda ypos_incr_h,y
	adc fx_y_val+1
	sta fx_y_val+1

	inx
	cpx #120
	bne outerloop

	; disable FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::FXMult
	stz Vera::Reg::Ctrl

	inc frameno

	lda syncval
	cmp #$0e
	jne temploop
synce:
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

	; set VSTOP for 200px
	lda #%00000010  ; DCSEL=1
	sta Vera::Reg::Ctrl
   
	lda #20
	sta Vera::Reg::DCVStart
	lda #200+20-1
	sta Vera::Reg::DCVStop
	
	stz Vera::Reg::Ctrl

	; XXX this can go away after we set up an 8bpp fade to white
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L0Config

	rts
.endproc

.proc titlecard
syncf:
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
.endproc

shockzoom_l:
	.byte $ff,$50,$e0,$28,$20,$70,$16,$94,$a0,$10,$c8,$b8,$d1,$0b,$60,$ca
	.byte $45,$d0,$66,$08,$b2,$64,$1d,$dc,$a0,$68,$35,$05,$d9,$b0,$89,$65
	.byte $42,$22,$04,$e8,$cc,$b3,$9b,$84,$6e,$59,$45,$32,$20,$0e,$fd,$ee
	.byte $de,$d0,$c1,$b4,$a7,$9a,$8e,$82,$77,$6c,$62,$58,$4e,$44,$3b,$32
	.byte $29,$21,$19,$11,$09,$02,$fb,$f4,$ed,$e6,$e0,$d9,$d3,$cd,$c7,$c2
	.byte $bc,$b7,$b1,$ac,$a7,$a2,$9d,$99,$94,$90,$8b,$87,$83,$7e,$7a,$77
	.byte $73,$6f,$6b,$68,$64,$60,$5d,$5a,$56,$53,$50,$4d,$4a,$47,$44,$41
	.byte $3e,$3b,$39,$36,$33,$31,$2e,$2c,$29,$27,$24,$22,$20,$1d,$1b,$19
	.byte $17,$14,$12,$10,$0e,$0c,$0a,$08,$06,$04,$02,$01,$ff,$fd,$fb,$fa
	.byte $f8,$f6,$f4,$f3,$f1,$f0,$ee,$ec,$eb,$e9,$e8,$e6,$e5,$e3,$e2,$e1
	.byte $df,$de,$dc,$db,$da,$d8,$d7,$d6,$d5,$d3,$d2,$d1,$d0,$ce,$cd,$cc
	.byte $cb,$ca,$c9,$c8,$c6,$c5,$c4,$c3,$c2,$c1,$c0,$bf,$be,$bd,$bc,$bb
	.byte $ba,$b9,$b8,$b7,$b6,$b5,$b4,$b4,$b3,$b2,$b1,$b0,$af,$ae,$ad,$ad
	.byte $ac,$ab,$aa,$a9,$a9,$a8,$a7,$a6,$a5,$a5,$a4,$a3,$a2,$a2,$a1,$a0
	.byte $a0,$9f,$9e,$9d,$9d,$9c,$9b,$9b,$9a,$99,$99,$98,$97,$97,$96,$96
	.byte $95,$94,$94,$93,$92,$92,$91,$91,$90,$90,$8f,$8e,$8e,$8d,$8d,$8c
shockzoom_h:
	.byte $7f,$46,$2e,$23,$1c,$17,$14,$11,$0f,$0e,$0c,$0b,$0a,$0a,$09,$08
	.byte $08,$07,$07,$07,$06,$06,$06,$05,$05,$05,$05,$05,$04,$04,$04,$04
	.byte $04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ypos_incr_l:
	.byte $ff,$28,$70,$94,$10,$b8,$0b,$ca,$d0,$08,$64,$dc,$68,$05,$b0,$65
	.byte $22,$e8,$b3,$84,$59,$32,$0e,$ee,$d0,$b4,$9a,$82,$6c,$58,$44,$32
	.byte $21,$11,$02,$f4,$e6,$d9,$cd,$c2,$b7,$ac,$a2,$99,$90,$87,$7e,$77
	.byte $6f,$68,$60,$5a,$53,$4d,$47,$41,$3b,$36,$31,$2c,$27,$22,$1d,$19
	.byte $14,$10,$0c,$08,$04,$01,$fd,$fa,$f6,$f3,$f0,$ec,$e9,$e6,$e3,$e1
	.byte $de,$db,$d8,$d6,$d3,$d1,$ce,$cc,$ca,$c8,$c5,$c3,$c1,$bf,$bd,$bb
	.byte $b9,$b7,$b5,$b4,$b2,$b0,$ae,$ad,$ab,$a9,$a8,$a6,$a5,$a3,$a2,$a0
	.byte $9f,$9d,$9c,$9b,$99,$98,$97,$96,$94,$93,$92,$91,$90,$8e,$8d,$8c
	.byte $8b,$8a,$89,$88,$87,$86,$85,$84,$83,$82,$81,$80,$7f,$7e,$7d,$7d
	.byte $7c,$7b,$7a,$79,$78,$78,$77,$76,$75,$74,$74,$73,$72,$71,$71,$70
	.byte $6f,$6f,$6e,$6d,$6d,$6c,$6b,$6b,$6a,$69,$69,$68,$68,$67,$66,$66
	.byte $65,$65,$64,$64,$63,$62,$62,$61,$61,$60,$60,$5f,$5f,$5e,$5e,$5d
	.byte $5d,$5c,$5c,$5b,$5b,$5a,$5a,$5a,$59,$59,$58,$58,$57,$57,$56,$56
	.byte $56,$55,$55,$54,$54,$54,$53,$53,$52,$52,$52,$51,$51,$51,$50,$50
	.byte $50,$4f,$4f,$4e,$4e,$4e,$4d,$4d,$4d,$4c,$4c,$4c,$4b,$4b,$4b,$4b
	.byte $4a,$4a,$4a,$49,$49,$49,$48,$48,$48,$48,$47,$47,$47,$46,$46,$46
ypos_incr_h:
	.byte $3f,$23,$17,$11,$0e,$0b,$0a,$08,$07,$07,$06,$05,$05,$05,$04,$04
	.byte $04,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

titlepal:
	.word $0000,$0001,$0102,$0202,$0112,$0122,$0223,$0224,$0234,$0333,$0335,$0346,$0456,$0457,$0842,$0641
praxispal:
	.word $0000,$0001,$0102,$0202,$0112,$0122,$0223,$0224,$0234,$0333,$0335,$0346,$0456,$0457,$0842,$0641
	.word $0111,$0112,$0213,$0313,$0223,$0233,$0334,$0334,$0344,$0444,$0445,$0446,$0456,$0457,$0843,$0642
	.word $0111,$0112,$0213,$0313,$0223,$0233,$0334,$0335,$0345,$0444,$0446,$0457,$0567,$0568,$0953,$0752
	.word $0222,$0223,$0324,$0424,$0334,$0344,$0445,$0445,$0455,$0555,$0556,$0557,$0567,$0568,$0954,$0753
	.word $0333,$0333,$0334,$0434,$0334,$0344,$0445,$0446,$0456,$0555,$0557,$0567,$0677,$0678,$0964,$0763
	.word $0333,$0334,$0435,$0535,$0445,$0455,$0556,$0556,$0566,$0666,$0667,$0668,$0678,$0679,$0965,$0864
	.word $0444,$0445,$0545,$0545,$0555,$0555,$0556,$0557,$0567,$0666,$0667,$0678,$0778,$0779,$0a75,$0875
	.word $0555,$0555,$0556,$0656,$0556,$0566,$0667,$0667,$0677,$0777,$0778,$0778,$0788,$0789,$0a76,$0875
	.word $0555,$0556,$0656,$0656,$0666,$0666,$0667,$0668,$0678,$0777,$0778,$0789,$0889,$0889,$0a86,$0986
	.word $0666,$0666,$0667,$0767,$0667,$0677,$0778,$0778,$0788,$0888,$0889,$0889,$0899,$089a,$0a87,$0986
	.word $0777,$0777,$0778,$0878,$0778,$0788,$0888,$0889,$0889,$0888,$0889,$089a,$099a,$099a,$0b98,$0a97
	.word $0777,$0778,$0878,$0878,$0888,$0888,$0889,$0889,$0899,$0999,$0999,$099a,$099a,$099a,$0b98,$0a98
	.word $0888,$0888,$0889,$0989,$0889,$0899,$0999,$0999,$0999,$0999,$099a,$099a,$09aa,$09ab,$0b99,$0a98
	.word $0888,$0889,$0989,$0989,$0999,$0999,$099a,$099a,$09aa,$0aaa,$0aaa,$0aab,$0aab,$0aab,$0ba9,$0ba9
	.word $0999,$0999,$099a,$0a9a,$099a,$09aa,$0aaa,$0aaa,$0aaa,$0aaa,$0aab,$0aab,$0abb,$0abb,$0caa,$0ba9
	.word $0aaa,$0aaa,$0aaa,$0aaa,$0aaa,$0aaa,$0aab,$0aab,$0abb,$0bbb,$0bbb,$0bbb,$0bbb,$0bbc,$0cba,$0bba

