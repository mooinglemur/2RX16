.importzp blob_to_read
.importzp blob_target_ptr

.import graceful_fail

.export blobload, blobseek, blobopen
.export blobseekfn

.include "x16.inc"

.macpack longbranch

.segment "UTIL"

.proc blobopen
	lda #1
	ldx #8
	ldy #2
	jsr X16::Kernal::SETLFS

	lda #FNLEN
	ldx #<fn
	ldy #>fn
	jsr X16::Kernal::SETNAM

	jsr X16::Kernal::OPEN
	rts
fn:
	.byte "REALITY.X16"
FNLEN = * - fn
.endproc

.proc blobload
	cmp #2
	bcc memory
	stz Vera::Reg::Ctrl
	stx Vera::Reg::AddrL
	sty Vera::Reg::AddrM
	sbc #2 ; carry is set
	ora #$10 ; incr
	sta Vera::Reg::AddrH

	ldx #1
	jsr X16::Kernal::CHKIN

vreadloop:
	; if we have >= 512 bytes to read, ask for the max
	lda blob_to_read+1
	cmp #2
	bcs vreadmax
	lda blob_to_read+2
	bne vreadmax
	lda blob_to_read
	bne vreadit
	dec
vreadit:
	ldx #<Vera::Reg::Data0
	ldy #>Vera::Reg::Data0
	sec
	jsr X16::Kernal::MACPTR
	jcs graceful_fail
	stx tmp1
	lda blob_to_read
	sec
	sbc tmp1
	sta blob_to_read
	sty tmp1
	lda blob_to_read+1
	sbc tmp1
	sta blob_to_read+1
	lda blob_to_read+2
	bcs :+
	dec
	sta blob_to_read+2
:	ora blob_to_read+1
	ora blob_to_read
	bne vreadloop
	bra eof
vreadmax:
	lda #0
	bra vreadit

memory:
	stx blob_target_ptr
	sty blob_target_ptr+1
	
	ldx #1
	jsr X16::Kernal::CHKIN
readloop:
	; if we have >= 512 bytes to read, ask for the max
	lda blob_to_read+1
	cmp #2
	bcs readmax
	lda blob_to_read+2
	bne readmax
	lda blob_to_read
	bne readit
	dec
readit:
	ldx blob_target_ptr
	ldy blob_target_ptr+1
	clc
	jsr X16::Kernal::MACPTR
	jcs graceful_fail
	txa
	adc blob_target_ptr
	sta blob_target_ptr
	tya
	adc blob_target_ptr+1
	cmp #$c0
	bcc :+
	sbc #$20
:	sta blob_target_ptr+1
	stx tmp1
	lda blob_to_read
	sec
	sbc tmp1
	sta blob_to_read
	sty tmp1
	lda blob_to_read+1
	sbc tmp1
	sta blob_to_read+1
	lda blob_to_read+2
	bcs :+
	dec
	sta blob_to_read+2
:	ora blob_to_read+1
	ora blob_to_read
	bne readloop
eof:
	lda #1
	jsr X16::Kernal::CLOSE

	jsr X16::Kernal::CLRCHN

	rts
readmax:
	lda #0
	bra readit
tmp1:
	.byte 0
.endproc

.proc blobseek
	lda #15
	ldx #8
	ldy #15
	jsr X16::Kernal::SETLFS

	lda #6
	ldx #<blobseekfn
	ldy #>blobseekfn
	jsr X16::Kernal::SETNAM
	
	jsr X16::Kernal::OPEN
	ldx #15
	jsr X16::Kernal::CHKIN
eat:
	jsr X16::Kernal::CHRIN
	jsr X16::Kernal::READST
	and #$40
	bne eat

	lda #15
	jsr X16::Kernal::CLOSE

	jsr X16::Kernal::CLRCHN
	rts
.endproc

blobseekfn:
	.byte "P",$02,"xxx",$00
