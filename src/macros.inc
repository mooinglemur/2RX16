.ifndef macros_inc
macros_inc = 1

.include "x16.inc"

.import addrl_per_row_4bit
.import addrm_per_row_4bit
.import addrl_per_row_8bit
.import addrm_per_row_8bit

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


.macro POS_ADDR_ROW_8BIT
    lda addrl_per_row_8bit,x
    sta Vera::Reg::AddrL
    lda addrm_per_row_8bit,x
    sta Vera::Reg::AddrM
.endmacro

.endif
