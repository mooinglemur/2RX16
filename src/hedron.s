.include "x16.inc"

.segment "HEDRON"
entry:
	lda #0
	sta X16::Reg::ROMBank
	jsr X16::Kernal::PRIMM
	.byte "(POLY)HEDRON SCENE",13,0
    rts
