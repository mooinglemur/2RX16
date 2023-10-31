.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.importzp tmp1zp, tmp2zp, tmp3zp, tmp4zp, tmp5zp, tmp6zp, tmp7zp, tmp9zp, ptr1, ptr2
tunczp = ptr1
MADDRM = tmp1zp
minlevel = tmp2zp
leveltime = tmp3zp
time = tmp4zp
level = tmp5zp
point = tmp6zp
xcoordzp = tmp7zp
ycoordzp = tmp9zp


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.include "tunnel.inc"

.segment "TUNNEL"
entry:


	LOADFILE "TUNCOORDS.BIN", $20, $a000

	stz MADDRM

	jsr full_clear
	jsr tunnel_palette
	jsr tunnel_main

	MUSIC_SYNC $30

	ldx #32
:   stz target_palette-1,x
	dex
	bne :-

	lda target_palette

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1


	rts


LEVELS=128
POINTS=64

HIGH_RAM = $A000

liss_coords_x_l:
	.res LEVELS
liss_coords_x_h:
	.res LEVELS
liss_coords_y_l:
	.res LEVELS
liss_coords_y_h:
	.res LEVELS


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
	tya
	and #(LEVELS - 1)
	tax
	lda times2p32,y
	phy
	tay
	lda cosmtbl_l,y
	sta liss_coords_x_l,x
	lda cosmtbl_h,y
	sta liss_coords_x_h,x
	ply
	lda times6,y
	tay
	lda cosmtbl_l,y
	sta liss_coords_y_l,x
	lda cosmtbl_h,y
	sta liss_coords_y_h,x
	rts
.endproc

.proc init_tunnel
	ldy #(LEVELS - 1)
	sty minlevel
:	phy
	jsr liss
	ply
	dey
	bpl :-
	rts
.endproc

.proc draw_tunnel ; input = time
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	lda #$04
	sta Vera::Reg::FXCtrl ; set 4bpp mode
	stz Vera::Reg::Ctrl

	lda minlevel
	beq :+
;	lda #120
;	sta minlevel
	dec minlevel
:

	lda #(LEVELS - 1)
	sta level
level_loop:
	lda level
	cmp minlevel
	jcc next_level
	clc
	adc time
	bit #2
	jeq next_level

	inc
	and #(LEVELS - 1)
	sta leveltime
	
	; point the RAM bank to all the tunnel coords
	lda level
	; 128/32
	lsr
	lsr
	lsr
	lsr
	lsr
	ora #$20
	sta X16::Reg::RAMBank
	; point the ZP pointer to our tun coords
	lda level
	and #$1f
	ora #$a0
	sta tunczp+1
	stz tunczp
	stz point
	ldx #0
point_loop:
	ldy times4,x
	ldx leveltime
	clc
	lda (tunczp),y
	adc liss_coords_x_l,x
	sta xcoordzp
	iny
	lda (tunczp),y
	adc liss_coords_x_h,x
	cmp #2
	jcs next_point ; is (negative or above 512, which is > 320)
	sta xcoordzp+1
	iny
	;clc - already clear
	lda (tunczp),y
	adc liss_coords_y_l,x
	sta ycoordzp
	iny
	lda (tunczp),y
	adc liss_coords_y_h,x
	jne next_point ; is negative (or above 256, which is > 200)
	;sta ycoordzp+1 ; (we don't use this)
	lda xcoordzp+1
	beq xok
	lda xcoordzp
	cmp #<320
	jcs next_point ; is >= 320
xok:
	ldx ycoordzp
	cpx #200
	bcs next_point ; is >= 200
	lda MADDRM
	;clc - already clear
	POS_ADDR_ROW_4BIT_AH
	lsr xcoordzp+1
	lda xcoordzp
	ror
	php ; save whether odd pixel
	clc
	adc Vera::Reg::AddrL
	sta Vera::Reg::AddrL
	lda Vera::Reg::AddrM
	adc #0
	sta Vera::Reg::AddrM
	lda #0
	plp
	rol
	asl
	sta Vera::Reg::AddrH ; nibble index
	ldx level
	lda level2color,x
	sta Vera::Reg::Data0
next_point:
	inc point
	ldx point
	cpx #POINTS
	jcc point_loop
next_level:
	dec level
	jpl level_loop

	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl ; clear FX (4bpp mode)
	stz Vera::Reg::Ctrl

	rts	

.endproc

.proc tunnel_main
	jsr init_tunnel
	stz time
loop:
	jsr draw_tunnel
	jsr wait_flip_and_clear_l1
	inc time
	bra loop
.endproc

.proc wait_flip_and_clear_l1
	WAITVSYNC
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
