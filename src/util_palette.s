; functions
.export setup_palette_fade
.export apply_palette_fade_step
.export flush_palette

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

    ; turn new_pallet_exp into 4.4 fixed point
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
