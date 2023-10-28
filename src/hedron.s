.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.importzp ptr1, ptr2, tmp1zp, tmp2zp, tmp3zp, tmp4zp, tmp5zp, tmp6zp, tmp7zp, tmp8zp, tmp9zp
.importzp pstart, pend

.macpack longbranch

MADDRM = tmp1zp
SPRX = tmp2zp ; with tmp3zp
SPRY = tmp4zp ; with tmp5zp
SPRADDR = tmp6zp
P1BANK = tmp7zp
P2BANK = tmp8zp
SPRPG = tmp9zp

POLY1TRILISTBANK = $16
SPRITETRILISTBANK = $1F
REDTRILIST1BANK = $22
REDTRILIST2BANK = $28

.include "x16.inc"
.include "macros.inc"

.segment "HEDRON"
entry:
	jsr chessboard_in
	jsr chessboard_to_tiles
	jsr polyhedron_palette1
	jsr polyhedron
	jsr waitfornext
	rts

.proc chessboard_in
	LOADFILE "HEDRONCHESS.VBM", 0, $0000, 1 ; $10000 VRAM

	; fade all palette colors to #$444
	ldx #130
fill_grey:
	lda #$44
	sta target_palette-128,x
	inx
	lda #$04
	sta target_palette-128,x
	inx
	bne fill_grey

	; set up
	lda #0
	jsr setup_palette_fade

	; wait for syncval to hit #$10
	MUSIC_SYNC $10

	; set FX cache to all zeroes
	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c

	; wipe effect while fading
	lda #199
	sta bottomwipe
	stz topwipe
wipeloop:
	lda topwipe
	cmp #16
	bcs :+
	WAITVSYNC
:	lda topwipe
	and #2
	beq :+
	WAITVSYNC
:
	
	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set up cache writes
	lda #$40
	tsb Vera::Reg::FXCtrl

	stz Vera::Reg::Ctrl

	lda #$30
	sta Vera::Reg::AddrH

	ldx topwipe
	cpx #$80
	bcs done_wiping

	POS_ADDR_ROW_4BIT

	; write 80 times to clear 2 lines
	ldx #80
:	stz Vera::Reg::Data0
	dex
	bne :-

	inc topwipe
	inc topwipe

	ldx bottomwipe

	POS_ADDR_ROW_4BIT

	; write 40 times to clear 1 line
	ldx #40
:	stz Vera::Reg::Data0
	dex
	bne :-

	dec bottomwipe

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; clear cache writes
	lda #$40
	trb Vera::Reg::FXCtrl

	stz Vera::Reg::Ctrl

	lda topwipe
	and #7
	bne :+
	jsr apply_palette_fade_step
	jsr flush_palette
:
	jmp wipeloop
done_wiping:
	; now copy the front of the chessboard in

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set cache fills and writes
	lda #$60
	tsb Vera::Reg::FXCtrl

	stz Vera::Reg::Ctrl ; ADDR0
	ldx #128

	POS_ADDR_ROW_4BIT

	lda #$30
	sta Vera::Reg::AddrH ; increment 4, chessboard edge drawn here

	jsr draw_chessboard_edge

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; clear cache/fill writes
	lda #$60
	trb Vera::Reg::FXCtrl
	
	stz Vera::Reg::Ctrl

	; then load the new palette immediately
	LOADFILE "HEDRONCHESS.PAL", 0, $FA00, 1 ; palette 0+

	; wait one frame
	WAITVSYNC

	; and then do the chessboard animation
	; in the 60fps video, we have
	; 32 frames of falling (including 3 frames that are still)
	; 18 frames rising
	; 9 frames holding
	; 19 frames falling
	; 12 frames rising
	; 5 frames holding
	; 13 frames falling
	; 1 frame holding at the bottom
	; 8 frames rising
	; 2 frames holding
	; 8 frames falling
	; 3 frames holding at the bottom
	; 2 frames rising
	; 7 frames holding
	; 1 frame falling
	; done

	CHESSBOARD_ACCEL = $01
	MAX_INCREMENT = $96

	stz momentum_sign
	stz velocity
	stz increment
	stz bounce_count
bounce_loop:
	WAITVSYNC
	lda momentum_sign
	bne neg_momentum

	lda velocity
	clc
	adc #CHESSBOARD_ACCEL
	sta velocity

	adc increment
	sta increment
	cmp #MAX_INCREMENT
	bcc bounce_cont
	lda #$ff
	sta momentum_sign
	ldx bounce_count
	lda upward_momenta,x
	sta velocity
	inx
	stx bounce_count
	cpx #5
	jeq bounce_done
	bra bounce_cont
neg_momentum:
	lda velocity
	sec
	sbc #CHESSBOARD_ACCEL
	bcs :+
	stz momentum_sign
	lda #0
:	sta velocity
	lda increment
	sbc velocity
	sta increment
	bcs bounce_cont
	stz momentum_sign
	stz increment
.repeat 4
	WAITVSYNC
.endrepeat
bounce_cont:
	stz line_iter_frac
	
	; set FX cache to all zeroes
	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c    

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set cache writes/fill
	lda #$60
	tsb Vera::Reg::FXCtrl

	lda #1
	sta Vera::Reg::Ctrl ; position addr1
	ldx #0

	POS_ADDR_ROW_4BIT

	lda #$11
	sta Vera::Reg::AddrH
	stz Vera::Reg::Ctrl


	ldx #128
	stx line_iter

	POS_ADDR_ROW_4BIT

	lda #$30
	sta Vera::Reg::AddrH

	; write 24 lines of blank
	ldy #24
blankouter:
	ldx #5
blankloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne blankloop

	lda increment
	clc
	adc line_iter_frac
	sta line_iter_frac
	bcc :+
	inc line_iter
:	ldx line_iter

	POS_ADDR_ROW_4BIT

	dey
	bne blankouter

	; write perspective chessboard, 100 lines
	ldy #100
boardouter:
	ldx #5
boardloop:
.repeat 8
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat

	dex
	bne boardloop

	lda increment
	clc
	adc line_iter_frac
	sta line_iter_frac
	bcc :+
	inc line_iter
:	ldx line_iter
	cpx #200
	jcs end_bounce_loop

	POS_ADDR_ROW_4BIT

	dey
	jne boardouter

	; finish the chessboard edge
	ldy #10
edgeouter:
	ldx #5
edgeloop:
.repeat 8
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat

	dex
	bne edgeloop

	inc line_iter
	lda line_iter
	cmp #200
	bcs end_bounce_loop
	dey
	jne edgeouter

	; set FX cache to all zeroes
	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c    

	stz Vera::Reg::Ctrl

	; write up to 12 lines of blankness
	ldy #12
bottom_blank_outer:
	ldx #5
bottom_blank_loop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne bottom_blank_loop

	inc line_iter
	lda line_iter
	cmp #200
	bcc bottom_blank_outer

end_bounce_loop:
	jmp bounce_loop

bounce_done:
	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl


	rts
.endproc


.proc chessboard_to_tiles
	; then convert the static chessboard to tiles
	; and replace the bitmap with a tilemap

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set cache mode
	lda #%01100000
	sta Vera::Reg::FXCtrl
	stz Vera::Reg::FXMult ; zeroing the cache byte index

	stz Vera::Reg::Ctrl

	; 16x16 tiles
	ldx #0 ; tile number
	ldy #0 ; row within tile
chesstile_loop:
	jsr point_data1
	jsr point_data0
.repeat 2
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat

	iny
	cpy #16
	bcc chesstile_loop
	ldy #0
	inx
	cpx #120 ; temp
	bcc chesstile_loop

	; set up layer 0's params

	lda #%00000010 ; 4bpp 32x32
	sta Vera::Reg::L0Config
	lda #%10000011 ; $10000 16x16
	sta Vera::Reg::L0TileBase
	; mapbase is at $13C00
	lda #($13C00 >> 9)
	sta Vera::Reg::L0MapBase

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	; place tiles on map
	VERA_SET_ADDR $13C00, 1

	; empty tile set
	ldx #0
:	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	dex
	bne :-

	; actual tiles

	ldy #20
	ldx #0
:	stx Vera::Reg::Data0
	stz Vera::Reg::Data0
	inx
	dey
	bne :-
	ldy #12
:	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	dey
	bne :-
	ldy #20
	cpx #120
	bcc :--


	stz Vera::Reg::L0HScrollL
	stz Vera::Reg::L0HScrollH

	; enable display of layer 0
	
	WAITVSYNC
	lda #$10
	tsb Vera::Reg::DCVideo

	; then disable layer 1

	WAITVSYNC
	lda #$20
	trb Vera::Reg::DCVideo


	rts

point_data0:
	; data0/addr0
	stz Vera::Reg::Ctrl

	; (8 bit value into 16) << 7 is the same as >> 1 when swapping the bytes
	clc
	stx @tmp1
	lda #0
	lsr @tmp1
	ror
	sta Vera::Reg::AddrL
	tya
	asl
	asl
	asl
	adc Vera::Reg::AddrL
	sta Vera::Reg::AddrL
	lda @tmp1
	adc #0
	sta Vera::Reg::AddrM
	lda #$31 ; advance by 4
	sta Vera::Reg::AddrH

	rts
@tmp1:
	.byte 0
@tmp2:
	.byte 0


point_data1:
	phx

	; data1/addr1
	lda #$01
	tsb Vera::Reg::Ctrl

	txa
	ldx #0
	sec
@20:
	sbc #20
	bcc @20a
	inx
	bra @20
@20a:
	adc #20
	asl
	asl
	asl ; 8 bytes per 16 pixels
	sta @tmp1 ; byte offset within the row
	txa ; contains the tile row number
	asl
	asl
	asl
	asl ; 16 rows per tile
	sta @tmp2 ; row of tile
	tya ; row offset within tile
	adc @tmp2
	adc #128
	tax

	POS_ADDR_ROW_4BIT

	lda Vera::Reg::AddrL
	adc @tmp1
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
:	lda #$10
	sta Vera::Reg::AddrH
	
	plx
	rts
@tmp1:
	.byte 0
@tmp2:
	.byte 0
.endproc

.proc polyhedron_palette1
	stz Vera::Reg::Ctrl
	VERA_SET_ADDR (32 + Vera::VRAM_palette), 1
	ldx #0
:	lda pal,x
	sta Vera::Reg::Data0
	sta target_palette+32,x
	inx
	cpx #64
	bne :-
	rts
pal:
;	.word $0000,$000f,$0fff,$00f0,$0fff,$0f00,$0fff,$00ff
;	.word $0fff,$0f0f,$0fff,$0ff0,$0fff,$000f,$0fff,$000f
	.word $0000,$000c,$0ccc,$000b,$0bbb,$000a,$0aaa,$0009
	.word $0999,$0007,$0777,$0005,$0555,$0003,$0333,$0000
	.word $0000,$0c00,$0c00,$0722,$0a22,$0f00,$0300,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
.endproc


.proc polyhedron
	; load the triangle lists
	LOADFILE "HEDRONTRILIST1.DAT", POLY1TRILISTBANK, $a000
	LOADFILE "HEDRONTRILIST2.DAT", SPRITETRILISTBANK, $a000
	LOADFILE "HEDRONTRILIST3.DAT", REDTRILIST1BANK, $a000
	LOADFILE "HEDRONTRILIST4.DAT", REDTRILIST2BANK, $a000

	stz MADDRM
	stz SPRPG

	lda #POLY1TRILISTBANK
	sta P1BANK

	lda #REDTRILIST1BANK
	sta P2BANK

	stz ptr1
	stz ptr2
	lda #$a0
	sta ptr1+1
	sta ptr2+1

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

	WAITVSYNC

	; show bitmap layer + layer 0 + sprites
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$70
	sta Vera::Reg::DCVideo

	lda #<321
	sta SPRX
	lda #>321
	sta SPRX+1

	lda #<201
	sta SPRY
	lda #>201
	sta SPRY+1

	MUSIC_SYNC $11

main_loop:
	jsr wait_flip_and_clear_sprite1
	jsr flip_and_clear_l1

	jsr fill_ptr1_poly_bmp
	bcc main_loop

	; the last read is an empty frame, don't flip it

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	; set up second trilist
	lda #SPRITETRILISTBANK
	sta P1BANK

	stz ptr1
	lda #$a0
	sta ptr1+1

	lda #<128
	sta SPRX
	lda #>128
	sta SPRX+1

	lda #<66
	sta SPRY
	lda #>66
	sta SPRY+1

	; enter polygon filler mode (with cache writes, 4-bit mode)
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda #$46
	sta Vera::Reg::FXCtrl

	jsr fill_ptr1_poly_sprite
	jsr wait_flip_and_clear_sprite1
	jsr flip_and_clear_l1

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off	
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	lda #16
	sta pfadectr

	; fade some palette colors to #$000
	ldx #(258-32)
fill_black:
	stz target_palette-(256-32),x
	inx
	stz target_palette-(256-32),x
	inx
	bne fill_black

	; set up
	lda #0
	jsr setup_palette_fade

fadechessloop:
	jsr fill_ptr1_poly_sprite

	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off	
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	jsr apply_palette_fade_step
	jsr flush_palette

	jsr wait_flip_and_clear_sprite1
	jsr flip_and_clear_l1

	dec pfadectr
	bne fadechessloop

	lda #2
	sta Vera::Reg::L1HScrollH ; palette offset


redloop:
	jsr fill_ptr1_poly_sprite
	jsr fill_ptr2_poly_bmp
	beq redworksplit
	bcs switch_to_red2
	jsr wait_flip_and_clear_sprite1
	jsr flip_and_clear_l1
	bra redloop
redworksplit:
	jsr wait_flip_and_clear_sprite1
	bra redloop

switch_to_red2:
	stz ptr2
	lda #$a0
	sta ptr2+1
	lda #REDTRILIST2BANK
	sta P2BANK
	bra redloop





end:
	; set up DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; set FX off	
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
pfadectr:
	.byte 16
.endproc

.proc wait_flip_and_clear_sprite1
	WAITVSYNC

	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl

	; point sprite 1 to $18000 / $19000
	VERA_SET_ADDR (8+Vera::VRAM_sprattr), 1
	lda #<($18000 >> 5)
	ora SPRPG
	sta Vera::Reg::Data0
	lda #>($18000 >> 5)
	sta Vera::Reg::Data0
	lda SPRX
	sta Vera::Reg::Data0
	lda SPRX+1
	sta Vera::Reg::Data0
	lda SPRY
	sta Vera::Reg::Data0
	lda SPRY+1
	sta Vera::Reg::Data0
	lda #$0c
	sta Vera::Reg::Data0
	lda #$f1
	sta Vera::Reg::Data0

	; flip it
	lda SPRPG
	eor #$80
	sta SPRPG

	lsr
	lsr
	lsr
	ora #$80
	sta SPRADDR

	lda #$40
	sta Vera::Reg::FXCtrl

	lda #(6 << 1)
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c
	stz Vera::Reg::Ctrl

	; clear sprite
	stz Vera::Reg::AddrL
	lda SPRADDR
	sta Vera::Reg::AddrM
	lda #$31
	sta Vera::Reg::AddrH
	ldx #64 ; 64 cycles = 2k * 8 per loop * 4 cache
sprclearloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne sprclearloop

	; enter polygon filler mode (with cache writes, 4-bit mode)
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda #$46
	sta Vera::Reg::FXCtrl

	rts
.endproc

.proc flip_and_clear_l1
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

	; enter polygon filler mode (with cache writes, 4-bit mode)
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda #$46
	sta Vera::Reg::FXCtrl

	rts
.endproc



.proc fill_ptr1_poly_sprite
	lda P1BANK
	sta X16::Reg::RAMBank
triloop:
	; now read the triangle list
	stz skip2 ; reset the branch
	lda (ptr1)
	jmi msinglepart
	bit #$40
	bne mchangex2
mchangex1:
	lda #$29
	sta xlow
	lda #$2a
	sta xhigh
	bra mchange
mchangex2:
	lda #$2b
	sta xlow
	lda #$2c
	sta xhigh
mchange:
	INCPTR1

	; Y coordinate: will set ADDR0 to column 0 of this coordinate
	lda (ptr1)
	tax ; we'll leave this coordinate in X for use later in case we start offscreen

	INCPTR1

	lda #(4 << 1) | 1           ; DCSEL=4, ADDRSEL=1
    sta Vera::Reg::Ctrl

	; X coordinate: set X1 and X2 to this value
	lda (ptr1)

	sta $9f29 ; X1L
	sta $9f2b ; X2L

c0entry:
	stz $9f2a ; X1H
	stz $9f2c ; X2H

	lda #$30 ; +4 INCR on ADDR1
	sta Vera::Reg::AddrH

	lda #(3 << 1)               ; DCSEL=3
    sta Vera::Reg::Ctrl

	; X1 and X2 increments, low and high bytes
	; These should already be cooked inside the bin
	INCPTR1
	lda (ptr1)
	sta $9f29
	INCPTR1
	lda (ptr1)
	sta $9f2a
	INCPTR1
	lda (ptr1)
	sta $9f2b
	INCPTR1
	lda (ptr1)
	sta $9f2c

	lda #(6 << 1)               ; DCSEL=6
    sta Vera::Reg::Ctrl

	; Color index
	INCPTR1
	lda (ptr1)
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c

	; row count
	INCPTR1
	lda (ptr1)
	tay
	; no offscreen handling in sprite
onsc:
	; X should be positive (0-63)
	; set positions
	clc
	lda SPRADDR

	POS_ADDR_SPR_ROW_4BIT_AH
	lda #$61 ; + 32 INCR
	sta Vera::Reg::AddrH

	lda #(5 << 1) | 1               ; DCSEL=5, ADDRSEL=1
    sta Vera::Reg::Ctrl

mloop1:
	lda Vera::Reg::Data1 ; advances X1/X2
	ldx $9f2b
	jsr poly_fill_do_row ; optimized procs to draw the entire row
	lda Vera::Reg::Data0 ; advances Y
	dey
	bne mloop1
	lda #$00
skip2 = * - 1
	jne endoftri
part2:
	lda #(3 << 1)               ; DCSEL=3
    sta Vera::Reg::Ctrl

	; change X1 or X2 increment, low and high bytes
	INCPTR1
	lda (ptr1)
	sta $9fff
xlow = * - 2
	INCPTR1
	lda (ptr1)
	sta $9fff
xhigh = * - 2

	; part 2 row count
	INCPTR1
	lda (ptr1)
	tay

	lda #(5 << 1) | 1               ; DCSEL=5, ADDRSEL=1
    sta Vera::Reg::Ctrl

mloop2:
	lda Vera::Reg::Data1 ; advances X1/X2
	ldx $9f2b
	jsr poly_fill_do_row ; optimized procs to draw the entire row
	lda Vera::Reg::Data0 ; advances Y
	dey
	bne mloop2

	jmp endoftri


msinglepart:
	bit #$40
	bne mpart2only
mpart1only:
	inc skip2
	jmp mchange

mpart2only:
; but also could be end of frame
	cmp #$ff
	jeq endofframe
	cmp #$fe
	jeq end ; end of data

	INCPTR1

	; Y coordinate: will set ADDR0 to column 0 of this coordinate
	lda (ptr1)
	tax ; we'll leave this coordinate in X for use later in case we start offscreen

	lda #(4 << 1) | 1           ; DCSEL=4, ADDRSEL=1
    sta Vera::Reg::Ctrl

	INCPTR1

	; X1 coordinate: set X1
	lda (ptr1)
	sta $9f29 ; X1L

	INCPTR1

	; X2 coordinate: set X2
	lda (ptr1)
	sta $9f2b ; X2L

	inc skip2
	jmp c0entry

endoftri:
	INCPTR1
	jmp triloop
endofframe:
	INCPTR1
	lda X16::Reg::RAMBank
	sta P1BANK
	clc
	rts
end:
	lda #$a0
	sta ptr1+1
	stz ptr1
	lda #SPRITETRILISTBANK
	sta P1BANK
	jmp fill_ptr1_poly_sprite
.endproc


.proc fill_ptr1_poly_bmp
	lda P1BANK
	sta X16::Reg::RAMBank
triloop:
	; now read the triangle list
	stz skip2 ; reset the branch
	lda (ptr1)
	jmi msinglepart
	bit #$40
	bne mchangex2
mchangex1:
	lda #$29
	sta xlow
	lda #$2a
	sta xhigh
	bra mchange
mchangex2:
	lda #$2b
	sta xlow
	lda #$2c
	sta xhigh
mchange:
	INCPTR1

	; Y coordinate: will set ADDR0 to column 0 of this coordinate
	lda (ptr1)
	tax ; we'll leave this coordinate in X for use later in case we start offscreen

	INCPTR1

	lda #(4 << 1) | 1           ; DCSEL=4, ADDRSEL=1
    sta Vera::Reg::Ctrl

	; X coordinate: set X1 and X2 to this value
	lda (ptr1)

	sta $9f29 ; X1L
	sta $9f2b ; X2L

c0entry:
	stz $9f2a ; X1H
	stz $9f2c ; X2H

	lda #$30 ; +4 INCR on ADDR1
	sta Vera::Reg::AddrH

	lda #(3 << 1)               ; DCSEL=3
    sta Vera::Reg::Ctrl

	; X1 and X2 increments, low and high bytes
	; These should already be cooked inside the bin
	INCPTR1
	lda (ptr1)
	sta $9f29
	INCPTR1
	lda (ptr1)
	sta $9f2a
	INCPTR1
	lda (ptr1)
	sta $9f2b
	INCPTR1
	lda (ptr1)
	sta $9f2c

	lda #(6 << 1)               ; DCSEL=6
    sta Vera::Reg::Ctrl

	; Color index
	INCPTR1
	lda (ptr1)
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c

	; row count
	INCPTR1
	lda (ptr1)
	tay

offscloop:
	cpx #200 ; above 200 treat as offscreen
	bcc onsc
	lda Vera::Reg::Data1 ; advance X1/X2
	lda Vera::Reg::Data1 ; advance X1/X2 (needed twice) since we're not writing the row
	inx
	dey
	bne offscloop
	; entire top part was offscreen (should never happen)
onsc:
	; X should be positive (0-199)
	; set positions
	clc
	lda MADDRM
	POS_ADDR_ROW_4BIT_AH
	lda #$d0 ; + 160 INCR
	sta Vera::Reg::AddrH

	lda #(5 << 1) | 1               ; DCSEL=5, ADDRSEL=1
    sta Vera::Reg::Ctrl

mloop1:
	lda Vera::Reg::Data1 ; advances X1/X2
	ldx $9f2b
	jsr poly_fill_do_row ; optimized procs to draw the entire row
	lda Vera::Reg::Data0 ; advances Y
	dey
	bne mloop1
	lda #$00
skip2 = * - 1
	jne endoftri
part2:
	lda #(3 << 1)               ; DCSEL=3
    sta Vera::Reg::Ctrl

	; change X1 or X2 increment, low and high bytes
	INCPTR1
	lda (ptr1)
	sta $9fff
xlow = * - 2
	INCPTR1
	lda (ptr1)
	sta $9fff
xhigh = * - 2

	; part 2 row count
	INCPTR1
	lda (ptr1)
	tay

	lda #(5 << 1) | 1               ; DCSEL=5, ADDRSEL=1
    sta Vera::Reg::Ctrl

mloop2:
	lda Vera::Reg::Data1 ; advances X1/X2
	ldx $9f2b
	jsr poly_fill_do_row ; optimized procs to draw the entire row
	lda Vera::Reg::Data0 ; advances Y
	dey
	bne mloop2

	jmp endoftri


msinglepart:
	bit #$40
	bne mpart2only
mpart1only:
	inc skip2
	jmp mchange

mpart2only:
; but also could be end of frame
	cmp #$ff
	jeq endofframe
	cmp #$fe
	jeq end ; end of data

	INCPTR1

	; Y coordinate: will set ADDR0 to column 0 of this coordinate
	lda (ptr1)
	tax ; we'll leave this coordinate in X for use later in case we start offscreen

	lda #(4 << 1) | 1           ; DCSEL=4, ADDRSEL=1
    sta Vera::Reg::Ctrl

	INCPTR1

	; X1 coordinate: set X1
	lda (ptr1)
	sta $9f29 ; X1L

	INCPTR1

	; X2 coordinate: set X2
	lda (ptr1)
	sta $9f2b ; X2L

	inc skip2
	jmp c0entry

endoftri:
	INCPTR1
	jmp triloop
endofframe:
	INCPTR1
	lda X16::Reg::RAMBank
	sta P1BANK
	clc
	rts
end:
	lda X16::Reg::RAMBank
	sta P1BANK
	sec
	rts
.endproc



.proc fill_ptr2_poly_bmp
	lda P2BANK
	sta X16::Reg::RAMBank
triloop:
	; now read the triangle list
	stz skip2 ; reset the branch
	lda (ptr2)
	jmi msinglepart
	bit #$40
	bne mchangex2
mchangex1:
	lda #$29
	sta xlow
	lda #$2a
	sta xhigh
	bra mchange
mchangex2:
	lda #$2b
	sta xlow
	lda #$2c
	sta xhigh
mchange:
	INCPTR2

	; Y coordinate: will set ADDR0 to column 0 of this coordinate
	lda (ptr2)
	tax ; we'll leave this coordinate in X for use later in case we start offscreen

	INCPTR2

	lda #(4 << 1) | 1           ; DCSEL=4, ADDRSEL=1
    sta Vera::Reg::Ctrl

	; X coordinate: set X1 and X2 to this value
	lda (ptr2)

	sta $9f29 ; X1L
	sta $9f2b ; X2L

c0entry:
	stz $9f2a ; X1H
	stz $9f2c ; X2H

	lda #$30 ; +4 INCR on ADDR1
	sta Vera::Reg::AddrH

	lda #(3 << 1)               ; DCSEL=3
    sta Vera::Reg::Ctrl

	; X1 and X2 increments, low and high bytes
	; These should already be cooked inside the bin
	INCPTR2
	lda (ptr2)
	sta $9f29
	INCPTR2
	lda (ptr2)
	sta $9f2a
	INCPTR2
	lda (ptr2)
	sta $9f2b
	INCPTR2
	lda (ptr2)
	sta $9f2c

	lda #(6 << 1)               ; DCSEL=6
    sta Vera::Reg::Ctrl

	; Color index
	INCPTR2
	lda (ptr2)
	sta $9f29
	sta $9f2a
	sta $9f2b
	sta $9f2c

	; row count
	INCPTR2
	lda (ptr2)
	tay

offscloop:
	cpx #200 ; above 200 treat as offscreen
	bcc onsc
	lda Vera::Reg::Data1 ; advance X1/X2
	lda Vera::Reg::Data1 ; advance X1/X2 (needed twice) since we're not writing the row
	inx
	dey
	bne offscloop
	; entire top part was offscreen (should never happen)
onsc:
	; X should be positive (0-199)
	; set positions
	clc
	lda MADDRM
	POS_ADDR_ROW_4BIT_AH
	lda #$d0 ; + 160 INCR
	sta Vera::Reg::AddrH

	lda #(5 << 1) | 1               ; DCSEL=5, ADDRSEL=1
    sta Vera::Reg::Ctrl

mloop1:
	lda Vera::Reg::Data1 ; advances X1/X2
	ldx $9f2b
	jsr poly_fill_do_row ; optimized procs to draw the entire row
	lda Vera::Reg::Data0 ; advances Y
	dey
	bne mloop1
	lda #$00
skip2 = * - 1
	jne endoftri
part2:
	lda #(3 << 1)               ; DCSEL=3
    sta Vera::Reg::Ctrl

	; change X1 or X2 increment, low and high bytes
	INCPTR2
	lda (ptr2)
	sta $9fff
xlow = * - 2
	INCPTR2
	lda (ptr2)
	sta $9fff
xhigh = * - 2

	; part 2 row count
	INCPTR2
	lda (ptr2)
	tay

	lda #(5 << 1) | 1               ; DCSEL=5, ADDRSEL=1
    sta Vera::Reg::Ctrl

mloop2:
	lda Vera::Reg::Data1 ; advances X1/X2
	ldx $9f2b
	jsr poly_fill_do_row ; optimized procs to draw the entire row
	lda Vera::Reg::Data0 ; advances Y
	dey
	bne mloop2

	jmp endoftri


msinglepart:
	bit #$40
	bne mpart2only
mpart1only:
	inc skip2
	jmp mchange

mpart2only:
; but also could be end of frame
	cmp #$ff
	jeq endofframe
	cmp #$fe
	jeq end ; end of data
	cmp #$fd
	jeq work_split

	INCPTR2

	; Y coordinate: will set ADDR0 to column 0 of this coordinate
	lda (ptr2)
	tax ; we'll leave this coordinate in X for use later in case we start offscreen

	lda #(4 << 1) | 1           ; DCSEL=4, ADDRSEL=1
    sta Vera::Reg::Ctrl

	INCPTR2

	; X1 coordinate: set X1
	lda (ptr2)
	sta $9f29 ; X1L

	INCPTR2

	; X2 coordinate: set X2
	lda (ptr2)
	sta $9f2b ; X2L

	inc skip2
	jmp c0entry

endoftri:
	INCPTR2
	jmp triloop
endofframe:
	INCPTR2
	lda X16::Reg::RAMBank
	sta P2BANK
	clc
	rts
work_split:
	INCPTR2
	lda X16::Reg::RAMBank
	sta P2BANK
	lda #0
	clc
	rts
end:
	lda X16::Reg::RAMBank
	sta P2BANK
	sec
	rts
.endproc



.proc poly_fill_do_row
	jmp (poly_jt,x)
poly_jt:
	.word poly_noop, poly_pix1_pos0, poly_pix2_pos0, poly_pix3_pos0
	.word poly_pix4_pos0, poly_pix5_pos0, poly_pix6_pos0, poly_pix7_pos0

	.word poly_noop, poly_pix1_pos4, poly_pix2_pos4, poly_pix3_pos4
	.word poly_pix4_pos4, poly_pix5_pos4, poly_pix6_pos4, poly_pix7_pos4

	.word poly_noop, poly_pix1_pos1, poly_pix2_pos1, poly_pix3_pos1
	.word poly_pix4_pos1, poly_pix5_pos1, poly_pix6_pos1, poly_pix7_pos1

	.word poly_noop, poly_pix1_pos5, poly_pix2_pos5, poly_pix3_pos5
	.word poly_pix4_pos5, poly_pix5_pos5, poly_pix6_pos5, poly_pix7_pos5

	.word poly_noop, poly_pix1_pos2, poly_pix2_pos2, poly_pix3_pos2
	.word poly_pix4_pos2, poly_pix5_pos2, poly_pix6_pos2, poly_pix7_pos2

	.word poly_noop, poly_pix1_pos6, poly_pix2_pos6, poly_pix3_pos6
	.word poly_pix4_pos6, poly_pix5_pos6, poly_pix6_pos6, poly_pix7_pos6

	.word poly_noop, poly_pix1_pos3, poly_pix2_pos3, poly_pix3_pos3
	.word poly_pix4_pos3, poly_pix5_pos3, poly_pix6_pos3, poly_pix7_pos3

	.word poly_noop, poly_pix1_pos7, poly_pix2_pos7, poly_pix3_pos7
	.word poly_pix4_pos7, poly_pix5_pos7, poly_pix6_pos7, poly_pix7_pos7


	.word poly_pix8p0_pos0, poly_pix8p1_pos0, poly_pix8p2_pos0, poly_pix8p3_pos0
	.word poly_pix8p4_pos0, poly_pix8p5_pos0, poly_pix8p6_pos0, poly_pix8p7_pos0

	.word poly_pix8p0_pos4, poly_pix8p1_pos4, poly_pix8p2_pos4, poly_pix8p3_pos4
	.word poly_pix8p4_pos4, poly_pix8p5_pos4, poly_pix8p6_pos4, poly_pix8p7_pos4

	.word poly_pix8p0_pos1, poly_pix8p1_pos1, poly_pix8p2_pos1, poly_pix8p3_pos1
	.word poly_pix8p4_pos1, poly_pix8p5_pos1, poly_pix8p6_pos1, poly_pix8p7_pos1

	.word poly_pix8p0_pos5, poly_pix8p1_pos5, poly_pix8p2_pos5, poly_pix8p3_pos5
	.word poly_pix8p4_pos5, poly_pix8p5_pos5, poly_pix8p6_pos5, poly_pix8p7_pos5

	.word poly_pix8p0_pos2, poly_pix8p1_pos2, poly_pix8p2_pos2, poly_pix8p3_pos2
	.word poly_pix8p4_pos2, poly_pix8p5_pos2, poly_pix8p6_pos2, poly_pix8p7_pos2

	.word poly_pix8p0_pos6, poly_pix8p1_pos6, poly_pix8p2_pos6, poly_pix8p3_pos6
	.word poly_pix8p4_pos6, poly_pix8p5_pos6, poly_pix8p6_pos6, poly_pix8p7_pos6

	.word poly_pix8p0_pos3, poly_pix8p1_pos3, poly_pix8p2_pos3, poly_pix8p3_pos3
	.word poly_pix8p4_pos3, poly_pix8p5_pos3, poly_pix8p6_pos3, poly_pix8p7_pos3

	.word poly_pix8p0_pos7, poly_pix8p1_pos7, poly_pix8p2_pos7, poly_pix8p3_pos7
	.word poly_pix8p4_pos7, poly_pix8p5_pos7, poly_pix8p6_pos7, poly_pix8p7_pos7

poly_noop:
	rts

poly_pix1_pos0:
	lda #%11111101
	sta Vera::Reg::Data1
	rts
poly_pix1_pos1:
	lda #%11111110
	sta Vera::Reg::Data1
	rts
poly_pix1_pos2:
	lda #%11110111
	sta Vera::Reg::Data1
	rts
poly_pix1_pos3:
	lda #%11111011
	sta Vera::Reg::Data1
	rts
poly_pix1_pos4:
	lda #%11011111
	sta Vera::Reg::Data1
	rts
poly_pix1_pos5:
	lda #%11101111
	sta Vera::Reg::Data1
	rts
poly_pix1_pos6:
	lda #%01111111
	sta Vera::Reg::Data1
	rts
poly_pix1_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	rts

poly_pix2_pos0:
	lda #%11111100
	sta Vera::Reg::Data1
	rts
poly_pix2_pos1:
	lda #%11110110
	sta Vera::Reg::Data1
	rts
poly_pix2_pos2:
	lda #%11110011
	sta Vera::Reg::Data1
	rts
poly_pix2_pos3:
	lda #%11011011
	sta Vera::Reg::Data1
	rts
poly_pix2_pos4:
	lda #%11001111
	sta Vera::Reg::Data1
	rts
poly_pix2_pos5:
	lda #%01101111
	sta Vera::Reg::Data1
	rts
poly_pix2_pos6:
	lda #%00111111
	sta Vera::Reg::Data1
	rts
poly_pix2_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	lda #%11111101
	sta Vera::Reg::Data1
	rts

poly_pix3_pos0:
	lda #%11110100
	sta Vera::Reg::Data1
	rts
poly_pix3_pos1:
	lda #%11110010
	sta Vera::Reg::Data1
	rts
poly_pix3_pos2:
	lda #%11010011
	sta Vera::Reg::Data1
	rts
poly_pix3_pos3:
	lda #%11001011
	sta Vera::Reg::Data1
	rts
poly_pix3_pos4:
	lda #%01001111
	sta Vera::Reg::Data1
	rts
poly_pix3_pos5:
	lda #%00101111
	sta Vera::Reg::Data1
	rts
poly_pix3_pos6:
	lda #%00111111
	sta Vera::Reg::Data1
	lda #%11111101
	sta Vera::Reg::Data1
	rts
poly_pix3_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	lda #%11111100
	sta Vera::Reg::Data1
	rts

poly_pix4_pos0:
	lda #%11110000
	sta Vera::Reg::Data1
	rts
poly_pix4_pos1:
	lda #%11010010
	sta Vera::Reg::Data1
	rts
poly_pix4_pos2:
	lda #%11000011
	sta Vera::Reg::Data1
	rts
poly_pix4_pos3:
	lda #%01001011
	sta Vera::Reg::Data1
	rts
poly_pix4_pos4:
	lda #%00001111
	sta Vera::Reg::Data1
	rts
poly_pix4_pos5:
	lda #%00101111
	sta Vera::Reg::Data1
	lda #%11111101
	sta Vera::Reg::Data1
	rts
poly_pix4_pos6:
	lda #%00111111
	sta Vera::Reg::Data1
	lda #%11111100
	sta Vera::Reg::Data1
	rts
poly_pix4_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	lda #%11110100
	sta Vera::Reg::Data1
	rts

poly_pix5_pos0:
	lda #%11010000
	sta Vera::Reg::Data1
	rts
poly_pix5_pos1:
	lda #%11000010
	sta Vera::Reg::Data1
	rts
poly_pix5_pos2:
	lda #%01000011
	sta Vera::Reg::Data1
	rts
poly_pix5_pos3:
	lda #%00001011
	sta Vera::Reg::Data1
	rts
poly_pix5_pos4:
	lda #%00001111
	sta Vera::Reg::Data1
	lda #%11111101
	sta Vera::Reg::Data1
	rts
poly_pix5_pos5:
	lda #%00101111
	sta Vera::Reg::Data1
	lda #%11111100
	sta Vera::Reg::Data1
	rts
poly_pix5_pos6:
	lda #%00111111
	sta Vera::Reg::Data1
	lda #%11110100
	sta Vera::Reg::Data1
	rts
poly_pix5_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	lda #%11110000
	sta Vera::Reg::Data1
	rts

poly_pix6_pos0:
	lda #%11000000
	sta Vera::Reg::Data1
	rts
poly_pix6_pos1:
	lda #%01000010
	sta Vera::Reg::Data1
	rts
poly_pix6_pos2:
	lda #%00000011
	sta Vera::Reg::Data1
	rts
poly_pix6_pos3:
	lda #%00001011
	sta Vera::Reg::Data1
	lda #%11111101
	sta Vera::Reg::Data1
	rts
poly_pix6_pos4:
	lda #%00001111
	sta Vera::Reg::Data1
	lda #%11111100
	sta Vera::Reg::Data1
	rts
poly_pix6_pos5:
	lda #%00101111
	sta Vera::Reg::Data1
	lda #%11110100
	sta Vera::Reg::Data1
	rts
poly_pix6_pos6:
	lda #%00111111
	sta Vera::Reg::Data1
	lda #%11110000
	sta Vera::Reg::Data1
	rts
poly_pix6_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	lda #%11010000
	sta Vera::Reg::Data1
	rts


poly_pix7_pos0:
	lda #%01000000
	sta Vera::Reg::Data1
	rts
poly_pix7_pos1:
	lda #%00000010
	sta Vera::Reg::Data1
	rts
poly_pix7_pos2:
	lda #%00000011
	sta Vera::Reg::Data1
	lda #%11111101
	sta Vera::Reg::Data1
	rts
poly_pix7_pos3:
	lda #%00001011
	sta Vera::Reg::Data1
	lda #%11111100
	sta Vera::Reg::Data1
	rts
poly_pix7_pos4:
	lda #%00001111
	sta Vera::Reg::Data1
	lda #%11110100
	sta Vera::Reg::Data1
	rts
poly_pix7_pos5:
	lda #%00101111
	sta Vera::Reg::Data1
	lda #%11110000
	sta Vera::Reg::Data1
	rts
poly_pix7_pos6:
	lda #%00111111
	sta Vera::Reg::Data1
	lda #%11010000
	sta Vera::Reg::Data1
	rts
poly_pix7_pos7:
	lda #%10111111
	sta Vera::Reg::Data1
	lda #%11000000
	sta Vera::Reg::Data1
	rts

poly_pix8p0_pos0: ; fully aligned multiple of 8
	lda $9f2c
	cmp #$c0
	bcs @end
	lsr
@loop:
	stz Vera::Reg::Data1
	dec
	bne @loop
@end:
	rts

poly_pix8p0_pos1:
	lda #%00000010
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p

poly_pix8p0_pos2:
	lda #%00000011
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p

poly_pix8p0_pos3:
	lda #%00001011
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p

poly_pix8p0_pos4:
	lda #%00001111
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p

poly_pix8p0_pos5:
	lda #%00101111
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p

poly_pix8p0_pos6:
	lda #%00111111
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p

poly_pix8p0_pos7:
	lda #%10111111
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos0:
	lda #%11111101
	sta pend
	jmp poly_pix8p_eo

poly_pix8p1_pos1:
	lda #%00000010
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos2:
	lda #%00000011
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos3:
	lda #%00001011
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos4:
	lda #%00001111
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos5:
	lda #%00101111
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos6:
	lda #%00111111
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p1_pos7:
	lda #%10111111
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos0:
	lda #%11111100
	sta pend
	jmp poly_pix8p_eo

poly_pix8p2_pos1:
	lda #%00000010
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos2:
	lda #%00000011
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos3:
	lda #%00001011
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos4:
	lda #%00001111
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos5:
	lda #%00101111
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos6:
	lda #%00111111
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p2_pos7:
	lda #%10111111
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p_ec

poly_pix8p3_pos0:
	lda #%11110100
	sta pend
	jmp poly_pix8p_eo

poly_pix8p3_pos1:
	lda #%00000010
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p

poly_pix8p3_pos2:
	lda #%00000011
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p

poly_pix8p3_pos3:
	lda #%00001011
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p

poly_pix8p3_pos4:
	lda #%00001111
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p3_pos5:
	lda #%00101111
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p3_pos6:
	lda #%00111111
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p_ec

poly_pix8p3_pos7:
	lda #%10111111
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p4_pos0:
	lda #%11110000
	sta pend
	jmp poly_pix8p_eo

poly_pix8p4_pos1:
	lda #%00000010
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p

poly_pix8p4_pos2:
	lda #%00000011
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p

poly_pix8p4_pos3:
	lda #%00001011
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p4_pos4:
	lda #%00001111
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p4_pos5:
	lda #%00101111
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p_ec

poly_pix8p4_pos6:
	lda #%00111111
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p4_pos7:
	lda #%10111111
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p5_pos0:
	lda #%11010000
	sta pend
	jmp poly_pix8p_eo

poly_pix8p5_pos1:
	lda #%00000010
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p

poly_pix8p5_pos2:
	lda #%00000011
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p5_pos3:
	lda #%00001011
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p5_pos4:
	lda #%00001111
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p_ec

poly_pix8p5_pos5:
	lda #%00101111
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p5_pos6:
	lda #%00111111
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p5_pos7:
	lda #%10111111
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p_ec

poly_pix8p6_pos0:
	lda #%11000000
	sta pend
	jmp poly_pix8p_eo

poly_pix8p6_pos1:
	lda #%00000010
	sta pstart
	lda #%01000000
	sta pend
	jmp poly_pix8p

poly_pix8p6_pos2:
	lda #%00000011
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p6_pos3:
	lda #%00001011
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p_ec

poly_pix8p6_pos4:
	lda #%00001111
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p6_pos5:
	lda #%00101111
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p6_pos6:
	lda #%00111111
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p_ec

poly_pix8p6_pos7:
	lda #%10111111
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p_ec

poly_pix8p7_pos0:
	lda #%01000000
	sta pend
	jmp poly_pix8p_eo

poly_pix8p7_pos1:
	lda #%00000010
	sta pstart
	lda #%00000000
	sta pend
	jmp poly_pix8p

poly_pix8p7_pos2:
	lda #%00000011
	sta pstart
	lda #%11111101
	sta pend
	jmp poly_pix8p_ec

poly_pix8p7_pos3:
	lda #%00001011
	sta pstart
	lda #%11111100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p7_pos4:
	lda #%00001111
	sta pstart
	lda #%11110100
	sta pend
	jmp poly_pix8p_ec

poly_pix8p7_pos5:
	lda #%00101111
	sta pstart
	lda #%11110000
	sta pend
	jmp poly_pix8p_ec

poly_pix8p7_pos6:
	lda #%00111111
	sta pstart
	lda #%11010000
	sta pend
	jmp poly_pix8p_ec

poly_pix8p7_pos7:
	lda #%10111111
	sta pstart
	lda #%11000000
	sta pend
	jmp poly_pix8p_ec


poly_pix8p:
	lda $9f2c
	cmp #$c0
	bcs @end
	ldx pstart
	stx Vera::Reg::Data1
	lsr
	dec
	beq @final
@loop:
	stz Vera::Reg::Data1
	dec
	bne @loop
@final:
	lda pend
	sta Vera::Reg::Data1
@end:
	rts

poly_pix8p_ec:
	lda $9f2c
	cmp #$c0
	bcs @end
	ldx pstart
	stx Vera::Reg::Data1
	lsr
@loop:
	stz Vera::Reg::Data1
	dec
	bne @loop
@final:
	lda pend
	sta Vera::Reg::Data1
@end:
	rts


poly_pix8p_eo:
	lda $9f2c
	cmp #$c0
	bcs @end
	lsr
@loop:
	stz Vera::Reg::Data1
	dec
	bne @loop
@final:
	lda pend
	sta Vera::Reg::Data1
@end:
	rts



.endproc

.proc waitfornext
	MUSIC_SYNC $20


	ldx #32
:	stz target_palette-1,x
	dex
	bne :-

	lda target_palette

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1


	rts
.endproc


.proc draw_chessboard_edge
	lda #1 ; ADDR1
	sta Vera::Reg::Ctrl
	
	ldx #100

	POS_ADDR_ROW_4BIT

	lda #$11
	sta Vera::Reg::AddrH ; increment 1, chessboard edge here

	; draw 10 lines, which is 40 writes per row, so 400.
	ldx #<400
	ldy #(>400)+1 ; the +1 to allow the loop to end when reaching 0
edgeloop:
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
	dex
	bne edgeloop
	dey
	bne edgeloop

	rts
.endproc


line_iter:
	.byte 0
line_iter_frac:
	.byte 0
increment:
	.byte 0
topwipe:
	.byte 0
bottomwipe:
	.byte 0
vsync_count:
	.byte 0
velocity:
	.byte 0
momentum_sign:
	.byte 0
bounce_count:
	.byte 0
upward_momenta:
	.byte 12,8,5,2,0
