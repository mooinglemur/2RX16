.include "x16.inc"

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
