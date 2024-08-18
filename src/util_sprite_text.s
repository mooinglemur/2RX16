; functions
.export sprite_text_pos
.export sprite_text_do
.export sprite_text_pos_y400
.export sprite_scroll_up
.export sprite_init

.export sprite_text_stamp
.export bmp_scroll_up_2bpp

.import addrl_per_row_8bit
.import addrm_per_row_8bit
.import addrh_per_row_8bit

.import addrl_per_hrow_8bit
.import addrm_per_hrow_8bit
.import addrh_per_hrow_8bit

.include "x16.inc"

.macpack longbranch

.segment "ZEROPAGE"
zptmp1:
	.res 1
zptmp2:
	.res 1
scroll_step:
	.res 1

.segment "BSS"
row_start:
	.res 256
row_end:
	.res 256
.segment "UTIL"

TXTDATA_ADDR = $18000

.proc sprite_init
	ldx #0
	lda #80
:	sta row_start,x
	sta row_end,x
	inx
	bne :-
	rts
.endproc

.proc sprite_text_pos
	stx xpos
	stz xpos+1
	sty ypos
	stz ypos+1
	rts
.endproc

.proc sprite_text_pos_y400
	stx xpos
	sty xpos+1
	lda #<400
	sta ypos
	lda #>400
	sta ypos+1
	rts
.endproc

.proc sprite_scroll_up
	VERA_SET_ADDR ((Vera::VRAM_sprattr)+4), 0

	ldy #128
loop:
	ldx Vera::Reg::AddrL
	lda Vera::Reg::Data0
	sec
	sbc #1
	sta Vera::Reg::Data0
	inx
	stx Vera::Reg::AddrL
	lda Vera::Reg::Data0
	sbc #0
	sta Vera::Reg::Data0
	and #$03
	cmp #$02
	clc
	beq sprite_off
	txa
	adc #7
cont:
	sta Vera::Reg::AddrL
	lda Vera::Reg::AddrM
	adc #0
	sta Vera::Reg::AddrM
	dey
	bne loop
	rts
sprite_off:
	inx
	stx Vera::Reg::AddrL
	stz Vera::Reg::Data0
	txa
	adc #6
	bra cont
.endproc

.proc bmp_scroll_up_2bpp
	lda #(2 << 1) ; DCSEL = 2, ADDRSEL = 0
	sta Vera::Reg::Ctrl

	lda #%01100000
	sta Vera::Reg::FXCtrl ; cache in/out
	stz Vera::Reg::FXMult ; reset cache byte index

	ldx #0
loop:
	lda row_start,x
	cmp row_start+1,x
	bcc	:+
	lda row_start+1,x
:	and #$fc
	sta zptmp1
	lda row_end,x
	cmp row_end+1,x
	bcs :+
	lda row_end+1,x
	sec
:	sbc zptmp1
	jeq next
	lsr
	lsr
	sta zptmp2

	stz Vera::Reg::Ctrl

	lda zptmp1
	clc
	adc addrl_per_row_8bit,x
	sta Vera::Reg::AddrL
	lda addrm_per_row_8bit,x
	adc #0
	sta Vera::Reg::AddrM
	lda addrh_per_row_8bit,x
	adc #%00110000
	sta Vera::Reg::AddrH

	lda #1
	sta Vera::Reg::Ctrl

	lda zptmp1
	clc
	adc addrl_per_hrow_8bit,x
	sta Vera::Reg::AddrL
	lda addrm_per_hrow_8bit,x
	adc #0
	sta Vera::Reg::AddrM
	lda addrh_per_hrow_8bit,x
	adc #%00010000
	sta Vera::Reg::AddrH

	ldy zptmp2
	cpy #9
	bcc eraseloop0
.repeat 8
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat
	tya
	sec
	sbc #8
	tay
eraseloop0:
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
	dey
	bne eraseloop0

	stz Vera::Reg::Ctrl

	lda zptmp1
	clc
	adc addrl_per_hrow_8bit,x
	sta Vera::Reg::AddrL
	lda addrm_per_hrow_8bit,x
	adc #0
	sta Vera::Reg::AddrM
	lda addrh_per_hrow_8bit,x
	adc #%00110000
	sta Vera::Reg::AddrH

	lda #1
	sta Vera::Reg::Ctrl

	lda zptmp1
	clc
	adc addrl_per_row_8bit+1,x
	sta Vera::Reg::AddrL
	lda addrm_per_row_8bit+1,x
	adc #0
	sta Vera::Reg::AddrM
	lda addrh_per_row_8bit+1,x
	adc #%00010000
	sta Vera::Reg::AddrH

	ldy zptmp2
	cpy #9
	bcc eraseloop1
.repeat 8
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
.endrepeat
	tya
	sec
	sbc #8
	tay
eraseloop1:
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	lda Vera::Reg::Data1
	stz Vera::Reg::Data0
	dey
	bne eraseloop1

next:
	lda scroll_step
	beq after_step
	lda row_start+1,x
	sta row_start,x

	lda row_end+1,x
	sta row_end,x
after_step:

	inx
	cpx #220
	jne loop

	lda scroll_step
	eor #$ff
	sta scroll_step

	lda #(2 << 1) ; DCSEL = 2, ADDRSEL = 0
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl
	rts
.endproc

.proc sprite_text_do
	sta palidx

	lda xpos
	sta start_xpos
	lda xpos+1
	sta start_xpos+1

	stx SPRTXT
	sty SPRTXT+1
	bra mainloop
incidx:
	inc spridx
nochar:
	lda xpos
	clc
	adc pitch
	sta xpos
	bcc :+
	inc xpos+1
:   cpy #0
	beq mainloop
	tya
	ldy #0
	bra char
punct1:
	sbc #$20 ; +1 for carry clear
	tax
	lda punct1tbl,x
	beq nochar
	bra char
punct2:
	sbc #$39 ; +1 for carry clear
	tax
	lda punct2tbl,x
	beq nochar
	bra char
mainloop:
	lda #13
	sta pitch
	ldy #0
	lda $ffff
SPRTXT = * - 2
	jeq done
	inc SPRTXT
	bne :+
	inc SPRTXT+1
:	cmp #$0f ; less than this is the Dolby logo
	bcs :+
	adc #$4c
	bra char
:	cmp #$21 ; everything space and earlier we skip
	bcc nochar
	cmp #$30 ; punctuation before numbers
	bcc punct1
	cmp #$3a
	bcs :+
	adc #$04
	bra char
:	cmp #$41 ; punctuation before letters
	bcc punct2
	cmp #$5b ; captials
	bcs :+
	sec
	sbc #$41
	cmp #22 ; letter W has a second part
	bne char
	ldy #74
	bra char
:   cmp #$61
	bcc nochar ; temporarily skip ASCII in between upper and lower
	cmp #$7b
	bcs nochar ; anything above the lowercase is null
	sec
	sbc #$47 ; shift down into sprite range
	cmp #38 ; letter m has second part
	bne :+
	ldy #75
	bra char
:   cmp #48 ; letter w has second part
	bne char
	ldy #76
char:
	tax
	lda pitches,x
	sta pitch

	lda spridx
	and #$7f
	stz SPH
.repeat 3
	asl
	rol SPH
.endrepeat
	adc #<Vera::VRAM_sprattr
	sta Vera::Reg::AddrL
	lda #$ff
SPH = * - 1
	adc #>Vera::VRAM_sprattr
	sta Vera::Reg::AddrM
	lda #(^Vera::VRAM_sprattr) | $10
	sta Vera::Reg::AddrH

	txa
	stz SAH
.repeat 3
	asl
	rol SAH
.endrepeat
	adc #<(TXTDATA_ADDR >> 5)
	sta Vera::Reg::Data0
	lda #$ff
SAH = * - 1
	adc #>(TXTDATA_ADDR >> 5)
	sta Vera::Reg::Data0
	lda xpos
	sta Vera::Reg::Data0
	lda xpos+1
	sta Vera::Reg::Data0
	lda ypos
	sta Vera::Reg::Data0
	lda ypos+1
	sta Vera::Reg::Data0
	lda #$0c
	sta Vera::Reg::Data0
	lda palidx
	ora #%10010000
	sta Vera::Reg::Data0
	jmp incidx
done:
	rts
.endproc

.proc sprite_text_stamp
	sta palidx

	lda xpos
	sta start_xpos
	lda xpos+1
	sta start_xpos+1

	stx SPRTXT
	sty SPRTXT+1
	bra mainloop
nochar:
	lda xpos
	clc
	adc pitch
	sta xpos
	bcc :+
	inc xpos+1
:   cpy #0
	beq mainloop
	tya
	ldy #0
	bra char
punct1:
	sbc #$20 ; +1 for carry clear
	tax
	lda punct1tbl,x
	beq nochar
	bra char
punct2:
	sbc #$39 ; +1 for carry clear
	tax
	lda punct2tbl,x
	beq nochar
	bra char
mainloop:
	lda #13
	sta pitch
	ldy #0
	lda $ffff
SPRTXT = * - 2
	jeq done
	inc SPRTXT
	bne :+
	inc SPRTXT+1
:	cmp #$0f ; less than this is the Dolby logo
	bcs :+
	adc #$4c
	bra char
:	cmp #$21 ; everything space and earlier we skip
	bcc nochar
	cmp #$30 ; punctuation before numbers
	bcc punct1
	cmp #$3a
	bcs :+
	adc #$04
	bra char
:	cmp #$41 ; punctuation before letters
	bcc punct2
	cmp #$5b ; captials
	bcs :+
	sec
	sbc #$41
	cmp #22 ; letter W has a second part
	bne char
	ldy #74
	bra char
:   cmp #$61
	bcc nochar ; temporarily skip ASCII in between upper and lower
	cmp #$7b
	bcs nochar ; anything above the lowercase is null
	sec
	sbc #$47 ; shift down into sprite range
	cmp #38 ; letter m has second part
	bne :+
	ldy #75
	bra char
:   cmp #48 ; letter w has second part
	bne char
	ldy #76
char:
	tax
	lda pitches,x
	sta pitch

	lda #1
	sta Vera::Reg::Ctrl ; ADDRSEL = 1

	lda #<TXTDATA_ADDR
	sta Vera::Reg::AddrL

	txa
	clc
	adc #>TXTDATA_ADDR
	sta Vera::Reg::AddrM

	lda #%00010000
	adc #^TXTDATA_ADDR
	sta Vera::Reg::AddrH

	stz Vera::Reg::Ctrl

	lda xpos+1
	sta tmp1
	lda xpos
	lsr tmp1
	ror
	lsr tmp1
	ror
	clc
	adc #<64000
	sta Vera::Reg::AddrL
	lda #>64000
	adc tmp1
	sta Vera::Reg::AddrM

	lda xpos
	lsr
	bcs odd
	lsr
	bcs two
zero:
	jmp place_zero
odd:
	lsr
	bcs three
one:
	jmp place_one
two:
	jmp place_two
three:
	jmp place_three
done:
	lda start_xpos+1
	sta zptmp1
	lda start_xpos
	lsr zptmp1
	ror
	lsr zptmp1
	ror
	sta zptmp1

	lda xpos+1
	sta zptmp2
	lda xpos
	lsr zptmp2
	ror
	lsr zptmp2
	ror
	sta zptmp2

	; round row end up
	lda xpos
	and #$0f
	beq :+
	clc
	lda #4
	adc zptmp2
	sta zptmp2
:

	ldx #200
:	lda zptmp1
	sta row_start,x
	lda zptmp2
	sta row_end,x
	inx
	cpx #210
	bne :-

	lda xpos
	sec
	sbc start_xpos
	sta xpos
	lda xpos+1
	sbc start_xpos+1
	lsr
	sta xpos+1
	lda xpos
	ror
	sta xpos

	lda xpos
	ora xpos+1
	beq end

	lda #<320
	sec
	sbc xpos
	sta xpos
	lda #>320
	sbc xpos+1
	sta xpos+1

	lda #10
	sta $9fbb
	lda xpos
	sta $9fb9
	lda xpos+1
	sta $9fba
end:
	rts

place_zero:
	lda #%00010000
	sta Vera::Reg::AddrH

	phy

	ldx #32
loop0:
.repeat 4
	lda Vera::Reg::Data1
	tay
	asl
	asl
	and #$c0
	sta tmp1
	tya

	asl
	asl
	asl
	asl
	and #$30
	tsb tmp1

	lda Vera::Reg::Data1
	tay
	lsr
	lsr
	and #$0c
	tsb tmp1
	tya

	and #$03
	ora tmp1
	sta Vera::Reg::Data0
.endrepeat
	lda Vera::Reg::AddrL
	clc
	adc #156
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
	bne :+
	inc Vera::Reg::AddrH
:	dex
	jne loop0

	ply
	jmp nochar


place_one:
	stz Vera::Reg::AddrH

	phy

	ldx #32
loop1:
	lda #%11111000
	trb Vera::Reg::AddrH

	lda Vera::Reg::Data0
	and #$c0
	sta tmp1

	lda #%00010000
	tsb Vera::Reg::AddrH
.repeat 4
	lda Vera::Reg::Data1
	tay

	and #$30
	tsb tmp1

	tya
	asl
	asl

	and #$0c
	tsb tmp1

	lda Vera::Reg::Data1
	tay

	lsr
	lsr
	lsr
	lsr

	and #$03
	ora tmp1

	sta Vera::Reg::Data0

	tya
	ror
	ror
	ror
	and #$c0
	sta tmp1
.endrepeat
	sta Vera::Reg::Data0

	lda Vera::Reg::AddrL
	clc
	adc #155
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
	bne :+
	inc Vera::Reg::AddrH
:	dex
	jne loop1

	ply
	jmp nochar


place_two:
	stz Vera::Reg::AddrH

	phy

	ldx #32
loop2:
	lda #%11111000
	trb Vera::Reg::AddrH

	lda Vera::Reg::Data0

	and #$f0
	sta tmp1

	lda #%00010000
	tsb Vera::Reg::AddrH
.repeat 4
	lda Vera::Reg::Data1
	tay
	lsr
	lsr
	and #$0c
	tsb tmp1
	tya

	and #$03
	ora tmp1
	sta Vera::Reg::Data0

	lda Vera::Reg::Data1
	tay
	asl
	asl
	and #$c0
	sta tmp1
	tya

	asl
	asl
	asl
	asl
	and #$30
	tsb tmp1
.endrepeat
	lda tmp1
	sta Vera::Reg::Data0

	lda Vera::Reg::AddrL
	clc
	adc #155
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
	bne :+
	inc Vera::Reg::AddrH
:	dex
	jne loop2

	ply
	jmp nochar

place_three:
	stz Vera::Reg::AddrH

	phy

	ldx #32
loop3:
	lda #%11111000
	trb Vera::Reg::AddrH

	lda Vera::Reg::Data0
	and #$fc
	sta tmp1

	lda #%00010000
	tsb Vera::Reg::AddrH
.repeat 4
	lda Vera::Reg::Data1
	tay

	lsr
	lsr
	lsr
	lsr

	and #$03
	ora tmp1

	sta Vera::Reg::Data0

	tya
	ror
	ror
	ror
	and #$c0
	sta tmp1

	lda Vera::Reg::Data1
	tay

	and #$30
	tsb tmp1

	tya
	asl
	asl

	and #$0c
	tsb tmp1
.endrepeat
	lda tmp1
	sta Vera::Reg::Data0

	lda Vera::Reg::AddrL
	clc
	adc #155
	sta Vera::Reg::AddrL
	bcc :+
	inc Vera::Reg::AddrM
	bne :+
	inc Vera::Reg::AddrH
:	dex
	jne loop3

	ply
	jmp nochar


.endproc

start_xpos:
	.byte 0,0
xpos:
	.byte 0,0
ypos:
	.byte 0,0
palidx:
	.byte 0
spridx:
	.byte 0
pitch:
	.byte 16
pitches:
	.byte 17,16,15,17,15,15,17,17,10,14,17,15,17 ; A-M
	.byte 17,17,14,17,17,14,14,17,17,16,17,17,17 ; N-Z
	.byte 14,15,12,15,14,11,14,16,8,10,16,8,16   ; a-m
	.byte 15,12,15,15,12,11,9,16,16,16,15,17,13  ; n-z
	.byte 15,10,13,14,15,13,14,13,12,14          ; 0-9
	.byte 5,13,5,4,4,4,4,9,9,10,10,11            ; ! ? , . : ` ' ( ) + - *
	.byte 10,6,8                                 ; W m w overflow
	.byte 16,16,16,16,16,16,16,16,16,16,16,16,16,16 ; DOLBY logo

punct1tbl:
	.byte 62,0,0,0,0,0,68,69,70,73,71,64,72,65,0
punct2tbl:
	.byte 66,0,0,0,0,63
tmp1:
	.byte 0
