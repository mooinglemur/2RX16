; functions
.export sprite_text_pos
.export sprite_text_do

.include "x16.inc"

.macpack longbranch

.segment "UTIL"

TXTDATA_ADDR = $10000

.proc sprite_text_pos
	sta spridx
	stx xpos
	stz xpos+1
	sty ypos
	rts
.endproc

.proc sprite_text_do
	sta palidx
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
	cmp #$30 ; skip everything before numbers
	bcc nochar
	cmp #$3a
	bcs :+
	adc #$04
	bra char
:	cmp #$41 ; temporarily skip non-letters
	bcc nochar
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
	stz Vera::Reg::Data0
	lda #$0c
	sta Vera::Reg::Data0
	lda palidx
	ora #%10010000
	sta Vera::Reg::Data0
	jmp incidx
done:
	rts
.endproc

xpos:
	.byte 0,0
ypos:
	.byte 0
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

