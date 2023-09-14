.include "x16.inc"

.segment "INTRO"
entry:
	lda #0
	sta X16::Reg::ROMBank
	jsr X16::Kernal::PRIMM
	.byte "INTRO SCENE",13,0

	rts
