.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.import syncval


.include "x16.inc"
.include "macros.inc"

.segment "HEDRON"
entry:
    jsr transition_to_chessboard

.proc transition_to_chessboard
    LOADFILE "HEDRONCHESS.VBM", 0, $0000, 1 ; $10000 VRAM

    ; fade all palette colors to #$444
    ldx #130
fill_grey:
    lda #$44
    sta target_palette-128,x
    inx
    lda #$04
    sta target_palette-128,x
    inx
    bne fill_grey

    ; set up
    lda #0
    jsr setup_palette_fade

    ; wait for syncval to hit #$10
sync10loop:
    wai
    lda syncval
    cmp #$10
    bne sync10loop


    ; set FX cache to all zeroes
    lda #(6 << 1)
    sta Vera::Reg::Ctrl
    stz $9f29
    stz $9f2a
    stz $9f2b
    stz $9f2c

    ; wipe effect while fading
    lda #199
    sta bottomwipe
    stz topwipe
wipeloop:
    lda topwipe
    cmp #16
    bcs :+
    WAITVSYNC
:   lda topwipe
    and #2
    beq :+
    WAITVSYNC
:
    
    ; set up DCSEL=2
    lda #(2 << 1)
    sta Vera::Reg::Ctrl

    ; set up cache writes
    lda #$40
    tsb Vera::Reg::FXCtrl

    stz Vera::Reg::Ctrl

    lda #$30
    sta Vera::Reg::AddrH

    lda topwipe
    cmp #$80
    bcs done_wiping
    jsr pos_addr_row

    ; write 160 times to clear 2 lines
    ldx #160
:   stz Vera::Reg::Data0
    dex
    bne :-

    inc topwipe
    inc topwipe

    lda bottomwipe
    jsr pos_addr_row

    ; write 80 times to clear 1 line
    ldx #80
:   stz Vera::Reg::Data0
    dex
    bne :-

    dec bottomwipe

    ; set up DCSEL=2
    lda #(2 << 1)
    sta Vera::Reg::Ctrl

    ; clear cache writes
    lda #$40
    trb Vera::Reg::FXCtrl

    stz Vera::Reg::Ctrl

    lda topwipe
    and #7
    bne :+
    jsr apply_palette_fade_step
    jsr flush_palette
:
    jmp wipeloop
done_wiping:
    ; now copy the front of the chessboard in

;    LOADFILE "HEDRONCHESS.PAL", 0, $FA00, 1 ; palette 0+

    rts
topwipe:
    .byte 0
bottomwipe:
    .byte 0
.endproc

.proc pos_addr_row
    tax

    ror
    ror
    ror
    and #$c0
    sta Vera::Reg::AddrL
    lda addrm_per_row,x
    sta Vera::Reg::AddrM
    rts
.endproc

addrm_per_row:
    .byte $00,$01,$02,$03,$05,$06,$07,$08
    .byte $0a,$0b,$0c,$0d,$0f,$10,$11,$12
    .byte $14,$15,$16,$17,$19,$1a,$1b,$1c
    .byte $1e,$1f,$20,$21,$23,$24,$25,$26
    .byte $28,$29,$2a,$2b,$2d,$2e,$2f,$30
    .byte $32,$33,$34,$35,$37,$38,$39,$3a
    .byte $3c,$3d,$3e,$3f,$41,$42,$43,$44
    .byte $46,$47,$48,$49,$4b,$4c,$4d,$4e
    .byte $50,$51,$52,$53,$55,$56,$57,$58
    .byte $5a,$5b,$5c,$5d,$5f,$60,$61,$62
    .byte $64,$65,$66,$67,$69,$6a,$6b,$6c
    .byte $6e,$6f,$70,$71,$73,$74,$75,$76
    .byte $78,$79,$7a,$7b,$7d,$7e,$7f,$80
    .byte $82,$83,$84,$85,$87,$88,$89,$8a
    .byte $8c,$8d,$8e,$8f,$91,$92,$93,$94
    .byte $96,$97,$98,$99,$9b,$9c,$9d,$9e
    .byte $a0,$a1,$a2,$a3,$a5,$a6,$a7,$a8
    .byte $aa,$ab,$ac,$ad,$af,$b0,$b1,$b2
    .byte $b4,$b5,$b6,$b7,$b9,$ba,$bb,$bc
    .byte $be,$bf,$c0,$c1,$c3,$c4,$c5,$c6
    .byte $c8,$c9,$ca,$cb,$cd,$ce,$cf,$d0
    .byte $d2,$d3,$d4,$d5,$d7,$d8,$d9,$da
    .byte $dc,$dd,$de,$df,$e1,$e2,$e3,$e4
    .byte $e6,$e7,$e8,$e9,$eb,$ec,$ed,$ee
    .byte $f0,$f1,$f2,$f3,$f5,$f6,$f7,$f8
