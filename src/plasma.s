.import setup_palette_fade
.import setup_palette_fade2
.import setup_palette_fade3
.import setup_palette_fade4
.import apply_palette_fade_step
.import apply_palette_fade_step2
.import apply_palette_fade_step3
.import apply_palette_fade_step4
.import flush_palette
.import flush_palette2
.import flush_palette3
.import flush_palette4

.import target_palette
.import target_palette2
.import target_palette3
.import target_palette4

.import scenevector

.macpack longbranch

.segment "PLASMA_ZP"
l1:	.res 2
l2: .res 2

k1:	.res 2
k2: .res 2

ml: .res 1

pfade_ctr: .res 1

nextsync: .res 1

cur_row: .res 1

tmp1: .res 1
tmp2: .res 1
tmp3: .res 1

accum1: .res 1
accum2: .res 2


cop_drop: .res 1
.segment "PLASMA_BSS"
paras1l: .res 256
paras2l: .res 256
paras1k: .res 256
paras2k: .res 256

.include "x16.inc"
.include "macros.inc"

.segment "PLASMA"
entry:
	jsr setup_vera ; forces palette to full white, sets up layer params
	               ; and for bitmap on layer 0

	jsr clear_bitmap_area

	jsr init_params

	jsr copy_pal0_to_target_palette

	jsr setup_drop_handler

	lda #$72
	sta nextsync

	jsr do_plasma

	jsr init_params2

	jsr blank_palette
	jsr copy_pal1_to_target_palette

	lda #$74
	sta nextsync

	jsr do_plasma

	jsr init_params3

	jsr blank_palette
	jsr copy_pal2_to_target_palette

	lda #$7c
	sta nextsync

	jsr do_plasma

	jsr deregister_drop_handler

	jsr blank_palette

	; reset V-scroll offset
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	stz Vera::Reg::Ctrl

	MUSIC_SYNC $7C

	rts

.proc deregister_drop_handler
	lda #$60 ; RTS
	sta scenevector
	rts
.endproc

.proc setup_drop_handler
	lda #<drop_handler
	sta scenevector+2
	lda #>drop_handler
	sta scenevector+3
	lda #$ea ; NOP
	sta scenevector
	rts
.endproc

.proc drop_handler
	ldy cop_drop
	beq end
	iny
	sty cop_drop
	cpy #64
	bcs end
	lda Vera::Reg::Ctrl
	pha
	lda #2
	sta Vera::Reg::Ctrl
	lda dtau,y
	sta Vera::Reg::DCVStart
	pla
	sta Vera::Reg::Ctrl
end:
	rts
.endproc

.proc do_plasma
	; reset V-scroll offset
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	stz Vera::Reg::Ctrl

	stz cop_drop

	jsr set_plz_params ; initial setup
mainloop:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	jsr apply_palette_fade_step3
	jsr apply_palette_fade_step4

	lda syncval
	cmp nextsync
	bcc noslide
	lda cop_drop
	bne :+
	inc
	sta cop_drop ; this starts the drop in the IRQ
:	cmp #64
	bcc noslide
end:
	rts
noslide:
	WAITVSYNC

	jsr flush_palette
	jsr flush_palette2
	jsr flush_palette3
	jsr flush_palette4
	
	VERA_SET_ADDR ($00000 + (10*320)), 1 ; 10 rows down
	stz cur_row

rowloop1:
	; y2 = (y >> 1)
	lda cur_row
	lsr
	sta tmp1 ; row/2

	; Set Data1 pointer to the next line
	ldx Vera::Reg::AddrL
	ldy Vera::Reg::AddrM
	lda #1
	sta Vera::Reg::Ctrl
	txa
	clc
	adc #<320
	sta Vera::Reg::AddrL
	tya
	adc #>320
	sta Vera::Reg::AddrM
	lda #%00010000
	sta Vera::Reg::AddrH
	stz Vera::Reg::Ctrl

	ldx #0 ; column
colloop1:
	; i2 = (i - y2) & 0xff
	txa
	sec
	sbc tmp1
	sta tmp2

	; for the (l) parameters

	; offs = (y2 + selfmod[3][i2]) & 0xff
	tay
	lda paras1l,y
	clc
	adc tmp1
	; bx = sint3[offs]
	tay
	lda sint3,y
	sta accum1
	; offs = (bx + selfmod[4][i2]) & 0xff
	ldy tmp2
	lda paras2l,y
	clc
	adc accum1
	; ax = (((ax + sint4[offs]) >> 1) + ml) & 0xff
	tay
	lda sint4,y
	clc
	adc accum2
	lsr
	clc
	adc ml
	clc
	adc accum2
	; plot_point(i*2+parity, y, ax)
	sta Vera::Reg::Data0
	pha

	; for the (k) parameters

	ldy tmp2
	lda paras1k,y
	clc
	adc tmp1
	; bx = sint3[offs]
	tay
	lda sint1,y
	sta accum1
	; offs = (bx + selfmod[4][i2]) & 0xff
	ldy tmp2
	lda paras2k,y
	clc
	adc accum1
	; ax = (((ax + sint4[offs]) >> 1) + ml) & 0xff
	tay
	lda sint2,y
	clc
	adc accum2
	lsr
	clc
	adc ml
	clc
	adc accum2
	; plot_point(i*2+parity, y, ax)
	sta Vera::Reg::Data0
	sta Vera::Reg::Data1
	ply
	sty Vera::Reg::Data0
	sty Vera::Reg::Data1
	sta Vera::Reg::Data0
	sta Vera::Reg::Data1
	sty Vera::Reg::Data1
	
	inx
	cpx #40
	jcc colloop1

	lda #1
	sta Vera::Reg::Ctrl
	lda Vera::Reg::AddrL
	clc
	adc #160
	tax
	lda Vera::Reg::AddrM
	adc #0
	tay
	stz Vera::Reg::Ctrl
	stx Vera::Reg::AddrL
	sty Vera::Reg::AddrM

	inc cur_row
	lda cur_row
	cmp #40
	jcc rowloop1

	jsr move_plz
	jsr set_plz_params

	jmp mainloop
.endproc

.proc move_plz
	lda k1
	clc
	adc #120
	sta k1
	bcc :+
	inc k1+1
	clc
:	lda k2
	adc #199
	sta k2
	bcc :+
	inc k2+1
:	lda l1
	sec
	sbc #133
	sta l1
	bcs :+
	dec l1+1
	sec
:	lda l2
	sbc #140
	sta l2
	bcs :+
	dec l2+1
	sec
:	rts

.endproc

.proc set_plz_params
	stz tmp1
	ldy #0
paraloop:
	lda l1+1
	clc
	adc tmp1
	sta paras1l,y

	lda l2+1
	clc
	adc tmp1
	eor #$80
	sta paras2l,y

	lda k1+1
	clc
	adc tmp1
	sta paras1k,y

	lda k2+1
	clc
	adc tmp1
	eor #$80
	sta paras2k,y

	inc tmp1
	iny
	bne paraloop

	inc ml

	rts
.endproc

.proc init_params
	IL1 = 5000
	IL2 = 10000

	IK1 = 2100
	IK2 = 17800

	SET16VAL l1, IL1
	SET16VAL l2, IL2

	SET16VAL k1, IK1
	SET16VAL k2, IK2

	stz ml

	rts
.endproc

.proc init_params2
	IL1 = 10000
	IL2 = 33000

	IK1 = 41500
	IK2 = 31780

	SET16VAL l1, IL1
	SET16VAL l2, IL2

	SET16VAL k1, IK1
	SET16VAL k2, IK2

	lda #60
	sta ml

	rts
.endproc


.proc init_params3
	IL1 = 50000
	IL2 = 1000

	IK1 = 21000
	IK2 = 1780

	SET16VAL l1, IL1
	SET16VAL l2, IL2

	SET16VAL k1, IK1
	SET16VAL k2, IK2

	stz ml

	rts
.endproc


.proc copy_pal0_to_target_palette
	VERA_SET_ADDR Vera::VRAM_palette

	ldy #0
p1:
	lda pal0, y
	sta target_palette, y
	iny
	bne p1

	ldy #0
p2:
	lda pal0+256, y
	sta target_palette3, y
	iny
	bne p2
	
	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	rts
.endproc

.proc copy_pal1_to_target_palette
	VERA_SET_ADDR Vera::VRAM_palette

	ldy #0
p1:
	lda pal1, y
	sta target_palette, y
	iny
	bne p1

	ldy #0
p2:
	lda pal1+256, y
	sta target_palette3, y
	iny
	bne p2
	
	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	rts
.endproc

.proc copy_pal2_to_target_palette
	VERA_SET_ADDR Vera::VRAM_palette

	ldy #0
p1:
	lda pal2, y
	sta target_palette, y
	iny
	bne p1

	ldy #0
p2:
	lda pal2+256, y
	sta target_palette3, y
	iny
	bne p2
	
	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	rts
.endproc

.proc clear_bitmap_area
	; enable FX

	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	lda #%01000000 ; enable cache writes
	sta Vera::Reg::FXCtrl
	lda #(6 << 1) ; DCSEL = 6
	; zero the cache
	sta Vera::Reg::Ctrl
	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c
	stz Vera::Reg::Ctrl

	VERA_SET_ADDR $00000, 3

	ldy #8 ; 64kB
	ldx #0  ; 8kB per loop (256 * 32 w/ cache)
clearloop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne clearloop
	dey
	bne clearloop

	; disable FX
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc blank_palette

	VERA_SET_ADDR Vera::VRAM_palette, 1

	ldx #128
:	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	dex
	bne :-

	rts
.endproc

.proc setup_vera
	; set full palette to white

	VERA_SET_ADDR Vera::VRAM_palette, 1

	ldx #128
	lda #$0f
	ldy #$ff
:	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	dex
	bne :-

	; set VERA layers up
	; show layer 0
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$10
	sta Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21
	sta Vera::Reg::DCVStart
	lda #($f0 - 20)
	sta Vera::Reg::DCVStop
	stz Vera::Reg::Ctrl

	; 4:1 scale
	lda #$20
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; bitmap mode, 8bpp
	lda #%00000111
	sta Vera::Reg::L0Config

	; bitmap base, 320x240
	stz Vera::Reg::L0TileBase

	rts
.endproc

sint1:
	.byte $40,$44,$48,$4B,$4F,$52,$54,$56,$58,$59,$5A,$5B,$5C,$5D,$5E,$60
	.byte $61,$63,$66,$69,$6B,$6E,$71,$74,$76,$78,$79,$7A,$7A,$7A,$79,$78
	.byte $77,$75,$73,$72,$71,$70,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6E,$6D
	.byte $6B,$69,$67,$63,$60,$5C,$58,$55,$51,$4E,$4B,$48,$46,$44,$42,$41
	.byte $40,$3E,$3D,$3B,$39,$37,$34,$31,$2E,$2A,$27,$23,$1F,$1C,$18,$16
	.byte $14,$12,$11,$10,$10,$10,$10,$10,$10,$10,$10,$0F,$0E,$0D,$0C,$0A
	.byte $09,$07,$06,$05,$05,$05,$06,$07,$09,$0B,$0E,$11,$14,$16,$19,$1C
	.byte $1E,$1F,$21,$22,$23,$24,$25,$26,$27,$29,$2B,$2D,$30,$34,$37,$3B
	.byte $40,$44,$48,$4B,$4F,$52,$54,$56,$58,$59,$5A,$5B,$5C,$5D,$5E,$60
	.byte $61,$63,$66,$69,$6B,$6E,$71,$74,$76,$78,$79,$7A,$7A,$7A,$79,$78
	.byte $77,$75,$73,$72,$71,$70,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6E,$6D
	.byte $6B,$69,$67,$63,$60,$5C,$58,$55,$51,$4E,$4B,$48,$46,$44,$42,$41
	.byte $40,$3E,$3D,$3B,$39,$37,$34,$31,$2E,$2A,$27,$23,$1F,$1C,$18,$16
	.byte $14,$12,$11,$10,$10,$10,$10,$10,$10,$10,$10,$0F,$0E,$0D,$0C,$0A
	.byte $09,$07,$06,$05,$05,$05,$06,$07,$09,$0B,$0E,$11,$14,$16,$19,$1C
	.byte $1E,$1F,$21,$22,$23,$24,$25,$26,$27,$29,$2B,$2D,$30,$34,$37,$3B
sint2:
	.byte $00,$03,$06,$09,$0C,$10,$13,$15,$18,$1B,$1D,$20,$22,$24,$26,$28
	.byte $29,$2B,$2C,$2D,$2E,$2F,$30,$30,$31,$31,$32,$32,$32,$32,$32,$32
	.byte $32,$32,$32,$32,$32,$32,$32,$31,$31,$30,$30,$2F,$2E,$2D,$2C,$2B
	.byte $29,$28,$26,$24,$22,$20,$1D,$1B,$18,$15,$13,$10,$0C,$09,$06,$03
	.byte $00,$FD,$FA,$F7,$F4,$F0,$ED,$EB,$E8,$E5,$E3,$E0,$DE,$DC,$DA,$D8
	.byte $D7,$D5,$D4,$D3,$D2,$D1,$D0,$D0,$CF,$CF,$CE,$CE,$CE,$CE,$CE,$CE
	.byte $CD,$CE,$CE,$CE,$CE,$CE,$CE,$CF,$CF,$D0,$D0,$D1,$D2,$D3,$D4,$D5
	.byte $D7,$D8,$DA,$DC,$DE,$E0,$E3,$E5,$E8,$EB,$ED,$F0,$F4,$F7,$FA,$FD
	.byte $00,$03,$06,$09,$0C,$10,$13,$15,$18,$1B,$1D,$20,$22,$24,$26,$28
	.byte $29,$2B,$2C,$2D,$2E,$2F,$30,$30,$31,$31,$32,$32,$32,$32,$32,$32
	.byte $32,$32,$32,$32,$32,$32,$32,$31,$31,$30,$30,$2F,$2E,$2D,$2C,$2B
	.byte $29,$28,$26,$24,$22,$20,$1D,$1B,$18,$15,$13,$10,$0C,$09,$06,$03
	.byte $00,$FD,$FA,$F7,$F4,$F0,$ED,$EB,$E8,$E5,$E3,$E0,$DE,$DC,$DA,$D8
	.byte $D7,$D5,$D4,$D3,$D2,$D1,$D0,$D0,$CF,$CF,$CE,$CE,$CE,$CE,$CE,$CE
	.byte $CD,$CE,$CE,$CE,$CE,$CE,$CE,$CF,$CF,$D0,$D0,$D1,$D2,$D3,$D4,$D5
	.byte $D7,$D8,$DA,$DC,$DE,$E0,$E3,$E5,$E8,$EB,$ED,$F0,$F4,$F7,$FA,$FD
sint3:
	.byte $80,$8A,$92,$94,$96,$98,$9C,$A6,$B0,$B8,$BC,$BC,$BC,$BC,$C2,$CA
	.byte $D2,$D6,$D6,$D4,$D2,$D4,$DA,$E0,$E6,$E8,$E6,$E4,$E2,$E4,$EA,$F0
	.byte $F4,$F2,$EE,$EA,$E8,$EA,$EE,$F0,$EE,$E8,$E0,$DA,$D8,$D8,$DA,$D8
	.byte $D2,$C8,$BE,$B8,$B6,$B6,$B4,$B0,$A8,$9E,$96,$92,$90,$90,$8E,$88
	.byte $80,$76,$70,$6E,$6E,$6C,$68,$60,$56,$4E,$4A,$48,$48,$46,$40,$36
	.byte $2C,$26,$24,$26,$26,$24,$1E,$16,$10,$0E,$10,$14,$16,$14,$10,$0C
	.byte $0C,$0E,$14,$1A,$1C,$1A,$18,$16,$18,$1E,$24,$2A,$2C,$2A,$28,$28
	.byte $2C,$34,$3C,$42,$42,$42,$42,$46,$4E,$58,$62,$66,$68,$6A,$6C,$74
	.byte $7E,$8A,$92,$94,$96,$98,$9C,$A6,$B0,$B8,$BC,$BC,$BC,$BC,$C2,$CA
	.byte $D2,$D6,$D6,$D4,$D2,$D4,$DA,$E0,$E6,$E8,$E6,$E4,$E2,$E4,$EA,$F0
	.byte $F4,$F2,$EE,$EA,$E8,$EA,$EE,$F0,$EE,$E8,$E0,$DA,$D8,$D8,$DA,$D8
	.byte $D2,$C8,$BE,$B8,$B6,$B6,$B4,$B0,$A8,$9E,$96,$92,$90,$90,$8E,$88
	.byte $80,$76,$70,$6E,$6E,$6C,$68,$60,$56,$4E,$4A,$48,$48,$46,$40,$36
	.byte $2C,$26,$24,$26,$26,$24,$1E,$16,$10,$0E,$10,$14,$16,$14,$10,$0C
	.byte $0C,$0E,$14,$1A,$1C,$1A,$18,$16,$18,$1E,$24,$2A,$2C,$2A,$28,$28
	.byte $2C,$34,$3C,$42,$42,$42,$42,$46,$4E,$58,$62,$66,$68,$6A,$6C,$74
sint4:
	.byte $80,$83,$87,$8A,$8D,$91,$94,$97,$99,$9C,$9E,$A0,$A2,$A3,$A5,$A6
	.byte $A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF,$B0,$B1,$B2,$B3,$B4,$B5,$B6
	.byte $B7,$B7,$B8,$B8,$B8,$B8,$B7,$B7,$B6,$B4,$B3,$B1,$AF,$AD,$AB,$A8
	.byte $A5,$A3,$A0,$9D,$9A,$98,$95,$92,$90,$8D,$8B,$89,$87,$85,$83,$81
	.byte $80,$7E,$7C,$7A,$78,$76,$74,$72,$6F,$6D,$6A,$67,$65,$62,$5F,$5C
	.byte $5A,$57,$54,$52,$50,$4E,$4C,$4B,$49,$48,$48,$47,$47,$47,$47,$48
	.byte $49,$49,$4A,$4B,$4C,$4D,$4E,$4F,$50,$51,$52,$53,$54,$55,$56,$57
	.byte $58,$59,$5A,$5C,$5D,$5F,$61,$63,$66,$68,$6B,$6E,$72,$75,$78,$7C
	.byte $7F,$83,$87,$8A,$8D,$91,$94,$97,$99,$9C,$9E,$A0,$A2,$A3,$A5,$A6
	.byte $A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF,$B0,$B1,$B2,$B3,$B4,$B5,$B6
	.byte $B7,$B7,$B8,$B8,$B8,$B8,$B7,$B7,$B6,$B4,$B3,$B1,$AF,$AD,$AB,$A8
	.byte $A5,$A3,$A0,$9D,$9A,$98,$95,$92,$90,$8D,$8B,$89,$87,$85,$83,$81
	.byte $80,$7E,$7C,$7A,$78,$76,$74,$72,$6F,$6D,$6A,$67,$65,$62,$5F,$5C
	.byte $5A,$57,$54,$52,$50,$4E,$4C,$4B,$49,$48,$48,$47,$47,$47,$47,$48
	.byte $49,$49,$4A,$4B,$4C,$4D,$4E,$4F,$50,$51,$52,$53,$54,$55,$56,$57
	.byte $58,$59,$5A,$5C,$5D,$5F,$61,$63,$66,$68,$6B,$6E,$72,$75,$78,$7C
ptau:
	.byte $00,$01,$01,$02,$03,$04,$06,$08,$0A,$0C,$0E,$11,$14,$17,$19,$1C
	.byte $1F,$23,$26,$28,$2B,$2E,$31,$33,$35,$37,$39,$3B,$3C,$3D,$3E,$3E
	.byte $3F,$3E,$3E,$3D,$3C,$3B,$39,$37,$35,$33,$31,$2E,$2B,$28,$26,$23
	.byte $20,$1C,$19,$17,$14,$11,$0E,$0C,$0A,$08,$06,$04,$03,$02,$01,$01
dtau:
	.byte $15,$15,$15,$15,$15,$16,$16,$17,$17,$18,$19,$1A,$1B,$1C,$1D,$1E
	.byte $1F,$21,$22,$24,$25,$27,$29,$2B,$2D,$2F,$31,$33,$35,$38,$3A,$3D
	.byte $40,$42,$45,$48,$4B,$4E,$51,$54,$58,$5B,$5F,$62,$66,$6A,$6D,$71
	.byte $75,$79,$7D,$82,$86,$8A,$8F,$94,$98,$9D,$A2,$A7,$AC,$B1,$B6,$BB
pal0:
	.word $0000,$0000,$0000,$0000,$0100,$0100,$0100,$0200
	.word $0200,$0300,$0300,$0400,$0500,$0500,$0600,$0700
	.word $0700,$0800,$0900,$0A00,$0A00,$0B00,$0C00,$0C00
	.word $0D00,$0D00,$0E00,$0E00,$0E00,$0F00,$0F00,$0F00
	.word $0F00,$0F00,$0F00,$0F00,$0E00,$0E00,$0E00,$0D00
	.word $0D00,$0C00,$0C00,$0B00,$0A00,$0A00,$0900,$0800
	.word $0800,$0700,$0600,$0500,$0500,$0400,$0300,$0300
	.word $0200,$0200,$0100,$0100,$0100,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0100,$0100,$0100,$0200,$0200
	.word $0300,$0300,$0400,$0500,$0500,$0600,$0700,$0800
	.word $0800,$0900,$0A00,$0A00,$0B00,$0C00,$0C00,$0D00
	.word $0D00,$0E00,$0E00,$0E00,$0F00,$0F00,$0F00,$0F00
	.word $0F00,$0F00,$0F00,$0E00,$0E00,$0E00,$0D00,$0D00
	.word $0C00,$0C00,$0B00,$0A00,$0A00,$0900,$0800,$0700
	.word $0700,$0600,$0500,$0500,$0400,$0300,$0300,$0200
	.word $0200,$0100,$0100,$0100,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0001,$0001,$0001,$0002
	.word $0002,$0003,$0003,$0004,$0005,$0005,$0006,$0007
	.word $0007,$0008,$0009,$000A,$000A,$000B,$000C,$000C
	.word $000D,$000D,$000E,$000E,$000E,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000E,$000E,$000E,$000D
	.word $000D,$000C,$000C,$000B,$000A,$000A,$0009,$0008
	.word $0008,$0007,$0006,$0005,$0005,$0004,$0003,$0003
	.word $0002,$0002,$0001,$0001,$0001,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0001,$0101,$0101,$0102,$0202
	.word $0203,$0303,$0304,$0405,$0505,$0506,$0607,$0708
	.word $0708,$0809,$090A,$0A0A,$0A0B,$0B0C,$0C0C,$0C0D
	.word $0D0D,$0D0E,$0E0E,$0E0E,$0E0F,$0F0F,$0F0F,$0F0F
	.word $0F0F,$0F0F,$0F0F,$0F0E,$0E0E,$0E0E,$0E0D,$0D0D
	.word $0D0C,$0C0C,$0C0B,$0B0A,$0A0A,$0A09,$0908,$0807
	.word $0807,$0706,$0605,$0505,$0504,$0403,$0303,$0302
	.word $0202,$0201,$0101,$0101,$0100,$0000,$0000,$0000
pal1:
	.word $0000,$0000,$0000,$0000,$0100,$0100,$0100,$0200
	.word $0200,$0300,$0300,$0400,$0500,$0500,$0600,$0700
	.word $0700,$0800,$0900,$0A00,$0A00,$0B00,$0C00,$0C00
	.word $0D00,$0D00,$0E00,$0E00,$0E00,$0F00,$0F00,$0F00
	.word $0F00,$0F00,$0F00,$0F00,$0E00,$0E00,$0E00,$0D00
	.word $0D00,$0C00,$0C00,$0B00,$0A00,$0A00,$0900,$0800
	.word $0800,$0700,$0600,$0500,$0500,$0400,$0300,$0300
	.word $0200,$0200,$0100,$0100,$0100,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0100,$0101,$0101,$0201,$0202
	.word $0302,$0303,$0403,$0504,$0505,$0605,$0706,$0807
	.word $0807,$0908,$0A09,$0A0A,$0B0A,$0C0B,$0C0C,$0D0C
	.word $0D0D,$0E0D,$0E0E,$0E0E,$0F0E,$0F0F,$0F0F,$0F0F
	.word $0F0F,$0F0F,$0F0F,$0E0F,$0E0E,$0E0E,$0D0E,$0D0D
	.word $0C0D,$0C0C,$0B0C,$0A0B,$0A0A,$090A,$0809,$0708
	.word $0708,$0607,$0506,$0505,$0405,$0304,$0303,$0203
	.word $0202,$0102,$0101,$0101,$0001,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0001,$0011,$0011,$0012,$0022
	.word $0023,$0033,$0034,$0045,$0055,$0056,$0067,$0078
	.word $0078,$0089,$009A,$00AA,$00AB,$00BC,$00CC,$00CD
	.word $00DD,$00DE,$00EE,$00EE,$00EF,$00FF,$00FF,$00FF
	.word $00FF,$00FF,$00FF,$00FE,$00EE,$00EE,$00ED,$00DD
	.word $00DC,$00CC,$00CB,$00BA,$00AA,$00A9,$0098,$0087
	.word $0087,$0076,$0065,$0055,$0054,$0043,$0033,$0032
	.word $0022,$0021,$0011,$0011,$0010,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0101,$0101,$0101,$0202
	.word $0202,$0303,$0303,$0404,$0505,$0505,$0606,$0707
	.word $0707,$0808,$0909,$0A0A,$0A0A,$0B0B,$0C0C,$0C0C
	.word $0D0D,$0D0D,$0E0E,$0E0E,$0E0E,$0F0F,$0F0F,$0F0F
	.word $0F0F,$0F0F,$0F0F,$0F0F,$0E0E,$0E0E,$0E0E,$0D0D
	.word $0D0D,$0C0C,$0C0C,$0B0B,$0A0A,$0A0A,$0909,$0808
	.word $0808,$0707,$0606,$0505,$0505,$0404,$0303,$0303
	.word $0202,$0202,$0101,$0101,$0101,$0000,$0000,$0000
pal2:
	.word $0000,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0444,$0444,$0444,$0444,$0444,$0444,$0555,$0555
	.word $0555,$0555,$0555,$0666,$0666,$0666,$0777,$0777
	.word $0777,$0888,$0888,$0999,$0999,$0999,$0AAA,$0AAA
	.word $0AAA,$0AAA,$0AAA,$0BBB,$0BBB,$0BBB,$0BBB,$0BBB
	.word $0BBB,$0BBB,$0BBB,$0BBB,$0BBB,$0BBB,$0AAA,$0AAA
	.word $0AAA,$0AAA,$0AAA,$0999,$0999,$0999,$0888,$0888
	.word $0888,$0777,$0777,$0666,$0666,$0666,$0555,$0555
	.word $0555,$0555,$0555,$0444,$0444,$0444,$0444,$0444
	.word $0444,$0444,$0444,$0444,$0444,$0555,$0555,$0555
	.word $0555,$0555,$0666,$0666,$0666,$0777,$0777,$0888
	.word $0888,$0888,$0999,$0999,$0999,$0AAA,$0AAA,$0AAA
	.word $0AAA,$0AAA,$0BBB,$0BBB,$0BBB,$0BBB,$0BBB,$0BBB
	.word $0BBB,$0BBB,$0BBB,$0BBB,$0BBB,$0AAA,$0AAA,$0AAA
	.word $0AAA,$0AAA,$0999,$0999,$0999,$0888,$0888,$0777
	.word $0777,$0777,$0666,$0666,$0666,$0555,$0555,$0555
	.word $0555,$0555,$0444,$0444,$0444,$0444,$0444,$0444
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
	.word $0111,$0111,$0111,$0111,$0111,$0111,$0111,$0111
pal3:
	.word $0000,$0000,$0000,$0000,$0100,$0100,$0100,$0200
	.word $0200,$0300,$0300,$0400,$0500,$0500,$0600,$0700
	.word $0700,$0800,$0900,$0A00,$0A00,$0B00,$0C00,$0C00
	.word $0D00,$0D00,$0E00,$0E00,$0E00,$0F00,$0F00,$0F00
	.word $0F00,$0F00,$0F00,$0F00,$0E00,$0E00,$0E00,$0D00
	.word $0D00,$0C00,$0C00,$0B00,$0A00,$0A00,$0900,$0800
	.word $0800,$0700,$0600,$0500,$0500,$0400,$0300,$0300
	.word $0200,$0200,$0100,$0100,$0100,$0000,$0000,$0000
	.word $0F00,$0F00,$0F00,$0F00,$0F11,$0F11,$0F11,$0F22
	.word $0F22,$0F33,$0F33,$0F44,$0F55,$0F55,$0F66,$0F77
	.word $0F77,$0F88,$0F99,$0FAA,$0FAA,$0FBB,$0FCC,$0FCC
	.word $0FDD,$0FDD,$0FEE,$0FEE,$0FEE,$0FFF,$0FFF,$0FFF
	.word $0FFF,$0FFF,$0FFF,$0FFF,$0FEE,$0FEE,$0FEE,$0FDD
	.word $0FDD,$0FCC,$0FCC,$0FBB,$0FAA,$0FAA,$0F99,$0F88
	.word $0F88,$0F77,$0F66,$0F55,$0F55,$0F44,$0F33,$0F33
	.word $0F22,$0F22,$0F11,$0F11,$0F11,$0F00,$0F00,$0F00
	.word $000F,$000F,$000F,$011F,$011F,$011F,$022F,$022F
	.word $033F,$033F,$044F,$055F,$055F,$066F,$077F,$088F
	.word $088F,$099F,$0AAF,$0AAF,$0BBF,$0CCF,$0CCF,$0DDF
	.word $0DDF,$0EEF,$0EEF,$0EEF,$0FFF,$0FFF,$0FFF,$0FFF
	.word $0FFF,$0FFF,$0FFF,$0EEF,$0EEF,$0EEF,$0DDF,$0DDF
	.word $0CCF,$0CCF,$0BBF,$0AAF,$0AAF,$099F,$088F,$077F
	.word $077F,$066F,$055F,$055F,$044F,$033F,$033F,$022F
	.word $022F,$011F,$011F,$011F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
	.word $000F,$000F,$000F,$000F,$000F,$000F,$000F,$000F
pal4:
	.word $0000,$0000,$0000,$0111,$0111,$0111,$0222,$0222
	.word $0222,$0333,$0333,$0444,$0555,$0555,$0555,$0666
	.word $0777,$0888,$0888,$0999,$0AAA,$0AAA,$0AAA,$0BBB
	.word $0CCC,$0CCC,$0DDD,$0DDD,$0DDD,$0EEE,$0EEE,$0EEE
	.word $0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF
	.word $0EEE,$0EEE,$0EEE,$0EEE,$0DDD,$0DDD,$0CCC,$0CCC
	.word $0CCC,$0BBB,$0AAA,$0AAA,$0999,$0888,$0777,$0777
	.word $0777,$0666,$0555,$0555,$0444,$0333,$0333,$0333
	.word $0222,$0222,$0111,$0111,$0111,$0111,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	.word $0000,$0000,$0001,$0111,$0111,$0111,$0122,$0222
	.word $0223,$0333,$0344,$0344,$0445,$0455,$0556,$0567
	.word $0667,$0778,$0778,$0789,$089A,$089A,$09AB,$09AC
	.word $0ABC,$0ABC,$0ABD,$0ACD,$0BCE,$0BDE,$0BDE,$0BDF
	.word $0BDF,$0CDF,$0CDF,$0CDF,$0CDF,$0CDF,$0CDF,$0BDF
	.word $0BDE,$0BDE,$0BCE,$0ACD,$0ABD,$0ABD,$0ABC,$09AC
	.word $09AB,$089A,$089A,$0789,$0789,$0778,$0678,$0567
	.word $0556,$0455,$0445,$0445,$0344,$0333,$0223,$0222
	.word $0122,$0111,$0111,$0111,$0001,$0000,$0000,$0000
