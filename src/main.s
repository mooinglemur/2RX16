.segment "LOADADDR"
	.word $0801
.segment "BASICSTUB"
	.word start-2
	.byte $00,$00,$9e
	.byte "2061"
	.byte $00,$00,$00
.segment "STARTUP"
start:
	jmp main
.segment "BSS"
syncval:
	.res 1
.segment "CODE"

.include "x16.inc"
.include "macros.inc"

.scope AudioAPI
	.include "audio.inc"
.endscope

.scope zsmkit
	.include "zsmkit.inc"
.endscope

ZSMKIT_BANK = 1
SONG_BANK = 2

SCENE = $4800


.proc main
	jsr setup_zsmkit
	jsr setup_irq_handler
	LOADFILE "INTRO.BIN", 0, SCENE
	jsr SCENE
	LOADFILE "MUSIC2.ZSM", SONG_BANK, $a000
	LOADFILE "HEDRON.BIN", 0, SCENE
	jsr play_song
	jsr SCENE

@1:	jmp @1
	jsr clear_irq_handler
	rts
.endproc

.proc play_song
	ldx #0
	jsr zsmkit::zsm_close
	lda #SONG_BANK
	sta X16::Reg::RAMBank
	ldx #0
	lda #<$a000
	ldy #>$a000
	jsr zsmkit::zsm_setmem
	ldx #0
	jsr zsmkit::zsm_play
	rts
.endproc

.proc sync_handler
	cpy #2
	bne end
	sta syncval
end:
	rts
.endproc

.proc setup_zsmkit
	lda #ZSMKIT_BANK ; ZSMKit gets bank 1 for itself
	jsr zsmkit::zsm_init_engine
	lda #52
	ldy #0
	jsr zsmkit::zsm_set_int_rate
	stz syncval
	lda #2
	sta X16::Reg::RAMBank ; for setcb
	ldx #0
	lda #<sync_handler
	ldy #>sync_handler
	jsr zsmkit::zsm_setcb
	rts
.endproc

clear_irq_handler:
	jsr clear_via_timer

	sei

	lda OLDIRQ
	sta X16::Vec::IRQVec
	lda OLDIRQ+1
	sta X16::Vec::IRQVec+1

	cli
	rts

setup_irq_handler:
	sei

	lda X16::Vec::IRQVec
	sta OLDIRQ
	lda X16::Vec::IRQVec+1
	sta OLDIRQ+1

	lda #<handler
	sta X16::Vec::IRQVec
	lda #>handler
	sta X16::Vec::IRQVec+1

	stz irqsub
	stz irqsub+1

	cli

	; set up 52 Hz VIA timer
	lda #52
	jsr setup_via_timer

	rts
handler:
    lda X16::Reg::ROMBank
    pha
    lda #$0A
    sta X16::Reg::ROMBank
    lda X16::Reg::RAMBank
    pha

	; check for IRQ type
    ; is it a via timer?
    lda VIA1::Reg::IFR
    and #$40
    bne via

	lda irqsub+1
	beq :+

	jsr $ffff
irqsub = * - 2
:	lda #1
	jsr zsmkit::zsm_tick

    pla
    sta X16::Reg::RAMBank

    pla
    sta X16::Reg::ROMBank
	jmp $ffff
OLDIRQ = * - 2
via:
	lda VIA1::Reg::T1CL ; clear T1 interrupt flag on VIA

	dec via_timer_iter
	bne endirq

	lda #0
via_timer_loops = * - 1
	sta via_timer_iter

	; preserve FX
	lda Vera::Reg::Ctrl
	pha
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda Vera::Reg::FXCtrl
	pha
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	lda #2
	jsr zsmkit::zsm_tick

	; restore FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	pla
	lda Vera::Reg::FXCtrl
	pla
	stz Vera::Reg::Ctrl	
endirq:
    pla
    sta X16::Reg::RAMBank

    pla
    sta X16::Reg::ROMBank

	ply
	plx
	pla
	rti
via_timer_iter:
	.byte 0

; .A = Hz
.proc setup_via_timer: near
    ; tmp1 = remainder
    ; tmp2 = dividend
    ; tmp3 = divisor

    sta IR

	; initialize remainder to 0
	stz tmp1
	stz tmp1+1
	
    lda #<8000000
	sta tmp2
	lda #>8000000
	sta tmp2+1
	lda #^8000000
	sta tmp2+2

	; initialize divisor to int_rate (default 60)
	lda #$ff
IR = * - 1
	sta tmp3
	stz tmp3+1

	; 24 bits in the dividend
	ldx #24
l1:
	asl tmp2
	rol tmp2+1
	rol tmp2+2
	rol tmp1
	rol tmp1+1
	lda tmp1
	sec
	sbc tmp3
	tay
	lda tmp1+1
	sbc tmp3+1
	bcc l2
	sta tmp1+1
	sty tmp1
	inc tmp2
l2:
	dex
	bne l1

    lda #1
    sta via_timer_loops
	lda tmp2+2
    beq l4    
l3:
	lda tmp2+2
    beq l4
    asl via_timer_loops
l3a:
    lsr tmp2+2
    ror tmp2+1
    ror tmp2
    bra l3
l4:
    lda tmp2
    sta via_timer_latch_l
	lda tmp2+1
	sta via_timer_latch_h

    lda via_timer_loops
    sta via_timer_iter
    ; set up the via
    php
    sei

    ; set T1 to freerunning mode
    lda #%01000000 
    sta VIA1::Reg::ACR

    ; enable T1 interrupts
    lda #%11000000
    sta VIA1::Reg::IER
    
    ; fill the timer (start it)
    lda #$00
	via_timer_latch_l = * - 1
    sta VIA1::Reg::T1CL
	lda #$00
	via_timer_latch_h = * - 1
    sta VIA1::Reg::T1CH

    plp

	rts
tmp1:
    .byte 0,0,0
tmp2:
    .byte 0,0,0
tmp3:
    .byte 0,0,0

.endproc

.proc clear_via_timer: near
    php
    sei

    ; disable T1 interrupts
    lda #%01000000
    sta VIA1::Reg::IER
    
    plp
    rts
.endproc
