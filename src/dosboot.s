.import graceful_fail

.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.import scenevector

.macpack longbranch
.feature string_escapes

.include "x16.inc"
.include "macros.inc"

ym_get_chip_type = $C0A5
fat32_get_free_space = $C012

.macro BIOS_WRITE_TEXT text, delay
.local btxt
.local cont
	ldx #<btxt
	ldy #>btxt
.ifblank delay
	lda #0
.else
	lda #delay
.endif
	jsr do_bios_text
	bra cont
btxt:
	.byte text,0
cont:
.endmacro

.segment "DOSBOOT_ZP": zeropage
cur_x: .res 1
cur_y: .res 1
cur_blink: .res 1

txtptr: .res 2
memtmp: .res 2
.segment "DOSBOOT"
entry:
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	pha ; preserve old video mode so that we can
	; restore it to 240p if we had it set that way
	; since this part of the demo is high res

	; initialize vera
	jsr setup_vera

	jsr clear_text_area

	jsr setup_cursor_sprite

	jsr set_text_palette_target

	jsr setup_cursor_handler
	stz cur_x
	stz cur_y

	; load text tiles into VRAM
	LOADFILE "DOS-CHARSET.VTS", 0, $0000, 0

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 28

	; load butterfly into VRAM
	LOADFILE "DOS-BFLY.VBM", 0, $2000, 0
	; load energy star tiles into VRAM
	LOADFILE "DOS-ESTAR.VTS", 0, $4000, 0


	MUSIC_SYNC $FA

	; write first line banner
	BIOS_WRITE_TEXT "     VERA VGA BIOS v"

	lda #(63 << 1)
	sta Vera::Reg::Ctrl

	ldx $9f2a
	ldy #0

	jsr bios_output_number
	BIOS_WRITE_TEXT "."

	lda #(63 << 1)
	sta Vera::Reg::Ctrl

	ldx $9f2b
	ldy #0

	jsr bios_output_number
	BIOS_WRITE_TEXT "."

	lda #(63 << 1)
	sta Vera::Reg::Ctrl

	ldx $9f2c
	ldy #0

	jsr bios_output_number


	BIOS_WRITE_TEXT "\n     Copyright (C) 2023, Frank van den Hoef\n\n\n"

	jsr place_estar_and_bfly

	MUSIC_SYNC $FB

	BIOS_WRITE_TEXT "40 KB LOW RAM Detected\n"

	ldx #0
memtestloop:
	phx
	txa
	stz memtmp
	asl
	rol memtmp
	asl
	rol memtmp
	asl
	rol memtmp
	asl
	rol memtmp
	tax
	ldy memtmp

	jsr bios_output_number

	BIOS_WRITE_TEXT " KB HIGH RAM OK \r"

	WAITVSYNC 5

	plx
	inx
	cpx #33
	bcc memtestloop

	sec
	jsr X16::Kernal::MEMTOP

	cmp #0
	beq is2048

	stz memtmp
	asl
	rol memtmp
	asl
	rol memtmp
	asl
	rol memtmp
	tax
	ldy memtmp

	bra finalramtest


is2048:
	ldx #<2048
	ldy #>2048

finalramtest:
	jsr bios_output_number

	BIOS_WRITE_TEXT " KB HIGH RAM OK \n\n\n"

	BIOS_WRITE_TEXT "VGA: VERA with 128KB VRAM\n"

	sec
	.byte $c2,$03 ; REP #3 (65C816 detect)
	; will either do a NOP #3 on real 65C02 and modern "fixed" emulators
	; or a NOP NOP on older "broken" emulators
	bcc c816

	BIOS_WRITE_TEXT "CPU: Western Design Center 65C02\n"
	bra soundchip
	
c816:
	BIOS_WRITE_TEXT "CPU: Western Design Center 65C816\n"
soundchip:

	JSRFAR ym_get_chip_type, $0A

	cmp #0
	beq noym

	cmp #1
	beq opp

	cmp #2
	beq opm

	BIOS_WRITE_TEXT "FM sound chip: unknown\n"

	bra endsoundchk

noym:
	BIOS_WRITE_TEXT "FM sound chip: not detected\n"
	bra endsoundchk

opp:
	BIOS_WRITE_TEXT "FM sound chip: YM2164\n"
	bra endsoundchk

opm:
	BIOS_WRITE_TEXT "FM sound chip: YM2151\n"

endsoundchk:
	MUSIC_SYNC $FC

	BIOS_WRITE_TEXT "\nRemovable storage: 1\xab\x22 SD card: "

	WAITVSYNC 60

	BIOS_WRITE_TEXT "OK\n"
	

	MUSIC_SYNC $FD

	BIOS_WRITE_TEXT "\n\nStarting 2R-DOS..."

	WAITVSYNC 60

	BIOS_WRITE_TEXT "\nLoading VERAFX.DRV..."

	lda #15
	jsr spinny

	BIOS_WRITE_TEXT " \nPreparing for awesomeness..."

	lda #25
	jsr spinny

	BIOS_WRITE_TEXT " \n\n"

	MUSIC_SYNC $FE

	ldx #32
:	stz target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	jsr deregister_cursor_handler

	; restore video mode, keeping 240p if we started that way
	pla
	stz Vera::Reg::Ctrl
	sta Vera::Reg::DCVideo

	rts

.proc spinny
	pha
	BIOS_WRITE_TEXT "\\\x09|\x09/\x09-\x09", 1
	pla
	dec
	bne spinny
	rts
.endproc

.proc place_estar_and_bfly
	VERA_SET_ADDR ((Vera::VRAM_sprattr)+8), 1
	ldx #0
loop:
	lda sprattr,x
	sta Vera::Reg::Data0
	inx
	cpx #(7 * 8)
	bcc loop
	rts
ESTARX = 364
ESTARY = 0
ESTARDATA = $4000
BFLYDATA = $2000
sprattr:
.repeat 6, i
	.word ((ESTARDATA+(i * $800)) >> 5)
	.word (ESTARX+((i .mod 3)*64))
	.word (ESTARY+((i / 3)*64))
	.byte $04,$f0
.endrepeat
	;butterfly
	.word (BFLYDATA >> 5)
	.word $0000
	.word $0000
	.byte $04,$a0

.endproc

.proc bios_output_number ; .X .Y (lo hi)
	lda X16::Reg::ROMBank
	pha
	lda #4
	sta X16::Reg::ROMBank

	tya
	phx
	ply

	jsr X16::Math::GIVAYF
	jsr X16::Math::FOUT

	; output of fout is here.  skip the sign
	ldx #<$101
	ldy #>$101

	pla
	sta X16::Reg::ROMBank
	lda #0
	; fall through
.endproc

; !!! don't place anything here between bios_output_number and do_bios_text

.proc do_bios_text
	stx txtptr
	sty txtptr+1
	sta delay

	ldy #0
	bra start
loop:
	lda delay
	beq start
	phy
dloop:
	pha
	WAITVSYNC
	pla
	dec
	bne dloop
	ply
start:
	lda cur_x
	asl
	sta Vera::Reg::AddrL

	lda cur_y
	clc
	adc #$b0
	sta Vera::Reg::AddrM
	lda #$11
	sta Vera::Reg::AddrH

	lda (txtptr),y
	beq end
	cmp #13
	beq cr
	cmp #10
	beq lf
	cmp #9
	beq bs
	sta Vera::Reg::Data0
	inc cur_x
	iny
	bra loop
bs:
	dec cur_x
	iny
	bra loop
lf:
	inc cur_y
cr:
	stz cur_x
	iny
	bra loop
end:
	rts
delay:
	.byte 0
.endproc

.proc deregister_cursor_handler
	lda #$60 ; RTS
	sta scenevector
	rts
.endproc

.proc setup_cursor_handler
	lda #<cursor_handler
	sta scenevector+2
	lda #>cursor_handler
	sta scenevector+3
	lda #$ea ; NOP
	sta scenevector
	rts
.endproc

.proc cursor_handler

	; preserve FX
	lda Vera::Reg::Ctrl
	pha
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda Vera::Reg::FXCtrl
	pha
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl
	; preserve addrs
	lda Vera::Reg::AddrL
	pha
	lda Vera::Reg::AddrM
	pha
	lda Vera::Reg::AddrH
	pha
	; do blink
	VERA_SET_ADDR (2+(Vera::VRAM_sprattr)), 1

	stz cur_tmp
	lda cur_x
	asl
	;rol cur_tmp  ; no need, high byte only has two bits of precision anyway
	asl
	rol cur_tmp
	asl
	rol cur_tmp
	sta Vera::Reg::Data0
	lda cur_tmp
	sta Vera::Reg::Data0

	stz cur_tmp
	lda cur_y
	asl
	asl
	asl
	rol cur_tmp
	asl
	rol cur_tmp
	sta Vera::Reg::Data0
	lda cur_tmp
	sta Vera::Reg::Data0

	lda cur_blink
	inc
	cmp #14
	bcc :+
	lda #0
:	sta cur_blink
	cmp #7
	lda #0
	rol
	asl
	asl
	asl
	sta Vera::Reg::Data0

	; restore addrs
	stz Vera::Reg::Ctrl
	pla
	sta Vera::Reg::AddrH
	pla
	sta Vera::Reg::AddrM
	pla
	sta Vera::Reg::AddrL
	; restore FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	pla
	sta Vera::Reg::FXCtrl
	pla
	sta Vera::Reg::Ctrl	

	rts
cur_tmp:
	.byte 0
.endproc

.proc set_text_palette_target
	ldx #32
loop:
	lda textpalette-1,x
	sta target_palette-1,x
	dex
	bne loop

	rts
.endproc

.proc clear_text_area
	; enable FX

	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	lda #%01000000 ; enable cache writes
	sta Vera::Reg::FXCtrl
	lda #(6 << 1) ; DCSEL = 6
	; zero the cache
	sta Vera::Reg::Ctrl
	lda #$20 ; space
	sta $9f29
	sta $9f2b
	lda #$07
	sta $9f2a
	sta $9f2c
	stz Vera::Reg::Ctrl

	VERA_SET_ADDR $1B000, 3

	; clear 8K
	ldx #0
clearloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne clearloop

	; disable FX
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc setup_cursor_sprite
	; VGA cursor sprite, 4bpp, 8x16, 12 lines of blank, 2 lines of cursor, and 2 lines of blank
	VERA_SET_ADDR $08000, 1

	ldx #48
top:
	stz Vera::Reg::Data0
	dex
	bne top

	ldx #8
	lda #$77
middle:
	sta Vera::Reg::Data0
	dex
	bne middle

	ldx #8
bottom:
	stz Vera::Reg::Data0
	dex
	bne bottom

	VERA_SET_ADDR (Vera::VRAM_sprattr), 1
	lda #<($08000 >> 5)
	sta Vera::Reg::Data0
	lda #>($08000 >> 5)
	sta Vera::Reg::Data0
.repeat 5
	stz Vera::Reg::Data0
.endrepeat
	lda #%01000000
	sta Vera::Reg::Data0

	rts
.endproc

.proc setup_vera
	; set all sprites to disabled
	DISABLE_SPRITES

	; set VERA layers up
	; show layer 1+sprites
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$07
	ora #$60
	sta Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; letterbox for 640x~400
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	; shift ourselves over a little
	lda #14
	sta Vera::Reg::DCHStart
	stz Vera::Reg::Ctrl

	; 1:1 scale
	lda #$80
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; tile mode, 1bpp, 128x32
	lda #%00100000
	sta Vera::Reg::L1Config

	; $00000 tile base, 8x16
	lda #%00000010
	sta Vera::Reg::L1TileBase

	; reuse default text area
	lda #($1B000 >> 9)
	sta Vera::Reg::L1MapBase

	rts
.endproc


textpalette:
	.word $0000,$000a,$00a0,$00aa,$0a00,$0a0a,$0a50,$0aaa
	.word $0555,$055f,$05f5,$05ff,$0f55,$0f5f,$0ff5,$0fff
