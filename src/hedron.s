.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.import syncval

.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "HEDRON"
entry:
    jsr transition_to_chessboard
    rts

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

    ldx topwipe
    cpx #$80
    bcs done_wiping

    POS_ADDR_ROW_4BIT

    ; write 80 times to clear 2 lines
    ldx #80
:   stz Vera::Reg::Data0
    dex
    bne :-

    inc topwipe
    inc topwipe

    ldx bottomwipe

    POS_ADDR_ROW_4BIT

    ; write 40 times to clear 1 line
    ldx #40
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

    ; set up DCSEL=2
    lda #(2 << 1)
    sta Vera::Reg::Ctrl

    ; set cache fills and writes
    lda #$60
    tsb Vera::Reg::FXCtrl

    stz Vera::Reg::Ctrl ; ADDR0
    ldx #128

    POS_ADDR_ROW_4BIT

    lda #$30
    sta Vera::Reg::AddrH ; increment 4, chessboard edge drawn here

    jsr draw_chessboard_edge

    ; set up DCSEL=2
    lda #(2 << 1)
    sta Vera::Reg::Ctrl

    ; clear cache/fill writes
    lda #$60
    trb Vera::Reg::FXCtrl
    
    stz Vera::Reg::Ctrl

    ; then load the new palette immediately
    LOADFILE "HEDRONCHESS.PAL", 0, $FA00, 1 ; palette 0+

    ; wait one frame
    WAITVSYNC

    ; and then do the chessboard animation
    ; in the 60fps video, we have
    ; 32 frames of falling (including 3 frames that are still)
    ; 18 frames rising
    ; 9 frames holding
    ; 19 frames falling
    ; 12 frames rising
    ; 5 frames holding
    ; 13 frames falling
    ; 1 frame holding at the bottom
    ; 8 frames rising
    ; 2 frames holding
    ; 8 frames falling
    ; 3 frames holding at the bottom
    ; 2 frames rising
    ; 7 frames holding
    ; 1 frame falling
    ; done

    CHESSBOARD_ACCEL = $01
    MAX_INCREMENT = $96

    stz momentum_sign
    stz velocity
    stz increment
    stz bounce_count
bounce_loop:
    WAITVSYNC
    lda momentum_sign
    bne neg_momentum

    lda velocity
    clc
    adc #CHESSBOARD_ACCEL
    sta velocity

    adc increment
    sta increment
    cmp #MAX_INCREMENT
    bcc bounce_cont
    lda #$ff
    sta momentum_sign
    ldx bounce_count
    lda velocity
    lda upward_momenta,x
    sta velocity
    inx
    stx bounce_count
    cpx #5
    jeq bounce_done
    bra bounce_cont
neg_momentum:
    lda velocity
    sec
    sbc #CHESSBOARD_ACCEL
    bcs :+
    stz momentum_sign
    lda #0
:   sta velocity
    lda increment
    sbc velocity
    sta increment
    bcs bounce_cont
    stz momentum_sign
    stz increment
.repeat 4
    WAITVSYNC
.endrepeat
bounce_cont:
    stz line_iter_frac
    
    ; set FX cache to all zeroes
    lda #(6 << 1)
    sta Vera::Reg::Ctrl
    stz $9f29
    stz $9f2a
    stz $9f2b
    stz $9f2c    

    ; set up DCSEL=2
    lda #(2 << 1)
    sta Vera::Reg::Ctrl

    ; set cache writes/fill
    lda #$60
    tsb Vera::Reg::FXCtrl

    lda #1
    sta Vera::Reg::Ctrl ; position addr1
    ldx #0

    POS_ADDR_ROW_4BIT

    lda #$11
    sta Vera::Reg::AddrH
    stz Vera::Reg::Ctrl


    ldx #128
    stx line_iter

    POS_ADDR_ROW_4BIT

    lda #$30
    sta Vera::Reg::AddrH

    ; write 24 lines of blank
    ldy #24
blankouter:
    ldx #5
blankloop:
.repeat 8
    stz Vera::Reg::Data0
.endrepeat
    dex
    bne blankloop

    lda increment
    clc
    adc line_iter_frac
    sta line_iter_frac
    bcc :+
    inc line_iter
:   ldx line_iter

    POS_ADDR_ROW_4BIT

    dey
    bne blankouter

    ; write perspective chessboard, 100 lines
    ldy #100
boardouter:
    ldx #5
boardloop:
.repeat 8
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    stz Vera::Reg::Data0
.endrepeat

    dex
    bne boardloop

    lda increment
    clc
    adc line_iter_frac
    sta line_iter_frac
    bcc :+
    inc line_iter
:   ldx line_iter
    cpx #200
    jcs end_bounce_loop

    POS_ADDR_ROW_4BIT

    dey
    jne boardouter

    ; finish the chessboard edge
    ldy #10
edgeouter:
    ldx #5
edgeloop:
.repeat 8
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    stz Vera::Reg::Data0
.endrepeat

    dex
    bne edgeloop

    inc line_iter
    lda line_iter
    cmp #200
    bcs end_bounce_loop
    dey
    jne edgeouter

    ; set FX cache to all zeroes
    lda #(6 << 1)
    sta Vera::Reg::Ctrl
    stz $9f29
    stz $9f2a
    stz $9f2b
    stz $9f2c    

    stz Vera::Reg::Ctrl

    ; write up to 12 lines of blankness
    ldy #12
bottom_blank_outer:
    ldx #5
bottom_blank_loop:
.repeat 8
    stz Vera::Reg::Data0
.endrepeat
    dex
    bne bottom_blank_loop

    inc line_iter
    lda line_iter
    cmp #200
    bcc bottom_blank_outer

end_bounce_loop:
    jmp bounce_loop

bounce_done:
    ; then convert the static chessboard to tiles
    ; and replace the bitmap with a tilemap

    rts
line_iter:
    .byte 0
line_iter_frac:
    .byte 0
increment:
    .byte 0
topwipe:
    .byte 0
bottomwipe:
    .byte 0
vsync_count:
    .byte 0
velocity:
    .byte 0
momentum_sign:
    .byte 0
bounce_count:
    .byte 0
upward_momenta:
    .byte 12,8,5,2,0
.endproc

.proc draw_chessboard_edge
    lda #1 ; ADDR1
    sta Vera::Reg::Ctrl
    
    ldx #100

    POS_ADDR_ROW_4BIT

    lda #$11
    sta Vera::Reg::AddrH ; increment 1, chessboard edge here

    ; draw 10 lines, which is 40 writes per row, so 400.
    ldx #<400
    ldy #(>400)+1 ; the +1 to allow the loop to end when reaching 0
edgeloop:
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    lda Vera::Reg::Data1
    stz Vera::Reg::Data0
    dex
    bne edgeloop
    dey
    bne edgeloop

    rts
.endproc

