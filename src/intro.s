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
	asl
	sta scratch
	lsr
	lsr
	lsr
	lsr
	ora scratch
	sta Vera::Reg::Data0

	lda (tmpptr)
	and #$07
	asl
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
	.byte $28,$94,$b8,$ca,$08,$dc,$05,$65,$e8,$84,$32,$ee,$b4,$82,$58,$32
	.byte $11,$f4,$d9,$c2,$ac,$99,$87,$77,$68,$5a,$4d,$41,$36,$2c,$22,$19
	.byte $10,$08,$01,$fa,$f3,$ec,$e6,$e1,$db,$d6,$d1,$cc,$c8,$c3,$bf,$bb
	.byte $b7,$b4,$b0,$ad,$a9,$a6,$a3,$a0,$9d,$9b,$98,$96,$93,$91,$8e,$8c
	.byte $8a,$88,$86,$84,$82,$80,$7e,$7d,$7b,$79,$78,$76,$74,$73,$71,$70
	.byte $6f,$6d,$6c,$6b,$69,$68,$67,$66,$65,$64,$62,$61,$60,$5f,$5e,$5d
	.byte $5c,$5b,$5a,$5a,$59,$58,$57,$56,$55,$54,$54,$53,$52,$51,$51,$50
	.byte $4f,$4e,$4e,$4d,$4c,$4c,$4b,$4b,$4a,$49,$49,$48,$48,$47,$46,$46
	.byte $45,$45,$44,$44,$43,$43,$42,$42,$41,$41,$40,$40,$3f,$3f,$3e,$3e
	.byte $3e,$3d,$3d,$3c,$3c,$3c,$3b,$3b,$3a,$3a,$3a,$39,$39,$38,$38,$38
	.byte $37,$37,$37,$36,$36,$36,$35,$35,$35,$34,$34,$34,$34,$33,$33,$33
	.byte $32,$32,$32,$32,$31,$31,$31,$30,$30,$30,$30,$2f,$2f,$2f,$2f,$2e
	.byte $2e,$2e,$2e,$2d,$2d,$2d,$2d,$2d,$2c,$2c,$2c,$2c,$2b,$2b,$2b,$2b
	.byte $2b,$2a,$2a,$2a,$2a,$2a,$29,$29,$29,$29,$29,$28,$28,$28,$28,$28
	.byte $28,$27,$27,$27,$27,$27,$26,$26,$26,$26,$26,$26,$25,$25,$25,$25
	.byte $25,$25,$25,$24,$24,$24,$24,$24,$24,$24,$23,$23,$23,$23,$23,$23
shockzoom_h:
	.byte $23,$11,$0b,$08,$07,$05,$05,$04,$03,$03,$03,$02,$02,$02,$02,$02
	.byte $02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
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
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ypos_incr_l:
	.byte $94,$ca,$dc,$65,$84,$ee,$82,$32,$f4,$c2,$99,$77,$5a,$41,$2c,$19
	.byte $08,$fa,$ec,$e1,$d6,$cc,$c3,$bb,$b4,$ad,$a6,$a0,$9b,$96,$91,$8c
	.byte $88,$84,$80,$7d,$79,$76,$73,$70,$6d,$6b,$68,$66,$64,$61,$5f,$5d
	.byte $5b,$5a,$58,$56,$54,$53,$51,$50,$4e,$4d,$4c,$4b,$49,$48,$47,$46
	.byte $45,$44,$43,$42,$41,$40,$3f,$3e,$3d,$3c,$3c,$3b,$3a,$39,$38,$38
	.byte $37,$36,$36,$35,$34,$34,$33,$33,$32,$32,$31,$30,$30,$2f,$2f,$2e
	.byte $2e,$2d,$2d,$2d,$2c,$2c,$2b,$2b,$2a,$2a,$2a,$29,$29,$28,$28,$28
	.byte $27,$27,$27,$26,$26,$26,$25,$25,$25,$24,$24,$24,$24,$23,$23,$23
	.byte $22,$22,$22,$22,$21,$21,$21,$21,$20,$20,$20,$20,$1f,$1f,$1f,$1f
	.byte $1f,$1e,$1e,$1e,$1e,$1e,$1d,$1d,$1d,$1d,$1d,$1c,$1c,$1c,$1c,$1c
	.byte $1b,$1b,$1b,$1b,$1b,$1b,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$19,$19,$19
	.byte $19,$19,$19,$19,$18,$18,$18,$18,$18,$18,$18,$17,$17,$17,$17,$17
	.byte $17,$17,$17,$16,$16,$16,$16,$16,$16,$16,$16,$16,$15,$15,$15,$15
	.byte $15,$15,$15,$15,$15,$15,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14
	.byte $14,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$12,$12,$12,$12
	.byte $12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$11,$11,$11,$11,$11,$11
ypos_incr_h:
	.byte $11,$08,$05,$04,$03,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
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
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

titlepal:
	.word $0000,$0002,$0202,$0203,$0303,$0222,$0223,$0333,$0334,$0345,$0444,$0446,$0457,$0565,$0457,$0568
praxispal:
	.word $0000,$0001,$0101,$0102,$0202,$0111,$0112,$0222,$0223,$0234,$0333,$0335,$0346,$0454,$0456,$0457
	.word $0000,$0111,$0222,$0333,$0444,$0555,$0666,$0777,$0000,$0100,$0200,$0300,$0410,$0521,$0643,$0765
	.word $0222,$0223,$0323,$0323,$0323,$0333,$0333,$0333,$0334,$0345,$0444,$0446,$0457,$0565,$0567,$0568
	.word $0222,$0333,$0333,$0444,$0555,$0666,$0777,$0888,$0222,$0322,$0322,$0422,$0532,$0633,$0754,$0876
	.word $0333,$0334,$0434,$0435,$0535,$0444,$0445,$0555,$0556,$0566,$0666,$0667,$0668,$0676,$0678,$0679
	.word $0333,$0444,$0555,$0666,$0666,$0777,$0888,$0999,$0333,$0433,$0533,$0633,$0643,$0754,$0866,$0987
	.word $0555,$0556,$0656,$0656,$0656,$0666,$0666,$0666,$0667,$0677,$0777,$0778,$0779,$0787,$0789,$0789
	.word $0555,$0666,$0666,$0777,$0777,$0888,$0999,$0999,$0555,$0655,$0655,$0755,$0765,$0866,$0977,$0998
	.word $0777,$0777,$0777,$0778,$0878,$0777,$0778,$0888,$0888,$0889,$0888,$0889,$089a,$0999,$099a,$099a
	.word $0777,$0777,$0888,$0888,$0999,$0999,$0aaa,$0aaa,$0777,$0777,$0877,$0877,$0977,$0987,$0a98,$0aa9
	.word $0888,$0889,$0989,$0989,$0989,$0999,$0999,$0999,$0999,$099a,$0999,$099a,$09aa,$0aaa,$0aaa,$0aab
	.word $0888,$0999,$0999,$0999,$0aaa,$0aaa,$0aaa,$0bbb,$0888,$0988,$0988,$0988,$0a98,$0a99,$0aa9,$0baa
	.word $0aaa,$0aaa,$0aaa,$0aaa,$0aaa,$0aaa,$0aaa,$0aaa,$0aab,$0abb,$0bbb,$0bbb,$0bbb,$0bbb,$0bbb,$0bbc
	.word $0aaa,$0aaa,$0aaa,$0bbb,$0bbb,$0bbb,$0bbb,$0ccc,$0aaa,$0aaa,$0aaa,$0baa,$0baa,$0baa,$0bbb,$0cbb
	.word $0bbb,$0bbc,$0cbc,$0cbc,$0cbc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc
	.word $0bbb,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0ccc,$0bbb,$0cbb,$0cbb,$0cbb,$0ccb,$0ccc,$0ccc,$0ccc
