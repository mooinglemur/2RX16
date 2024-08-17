.ifndef macros_inc
macros_inc = 1

.include "x16.inc"

.import addrl_per_row_4bit
.import addrm_per_row_4bit
.import addrl_per_row_8bit
.import addrm_per_row_8bit
.import addrl_per_row_spr_4bit
.import addrm_per_row_spr_4bit
.import blobload
.import blobseek
.import blobopen
.ifndef blob_to_read
.importzp blob_to_read
.endif
.import blobseekfn

.ifndef syncval
.importzp syncval
.endif
.import sprite_text_pos
.import sprite_text_do

.ifndef ASSETBLOB
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
	bcc cont
	jmp graceful_fail
fn:
	.byte name
FNLEN = * - fn
cont:
.endmacro
.else
.include "blob_loadfile.inc"
.endif

.ifndef ASSETBLOB
.macro OPENFILE name
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

	jsr X16::Kernal::OPEN
	bra cont
fn:
	.byte name
FNLEN = * - fn
cont:
.endmacro
.else
.include "blob_openfile.inc"
.endif

.macro WAITVSYNC frames
.local endless
.local FRC
	jsr X16::Kernal::RDTIM
.ifnblank frames
	clc
	adc #frames
.endif
	sta FRC
endless:
	wai
	jsr X16::Kernal::RDTIM
	cmp #$ff
FRC = * -1
.ifnblank frames
	bne endless
.else
	beq endless
.endif
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

.macro POS_ADDR_SPR_ROW_4BIT_AH
	adc addrm_per_row_spr_4bit,x
	sta Vera::Reg::AddrM
	lda addrl_per_row_spr_4bit,x
	sta Vera::Reg::AddrL
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

.macro PALETTE_FADE_FULL vsyncs_per_step
.local PALITER
.local palloop
.local vsloop
.local VS
	lda #16
	sta PALITER
palloop:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	jsr apply_palette_fade_step3
	jsr apply_palette_fade_step4

	lda #vsyncs_per_step
	sta VS
vsloop:
	WAITVSYNC
	dec VS
	lda #$ff
VS = * - 1
	bne vsloop

	jsr flush_palette
	jsr flush_palette2
	jsr flush_palette3
	jsr flush_palette4
	dec PALITER
	lda #$ff
PALITER = * - 1
	bne palloop
.endmacro

.macro PALETTE_FADE_1_2 vsyncs_per_step
.local PALITER
.local palloop
.local vsloop
.local VS
	lda #16
	sta PALITER
palloop:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2

	lda #vsyncs_per_step
	sta VS
vsloop:
	WAITVSYNC
	dec VS
	lda #$ff
VS = * - 1
	bne vsloop

	jsr flush_palette
	jsr flush_palette2
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
	bcc syncloop
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

.macro SPRITE_TEXT xpos, ypos, palidx, text
.local sprtxt
.local cont
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
.local @2
	inc ptr1
	bne @2
	lda ptr1+1
	inc
	cmp #$c0
	bcc @1
	sbc #$20
	inc X16::Reg::RAMBank
@1: sta ptr1+1
@2:
.endmacro

.macro INCPTR2
.local @1
.local @2
	inc ptr2
	bne @2
	lda ptr2+1
	inc
	cmp #$c0
	bcc @1
	sbc #$20
	inc X16::Reg::RAMBank
@1: sta ptr2+1
@2:
.endmacro

.macro DEBUGMSG msg
.local msgloc
.local loop
.local cont
	pha
	phx
	ldx #0
loop:
	lda msgloc,x
	beq cont
	sta $9fbb
	inx
	bne loop
	bra cont
msgloc:
	.byte msg
	.byte 13,10,0
cont:
	plx
	pla
.endmacro

.macro SET16VAL dst, val
.if .const(val) && <(val) = 0
	stz dst + 0
.else
	lda #<(val)
	sta dst + 0
.endif
.if .const(val) && >(val) = 0
	stz dst + 1
.else
	lda #>(val)
	sta dst + 1
.endif
.endmacro

.endif
