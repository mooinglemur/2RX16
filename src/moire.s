.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "MOIRE"
entry:
    ; fade to white

    ldx #32
:   lda #$0f
    sta target_palette-1,x
    dex
    lda #$ff
    sta target_palette-1,x
    dex
    bne :-



    LOADFILE "PLACEHOLDER_MOIRE.VBM", 0, $0000, 0 ; $00000 VRAM

    MUSIC_SYNC $45

    LOADFILE "PLACEHOLDER_MOIRE.PAL", 0, target_palette

    lda #0
    jsr setup_palette_fade

    PALETTE_FADE 1

    MUSIC_SYNC $50

    ldx #32
:   stz target_palette-1,x
    dex
    bne :-

    lda #0
    jsr setup_palette_fade

    PALETTE_FADE 1


    rts