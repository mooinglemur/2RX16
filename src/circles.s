.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "CIRCLES"
entry:


    LOADFILE "PLACEHOLDER_CIRCLES.VBM", 0, $0000, 0 ; $00000 VRAM
    LOADFILE "PLACEHOLDER_CIRCLES.PAL", 0, target_palette

    lda #0
    jsr setup_palette_fade

    PALETTE_FADE 1

    MUSIC_SYNC $40

    ; fade to white (except for index 0)

    ldx #30
:   lda #$0f
    sta target_palette+1,x
    dex
    lda #$ff
    sta target_palette+1,x
    dex
    bne :-

    lda #0
    jsr setup_palette_fade

    PALETTE_FADE 1


    rts
