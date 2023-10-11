.ifndef macros_inc
macros_inc = 1

.include "x16.inc"

.import addrl_per_row_4bit
.import addrm_per_row_4bit
.import addrl_per_row_8bit
.import addrm_per_row_8bit
.ifndef syncval
.import syncval
.endif
.import sprite_text_pos
.import sprite_text_do

.macro LOADFILE name, bank, addr, vbank
.local fn
.local FNLEN
.local cont
	lda #1
	ldx #8
	ldy #2
	jsr X16::Kernal::SETLFS

	lda #FNLEN
	ldx #<fn
	ldy #>fn
	jsr X16::Kernal::SETNAM

	lda #bank
	sta X16::Reg::RAMBank
	ldx #<addr
	ldy #>addr
.ifnblank vbank
    lda #(vbank + 2)
.else
	lda #0
.endif
	jsr X16::Kernal::LOAD
	bra cont
fn:
    .byte name
FNLEN = * - fn
cont:
.endmacro

.macro WAITVSYNC
.local endless
.local FRC
endless:
	jsr X16::Kernal::RDTIM
	sta FRC
	wai
	jsr X16::Kernal::RDTIM
	cmp #$ff
FRC = * -1
	beq endless
.endmacro


.macro POS_ADDR_ROW_4BIT
    lda addrl_per_row_4bit,x
    sta Vera::Reg::AddrL
    lda addrm_per_row_4bit,x
    sta Vera::Reg::AddrM
.endmacro

.macro POS_ADDR_ROW_4BIT_AH
    adc addrm_per_row_4bit,x
    sta Vera::Reg::AddrM
    lda addrl_per_row_4bit,x
    sta Vera::Reg::AddrL
.endmacro

.macro POS_ADDR_ROW_8BIT
    lda addrl_per_row_8bit,x
    sta Vera::Reg::AddrL
    lda addrm_per_row_8bit,x
    sta Vera::Reg::AddrM
.endmacro


.macro PALETTE_FADE vsyncs_per_step
.local PALITER
.local palloop
.local vsloop
.local VS
    lda #16
    sta PALITER
palloop:
    jsr apply_palette_fade_step

    lda #vsyncs_per_step
    sta VS
vsloop:
    WAITVSYNC
    dec VS
    lda #$ff
VS = * - 1
    bne vsloop

    jsr flush_palette
    dec PALITER
    lda #$ff
PALITER = * - 1
    bne palloop
.endmacro

.macro MUSIC_SYNC val
.local syncloop
syncloop:
    wai
    lda syncval
    cmp #val
    bne syncloop
.endmacro

.macro DISABLE_SPRITES
.local sp
    VERA_SET_ADDR (Vera::VRAM_sprattr+6), 4 ; stride 4, auto-inc 8
    ldy #128
sp:
    stz Vera::Reg::Data0
    dey
    bne sp
.endmacro

.macro SPRITE_TEXT spridx, xpos, ypos, palidx, text
.local sprtxt
.local cont
    lda #spridx
    ldx #xpos
    ldy #ypos
    jsr sprite_text_pos
    lda #palidx
    ldx #<sprtxt
    ldy #>sprtxt
    jsr sprite_text_do
    bra cont
sprtxt:
    .byte text,0
cont:
.endmacro

.macro INCPTR1
.local @1
    inc ptr1
    bne @1
    lda ptr1+1
    inc
    cmp #$c0
    bcc @1
    sbc #$20
    sta ptr1+1
    inc X16::Reg::RAMBank
@1:
.endmacro

.endif
