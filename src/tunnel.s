.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.importzp tmp1zp, tmp2zp, tmp3zp, tmp4zp, tmp5zp, tmp6zp, tmp7zp, tmp8zp, tmp9zp, tmp10zp, ptr1, ptr2
tunczp = ptr1
MADDRM = tmp1zp
minlevel = tmp2zp
leveltime = tmp3zp
time = tmp4zp
level = tmp5zp
point = tmp6zp
xcoordzp = tmp7zp
jdelta = tmp8zp
ycoordzp = tmp9zp
maxlevel = tmp10zp


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.include "tunnel.inc"
.include "flow.inc"

.segment "TUNNEL"
entry:


	LOADFILE "TUNCOORDS.BIN", $20, $a000

	stz MADDRM

	jsr full_clear
	jsr tunnel_palette
	jsr tunnel_main

	MUSIC_SYNC $30

	rts


LEVELS=128
POINTS=64

HIGH_RAM = $A000

liss_coords_x:
	.res 256
liss_coords_y:
	.res 256


.macro BANK bank
	ldx #bank
	stx X16::Reg::RAMBank
.endmacro

.proc full_clear
	; clear bitmap area completely

	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda #$40
	sta Vera::Reg::FXCtrl

	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c
	stz Vera::Reg::Ctrl

	stz Vera::Reg::AddrL
	stz Vera::Reg::AddrM
	lda #$30
	sta Vera::Reg::AddrH

	ldy #64 ; 64kB
	ldx #0  ; 1kB per loop (256 * 4 w/ cache)
fullclearloop:
	stz Vera::Reg::Data0
	dex
	bne fullclearloop
	dey
	bne fullclearloop

	; set bitmap mode for layer 1
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L1Config
	lda #(($08000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L1TileBase
	lda #1
	sta Vera::Reg::L1HScrollH ; palette offset

	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	WAITVSYNC
	rts
.endproc

.proc tunnel_palette
	stz Vera::Reg::Ctrl
	VERA_SET_ADDR (32 + Vera::VRAM_palette), 1
	ldx #0
:	lda pal,x
	sta Vera::Reg::Data0
	sta target_palette+32,x
	inx
	cpx #32
	bne :-
	rts
pal:
	.word $0000,$0111,$0222,$0333,$0444,$0555,$0666,$0777
	.word $0888,$0999,$0aaa,$0bbb,$0ccc,$0ddd,$0eee,$0fff
.endproc

.proc liss ; y = offset
	lda times2p32,y
	tax
	lda sinmtbl_x,x
	sta liss_coords_x,y
	lda times3,y
	tax
	lda sinmtbl_y,x
	sta liss_coords_y,y
	rts
.endproc

.proc init_tunnel
	ldy #(LEVELS - 1)
	sty minlevel
	ldy #0
:	jsr liss
	iny
	bne :-
	rts
.endproc

.proc draw_tunnel ; input = time
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	lda #$04
	sta Vera::Reg::FXCtrl ; set 4bpp mode
	stz Vera::Reg::Ctrl

	lda #(LEVELS - 1)
	sta level
level_loop:
	lda level
	cmp maxlevel
	bcs next_level
	cmp minlevel
	bcc end
	adc time
	bit #$02
	beq next_level

	sta leveltime
	; nibble index fun
	and #2
	sta Vera::Reg::AddrH
	; point the RAM bank to all the tunnel coords
	lda #$20
	bit level
	bvc :+
	ora #$01
:	sta X16::Reg::RAMBank
	; self-mod pointer to our tun coords location
	; such that Y is set so that it iterates by 2*POINTS
	; before reaching zero.  This means for 64 points,
	; TUNC1 and TUNC2 point to a half page before
	; the actual location, and Y starts out at #128
	lda level
	lsr
	and #$1f
	ora #$a0
	tay
	lda #0
	ror
	sbc #((POINTS * 2) - 1) ; carry is clear, subtract 1 less
	sta TUNC1
	sta TUNC2
	tya
	sbc #0
	sta TUNC1+1
	sta TUNC2+1
	ldx level
	lda level2color,x
	sta LEVC
	ldy #(256 - (POINTS * 2))
point_loop:
	ldx leveltime
	clc

	lda $ffff,y
TUNC1 = * - 2
	adc liss_coords_y,x
	cmp #200
	bcs next_point2
	sta ycoordzp

	iny

	lda $ffff,y
TUNC2 = * - 2
	adc liss_coords_x,x
	cmp #160
	bcs next_point
	ldx ycoordzp

	adc addrl_per_row_4bit,x
	sta Vera::Reg::AddrL
	lda MADDRM
	adc addrm_per_row_4bit,x
	sta Vera::Reg::AddrM

	lda #$ff
LEVC = * - 1
	sta Vera::Reg::Data0
next_point:
	iny
	bne point_loop
next_level:
	dec level
	bpl level_loop
end:
	; done drawing frame
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl ; clear FX (4bpp mode)
	stz Vera::Reg::Ctrl

	rts	
next_point2:
	iny
	iny
	bne point_loop
	jmp next_level
.endproc

.proc tunnel_main
	jsr init_tunnel
	stz time
	lda #128
	sta maxlevel
openloop:
	jsr X16::Kernal::RDTIM
	sta jdelta
	jsr draw_tunnel
	jsr wait_flip_and_clear_l1
	jsr X16::Kernal::RDTIM
	sec
	sbc jdelta
	clc
	sta jdelta
	adc time
	sta time
	lda minlevel
	cmp #20
	bcc midloop
	sec
	sbc jdelta
	bpl :+
	lda #0
:	sta minlevel
	jmp openloop
midloop:
	jsr X16::Kernal::RDTIM
	sta jdelta
	jsr draw_tunnel
	jsr wait_flip_and_clear_l1
	jsr X16::Kernal::RDTIM
	sec
	sbc jdelta
	clc
	sta jdelta
	adc time
	sta time
	lda syncval
	cmp #$2a
	bcc midloop
endloop:
	jsr X16::Kernal::RDTIM
	sta jdelta
	jsr draw_tunnel
	jsr wait_flip_and_clear_l1
	jsr X16::Kernal::RDTIM
	sec
	sbc jdelta
	clc
	sta jdelta
	adc time
	sta time
	lda maxlevel
	cmp #25
	bcc return
	sec
	sbc jdelta
	bpl :+
	lda #0
:	sta maxlevel
	jmp endloop
return:
	rts
lisslevel:
	.byte 0
.endproc

.proc wait_flip_and_clear_l1
	WAITVSYNC
;	sta $9fb9 ; debug
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #$40
	sta Vera::Reg::FXCtrl

	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c
	stz Vera::Reg::Ctrl

	; double buffer flip

	; flip it
	lda MADDRM
	eor #$80
	sta MADDRM

	stz Vera::Reg::AddrL
	sta Vera::Reg::AddrM

	lda #$30
	sta Vera::Reg::AddrH

	; repoint L1 bitmap
	lda Vera::Reg::L1TileBase
	eor #$40
	sta Vera::Reg::L1TileBase

	; double buffer flip complete

	; clear draw buffer

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

	rts
.endproc
