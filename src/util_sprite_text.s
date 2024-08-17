; functions
.export sprite_text_pos
.export sprite_text_do
.export sprite_text_pos_y400
.export sprite_scroll_up

.include "x16.inc"

.macpack longbranch

.segment "UTIL"

TXTDATA_ADDR = $10000

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
