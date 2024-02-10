.include "x16.inc"
.include "macros.inc"

.include "flow.inc"

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
.feature string_escapes

TEMP_4BPP_BMP_ADDR = $18000
TILE_MAPBASE = $0D000
SHOCKWAVE_FX_TILEMAP = $10000
SHOCKWAVE_FX_TILEBASE = $11000
SCRATCH_BANK = $20

.segment "INTRO_ZP": zeropage
frameno:
	.res 1
tmpptr:
	.res 2
scratch:
	.res 1
fx_y_val:
	.res 3
fadingout:
	.res 1

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
	cmp #192
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

	ldy #4

	VERA_SET_ADDR SHOCKWAVE_FX_TILEBASE, 1
outerloop:
	lda #<$a000
	sta tmpptr

	lda #>$a000
	sta tmpptr+1
cookloop:
	lda (tmpptr)
	ldx #8
bitloop:
	asl
	pha
	bcc zero

	jsr galois16o
	and #$03
	inc
	sta scratch
	asl
	asl
	asl
	asl
	ora scratch
	sta Vera::Reg::Data0
	bra bitloop_end
zero:
	stz Vera::Reg::Data0
bitloop_end:
	pla
	dex
	bne bitloop

	inc tmpptr
	bne cookloop
	inc tmpptr+1
	lda tmpptr+1
	cmp #$a4
	bcc cookloop
	dey
	bne outerloop

	; create the 32x4 tile map (fill out the rest of the 32x32 map with zeroes)
	VERA_SET_ADDR SHOCKWAVE_FX_TILEMAP, 1

	ldx #0
shockmap_loop:
	stx Vera::Reg::Data0
	inx
	cpx #128
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
	stz fadingout
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
	lda fadingout
	beq fade
	lda frameno
	and #$03
	bne nofade
fade:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	jsr apply_palette_fade_step3
	jsr apply_palette_fade_step4

nofade:
	; set up FX affine stuff for next frame
	; but leave FX itself disabled
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	lda frameno
	asl
	asl
	asl
	and #$30
	ora #((SHOCKWAVE_FX_TILEBASE >> 11) << 2) | $02 ; affine clip enable
FXT = * - 1
	sta Vera::Reg::FXTileBase

	lda #((SHOCKWAVE_FX_TILEMAP >> 11) << 2) | $02 ; 32x32
	sta Vera::Reg::FXMapBase


	lda #(3 << 1) ; DCSEL = 3
	sta Vera::Reg::Ctrl
	ldy frameno
	lda shockzoom_l,y
	sta $9f29
	lda shockzoom_h,y
	sta $9f2a
	stz $9f2b
	stz $9f2c

	lda ypos_s,y
	sta fx_y_val
	lda ypos_l,y
	sta fx_y_val+1
	lda ypos_h,y
	sta fx_y_val+2

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

	lda xpos_l,y
	sta $9f29

	lda xpos_h,y
	sta $9f2a
	lda fx_y_val+1
	sta $9f2b
	lda fx_y_val+2
	sta $9f2c

	; set DCSEL=5 to return to beginning of row (subpixels) 
	lda #(5 << 1)
	sta Vera::Reg::Ctrl
	lda xpos_s,y
	sta $9f29
	lda fx_y_val
	sta $9f2a
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
	bcc :+
	inc fx_y_val+2
:
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
	cmp #$0f
	beq exit

	lda fadingout
	jne temploop

	lda syncval
	cmp #$0e
	jne temploop
	inc fadingout

	ldx #0
whitepal:
	lda #$ff
	sta target_palette,x
	sta target_palette3,x
	inx
	lda #$0f
	sta target_palette,x
	sta target_palette3,x
	inx
	bne whitepal

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	jmp temploop

exit:
	; set VSTOP for 200px
	lda #%00000010  ; DCSEL=1
	sta Vera::Reg::Ctrl
   
	lda #20
	sta Vera::Reg::DCVStart
	lda #200+20-1
	sta Vera::Reg::DCVStop
	
	stz Vera::Reg::Ctrl

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

.proc galois16o
	lda seed+1
	pha ; store copy of high byte
	; compute seed+1 ($39>>1 = %11100)
	lsr ; shift to consume zeroes on left...
	lsr
	lsr
	sta seed+1 ; now recreate the remaining bits in reverse order... %111
	lsr
	eor seed+1
	lsr
	eor seed+1
	eor seed+0 ; recombine with original low byte
	sta seed+1
	; compute seed+0 ($39 = %111001)
	pla ; original high byte
	sta seed+0
	asl
	eor seed+0
	asl
	eor seed+0
	asl
	asl
	asl
	eor seed+0
	sta seed+0
	rts
seed:
	.word $6502
.endproc

titlepal:
	.word $0000,$0001,$0102,$0202,$0112,$0122,$0223,$0224,$0234,$0333,$0335,$0346,$0456,$0457,$0842,$0641
praxispal:
	.word $0000,$0001,$0102,$0202,$0112,$0122,$0223,$0224,$0234,$0333,$0335,$0346,$0456,$0457,$0842,$0641
	.word $0111,$0112,$0213,$0313,$0223,$0233,$0334,$0335,$0345,$0444,$0446,$0457,$0557,$0557,$0853,$0652
	.word $0112,$0113,$0213,$0313,$0223,$0233,$0334,$0335,$0345,$0444,$0446,$0457,$0567,$0568,$0953,$0753
	.word $0223,$0223,$0324,$0424,$0334,$0344,$0445,$0446,$0456,$0555,$0557,$0568,$0668,$0668,$0964,$0763
	.word $0333,$0334,$0435,$0435,$0445,$0445,$0446,$0446,$0456,$0556,$0557,$0568,$0678,$0679,$0965,$0864
	.word $0444,$0445,$0446,$0546,$0446,$0456,$0556,$0557,$0567,$0666,$0668,$0679,$0779,$0779,$0976,$0875
	.word $0445,$0446,$0546,$0646,$0556,$0566,$0667,$0668,$0668,$0667,$0668,$0679,$0789,$078a,$0a76,$0876
	.word $0556,$0556,$0657,$0657,$0667,$0667,$0668,$0668,$0678,$0778,$0779,$078a,$088a,$088a,$0a87,$0986
	.word $0667,$0667,$0668,$0768,$0668,$0678,$0778,$0779,$0779,$0778,$0779,$078a,$089a,$089b,$0a88,$0987
	.word $0778,$0778,$0779,$0879,$0779,$0789,$0889,$088a,$088a,$0889,$088a,$089b,$099b,$099b,$0b99,$0a98
	.word $0778,$0779,$0879,$0879,$0889,$0889,$088a,$088a,$089a,$099a,$099b,$099b,$099b,$099b,$0b99,$0a99
	.word $0889,$088a,$088a,$098a,$088a,$089a,$099a,$099b,$099b,$099a,$099b,$09ac,$0aac,$0aac,$0baa,$0aaa
	.word $099a,$099a,$099b,$099b,$099b,$099b,$099b,$099b,$09ab,$0aab,$0aac,$0aac,$0aac,$0aac,$0bab,$0baa
	.word $099b,$099b,$0a9b,$0a9b,$0aab,$0aab,$0aac,$0aac,$0aac,$0aac,$0aac,$0abd,$0bbd,$0bbd,$0cbb,$0bbb
	.word $0aac,$0aac,$0aac,$0bac,$0aac,$0abc,$0bbc,$0bbd,$0bbd,$0bbc,$0bbd,$0bbd,$0bbd,$0bbd,$0cbc,$0bbc
	.word $0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bce,$0cce,$0cce,$0ccd,$0ccd

shockzoom_l:
	.byte $20,$70,$16,$94,$a0,$10,$c8,$b8,$d1,$0b,$60,$ca,$45,$d0,$66,$08
	.byte $b2,$64,$1d,$dc,$a0,$68,$35,$05,$d9,$b0,$89,$65,$42,$22,$04,$e8
	.byte $cc,$b3,$9b,$84,$6e,$59,$45,$32,$20,$0e,$fd,$ee,$de,$d0,$c1,$b4
	.byte $a7,$9a,$8e,$82,$77,$6c,$62,$58,$4e,$44,$3b,$32,$29,$21,$19,$11
	.byte $09,$02,$fb,$f4,$ed,$e6,$e0,$d9,$d3,$cd,$c7,$c2,$bc,$b7,$b1,$ac
	.byte $a7,$a2,$9d,$99,$94,$90,$8b,$87,$83,$7e,$7a,$77,$73,$6f,$6b,$68
	.byte $64,$60,$5d,$5a,$56,$53,$50,$4d,$4a,$47,$44,$41,$3e,$3b,$39,$36
	.byte $33,$31,$2e,$2c,$29,$27,$24,$22,$20,$1d,$1b,$19,$17,$14,$12,$10
	.byte $0e,$0c,$0a,$08,$06,$04,$02,$01,$ff,$fd,$fb,$fa,$f8,$f6,$f4,$f3
	.byte $f1,$f0,$ee,$ec,$eb,$e9,$e8,$e6,$e5,$e3,$e2,$e1,$df,$de,$dc,$db
	.byte $da,$d8,$d7,$d6,$d5,$d3,$d2,$d1,$d0,$ce,$cd,$cc,$cb,$ca,$c9,$c8
	.byte $c6,$c5,$c4,$c3,$c2,$c1,$c0,$bf,$be,$bd,$bc,$bb,$ba,$b9,$b8,$b7
	.byte $b6,$b5,$b4,$b4,$b3,$b2,$b1,$b0,$af,$ae,$ad,$ad,$ac,$ab,$aa,$a9
	.byte $a9,$a8,$a7,$a6,$a5,$a5,$a4,$a3,$a2,$a2,$a1,$a0,$a0,$9f,$9e,$9d
	.byte $9d,$9c,$9b,$9b,$9a,$99,$99,$98,$97,$97,$96,$96,$95,$94,$94,$93
	.byte $92,$92,$91,$91,$90,$90,$8f,$8e,$8e,$8d,$8d,$8c,$8c,$8b,$8a,$8a
shockzoom_h:
	.byte $1c,$17,$14,$11,$0f,$0e,$0c,$0b,$0a,$0a,$09,$08,$08,$07,$07,$07
	.byte $06,$06,$06,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04,$04,$04,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ypos_incr_l:
	.byte $30,$28,$22,$5e,$70,$18,$2d,$94,$39,$11,$10,$2f,$68,$b8,$1a,$8c
	.byte $0b,$96,$2b,$ca,$70,$1c,$d0,$88,$46,$08,$cd,$97,$64,$34,$06,$dc
	.byte $b3,$8d,$68,$46,$25,$05,$e7,$cb,$b0,$95,$7c,$65,$4e,$38,$22,$0e
	.byte $fa,$e8,$d5,$c4,$b3,$a3,$93,$84,$75,$66,$59,$4b,$3e,$32,$25,$1a
	.byte $0e,$03,$f8,$ee,$e3,$d9,$d0,$c6,$bd,$b4,$ab,$a3,$9a,$92,$8a,$82
	.byte $7b,$73,$6c,$65,$5e,$58,$51,$4a,$44,$3e,$38,$32,$2c,$27,$21,$1c
	.byte $16,$11,$0c,$07,$02,$fd,$f8,$f4,$ef,$ea,$e6,$e2,$dd,$d9,$d5,$d1
	.byte $cd,$c9,$c5,$c2,$be,$ba,$b7,$b3,$b0,$ac,$a9,$a5,$a2,$9f,$9c,$99
	.byte $96,$92,$90,$8d,$8a,$87,$84,$81,$7e,$7c,$79,$77,$74,$71,$6f,$6c
	.byte $6a,$68,$65,$63,$60,$5e,$5c,$5a,$57,$55,$53,$51,$4f,$4d,$4b,$49
	.byte $47,$45,$43,$41,$3f,$3d,$3b,$39,$38,$36,$34,$32,$31,$2f,$2d,$2c
	.byte $2a,$28,$27,$25,$23,$22,$20,$1f,$1d,$1c,$1a,$19,$17,$16,$14,$13
	.byte $12,$10,$0f,$0e,$0c,$0b,$0a,$08,$07,$06,$04,$03,$02,$01,$ff,$fe
	.byte $fd,$fc,$fb,$fa,$f8,$f7,$f6,$f5,$f4,$f3,$f2,$f1,$f0,$ee,$ed,$ec
	.byte $eb,$ea,$e9,$e8,$e7,$e6,$e5,$e4,$e3,$e2,$e1,$e1,$e0,$df,$de,$dd
	.byte $dc,$db,$da,$d9,$d8,$d8,$d7,$d6,$d5,$d4,$d3,$d2,$d2,$d1,$d0,$cf
ypos_incr_h:
	.byte $2a,$23,$1e,$1a,$17,$15,$13,$11,$10,$0f,$0e,$0d,$0c,$0b,$0b,$0a
	.byte $0a,$09,$09,$08,$08,$08,$07,$07,$07,$07,$06,$06,$06,$06,$06,$05
	.byte $05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
xpos_s:
	.byte $00,$00,$db,$c0,$00,$00,$45,$80,$9d,$6d,$00,$e0,$3c,$00,$e5,$80
	.byte $49,$a2,$de,$40,$00,$4e,$55,$36,$11,$00,$18,$70,$17,$1e,$92,$80
	.byte $f2,$f2,$89,$c0,$9c,$24,$5f,$51,$00,$6f,$a3,$a0,$68,$00,$69,$a7
	.byte $bc,$aa,$74,$1b,$a1,$08,$52,$80,$92,$8c,$6d,$38,$ec,$8b,$16,$8f
	.byte $f4,$49,$8c,$c0,$e3,$f9,$00,$f9,$e5,$c4,$98,$60,$1c,$ce,$75,$12
	.byte $a5,$2f,$b0,$28,$98,$00,$5f,$b7,$08,$51,$94,$d0,$05,$34,$5d,$80
	.byte $9d,$b4,$c6,$d3,$db,$de,$dc,$d5,$c9,$ba,$a6,$8d,$71,$50,$2c,$04
	.byte $d8,$a9,$76,$40,$06,$c9,$89,$46,$00,$b6,$6a,$1c,$ca,$76,$1f,$c5
	.byte $69,$0b,$aa,$47,$e2,$7a,$10,$a4,$36,$c6,$54,$e0,$69,$f1,$78,$fc
	.byte $7f,$00,$7f,$fc,$78,$f2,$6b,$e2,$58,$cc,$3e,$b0,$1f,$8e,$fb,$67
	.byte $d1,$3a,$a2,$09,$6e,$d2,$35,$97,$f8,$58,$b6,$14,$70,$cc,$26,$80
	.byte $d8,$2f,$86,$db,$30,$84,$d6,$28,$79,$ca,$19,$68,$b5,$02,$4e,$9a
	.byte $e4,$2e,$77,$c0,$07,$4e,$94,$da,$1f,$63,$a6,$e9,$2c,$6d,$ae,$ef
	.byte $2e,$6e,$ac,$ea,$28,$64,$a1,$dd,$18,$53,$8d,$c6,$00,$38,$70,$a8
	.byte $df,$16,$4c,$82,$b7,$ec,$20,$54,$88,$bb,$ed,$20,$51,$83,$b4,$e4
	.byte $14,$44,$74,$a3,$d1,$00,$2d,$5b,$88,$b5,$e1,$0e,$39,$65,$90,$bb
xpos_l:
	.byte $b6,$2d,$38,$01,$9e,$1b,$81,$d6,$1e,$5c,$92,$c0,$ea,$0f,$2f,$4d
	.byte $68,$80,$96,$ab,$be,$cf,$df,$ee,$fc,$09,$15,$20,$2b,$35,$3e,$47
	.byte $4f,$57,$5f,$66,$6d,$74,$7a,$80,$86,$8b,$90,$95,$9a,$9f,$a3,$a7
	.byte $ab,$af,$b3,$b7,$ba,$be,$c1,$c4,$c7,$ca,$cd,$d0,$d2,$d5,$d8,$da
	.byte $dc,$df,$e1,$e3,$e5,$e7,$ea,$eb,$ed,$ef,$f1,$f3,$f5,$f6,$f8,$fa
	.byte $fb,$fd,$fe,$00,$01,$03,$04,$05,$07,$08,$09,$0a,$0c,$0d,$0e,$0f
	.byte $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f
	.byte $1f,$20,$21,$22,$23,$23,$24,$25,$26,$26,$27,$28,$28,$29,$2a,$2a
	.byte $2b,$2c,$2c,$2d,$2d,$2e,$2f,$2f,$30,$30,$31,$31,$32,$32,$33,$33
	.byte $34,$35,$35,$35,$36,$36,$37,$37,$38,$38,$39,$39,$3a,$3a,$3a,$3b
	.byte $3b,$3c,$3c,$3d,$3d,$3d,$3e,$3e,$3e,$3f,$3f,$40,$40,$40,$41,$41
	.byte $41,$42,$42,$42,$43,$43,$43,$44,$44,$44,$45,$45,$45,$46,$46,$46
	.byte $46,$47,$47,$47,$48,$48,$48,$48,$49,$49,$49,$49,$4a,$4a,$4a,$4a
	.byte $4b,$4b,$4b,$4b,$4c,$4c,$4c,$4c,$4d,$4d,$4d,$4d,$4e,$4e,$4e,$4e
	.byte $4e,$4f,$4f,$4f,$4f,$4f,$50,$50,$50,$50,$50,$51,$51,$51,$51,$51
	.byte $52,$52,$52,$52,$52,$53,$53,$53,$53,$53,$53,$54,$54,$54,$54,$54
xpos_h:
	.byte $07,$01,$02,$03,$03,$04,$04,$04,$05,$05,$05,$05,$05,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
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
ypos_s:
	.byte $00,$80,$db,$20,$00,$80,$2e,$c0,$62,$ed,$00,$10,$78,$80,$5e,$40
	.byte $49,$97,$42,$60,$00,$31,$00,$76,$9e,$80,$21,$88,$ba,$bc,$92,$40
	.byte $c8,$2f,$76,$a0,$ae,$a4,$82,$4b,$00,$a1,$31,$b0,$1f,$80,$d2,$18
	.byte $52,$80,$a2,$bb,$ca,$cf,$cb,$c0,$ac,$90,$6d,$44,$13,$dd,$a0,$5e
	.byte $16,$c9,$76,$20,$c4,$64,$00,$97,$2b,$bb,$47,$d0,$55,$d7,$56,$d2
	.byte $4b,$c1,$34,$a5,$14,$80,$e9,$50,$b5,$18,$79,$d8,$34,$8f,$e8,$40
	.byte $95,$e9,$3b,$8c,$db,$29,$75,$c0,$09,$51,$98,$dd,$21,$65,$a6,$e7
	.byte $27,$65,$a3,$e0,$1b,$56,$8f,$c8,$00,$36,$6c,$a2,$d6,$09,$3c,$6e
	.byte $9f,$d0,$00,$2f,$5d,$8b,$b8,$e4,$10,$3b,$66,$90,$b9,$e2,$0a,$32
	.byte $59,$80,$a6,$cb,$f0,$15,$39,$5d,$80,$a3,$c6,$e8,$09,$2a,$4b,$6b
	.byte $8b,$ab,$ca,$e9,$07,$25,$43,$60,$7d,$9a,$b6,$d2,$ee,$0a,$25,$40
	.byte $5a,$74,$8e,$a8,$c1,$da,$f3,$0c,$24,$3c,$54,$6c,$83,$9a,$b1,$c7
	.byte $de,$f4,$0a,$20,$35,$4a,$5f,$74,$89,$9d,$b2,$c6,$da,$ed,$01,$14
	.byte $27,$3a,$4d,$60,$72,$84,$96,$a8,$ba,$cc,$dd,$ee,$00,$10,$21,$32
	.byte $43,$53,$63,$73,$83,$93,$a3,$b2,$c2,$d1,$e0,$f0,$fe,$0d,$1c,$2b
	.byte $39,$47,$56,$64,$72,$80,$8d,$9b,$a8,$b6,$c3,$d1,$de,$eb,$f8,$04
ypos_l:
	.byte $6d,$dd,$2d,$6a,$99,$be,$dd,$f6,$0c,$1e,$2f,$3d,$49,$54,$5e,$67
	.byte $6f,$76,$7d,$83,$89,$8e,$93,$97,$9b,$9f,$a3,$a6,$a9,$ac,$af,$b2
	.byte $b4,$b7,$b9,$bb,$bd,$bf,$c1,$c3,$c5,$c6,$c8,$c9,$cb,$cc,$cd,$cf
	.byte $d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$d8,$d9,$da,$db,$dc,$dc,$dd,$de
	.byte $df,$df,$e0,$e1,$e1,$e2,$e3,$e3,$e4,$e4,$e5,$e5,$e6,$e6,$e7,$e7
	.byte $e8,$e8,$e9,$e9,$ea,$ea,$ea,$eb,$eb,$ec,$ec,$ec,$ed,$ed,$ed,$ee
	.byte $ee,$ee,$ef,$ef,$ef,$f0,$f0,$f0,$f1,$f1,$f1,$f1,$f2,$f2,$f2,$f2
	.byte $f3,$f3,$f3,$f3,$f4,$f4,$f4,$f4,$f5,$f5,$f5,$f5,$f5,$f6,$f6,$f6
	.byte $f6,$f6,$f7,$f7,$f7,$f7,$f7,$f7,$f8,$f8,$f8,$f8,$f8,$f8,$f9,$f9
	.byte $f9,$f9,$f9,$f9,$f9,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fb,$fb,$fb,$fb
	.byte $fb,$fb,$fb,$fb,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fd,$fd,$fd
	.byte $fd,$fd,$fd,$fd,$fd,$fd,$fd,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
	.byte $fe,$fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$03
ypos_h:
	.byte $05,$05,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
