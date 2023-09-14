.include "x16.inc"

.macro LOADFILE name, bank, addr
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
	lda #0
	jsr X16::Kernal::LOAD
	bra cont
fn:
    .byte name
FNLEN = * - fn
cont:
.endmacro
