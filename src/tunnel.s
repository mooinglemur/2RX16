.import setup_palette_fade
.import apply_palette_fade_step
.import flush_palette

.import target_palette

.macpack longbranch


.include "x16.inc"
.include "macros.inc"

.segment "TUNNEL"
entry:


    LOADFILE "PLACEHOLDER_TUNNEL.VBM", 0, $0000, 0 ; $00000 VRAM
    LOADFILE "PLACEHOLDER_TUNNEL.PAL", 0, target_palette

    lda #0
    jsr setup_palette_fade

    PALETTE_FADE 1

    MUSIC_SYNC $30

    ldx #32
:   stz target_palette-1,x
    dex
    bne :-

    lda target_palette

    lda #0
    jsr setup_palette_fade

    PALETTE_FADE 1


    rts
