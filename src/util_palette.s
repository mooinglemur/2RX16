; functions
.export setup_palette_fade
.export apply_palette_fade_step
.export flush_palette
.export cycle_palette

; variables
.export target_palette

.include "x16.inc"

.segment "UTIL"

; palette transition routines
; to save memory, the only transition supported
; is a 16-step change across 64

target_palette:
	.res 128

new_palette_exp:
	.res 256

diff_palette_exp:
	.res 256

fade_iter:
	.res 1

palette_offset:
	.res 1

; pass palette offset in A
; after populating target_palette
.proc setup_palette_fade
	sta palette_offset
	jsr point_data0_to_palette

	; split xRGB values out of the first 64 existing palette entries
	ldx #0
palexpand:
	lda Vera::Reg::Data0
	pha
	and #$0f
	sta new_palette_exp,x
	inx
	pla
	lsr
	lsr
	lsr
	lsr
	sta new_palette_exp,x
	inx
	bne palexpand

	; diff between the existing palette and new one
	ldx #0
	ldy #0
paldiff:
	lda target_palette,x
	and #$0f
	sec
	sbc new_palette_exp,y
	sta diff_palette_exp,y
	iny
	lda target_palette,x
	lsr
	lsr
	lsr
	lsr
	sec
	sbc new_palette_exp,y
	sta diff_palette_exp,y
	inx
	iny
	bne paldiff

	; turn new_palette_exp into 4.4 fixed point
	ldy #0
pal44:
	lda new_palette_exp,y
	asl
	asl
	asl
	asl
	sta new_palette_exp,y
	iny
	bne pal44

	lda #16
	sta fade_iter

	rts
.endproc

.proc cycle_palette ; A = offset (index), X = length (index)
	sta offset
	stx length

	asl
	tax

	asl
	tay

	lda length
	clc
	adc offset
	asl

	sta stop_x
	asl
	sta stop_y
	lda target_palette,x
	sta val
	lda target_palette+1,x
	sta val+1
loop_x:
	inx
	inx
	cpx stop_x
	beq done_x
	lda target_palette,x
	pha
	lda val
	sta target_palette,x
	pla
	sta val
	lda target_palette+1,x
	pha
	lda val+1
	sta target_palette+1,x
	pla
	sta val+1
	bra loop_x
done_x:
	lda offset
	asl
	tax
	lda val
	sta target_palette,x
	lda val+1
	sta target_palette+1,x


.repeat 4, i
	lda new_palette_exp+i,y
	sta val+i
	lda diff_palette_exp+i,y
	sta diff+i
.endrepeat
loop_y:
	iny
	iny
	iny
	iny
	cpy stop_y
	beq done_y
.repeat 4, i
	lda new_palette_exp+i,y
	pha
	lda val+i
	sta new_palette_exp+i,y
	pla
	sta val+i
	lda diff_palette_exp+i,y
	pha
	lda diff+i
	sta diff_palette_exp+i,y
	pla
	sta diff+i
.endrepeat
	bra loop_y
done_y:
	lda offset
	asl
	asl
	tay
.repeat 4, i
	lda val+i
	sta new_palette_exp+i,y
	lda diff+i
	sta diff_palette_exp+i,y
.endrepeat
	rts

offset:
	.byte 0
length:
	.byte 0
stop_x:
	.byte 0
stop_y:
	.byte 0
val:
	.byte 0,0,0,0
diff:
	.byte 0,0,0,0
.endproc


.proc apply_palette_fade_step
	lda fade_iter
	beq end

	dec fade_iter

	ldx #0
	ldy #0
palloop:
	lda new_palette_exp,y
	clc
	adc diff_palette_exp,y
	sta new_palette_exp,y
	lsr
	lsr
	lsr
	lsr
	sta target_palette,x
	iny
	lda new_palette_exp,y
	clc
	adc diff_palette_exp,y
	sta new_palette_exp,y
	and #$f0
	ora target_palette,x
	sta target_palette,x
	inx
	iny
	bne palloop
end:
	rts
.endproc

.proc flush_palette
	jsr point_data0_to_palette

	; write palette shadow to VERA
	ldx #128
shadowpal:
	lda target_palette-128,x
	sta Vera::Reg::Data0
	inx
	bne shadowpal
.endproc

.proc point_data0_to_palette
	lda palette_offset
	asl
	php
	clc
	adc #<Vera::VRAM_palette
	sta Vera::Reg::AddrL
	plp
	lda #0
	rol
	adc #>Vera::VRAM_palette
	sta Vera::Reg::AddrM
	lda #((^Vera::VRAM_palette) | $10)
	sta Vera::Reg::AddrH
	rts
.endproc
