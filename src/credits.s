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

.import sprite_text_pos_y400
.import sprite_scroll_up

.import target_palette
.import target_palette2
.import target_palette3
.import target_palette4

.import graceful_fail

.macpack longbranch

SCREENSHOT_BASE = $00000
ATTRIBUTION_BASE = $08000

HOLDTIME = 200

MAX_EASE_ITER = 40

.include "x16.inc"
.include "macros.inc"

.macro EMPTY_LINE
	.byte 0,0,0
.endmacro

.macro EASE_ON
	clc
	jsr ease
.endmacro

.macro EASE_OFF
	sec
	jsr ease
.endmacro

.segment "CREDITS_ZP": zeropage
ptr1:
	.res 2
lines:
	.res 1

.segment "CREDITS"
entry:
	jsr setup_vera

	jsr do_cards
	jsr do_crawl

	; about 4 seconds
	ldx #0
:	phx
	WAITVSYNC
	plx
	dex
	bne :-

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


	PALETTE_FADE_FULL 2

	rts

.proc do_crawl
	WAITVSYNC

	DISABLE_SPRITES

	; load title font
	LOADFILE "TITLEFONT.VTS", 0, $0000, 1

	lda #%00001000 ; clear 240p
	trb Vera::Reg::DCVideo

	WAITVSYNC
	; high res mode
	stz Vera::Reg::Ctrl
	lda #$80
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	lda #<(crawl_text-1)
	sta ptr1
	lda #>(crawl_text-1)
	sta ptr1+1
next_string:
	INCPTR1
	lda (ptr1)
	tax
	INCPTR1
	lda (ptr1)
	tay
	bmi done
	jsr sprite_text_pos_y400

	INCPTR1
	ldx ptr1
	ldy ptr1+1
	lda #15
	jsr sprite_text_do

advance_ptr:
	lda (ptr1)
	beq eos
	INCPTR1
	bra advance_ptr
eos:
	lda #40
	sta lines
scroll_loop:
	WAITVSYNC 2
	jsr sprite_scroll_up
	dec lines
	bne scroll_loop
	jmp next_string
done:
	rts

.endproc

.proc do_cards
	DISABLE_SPRITES

	; set up sprite attrs (for 6 sprites)
	VERA_SET_ADDR Vera::VRAM_sprattr, 1

.repeat 2, i
	; SPRITE 0+1

	lda #<((SCREENSHOT_BASE + (i*$1000)) >> 5)
	sta Vera::Reg::Data0

	lda #>((SCREENSHOT_BASE + (i*$1000)) >> 5) | $80 ; 8bpp
	sta Vera::Reg::Data0

	lda Vera::Reg::Data0 ; skip over X
	lda Vera::Reg::Data0
	lda #$ff ; Y=255
	sta Vera::Reg::Data0
	stz Vera::Reg::Data0 ; Y high

	lda #$0c ; z-depth = 3, no flip
	sta Vera::Reg::Data0
	lda #$f0 ; 64x64, palette offset 0
	sta Vera::Reg::Data0
.endrepeat

.repeat 2, i
	; SPRITE 2+3

	lda #<((SCREENSHOT_BASE + $2000 + (i*$1000)) >> 5)
	sta Vera::Reg::Data0

	lda #>((SCREENSHOT_BASE + $2000 + (i*$1000)) >> 5) | $80 ; 8bpp
	sta Vera::Reg::Data0

	lda Vera::Reg::Data0 ; skip over X
	lda Vera::Reg::Data0
	lda #$ff ; Y=255
	sta Vera::Reg::Data0
	stz Vera::Reg::Data0 ; Y high

	lda #$0c ; z-depth = 3, no flip
	sta Vera::Reg::Data0
	lda #$70 ; 64x16, palette offset 0
	sta Vera::Reg::Data0
.endrepeat

.repeat 2, i
	; SPRITE 4+5

	lda #<((ATTRIBUTION_BASE + (i*$800)) >> 5)
	sta Vera::Reg::Data0

	lda #>((ATTRIBUTION_BASE + (i*$800)) >> 5); 4bpp
	sta Vera::Reg::Data0

	lda Vera::Reg::Data0 ; skip over X
	lda Vera::Reg::Data0
	lda #$ff ; Y=255
	sta Vera::Reg::Data0
	stz Vera::Reg::Data0 ; Y high

	lda #$0c ; z-depth = 3, no flip
	sta Vera::Reg::Data0
	lda #$ff ; 64x64, palette offset 15
	sta Vera::Reg::Data0
.endrepeat

	LOADFILE "CREDITS-DOSBOOT.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-DOSBOOT.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-MOOINGLEMUR.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-INTRO-SCROLL.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-INTRO-SCROLL.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-INTRO-SHIPS.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-INTRO-SHIPS.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-JEFFREYH.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-INTRO-PRAXIS.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-INTRO-PRAXIS.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-MOOINGLEMUR.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-HEDRON.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-HEDRON.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-TUNNEL.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-TUNNEL.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-CIRCLES.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-CIRCLES.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-TECHNO.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-TECHNO.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-PANIC.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-PANIC.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-SCROLLER.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-SCROLLER.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-JEFFREYH.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-CREATURE-LENS.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-CREATURE-LENS.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-CREATURE-ROTA.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-CREATURE-ROTA.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-PLASMA.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-PLASMA.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-MOOINGLEMUR.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-CUBE.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-CUBE.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-BALLS.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-BALLS.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-SWORD.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-SWORD.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-JEFFREYH.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-SINUS.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-SINUS.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-MOOINGLEMUR.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-BOUNCE.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-BOUNCE.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-JEFFREYH.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-CRAFT.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-CRAFT.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-PLACEHOLDER.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-PLACEHOLDER.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-MOOINGLEMUR.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	LOADFILE "CREDITS-CREDITS.DAT", 0, .loword(SCREENSHOT_BASE), ^SCREENSHOT_BASE
	LOADFILE "CREDITS-CREDITS.PAL", 0, .loword(Vera::VRAM_palette), ^(Vera::VRAM_palette)
	LOADFILE "CREDITS-CODE-MOOINGLEMUR.DAT", 0, .loword(ATTRIBUTION_BASE), ^ATTRIBUTION_BASE

	EASE_ON
	WAITVSYNC HOLDTIME
	EASE_OFF

	rts
.endproc

.proc ease
	ror
	sta dir
	lda #0
	sta iter
loop:
	WAITVSYNC

	VERA_SET_ADDR Vera::VRAM_sprattr, 1

	ldx iter

	bit dir
	bpl son
soff:
	ldy h_ease_off_h,x
	lda h_ease_off_l,x
	tax
	bra doscreenshot
son:
	ldy h_ease_on_h,x
	lda h_ease_on_l,x
	tax
doscreenshot:
	; sprite 0

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	stx Vera::Reg::Data0 ; XL
	sty Vera::Reg::Data0 ; XH

	lda #10
	sta Vera::Reg::Data0 ; YL
	stz Vera::Reg::Data0 ; YH

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	; sprite 1

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	txa
	clc
	adc #64
	sta Vera::Reg::Data0 ; XL
	tya
	adc #0
	sta Vera::Reg::Data0 ; XH

	lda #10
	sta Vera::Reg::Data0 ; YL
	stz Vera::Reg::Data0 ; YH

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	; sprite 2

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	stx Vera::Reg::Data0 ; XL
	sty Vera::Reg::Data0 ; XH

	lda #74
	sta Vera::Reg::Data0 ; YL
	stz Vera::Reg::Data0 ; YH

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	; sprite 3

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	txa
	clc
	adc #64
	sta Vera::Reg::Data0 ; XL
	tya
	adc #0
	sta Vera::Reg::Data0 ; XH

	lda #74
	sta Vera::Reg::Data0 ; YL
	stz Vera::Reg::Data0 ; YH

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	ldx iter

	bit dir
	bpl aon
aoff:
	ldy v_ease_off,x
	bra doattribution
aon:
	ldy v_ease_on,x
doattribution:
	; sprite 4

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	lda #96

	sta Vera::Reg::Data0 ; XL
	stz Vera::Reg::Data0 ; XH

	sty Vera::Reg::Data0 ; YL
	stz Vera::Reg::Data0 ; YH

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	; sprite 5

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	lda #160

	sta Vera::Reg::Data0 ; XL
	stz Vera::Reg::Data0 ; XH

	sty Vera::Reg::Data0 ; YL
	stz Vera::Reg::Data0 ; YH

	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	inc iter
	lda iter
	cmp #MAX_EASE_ITER
	jcc loop

	rts
iter:
	.byte 0
dir:
	.byte 0
.endproc

.proc setup_vera
	; set VERA layers up
	; show only sprites
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$40
	sta Vera::Reg::DCVideo
	and #%00000011
	cmp #1
	beq :+
	lda #%00001000 ; set 240p
	tsb Vera::Reg::DCVideo
:

	; border = index 0
	stz Vera::Reg::DCBorder

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #20
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; 2:1 scale
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	VERA_SET_ADDR ((Vera::VRAM_palette) + $1e0), 1
	ldy #0
palloop:
	lda palette_f,y
	sta Vera::Reg::Data0
	iny
	cpy #32
	bcc palloop

	rts
.endproc


v_ease_on:
	.byte $c8,$c5,$c2,$be,$bb,$b8,$b5,$b2,$af,$ac,$a9,$a6,$a3,$a0,$9d,$9a,$98,$95,$93,$90,$8e,$8c,$8a,$88,$86,$84,$82,$80,$7f,$7e,$7c,$7b,$7a,$79,$78,$78,$77,$77,$76,$76
v_ease_off:
	.byte $76,$76,$77,$77,$78,$78,$79,$7a,$7b,$7c,$7e,$7f,$80,$82,$84,$86,$88,$8a,$8c,$8e,$90,$93,$95,$98,$9a,$9d,$a0,$a3,$a6,$a9,$ac,$af,$b2,$b5,$b8,$bb,$be,$c2,$c5,$c8
h_ease_on_l:
	.byte $40,$37,$2e,$25,$1c,$14,$0b,$03,$fa,$f2,$ea,$e2,$da,$d2,$ca,$c3,$bc,$b5,$ae,$a7,$a1,$9b,$95,$90,$8a,$85,$81,$7c,$78,$74,$71,$6d,$6a,$68,$66,$64,$62,$61,$60,$60
h_ease_on_h:
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
h_ease_off_l:
	.byte $5f,$5f,$5e,$5d,$5b,$59,$57,$55,$52,$4e,$4b,$47,$43,$3e,$3a,$35,$2f,$2a,$24,$1e,$18,$11,$0a,$03,$fc,$f5,$ed,$e5,$dd,$d5,$cd,$c5,$bc,$b4,$ab,$a3,$9a,$91,$88,$80
h_ease_off_h:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

palette_f:
	.word $0000
	.word $0555
	.word $0aaa
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff
	.word $0fff

crawl_text:
	.word $ca
	.byte "Second Reality X16",0
	EMPTY_LINE
	.word $f3
	.byte "by Team FX",0
	EMPTY_LINE
	.word $a1
	.byte "Released September 2024",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $a8
	.byte "Now, a few words from",0
	.word $9e
	.byte "the members of Team FX:",0
	EMPTY_LINE
	.word $e9
	.byte "(MooingLemur)",0
	EMPTY_LINE
	.word $9a
	.byte "This has been a long road.",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $b5
	.byte "Porting Second Reality",0
	.word $b4
	.byte "to the Commander X16",0
	.word $9e
	.byte "was an idea that came to",0
	.word $98
	.byte "me during VCF Midwest 17",0
	.word $111
	.byte "in 2023.",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $101
	.byte "VERA's FX",0
	.word $c2
	.byte "extensions had been",0
	.word $d2
	.byte "recently released.",0
	EMPTY_LINE
	EMPTY_LINE
	.word $7d
	.byte "I pitched the idea to JeffreyH,",0
	.word $ac
	.byte "the author of VERA FX,",0
	.word $7b
	.byte "and he was certainly intrigued",0
	.word $e7
	.byte "by the idea. :)",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $9f
	.byte "I would like to shout out:",0
	EMPTY_LINE
	EMPTY_LINE
	.word $eb
	.byte "David Murray",0
	.word $9c
	.byte "for the original X16 vision",0
	EMPTY_LINE
	EMPTY_LINE
	.word $a4
	.byte "Kevin and Sara Williams",0
	.word $ce
	.byte "for making it real",0
	EMPTY_LINE
	EMPTY_LINE
	.word $102
	.byte "Joe Burks",0
	.word $8f
	.byte "for helping make it possible",0
	EMPTY_LINE
	EMPTY_LINE
	.word $f0
	.byte "Adrian Black",0
	.word $78
	.byte "for feedback and moral support",0
	EMPTY_LINE
	EMPTY_LINE
	.word $108
	.byte "nicco1690",0
	.word $9b
	.byte "for sound design feedback",0
	EMPTY_LINE
	EMPTY_LINE
	.word $10b
	.byte "zerobyte",0
	.word $78
	.byte "for being the brainchild of .zsm",0
	EMPTY_LINE
	EMPTY_LINE
	.word $100
	.byte "tildearrow",0
	.word $d9
	.byte "and the Furnace",0
	.word $cc
	.byte "community for the",0
	.word $97
	.byte "awesome tracker in which",0
	.word $e2
	.byte "this soundtrack",0
	.word $ea
	.byte "was arranged",0
	EMPTY_LINE
	EMPTY_LINE
	.word $ed
	.byte "TeriosShadow",0
	.word $10e
	.byte "for help",0
	.word $cf
	.byte "with math related",0
	.word $102
	.byte "debugging",0
	EMPTY_LINE
	EMPTY_LINE
	.word $109
	.byte "JeffreyH",0
	.word $dc
	.byte "for collaborating",0
	.word $db
	.byte "and for creating",0
	.word $ef
	.byte "the VERA FX",0
	.word $100
	.byte "extensions,",0
	.word $e4
	.byte "through which",0
	.word $c2
	.byte "many of this demo's",0
	.word $ef
	.byte "visualizations",0
	.word $d0
	.byte "are made possible",0
	EMPTY_LINE
	EMPTY_LINE
	.word $c2
	.byte "The Commander X16",0
	.word $115
	.byte "Discord",0
	EMPTY_LINE
	EMPTY_LINE
	.word $d4
	.byte "and Future Crew",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $a0
	.byte "I hope this demo inspires",0
	.word $ac
	.byte "others to discover what",0
	.word $8e
	.byte "the X16 is really capable of.",0
	EMPTY_LINE
	EMPTY_LINE
	.word $5d
	.byte "We've barely scratched the surface!",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $100
	.byte "(JeffreyH)",0
	EMPTY_LINE
	.word $c2
	.byte "text text text text",0
	EMPTY_LINE
	.word $c2
	.byte "text text text text",0
	EMPTY_LINE
	.word $c2
	.byte "text text text text",0
	EMPTY_LINE
	.word $c2
	.byte "text text text text",0
	EMPTY_LINE
	.word $c2
	.byte "text text text text",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $91
	.byte "Thank you for experiencing",0
	.word $ca
	.byte "Second Reality X16",0
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	EMPTY_LINE
	.word $ffff
