.exportzp syncval
.exportzp blob_to_read, blob_target_ptr
.exportzp SONG_BANK

.export play_song

.export galois16o

.export scenevector
.export graceful_fail

.import zero_entire_palette_and_target
.import zero_entire_target

.import target_palette

.import flush_palette
.import apply_palette_fade_step
.import setup_palette_fade

.macpack longbranch

.scope SCROLLER
	.import BITMAP_VRAM_ADDRESS
	.importzp SCROLL_COPY_CODE_RAM_BANK
	.import SCROLL_COPY_CODE_RAM_ADDRESS
.endscope

.scope CUBE
	.importzp CUBE_CHOREO_BANK
	.import CUBE_CHOREO_ADDR
.endscope

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

.segment "ZEROPAGE"
blob_to_read:
	.res 3
blob_target_ptr:
	.res 2
music_interrupt_type:
	.res 1
syncval:
	.res 1

.segment "CODE"

; this is where the scene-specific IRQ calls can go.
scenevector := $9EFC

.include "x16.inc"
.include "macros.inc"
.include "flow.inc"

.scope AudioAPI
	.include "audio.inc"
.endscope

.scope zsmkit
	.include "zsmkit.inc"
.endscope

ZSMKIT_BANK = 1
SONG_BANK := 2

SCENE = $4800

; see flow.inc for short-circuiting the demo while testing

.proc main
	stz X16::Reg::ROMBank ; kernal API calls are faster
	jsr measure_machine_speed
	jsr setup_zsmkit
	jsr setup_irq_handler

	; set up music for ~60 Hz VERA timer
	jsr clear_via_timer
	; tell ZSMKit about the 60 Hz timer
	stz music_interrupt_type
	lda #60
	ldy #0
	jsr zsmkit::zsm_set_int_rate

	jsr zero_entire_target
	lda #0
	jsr setup_palette_fade

	; set auto_tx if available (fast SD card reads!)
	lda #5
	ldx #<auto_tx
	ldy #>auto_tx
	jsr X16::Kernal::SETNAM

	lda #15
	ldx #8
	ldy #15
	jsr X16::Kernal::SETLFS

	jsr X16::Kernal::OPEN

	lda #15
	jsr X16::Kernal::CLOSE


	PALETTE_FADE 2
.ifndef SKIP_SONG0
	LOADFILE "MUSIC0.ZSM", SONG_BANK, $a000

	jsr play_song
	LOADFILE "DOSBOOT.BIN", 0, SCENE
	jsr SCENE
	; stop song
	ldx #0
	jsr zsmkit::zsm_close
.endif
	; set up 50 Hz VIA timer
	lda #50
	jsr setup_via_timer
	; tell ZSMKit about the 50 Hz timer
	lda #1
	sta music_interrupt_type
	lda #50
	ldy #0
	jsr zsmkit::zsm_set_int_rate

	LOADFILE "MUSIC1.ZSM", SONG_BANK, $a000
	jsr play_song

	LOADFILE "INTRO.BIN", 0, SCENE
	jsr SCENE

	; stop song
	ldx #0
	jsr zsmkit::zsm_close
.ifndef SKIP_SONG2
	LOADFILE "MUSIC2.ZSM", SONG_BANK, $a000
	LOADFILE "HEDRON.BIN", 0, SCENE
.endif
	; set up 52 Hz VIA timer
	lda #52
	jsr setup_via_timer
	; tell ZSMKit about the 52 Hz timer
	lda #1
	sta music_interrupt_type
	lda #52
	ldy #0
	jsr zsmkit::zsm_set_int_rate

.ifndef SKIP_SONG2
	jsr play_song
	jsr SCENE
	LOADFILE "TUNNEL.BIN", 0, SCENE
	jsr SCENE
	LOADFILE "CIRCLES.BIN", 0, SCENE
	jsr SCENE
	LOADFILE "MOIRE.BIN", 0, SCENE ; also includes the four column swipe to the beat
	jsr SCENE

	; stop song
	ldx #0
	jsr zsmkit::zsm_close
.endif
.ifndef SKIP_SONG3
	LOADFILE "MUSIC3.ZSM", SONG_BANK, $a000
	LOADFILE "SCROLLER.BIN", 0, SCENE
	jsr zero_entire_palette_and_target
.ifdef SKIP_SONG2
	; do this SCROLLER lengthy load here if we didn't get to it in MOIRE
	LOADFILE "SCROLLCOPY.DAT", SCROLLER::SCROLL_COPY_CODE_RAM_BANK, SCROLLER::SCROLL_COPY_CODE_RAM_ADDRESS
.endif
	LOADFILE "FOREST.DAT", 0, .loword(SCROLLER::BITMAP_VRAM_ADDRESS), <(.hiword(SCROLLER::BITMAP_VRAM_ADDRESS))

	jsr play_song
	jsr SCENE

	LOADFILE "CREATURE.BIN", 0, SCENE
	jsr SCENE
	; load this here because it's timing critical after plasma is done
	LOADFILE "CUBECHOREO.DAT", CUBE::CUBE_CHOREO_BANK, CUBE::CUBE_CHOREO_ADDR
	MUSIC_SYNC $6F
	LOADFILE "PLASMA.BIN", 0, SCENE
	jsr SCENE
	LOADFILE "CUBE.BIN", 0, SCENE
	jsr SCENE
	LOADFILE "BALLS.BIN", 0, SCENE
	jsr SCENE
	; overwrites the currently-playing song!
	; but the cursor is already past the end of the
	; new song's length, so the current playback
	; can coast to the end of the old song's data
	LOADFILE "MUSIC4.ZSM", SONG_BANK, $a000

	; fade to black
	ldx #0
:   stz target_palette,x
	inx
	bne :-

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 1

	MUSIC_SYNC $A0
	jsr play_song_1 ; priority 1 to mask the gap by keeping the PCM from MUSIC3 playing
.endif
.ifndef SKIP_SONG4
.ifdef SKIP_SONG3
	LOADFILE "MUSIC4.ZSM", SONG_BANK, $a000
.endif
	LOADFILE "SWORD.BIN", 0, SCENE
.ifdef SKIP_SONG3
	jsr play_song_1
.endif
	jsr SCENE

	LOADFILE "WATER.BIN", 0, SCENE
	jsr SCENE

	MUSIC_SYNC $C0

	LOADFILE "BOUNCE.BIN", 0, SCENE
	jsr SCENE ; exits at sync $CC

	; stop song
	ldx #1
	jsr zsmkit::zsm_close
.endif
	; set up 50 Hz VIA timer
	lda #50
	jsr setup_via_timer
	; tell ZSMKit about the 50 Hz timer
	lda #1
	sta music_interrupt_type
	lda #50
	ldy #0
	jsr zsmkit::zsm_set_int_rate

	; MUSIC5 is loaded inside CRAFT scene
	LOADFILE "CRAFT.BIN", 0, SCENE
	jsr SCENE

	LOADFILE "CREW.BIN", 0, SCENE
	jsr SCENE

	LOADFILE "CREDITS.BIN", 0, SCENE
	jsr SCENE

XXXEND:
	; fade out song
	ldy #0
:	phy
	WAITVSYNC
	WAITVSYNC
	WAITVSYNC
	ply
	phy
	tya
	ldx #0
	jsr zsmkit::zsm_setatten
	ply
	iny
	cpy #64
	bne :-

	; stop song
	ldx #0
	jsr zsmkit::zsm_close

	jsr clear_irq_handler
	jsr X16::Kernal::SCINIT

	stz Vera::Reg::L0HScrollL
	stz Vera::Reg::L0HScrollH
	stz Vera::Reg::L0VScrollL
	stz Vera::Reg::L0VScrollH

	stz Vera::Reg::L1HScrollL
	stz Vera::Reg::L1HScrollH
	stz Vera::Reg::L1VScrollL
	stz Vera::Reg::L1VScrollH

	clc
	jmp X16::Kernal::ENTER_BASIC ; won't return!
.endproc

.proc graceful_fail
	; stop song
	ldx #0
	jsr zsmkit::zsm_close

	jsr clear_irq_handler

	stz X16::Reg::ROMBank

	; reset VERA
	jsr X16::Kernal::SCINIT

	stz Vera::Reg::L0HScrollL
	stz Vera::Reg::L0HScrollH
	stz Vera::Reg::L0VScrollL
	stz Vera::Reg::L0VScrollH

	stz Vera::Reg::L1HScrollL
	stz Vera::Reg::L1HScrollH
	stz Vera::Reg::L1VScrollL
	stz Vera::Reg::L1VScrollH

	; clear screen when full res
	jsr X16::Kernal::PRIMM
	.byte $90,$01,$1c,$93,0

	; set screen mode 11
	lda #11
	jsr X16::Kernal::SCREEN_MODE

	jsr X16::Kernal::PRIMM
	.byte $90,$01,$1c,$93
	.byte "THE DEMO HAS STOPPED DUE TO AN",13
	.byte " UNEXPECTED FILE I/O PROBLEM.",13,13
	.byte "    THE SYSTEM HAS HALTED."
	.byte 0

	jmp *
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

.proc play_song_1
	ldx #1
	jsr zsmkit::zsm_close
	lda #SONG_BANK
	sta X16::Reg::RAMBank
	ldx #1
	lda #<$a000
	ldy #>$a000
	jsr zsmkit::zsm_setmem
	ldx #1
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
	stz syncval
	lda #2
	sta X16::Reg::RAMBank ; for setcb
	ldx #0
	lda #<sync_handler
	ldy #>sync_handler
	jsr zsmkit::zsm_setcb
	ldx #1
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

	lda #$60 ; 'RTS' // This will be NOPed out by anything that wants to hook here and then restored to RTS later
	sta scenevector

	lda #$4C ; 'JMP'
	sta scenevector+1

	lda X16::Vec::IRQVec
	sta OLDIRQ
	lda X16::Vec::IRQVec+1
	sta OLDIRQ+1

	lda #<handler
	sta X16::Vec::IRQVec
	lda #>handler
	sta X16::Vec::IRQVec+1

	cli

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
	and VIA1::Reg::IER
	and #$40
	bne via

	; preserve FX
	lda Vera::Reg::Ctrl
	pha
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	lda Vera::Reg::FXCtrl
	pha
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	; do this one first
	jsr scenevector

	lda Vera::Reg::ISR
	and #1
	beq restorefx_and_return

	lda music_interrupt_type ; 0 for vblank, 1 for via
	jsr zsmkit::zsm_tick

	; restore FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	pla
	sta Vera::Reg::FXCtrl
	pla
	sta Vera::Reg::Ctrl

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

restorefx_and_return:
	; restore FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	pla
	sta Vera::Reg::FXCtrl
	pla
	sta Vera::Reg::Ctrl
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

	lda machine_speed
	sta tmp2
	lda machine_speed+1
	sta tmp2+1
	lda machine_speed+2
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

; comment this out (or uncomment) if the assert below triggers due to
; unfortunate page alignment
.res 10

.proc measure_machine_speed: near
	WAITVSYNC
	; grab the least significant byte of the timer
	jsr X16::Kernal::RDTIM
	sta delta1

	lda #5
	ldx #0
	ldy #0
busyloop:
	dey
	bne busyloop
	dex
	bne busyloop
	dec
	bne busyloop

.assert (<busyloop) < 246, error, "measure_machine_speed busyloop crosses a page boundary within the loop, it must be moved"

	jsr X16::Kernal::RDTIM
	sec
	sbc delta1

	cmp #8
	bcc mhz14
	cmp #9
	bcc mhz12
	cmp #12
	bcc mhz10
	cmp #14
	bcc mhz8
	cmp #18
	bcc mhz6
	cmp #28
	bcc mhz4
	cmp #56
	bcc mhz2

mhz1:
	lda #<1000000
	sta machine_speed
	lda #>1000000
	sta machine_speed+1
	lda #^1000000
	sta machine_speed+2
	rts
mhz14:
	lda #<14000000
	sta machine_speed
	lda #>14000000
	sta machine_speed+1
	lda #^14000000
	sta machine_speed+2
	rts
mhz12:
	lda #<12000000
	sta machine_speed
	lda #>12000000
	sta machine_speed+1
	lda #^12000000
	sta machine_speed+2
	rts
mhz10:
	lda #<10000000
	sta machine_speed
	lda #>10000000
	sta machine_speed+1
	lda #^10000000
	sta machine_speed+2
	rts
mhz8:
	lda #<8000000
	sta machine_speed
	lda #>8000000
	sta machine_speed+1
	lda #^8000000
	sta machine_speed+2
	rts
mhz6:
	lda #<6000000
	sta machine_speed
	lda #>6000000
	sta machine_speed+1
	lda #^6000000
	sta machine_speed+2
	rts
mhz4:
	lda #<4000000
	sta machine_speed
	lda #>4000000
	sta machine_speed+1
	lda #^4000000
	sta machine_speed+2
	rts
mhz2:
	lda #<2000000
	sta machine_speed
	lda #>2000000
	sta machine_speed+1
	lda #^2000000
	sta machine_speed+2
	rts
delta1:
	.byte 0
.endproc

.proc clear_via_timer: near
	php
	sei

	; disable T1 interrupts
	lda #%01000000
	sta VIA1::Reg::IER

	; delay to make sure VIA gets a chance to de-assert before returning
	nop
	nop
	nop
	nop
	nop
	nop

	plp
	rts
.endproc

machine_speed:
	.dword 8000000

auto_tx:
	.byte "U0>B",1

.proc galois16o
	lda seed+1
	pha ; store copy of high byte
	; compute seed+1 ($39>>1 = %11100)
	lsr ; shift to consume zeroes on left...
	lsr
	lsr
	sta seed+1 ; now recreate the remaining bits in reverse order... %111
	lsr
	eor seed+1
	lsr
	eor seed+1
	eor seed+0 ; recombine with original low byte
	sta seed+1
	; compute seed+0 ($39 = %111001)
	pla ; original high byte
	sta seed+0
	asl
	eor seed+0
	asl
	eor seed+0
	asl
	asl
	asl
	eor seed+0
	sta seed+0
	rts
seed:
	.word $6502
.endproc

