; == PoC of the FOREST part of the 2R demo  ==

; To build: cl65 -t cx16 -o 3D-SCENE.PRG 3d-scene.s
; To run: x16emu.exe -prg 3D-SCENE.PRG -run

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

   jmp start

; TODO: The following is *copied* from my x16.s (it should be included instead)

; -- some X16 constants --

VERA_ADDR_LOW     = $9F20
VERA_ADDR_HIGH    = $9F21
VERA_ADDR_BANK    = $9F22
VERA_DATA0        = $9F23
VERA_DATA1        = $9F24
VERA_CTRL         = $9F25

VERA_IEN          = $9F26
VERA_ISR          = $9F27
VERA_IRQLINE_L    = $9F28
VERA_SCANLINE_L   = $9F28

VERA_DC_VIDEO     = $9F29  ; DCSEL=0
VERA_DC_HSCALE    = $9F2A  ; DCSEL=0
VERA_DC_VSCALE    = $9F2B  ; DCSEL=0

VERA_DC_VSTART    = $9F2B  ; DCSEL=1
VERA_DC_VSTOP     = $9F2C  ; DCSEL=1

VERA_FX_CTRL      = $9F29  ; DCSEL=2
VERA_FX_TILEBASE  = $9F2A  ; DCSEL=2
VERA_FX_MAPBASE   = $9F2B  ; DCSEL=2

VERA_FX_X_INCR_L  = $9F29  ; DCSEL=3
VERA_FX_X_INCR_H  = $9F2A  ; DCSEL=3
VERA_FX_Y_INCR_L  = $9F2B  ; DCSEL=3
VERA_FX_Y_INCR_H  = $9F2C  ; DCSEL=3

VERA_FX_X_POS_L   = $9F29  ; DCSEL=4
VERA_FX_X_POS_H   = $9F2A  ; DCSEL=4
VERA_FX_Y_POS_L   = $9F2B  ; DCSEL=4
VERA_FX_Y_POS_H   = $9F2C  ; DCSEL=4

VERA_FX_X_POS_S   = $9F29  ; DCSEL=5
VERA_FX_Y_POS_S   = $9F2A  ; DCSEL=5
VERA_FX_POLY_FILL_L = $9F2B  ; DCSEL=5
VERA_FX_POLY_FILL_H = $9F2C  ; DCSEL=5

VERA_FX_CACHE_L   = $9F29  ; DCSEL=6
VERA_FX_ACCUM_RESET = $9F29  ; DCSEL=6
VERA_FX_CACHE_M   = $9F2A  ; DCSEL=6
VERA_FX_ACCUM     = $9F2A  ; DCSEL=6
VERA_FX_CACHE_H   = $9F2B  ; DCSEL=6
VERA_FX_CACHE_U   = $9F2C  ; DCSEL=6

VERA_L0_CONFIG    = $9F2D
VERA_L0_TILEBASE  = $9F2F

VERA_PALETTE      = $1FA00


; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

; Temp vars
TMP1                      = $02
TMP2                      = $03
TMP3                      = $04
TMP4                      = $05

; For generating jump-table code
END_JUMP_ADDRESS          = $2B ; 2C
START_JUMP_ADDRESS        = $2D ; 2E
CODE_ADDRESS              = $2F ; 30
LOAD_ADDRESS              = $31 ; 32
STORE_ADDRESS             = $33 ; 34

; Used to generate jump-tables (and also the slow polygon filler)
FILL_LENGTH_LOW           = $40
FILL_LENGTH_HIGH          = $41
NUMBER_OF_ROWS            = $42

; FIXME: REMOVE THIS!?
TMP_COLOR                 = $43
TMP_POLYGON_TYPE          = $44

NEXT_STEP                 = $45
NR_OF_POLYGONS            = $46
NR_OF_FRAMES              = $47 ; 48

VRAM_ADDRESS              = $50 ; 51 ; 52


; Used to generate jump-tables
LEFT_OVER_PIXELS         = $B6 ; B7
NIBBLE_PATTERN           = $B8
NR_OF_FULL_CACHE_WRITES  = $B9
NR_OF_STARTING_PIXELS    = $BA
NR_OF_ENDING_PIXELS      = $BB

GEN_START_X              = $BC
GEN_START_X_ORG          = $BD ; only for 2-bit mode
GEN_START_X_SET_TO_ZERO  = $BE ; only for 2-bit mode
GEN_FILL_LENGTH_LOW      = $BF
GEN_FILL_LENGTH_IS_16_OR_MORE = $C0
GEN_FILL_LENGTH_IS_8_OR_MORE = GEN_FILL_LENGTH_IS_16_OR_MORE
GEN_LOANED_16_PIXELS     = $C1
GEN_LOANED_8_PIXELS = GEN_LOANED_16_PIXELS
GEN_START_X_SUB          = $C2 ; only for 2-bit mode
GEN_FILL_LINE_CODE_INDEX = $C3


; === RAM addresses ===

FILL_LINE_START_JUMP     = $2F00   ; 256 bytes
FILL_LINE_START_CODE     = $3000   ; 128 different (start of) fill line code patterns -> safe: takes $0D00 bytes

; -- IMPORTANT: we set the *two* lower bits of (the HIGH byte of) this address in the code, using FILL_LINE_END_JUMP_0 as base. So the distance between the 4 tables should be $100! AND bits 8 and 9 should be 00b! (for FILL_LINE_END_JUMP_0) --
FILL_LINE_END_JUMP_0     = $6400   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_0
FILL_LINE_END_JUMP_1     = $6500   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_1
FILL_LINE_END_JUMP_2     = $6600   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_2
FILL_LINE_END_JUMP_3     = $6700   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_3

; FIXME: can we put these code blocks closer to each other? Are they <= 256 bytes? -> NO, MORE than 256 bytes!!
FILL_LINE_END_CODE_0     = $6800   ; 3 (stz) * 80 (=320/4) = 240                      + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
FILL_LINE_END_CODE_1     = $6A00   ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
FILL_LINE_END_CODE_2     = $6C00   ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
FILL_LINE_END_CODE_3     = $6E00   ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?

Y_TO_ADDRESS_LOW         = $8100
Y_TO_ADDRESS_HIGH        = $8200
Y_TO_ADDRESS_BANK        = $8300


; === Other constants ===

NR_OF_BYTES_PER_LINE = 320

BACKGROUND_COLOR = 0

USE_JUMP_TABLE = 1
DEBUG = 0

; Jump table specific constants
TEST_JUMP_TABLE = 0   ; This turns off the iteration in-between the jump-table calls
USE_SOFT_FILL_LEN = 0 ; This turns off reading from 9F2B and 9F2C (for fill length data) and instead reads from USE_SOFT_FILL_LEN-variables
DO_4BIT = 0
DO_2BIT = 0


start:

    sei
    
; FIXME: do this a cleaner/nicer way!
    lda VERA_DC_VIDEO
    and #%10001111           ; Disable Layer 0, Layer 1 and sprites
    sta VERA_DC_VIDEO

    jsr copy_palette_from_index_0
; FIXME: use a fast clear buffers/vram!
    jsr clear_vram_slow
    
; FIXME: generate these tables *offline* (in Python!)
    .if(USE_JUMP_TABLE)
        jsr generate_fill_line_end_code
        jsr generate_fill_line_end_jump
        jsr generate_fill_line_start_code_and_jump
    .endif
    
    jsr generate_y_to_address_table
    
    jsr setup_vera_for_layer0_bitmap_general
    
    jsr setup_vera_for_layer0_bitmap_buffer_0

tmp_loop:
    
    jsr setup_polygon_filler
    jsr setup_polygon_data_address
    
   
; FIXME: HARDCODED!
; FIXME: this should be a 16-bit number!!
    lda #4
    sta NR_OF_FRAMES
    
draw_next_frame:
    
    jsr setup_vera_for_layer0_bitmap_buffer_1

    ldy #0
    
    ; -- Nr of polygons in this frame --
    lda (LOAD_ADDRESS), y
    sta NR_OF_POLYGONS

; FIXME: we can probably *avoid* incrementing LOAD_ADDRESS each frame here! (but now we set y to 0 each polygon, so we need to think about a cleaner/better way to implement this)
    clc
    lda LOAD_ADDRESS
    adc #1
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1
    

; FIXME: UGLY HACK: fixed amount of polygons!
;    lda #105
;    lda #86
; FIXME: nr 86 is BROKEN!
; FIXME: nr 86 is BROKEN!
; FIXME: nr 86 is BROKEN!
;    lda #21
;    lda #92
;    sta NR_OF_POLYGONS
    
draw_next_polygon:
    jsr test_draw_polygon_fast
    
    clc
    tya                 ; y contained the nr of bytes we read for the previous polygon
    adc LOAD_ADDRESS
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1
    
    dec NR_OF_POLYGONS
    bne draw_next_polygon



; FIXME: replace this with something proper!
    jsr dumb_wait_for_vsync
    
;    jsr switch_to_other_buffer


; FIXME: this should be a 16-bit number!!
    dec NR_OF_FRAMES
    bne draw_next_frame


    jsr unset_polygon_filler
    
; FIXME: HACK now looping!
    jmp tmp_loop
    
    
    ; We are not returning to BASIC here...
infinite_loop:
    jmp infinite_loop
    
    rts

    
; This is just a dumb verison of a proper vsync-wait
dumb_wait_for_vsync:

    ; We wait until SCANLINE == $1FF (indicating the beam is off screen, lines 512-524)
wait_for_scanline_bit8:
    lda VERA_IEN
    and #%01000000
    beq wait_for_scanline_bit8
    
wait_for_scanline_low:
    lda VERA_SCANLINE_L
    cmp #$FF
    bne wait_for_scanline_low

    rts

    
polygon_data:
    .byte 87, 0, 254, 93, 237, 0, 192, 68, 0, 10, 1, 2, 64, 66, 3, 1, 0, 0, 1, 0, 0, 254, 103, 98, 0, 0, 79, 128, 2, 2, 3, 0, 0, 171, 93, 3, 0, 0, 254, 123, 0, 0, 0, 0, 85, 1, 6, 0, 0, 254, 97, 41, 0, 0, 102, 136, 0, 1, 1, 114, 127, 27, 1, 0, 0, 75, 0, 0, 17, 96, 140, 0, 216, 252, 42, 5, 1, 1, 109, 0, 5, 2, 252, 253, 2, 0, 128, 17, 98, 0, 0, 17, 0, 0, 0, 147, 127, 7, 0, 128, 17, 107, 0, 0, 13, 0, 0, 0, 144, 127, 16, 0, 128, 17, 128, 0, 0, 4, 0, 0, 0, 143, 127, 9, 0, 0, 17, 104, 179, 0, 171, 82, 112, 3, 3, 1, 115, 0, 38, 2, 0, 0, 55, 0, 128, 203, 0, 0, 0, 50, 0, 0, 0, 5, 0, 95, 2, 0, 76, 1, 0, 128, 66, 0, 45, 0, 48, 0, 2, 0, 2, 0, 98, 1, 153, 0, 5, 0, 128, 75, 0, 48, 0, 109, 0, 2, 0, 121, 0, 101, 2, 0, 74, 2, 0, 128, 209, 106, 27, 0, 37, 0, 0, 0, 0, 0, 1, 0, 0, 208, 106, 27, 0, 205, 127, 0, 0, 1, 2, 192, 127, 4, 0, 128, 210, 107, 27, 0, 37, 0, 192, 127, 64, 0, 4, 0, 128, 213, 111, 26, 0, 38, 0, 0, 0, 0, 0, 2, 0, 128, 2, 0, 74, 0, 134, 0, 2, 0, 92, 0, 47, 2, 197, 127, 39, 2, 245, 124, 22, 0, 0, 2, 86, 142, 0, 245, 124, 0, 0, 22, 1, 80, 1, 51, 0, 128, 2, 0, 134, 0, 185, 0, 92, 0, 250, 127, 41, 2, 128, 122, 6, 0, 0, 11, 85, 64, 1, 112, 250, 0, 0, 1, 1, 45, 3, 56, 0, 0, 11, 86, 142, 0, 0, 0, 222, 2, 62, 2, 210, 111, 11, 0, 0, 13, 47, 151, 0, 197, 127, 85, 56, 3, 2, 0, 0, 35, 2, 112, 250, 1, 0, 0, 13, 41, 184, 0, 128, 122, 28, 15, 6, 1, 85, 56, 3, 0, 128, 2, 0, 185, 0, 203, 0, 250, 127, 0, 0, 41, 1, 93, 0, 52, 0, 0, 209, 82, 94, 0, 11, 0, 0, 4, 1, 2, 0, 0, 21, 1, 128, 1, 2, 0, 0, 209, 36, 97, 0, 128, 126, 0, 0, 2, 1, 0, 0, 22, 0, 128, 209, 0, 94, 0, 97, 0, 0, 0, 0, 0, 13, 2, 0, 127, 3, 0, 0, 209, 83, 101, 0, 10, 0, 0, 4, 1, 2, 10, 0, 24, 1, 0, 4, 1, 0, 0, 209, 32, 105, 0, 0, 126, 0, 0, 2, 1, 0, 0, 24, 2, 0, 124, 1, 0, 128, 209, 0, 101, 0, 105, 0, 0, 0, 0, 0, 6, 2, 171, 126, 3, 0, 128, 209, 85, 111, 0, 116, 0, 0, 0, 0, 0, 27, 1, 128, 2, 2, 0, 0, 209, 27, 116, 0, 0, 125, 0, 0, 2, 1, 9, 0, 27, 2, 0, 123, 1, 0, 128, 209, 0, 110, 0, 112, 0, 0, 0, 0, 126, 1, 0, 0, 209, 86, 122, 0, 0, 0, 0, 7, 1, 2, 0, 0, 30, 1, 85, 2, 3, 0, 0, 209, 20, 129, 0, 171, 125, 0, 0, 3, 1, 0, 0, 31, 2, 0, 121, 1, 0, 0, 204, 91, 172, 0, 192, 127, 0, 9, 1, 2, 0, 0, 3, 0, 0, 205, 85, 174, 0, 171, 127, 0, 3, 3, 2, 128, 127, 3, 1, 0, 9, 1, 0, 0, 205, 89, 156, 0, 0, 0, 0, 8, 2, 2, 192, 127, 3, 1, 0, 15, 1, 0, 0, 203, 94, 156, 0, 0, 0, 0, 15, 1, 2, 36, 0, 7, 2, 0, 112, 1, 0, 0, 205, 81, 159, 0, 160, 127, 192, 3, 4, 2, 171, 127, 4, 1, 0, 8, 2, 0, 128, 205, 94, 146, 0, 156, 0, 28, 0, 0, 0, 9, 0, 128, 206, 89, 147, 0, 156, 0, 205, 127, 0, 0, 5, 0, 128, 206, 81, 149, 0, 159, 0, 192, 127, 160, 127, 8, 0, 128, 197, 90, 146, 0, 151, 0, 102, 1, 51, 1, 5, 0, 0, 205, 94, 146, 0, 0, 124, 28, 0, 1, 1, 0, 0, 8, 2, 0, 123, 1, 0, 0, 206, 89, 147, 0, 0, 123, 205, 127, 1, 1, 0, 0, 4, 2, 0, 124, 1, 0, 0, 198, 91, 145, 0, 0, 0, 153, 1, 3, 1, 170, 2, 2, 2, 0, 0, 1, 0, 0, 207, 81, 149, 0, 128, 125, 192, 127, 2, 1, 183, 127, 6, 2, 0, 123, 1, 0, 0, 195, 90, 146, 0, 0, 127, 102, 1, 1, 1, 153, 1, 4, 2, 0, 0, 1, 0, 0, 10, 92, 165, 0, 128, 2, 192, 2, 4, 1, 0, 3, 4, 0, 0, 206, 95, 142, 0, 0, 125, 0, 0, 1, 1, 0, 0, 8, 0, 0, 206, 90, 142, 0, 0, 127, 0, 0, 2, 1, 192, 127, 3, 2, 0, 125, 1, 0, 0, 8, 93, 153, 0, 205, 127, 64, 0, 4, 2, 0, 0, 1, 1, 0, 2, 1, 0, 0, 207, 83, 144, 0, 128, 126, 183, 127, 2, 1, 220, 127, 5, 2, 0, 127, 2, 0, 0, 207, 111, 203, 0, 0, 126, 0, 127, 2, 2, 52, 126, 2, 1, 0, 127, 3, 0, 128, 10, 92, 158, 0, 165, 0, 51, 2, 128, 2, 4, 2, 0, 122, 1, 0, 0, 11, 98, 152, 0, 64, 1, 0, 2, 1, 2, 0, 1, 2, 2, 0, 1, 1, 0, 0, 193, 92, 158, 0, 0, 123, 192, 127, 1, 1, 64, 0, 3, 2, 0, 125, 1, 0, 0, 202, 94, 195, 0, 128, 0, 0, 8, 1, 2, 128, 0, 3, 1, 0, 8, 1, 0, 0, 207, 107, 205, 0, 86, 125, 128, 127, 3, 1, 154, 127, 1, 2, 0, 126, 4, 0, 0, 196, 87, 140, 0, 192, 127, 241, 127, 4, 1, 205, 127, 5, 1, 0, 0, 4, 1, 64, 0, 4, 0, 0, 204, 98, 197, 0, 36, 0, 0, 8, 1, 2, 64, 0, 4, 2, 0, 124, 2, 0, 0, 196, 85, 141, 0, 128, 127, 220, 127, 2, 1, 228, 127, 5, 2, 192, 127, 4, 0, 0, 13, 101, 156, 0, 0, 1, 0, 2, 1, 1, 51, 2, 1, 2, 0, 2, 4, 0, 0, 9, 92, 158, 0, 192, 127, 51, 2, 4, 1, 0, 2, 1, 2, 0, 120, 1, 0, 0, 164, 96, 157, 0, 0, 125, 0, 2, 1, 1, 0, 0, 1, 2, 0, 1, 1, 1, 0, 1, 1, 2, 0, 0, 1, 1, 0, 2, 2, 0, 0, 7, 105, 198, 0, 205, 127, 128, 3, 2, 2, 86, 125, 3, 0, 128, 13, 103, 160, 0, 163, 0, 0, 2, 85, 3, 3, 2, 0, 123, 1, 0, 0, 197, 97, 169, 0, 0, 120, 64, 1, 1, 1, 0, 1, 2, 1, 0, 11, 1, 0, 0, 207, 115, 195, 0, 0, 119, 0, 127, 1, 1, 128, 126, 2, 0, 0, 12, 100, 163, 0, 0, 0, 0, 11, 1, 2, 205, 127, 2, 1, 85, 3, 3, 0, 128, 202, 94, 186, 0, 195, 0, 128, 0, 128, 0, 4, 0, 0, 207, 110, 197, 0, 0, 119, 154, 127, 1, 1, 154, 127, 4, 2, 0, 119, 1, 0, 128, 204, 98, 188, 0, 197, 0, 36, 0, 36, 0, 7, 0, 128, 7, 105, 189, 0, 198, 0, 214, 127, 205, 127, 5, 2, 0, 119, 1, 0, 0, 205, 113, 174, 0, 0, 127, 0, 4, 3, 3, 0, 6, 128, 126, 2, 0, 128, 200, 94, 174, 0, 186, 0, 128, 0, 128, 0, 4, 0, 0, 205, 109, 176, 0, 128, 127, 0, 6, 2, 2, 154, 127, 2, 1, 0, 4, 3, 0, 128, 202, 98, 176, 0, 188, 0, 42, 0, 36, 0, 6, 1, 0, 12, 1, 0, 0, 6, 104, 177, 0, 205, 127, 0, 12, 1, 2, 214, 127, 4, 1, 0, 6, 2, 0, 0, 205, 112, 166, 0, 0, 127, 0, 8, 1, 2, 0, 127, 1, 1, 128, 3, 2, 0, 0, 204, 107, 167, 0, 205, 127, 128, 4, 2, 2, 128, 127, 3, 1, 0, 8, 1, 0, 0, 197, 94, 167, 0, 224, 127, 0, 0, 4, 2, 0, 0, 4, 1, 214, 127, 1, 2, 0, 0, 4, 2, 205, 127, 5, 2, 0, 127, 2, 0, 128, 201, 94, 167, 0, 174, 0, 0, 0, 128, 0, 4, 0, 128, 202, 98, 167, 0, 176, 0, 0, 0, 42, 0, 5, 1, 0, 10, 1, 0, 0, 5, 103, 167, 0, 0, 0, 0, 10, 1, 2, 205, 127, 3, 1, 128, 4, 2, 0, 128, 2, 0, 199, 0, 64, 1, 255, 127, 0, 0, 198, 1, 128, 1, 2, 0
    .byte 82, 0, 254, 92, 235, 0, 160, 98, 0, 9, 1, 2, 128, 97, 7, 1, 0, 0, 1, 0, 0, 254, 105, 96, 0, 0, 96, 128, 2, 2, 2, 192, 102, 1, 1, 0, 0, 3, 0, 0, 254, 99, 38, 0, 0, 101, 144, 0, 1, 1, 128, 127, 22, 1, 0, 0, 78, 0, 0, 17, 96, 138, 0, 128, 102, 0, 5, 4, 1, 109, 0, 2, 2, 52, 102, 5, 0, 0, 17, 100, 14, 0, 0, 114, 160, 127, 1, 1, 0, 0, 7, 0, 128, 17, 110, 0, 0, 10, 0, 0, 0, 144, 127, 16, 0, 128, 17, 132, 0, 0, 1, 0, 0, 0, 0, 127, 1, 0, 0, 17, 104, 177, 0, 154, 100, 195, 3, 5, 1, 120, 0, 33, 2, 0, 0, 58, 0, 128, 203, 0, 0, 0, 46, 0, 0, 0, 7, 0, 97, 2, 128, 103, 2, 0, 128, 66, 0, 40, 0, 43, 0, 7, 0, 7, 0, 101, 1, 192, 0, 4, 0, 128, 75, 0, 43, 0, 104, 0, 7, 0, 126, 0, 101, 2, 0, 101, 4, 0, 128, 209, 109, 24, 0, 34, 0, 0, 0, 0, 118, 1, 0, 0, 208, 109, 24, 0, 171, 127, 0, 0, 1, 2, 171, 127, 2, 1, 0, 0, 1, 0, 0, 210, 109, 34, 0, 0, 118, 128, 0, 1, 1, 171, 127, 3, 0, 128, 213, 113, 23, 0, 36, 0, 0, 0, 0, 0, 2, 2, 0, 115, 1, 0, 128, 2, 0, 69, 0, 131, 0, 6, 0, 98, 0, 47, 2, 197, 127, 39, 2, 43, 125, 24, 0, 0, 2, 86, 140, 0, 43, 125, 3, 0, 24, 1, 97, 1, 50, 0, 128, 2, 0, 131, 0, 183, 0, 98, 0, 0, 0, 39, 2, 192, 123, 8, 0, 0, 11, 82, 64, 1, 0, 83, 0, 0, 4, 1, 3, 0, 60, 2, 55, 115, 14, 0, 128, 14, 47, 149, 0, 64, 1, 197, 127, 0, 0, 35, 2, 0, 83, 4, 0, 0, 13, 39, 183, 0, 192, 123, 32, 17, 8, 0, 128, 2, 0, 183, 0, 202, 0, 0, 0, 2, 0, 39, 1, 96, 0, 53, 0, 0, 209, 83, 92, 0, 0, 0, 0, 3, 1, 2, 11, 0, 22, 1, 0, 4, 1, 0, 0, 209, 37, 94, 0, 0, 126, 0, 0, 2, 1, 11, 0, 21, 2, 0, 125, 1, 0, 128, 209, 0, 89, 0, 93, 0, 16, 0, 0, 0, 13, 2, 0, 127, 3, 0, 0, 209, 84, 99, 0, 0, 0, 0, 4, 1, 2, 9, 0, 24, 1, 128, 2, 2, 0, 0, 209, 33, 102, 0, 0, 126, 0, 0, 2, 1, 0, 0, 24, 2, 0, 124, 1, 0, 128, 209, 0, 97, 0, 101, 0, 0, 0, 0, 0, 6, 2, 0, 127, 4, 0, 0, 209, 85, 108, 0, 9, 0, 0, 6, 1, 2, 0, 0, 27, 1, 170, 1, 3, 0, 0, 209, 27, 112, 0, 86, 126, 8, 0, 3, 1, 9, 0, 27, 2, 0, 123, 1, 0, 128, 209, 0, 107, 0, 108, 0, 0, 127, 0, 126, 1, 0, 0, 209, 87, 120, 0, 8, 0, 0, 7, 1, 2, 7, 0, 30, 1, 85, 2, 3, 0, 0, 209, 19, 126, 0, 64, 126, 0, 0, 4, 1, 0, 0, 31, 2, 0, 121, 1, 0, 0, 204, 90, 174, 0, 0, 0, 0, 10, 1, 2, 0, 0, 3, 0, 0, 205, 84, 176, 0, 171, 127, 128, 4, 2, 2, 205, 127, 4, 1, 0, 10, 1, 0, 0, 205, 89, 159, 0, 205, 127, 0, 15, 1, 2, 0, 0, 4, 0, 128, 203, 94, 158, 0, 174, 0, 28, 0, 36, 0, 7, 2, 0, 120, 2, 0, 0, 205, 80, 161, 0, 200, 127, 192, 3, 4, 2, 171, 127, 5, 1, 0, 15, 1, 0, 128, 204, 94, 149, 0, 158, 0, 0, 0, 28, 0, 9, 0, 128, 206, 89, 150, 0, 159, 0, 205, 127, 205, 127, 5, 0, 128, 206, 80, 152, 0, 161, 0, 200, 127, 200, 127, 9, 0, 0, 10, 92, 168, 0, 192, 2, 51, 3, 4, 1, 170, 3, 1, 2, 0, 3, 2, 0, 128, 197, 90, 148, 0, 153, 0, 153, 1, 102, 1, 5, 0, 0, 205, 94, 149, 0, 0, 123, 0, 0, 1, 1, 32, 0, 8, 0, 0, 206, 89, 150, 0, 0, 123, 205, 127, 1, 1, 205, 127, 4, 2, 0, 123, 1, 0, 0, 198, 91, 148, 0, 0, 0, 0, 2, 3, 1, 170, 2, 1, 2, 0, 0, 2, 0, 0, 207, 80, 152, 0, 86, 126, 200, 127, 3, 1, 183, 127, 6, 2, 0, 123, 1, 0, 0, 195, 90, 148, 0, 153, 1, 153, 1, 5, 0, 0, 205, 95, 144, 0, 0, 126, 32, 0, 1, 1, 0, 0, 7, 2, 0, 125, 1, 0, 0, 206, 90, 145, 0, 128, 126, 205, 127, 2, 1, 0, 0, 3, 2, 0, 126, 1, 0, 0, 9, 93, 156, 0, 205, 127, 85, 0, 3, 2, 0, 0, 2, 1, 0, 2, 1, 0, 0, 207, 83, 147, 0, 0, 125, 183, 127, 1, 1, 192, 127, 6, 2, 128, 126, 2, 0, 128, 10, 92, 161, 0, 168, 0, 192, 2, 192, 2, 4, 0, 0, 11, 98, 155, 0, 64, 1, 0, 2, 1, 2, 0, 1, 2, 2, 0, 1, 1, 0, 0, 193, 92, 161, 0, 0, 123, 192, 127, 1, 1, 85, 0, 3, 0, 0, 196, 87, 142, 0, 192, 127, 237, 127, 4, 1, 0, 0, 5, 1, 0, 0, 4, 0, 0, 196, 84, 144, 0, 86, 127, 192, 127, 3, 1, 0, 0, 5, 2, 0, 0, 4, 2, 0, 0, 8, 0, 0, 207, 111, 204, 0, 86, 126, 171, 126, 3, 1, 0, 127, 3, 0, 0, 13, 101, 159, 0, 0, 1, 128, 2, 1, 1, 192, 2, 1, 2, 85, 2, 3, 0, 0, 9, 92, 161, 0, 192, 127, 192, 2, 4, 3, 0, 4, 0, 120, 1, 0, 128, 165, 96, 157, 0, 160, 0, 0, 0, 0, 4, 1, 2, 170, 0, 2, 1, 0, 1, 1, 2, 0, 0, 1, 1, 128, 2, 1, 2, 0, 126, 1, 0, 0, 13, 102, 166, 0, 0, 126, 192, 2, 1, 1, 85, 2, 3, 0, 0, 197, 96, 172, 0, 0, 120, 64, 1, 1, 1, 170, 0, 3, 0, 0, 207, 114, 199, 0, 0, 119, 0, 127, 1, 1, 0, 127, 2, 2, 0, 119, 1, 0, 128, 12, 100, 166, 0, 177, 0, 0, 0, 0, 0, 2, 1, 192, 2, 4, 0, 0, 202, 92, 199, 0, 0, 119, 102, 0, 1, 1, 128, 0, 4, 0, 0, 207, 109, 201, 0, 0, 119, 154, 127, 1, 1, 154, 127, 4, 2, 0, 119, 1, 0, 128, 204, 97, 192, 0, 201, 0, 36, 0, 42, 0, 6, 2, 0, 119, 1, 0, 0, 7, 103, 202, 0, 0, 119, 214, 127, 1, 1, 214, 127, 5, 2, 0, 119, 1, 0, 0, 205, 113, 178, 0, 128, 126, 0, 6, 2, 3, 0, 4, 0, 127, 3, 0, 128, 200, 93, 177, 0, 190, 0, 128, 0, 128, 0, 4, 0, 0, 205, 108, 180, 0, 154, 127, 0, 6, 2, 2, 154, 127, 3, 1, 0, 6, 2, 0, 128, 202, 97, 179, 0, 192, 0, 42, 0, 36, 0, 6, 1, 0, 13, 1, 0, 0, 6, 103, 180, 0, 0, 0, 0, 13, 1, 2, 214, 127, 4, 1, 0, 6, 2, 0, 0, 205, 111, 169, 0, 171, 127, 128, 4, 2, 2, 128, 126, 1, 1, 0, 7, 1, 0, 0, 204, 107, 171, 0, 128, 127, 0, 9, 1, 2, 154, 127, 3, 1, 128, 4, 2, 0, 128, 201, 93, 170, 0, 177, 0, 64, 0, 128, 0, 4, 0, 0, 197, 102, 170, 0, 192, 127, 214, 127, 4, 1, 224, 127, 8, 0, 0, 197, 93, 170, 0, 0, 0, 64, 0, 4, 2, 0, 0, 5, 3, 228, 127, 0, 0, 5, 2, 128, 127, 4, 0, 128, 202, 97, 171, 0, 179, 0, 0, 0, 42, 0, 5, 1, 0, 9, 1, 0, 0, 5, 102, 171, 0, 0, 0, 0, 9, 1, 2, 0, 0, 4, 1, 0, 9, 1, 0, 128, 2, 0, 198, 0, 64, 1, 2, 0, 0, 0, 199, 1, 0, 2, 1, 0
    .byte 79, 0, 254, 92, 232, 0, 0, 99, 0, 9, 1, 2, 224, 97, 7, 1, 0, 0, 1, 0, 0, 254, 105, 92, 0, 86, 97, 0, 3, 2, 2, 128, 103, 1, 1, 0, 0, 3, 0, 0, 254, 100, 34, 0, 0, 101, 145, 0, 1, 1, 128, 127, 14, 1, 0, 0, 85, 0, 0, 17, 97, 135, 0, 171, 93, 51, 6, 3, 1, 146, 0, 2, 2, 0, 102, 5, 0, 128, 17, 101, 0, 0, 10, 0, 0, 0, 147, 127, 7, 2, 0, 121, 1, 0, 0, 17, 110, 6, 0, 0, 122, 147, 127, 1, 1, 0, 0, 13, 0, 0, 17, 104, 174, 0, 103, 100, 190, 3, 5, 1, 123, 0, 34, 2, 0, 0, 57, 0, 128, 203, 0, 0, 0, 42, 0, 0, 0, 7, 0, 98, 2, 0, 83, 1, 0, 128, 66, 0, 36, 0, 39, 0, 7, 0, 9, 0, 101, 1, 0, 1, 4, 0, 128, 75, 0, 39, 0, 101, 0, 9, 0, 126, 0, 101, 2, 0, 101, 4, 0, 128, 209, 109, 20, 0, 30, 0, 0, 0, 0, 1, 1, 0, 0, 208, 109, 20, 0, 205, 127, 0, 0, 1, 2, 192, 127, 4, 0, 128, 210, 110, 20, 0, 31, 0, 192, 127, 85, 0, 3, 2, 0, 115, 1, 0, 0, 213, 113, 32, 0, 0, 115, 0, 0, 1, 1, 128, 0, 2, 0, 128, 2, 0, 66, 0, 129, 0, 6, 0, 105, 0, 46, 2, 192, 127, 40, 2, 32, 125, 24, 0, 0, 2, 86, 138, 0, 32, 125, 6, 0, 24, 1, 100, 1, 51, 0, 128, 2, 0, 129, 0, 183, 0, 105, 0, 250, 127, 38, 2, 192, 123, 8, 0, 0, 11, 82, 64, 1, 128, 82, 0, 0, 4, 1, 6, 0, 61, 2, 37, 115, 14, 0, 0, 14, 46, 148, 0, 192, 127, 96, 133, 1, 2, 0, 0, 35, 2, 128, 82, 4, 0, 0, 13, 38, 182, 0, 192, 123, 85, 15, 8, 1, 96, 133, 1, 0, 128, 2, 0, 183, 0, 203, 0, 250, 127, 2, 0, 38, 1, 104, 0, 54, 0, 128, 209, 84, 89, 0, 92, 0, 0, 0, 11, 0, 22, 1, 0, 4, 1, 0, 0, 209, 37, 91, 0, 0, 124, 0, 0, 1, 1, 11, 0, 22, 2, 0, 125, 1, 0, 128, 209, 0, 86, 0, 90, 0, 16, 0, 0, 0, 13, 2, 0, 127, 3, 0, 0, 209, 84, 96, 0, 10, 0, 0, 4, 1, 2, 9, 0, 24, 1, 0, 2, 2, 0, 0, 209, 32, 99, 0, 0, 126, 9, 0, 2, 1, 0, 0, 25, 0, 128, 209, 0, 94, 0, 98, 0, 0, 0, 0, 0, 5, 2, 0, 127, 4, 0, 128, 209, 86, 106, 0, 111, 0, 0, 0, 8, 0, 27, 1, 0, 2, 3, 0, 0, 209, 26, 110, 0, 0, 126, 8, 0, 3, 1, 9, 0, 27, 2, 0, 122, 1, 0, 0, 209, 87, 118, 0, 0, 0, 0, 7, 1, 2, 7, 0, 31, 1, 170, 2, 3, 0, 0, 209, 19, 123, 0, 64, 126, 7, 0, 4, 1, 8, 0, 30, 2, 128, 124, 2, 0, 0, 204, 90, 177, 0, 192, 127, 0, 9, 1, 2, 0, 0, 3, 0, 0, 205, 84, 179, 0, 171, 127, 128, 4, 2, 2, 154, 127, 4, 1, 0, 9, 1, 0, 0, 205, 88, 161, 0, 205, 127, 0, 8, 2, 2, 192, 127, 3, 1, 0, 16, 1, 0, 0, 203, 93, 160, 0, 25, 0, 0, 16, 1, 2, 36, 0, 7, 2, 0, 120, 2, 0, 0, 205, 80, 163, 0, 192, 127, 0, 4, 4, 2, 171, 127, 4, 1, 0, 8, 2, 0, 0, 204, 93, 160, 0, 0, 119, 25, 0, 1, 1, 28, 0, 9, 0, 128, 206, 88, 152, 0, 161, 0, 214, 127, 205, 127, 5, 2, 0, 119, 1, 0, 128, 206, 80, 154, 0, 163, 0, 192, 127, 192, 127, 8, 0, 128, 197, 89, 150, 0, 156, 0, 204, 1, 102, 1, 5, 0, 0, 205, 94, 151, 0, 0, 124, 28, 0, 1, 1, 0, 0, 8, 0, 0, 206, 88, 152, 0, 128, 125, 214, 127, 2, 1, 0, 0, 4, 2, 0, 124, 1, 0, 0, 198, 91, 150, 0, 0, 0, 0, 2, 3, 1, 0, 4, 1, 2, 0, 0, 1, 0, 0, 207, 80, 154, 0, 128, 125, 192, 127, 2, 1, 192, 127, 6, 2, 128, 125, 2, 0, 0, 195, 89, 150, 0, 0, 0, 204, 1, 2, 1, 0, 2, 3, 2, 0, 127, 1, 0, 0, 10, 91, 170, 0, 192, 2, 224, 2, 4, 1, 0, 3, 4, 0, 0, 205, 95, 147, 0, 0, 125, 0, 0, 1, 1, 0, 0, 7, 2, 0, 125, 1, 0, 0, 206, 90, 147, 0, 0, 126, 0, 0, 1, 1, 205, 127, 4, 2, 0, 125, 1, 0, 0, 9, 92, 158, 0, 0, 0, 128, 0, 4, 2, 128, 127, 1, 1, 0, 1, 1, 0, 0, 207, 82, 149, 0, 128, 126, 192, 127, 2, 1, 220, 127, 6, 2, 0, 126, 1, 0, 0, 10, 91, 170, 0, 0, 122, 192, 2, 1, 1, 192, 2, 3, 2, 0, 122, 1, 0, 0, 11, 97, 158, 0, 0, 1, 0, 1, 1, 2, 0, 1, 3, 2, 0, 1, 1, 0, 128, 193, 92, 158, 0, 164, 0, 128, 0, 86, 127, 3, 2, 0, 126, 1, 0, 0, 196, 87, 145, 0, 128, 127, 241, 127, 4, 1, 0, 0, 4, 1, 0, 0, 5, 1, 64, 0, 4, 0, 0, 196, 84, 146, 0, 171, 127, 220, 127, 3, 1, 228, 127, 4, 2, 205, 127, 5, 0, 0, 13, 101, 162, 0, 0, 1, 0, 5, 1, 3, 192, 2, 192, 1, 4, 0, 0, 9, 92, 164, 0, 86, 127, 192, 2, 3, 1, 128, 2, 1, 2, 0, 120, 1, 0, 0, 165, 95, 162, 0, 0, 126, 128, 2, 1, 1, 128, 127, 1, 2, 0, 1, 1, 1, 0, 1, 1, 2, 0, 0, 2, 1, 0, 5, 1, 0, 128, 13, 102, 167, 0, 169, 0, 192, 1, 170, 3, 3, 2, 0, 122, 1, 0, 0, 197, 96, 175, 0, 0, 120, 128, 1, 1, 1, 0, 1, 2, 1, 0, 12, 1, 0, 0, 207, 114, 202, 0, 0, 119, 0, 127, 1, 1, 128, 126, 2, 0, 0, 12, 99, 169, 0, 0, 0, 0, 12, 1, 2, 205, 127, 2, 1, 170, 3, 3, 0, 128, 202, 92, 193, 0, 202, 0, 102, 0, 102, 0, 5, 0, 128, 207, 109, 195, 0, 204, 0, 171, 127, 154, 127, 5, 2, 0, 119, 1, 0, 128, 204, 97, 195, 0, 204, 0, 42, 0, 42, 0, 6, 0, 128, 7, 103, 196, 0, 205, 0, 214, 127, 214, 127, 6, 0, 0, 205, 113, 181, 0, 128, 126, 0, 6, 2, 3, 0, 6, 128, 126, 2, 0, 0, 200, 92, 193, 0, 0, 115, 102, 0, 1, 1, 128, 0, 4, 0, 0, 205, 108, 183, 0, 154, 127, 0, 12, 1, 2, 171, 127, 4, 1, 0, 6, 2, 0, 128, 202, 97, 182, 0, 195, 0, 42, 0, 42, 0, 6, 0, 128, 6, 103, 183, 0, 196, 0, 0, 0, 214, 127, 5, 1, 0, 12, 1, 0, 0, 205, 111, 172, 0, 171, 127, 128, 4, 2, 2, 128, 126, 1, 1, 0, 7, 1, 0, 0, 204, 107, 174, 0, 128, 127, 0, 9, 1, 2, 154, 127, 3, 1, 128, 4, 2, 0, 128, 201, 93, 173, 0, 180, 0, 64, 0, 128, 0, 4, 0, 0, 197, 101, 173, 0, 205, 127, 217, 127, 5, 1, 224, 127, 8, 0, 128, 202, 97, 174, 0, 182, 0, 0, 0, 42, 0, 5, 1, 0, 9, 1, 0, 0, 197, 93, 173, 0, 0, 0, 64, 0, 4, 2, 0, 0, 4, 1, 231, 127, 1, 2, 0, 0, 5, 2, 128, 127, 4, 0, 0, 5, 102, 174, 0, 0, 0, 0, 9, 1, 2, 0, 0, 4, 1, 0, 9, 1, 0, 128, 2, 0, 198, 0, 64, 1, 2, 0, 0, 0, 200, 0
    .byte 78, 0, 254, 93, 238, 0, 64, 98, 64, 98, 8, 0, 0, 254, 93, 228, 0, 110, 95, 128, 99, 7, 1, 0, 0, 1, 0, 0, 254, 105, 89, 0, 192, 105, 128, 2, 2, 2, 128, 104, 2, 1, 0, 0, 2, 0, 0, 254, 100, 30, 0, 0, 101, 148, 0, 1, 1, 128, 127, 6, 1, 0, 0, 93, 0, 0, 17, 97, 131, 0, 171, 93, 102, 6, 3, 1, 128, 0, 2, 2, 43, 106, 6, 0, 128, 17, 101, 0, 0, 6, 0, 0, 0, 128, 127, 8, 0, 128, 17, 111, 0, 0, 2, 0, 0, 0, 86, 127, 3, 0, 0, 17, 104, 171, 0, 214, 104, 210, 3, 6, 1, 128, 0, 33, 2, 0, 0, 57, 0, 128, 203, 0, 0, 0, 38, 0, 0, 0, 7, 0, 98, 2, 0, 87, 1, 0, 128, 66, 0, 32, 0, 35, 0, 10, 0, 9, 0, 101, 1, 153, 0, 5, 0, 128, 75, 0, 35, 0, 98, 0, 9, 0, 126, 0, 101, 2, 52, 106, 5, 0, 0, 209, 109, 27, 0, 0, 117, 0, 0, 1, 3, 0, 0, 0, 117, 1, 0, 0, 209, 110, 16, 0, 128, 127, 0, 0, 1, 2, 171, 127, 1, 1, 0, 0, 2, 0, 0, 210, 110, 27, 0, 0, 117, 64, 0, 1, 1, 171, 127, 3, 0, 128, 213, 114, 15, 0, 28, 0, 85, 0, 0, 0, 2, 2, 0, 116, 1, 0, 128, 2, 0, 62, 0, 128, 0, 6, 0, 102, 0, 45, 2, 194, 127, 41, 2, 41, 125, 25, 0, 0, 2, 86, 136, 0, 41, 125, 6, 0, 25, 1, 110, 1, 51, 0, 128, 2, 0, 128, 0, 182, 0, 102, 0, 0, 0, 37, 2, 128, 123, 8, 0, 0, 11, 82, 64, 1, 0, 82, 0, 0, 4, 1, 6, 0, 61, 2, 222, 115, 15, 0, 0, 14, 45, 146, 0, 194, 127, 112, 133, 1, 2, 0, 0, 36, 2, 0, 82, 4, 0, 0, 13, 37, 182, 0, 128, 123, 85, 15, 8, 1, 112, 133, 1, 0, 128, 2, 0, 182, 0, 203, 0, 0, 0, 2, 0, 37, 1, 102, 0, 55, 0, 128, 209, 84, 86, 0, 89, 0, 0, 0, 10, 0, 22, 1, 0, 2, 2, 0, 0, 209, 36, 88, 0, 0, 126, 0, 0, 2, 1, 11, 0, 22, 2, 0, 125, 1, 0, 128, 209, 0, 83, 0, 87, 0, 17, 0, 0, 0, 12, 2, 0, 127, 3, 0, 0, 209, 84, 93, 0, 10, 0, 0, 4, 1, 2, 9, 0, 24, 1, 0, 2, 2, 0, 0, 209, 32, 96, 0, 0, 126, 9, 0, 2, 1, 0, 0, 24, 2, 0, 123, 1, 0, 128, 209, 0, 91, 0, 95, 0, 0, 0, 0, 0, 5, 2, 171, 126, 3, 0, 128, 209, 86, 103, 0, 109, 0, 9, 0, 0, 0, 28, 1, 128, 2, 2, 0, 0, 209, 25, 107, 0, 86, 126, 8, 0, 3, 1, 0, 0, 28, 2, 0, 122, 1, 0, 0, 209, 87, 115, 0, 8, 0, 0, 8, 1, 2, 0, 0, 31, 1, 85, 2, 3, 0, 0, 209, 18, 121, 0, 64, 126, 7, 0, 4, 1, 0, 0, 31, 2, 0, 120, 1, 0, 0, 204, 89, 179, 0, 0, 0, 0, 10, 1, 2, 171, 127, 3, 0, 0, 205, 83, 181, 0, 171, 127, 128, 4, 2, 2, 205, 127, 4, 1, 0, 10, 1, 0, 128, 203, 93, 163, 0, 179, 0, 0, 0, 0, 0, 7, 2, 171, 122, 3, 0, 0, 205, 88, 163, 0, 0, 0, 0, 16, 1, 2, 0, 0, 4, 0, 0, 205, 79, 166, 0, 171, 127, 192, 3, 4, 2, 171, 127, 5, 1, 0, 16, 1, 0, 0, 204, 93, 163, 0, 0, 119, 0, 0, 1, 1, 0, 0, 9, 0, 128, 206, 88, 154, 0, 163, 0, 0, 0, 0, 0, 5, 2, 0, 119, 1, 0, 128, 206, 79, 156, 0, 166, 0, 200, 127, 171, 127, 9, 0, 128, 197, 89, 153, 0, 158, 0, 153, 1, 102, 1, 5, 0, 0, 205, 94, 154, 0, 0, 123, 0, 0, 1, 1, 32, 0, 8, 0, 0, 206, 88, 154, 0, 128, 125, 0, 0, 2, 1, 0, 0, 4, 2, 0, 123, 1, 0, 0, 198, 91, 152, 0, 128, 0, 64, 2, 2, 1, 170, 2, 2, 2, 0, 0, 1, 0, 0, 207, 79, 156, 0, 171, 126, 200, 127, 3, 1, 160, 127, 6, 2, 128, 125, 2, 0, 0, 195, 89, 153, 0, 128, 127, 153, 1, 2, 1, 64, 2, 3, 2, 0, 0, 1, 0, 0, 10, 91, 173, 0, 192, 2, 224, 2, 4, 1, 0, 3, 4, 0, 0, 205, 95, 149, 0, 0, 126, 32, 0, 1, 1, 0, 0, 7, 2, 0, 125, 1, 0, 0, 206, 90, 149, 0, 0, 126, 0, 0, 1, 1, 0, 0, 4, 2, 0, 126, 1, 0, 0, 9, 92, 161, 0, 205, 127, 128, 0, 4, 2, 128, 127, 1, 1, 0, 2, 1, 0, 0, 207, 82, 152, 0, 128, 126, 160, 127, 2, 1, 183, 127, 6, 2, 0, 126, 1, 0, 128, 10, 91, 167, 0, 173, 0, 192, 2, 192, 2, 4, 0, 0, 11, 97, 160, 0, 51, 1, 0, 2, 1, 2, 0, 1, 3, 2, 0, 1, 1, 0, 0, 193, 91, 167, 0, 0, 122, 128, 127, 1, 1, 128, 0, 3, 2, 0, 126, 1, 0, 0, 197, 86, 147, 0, 205, 127, 238, 127, 5, 1, 0, 0, 4, 1, 0, 0, 5, 0, 0, 197, 84, 149, 0, 0, 127, 183, 127, 2, 1, 0, 0, 5, 2, 0, 0, 5, 2, 0, 0, 8, 0, 0, 13, 101, 165, 0, 0, 1, 0, 5, 1, 3, 192, 2, 192, 1, 4, 0, 0, 9, 91, 167, 0, 128, 127, 192, 2, 4, 3, 128, 2, 0, 124, 2, 0, 0, 165, 95, 165, 0, 0, 126, 128, 2, 1, 1, 128, 127, 1, 2, 0, 1, 1, 1, 0, 1, 1, 2, 0, 0, 2, 1, 0, 5, 1, 0, 128, 13, 102, 170, 0, 172, 0, 192, 1, 170, 3, 3, 2, 0, 122, 1, 0, 0, 197, 95, 178, 0, 0, 124, 51, 1, 2, 1, 0, 1, 2, 1, 0, 12, 1, 0, 128, 207, 114, 196, 0, 205, 0, 0, 127, 128, 126, 2, 2, 0, 119, 1, 0, 0, 12, 99, 172, 0, 0, 0, 0, 12, 1, 2, 205, 127, 2, 1, 170, 3, 3, 0, 0, 202, 91, 205, 0, 0, 119, 102, 0, 1, 1, 102, 0, 4, 2, 0, 119, 1, 0, 0, 207, 109, 199, 0, 103, 127, 51, 1, 5, 0, 0, 204, 97, 198, 0, 42, 0, 170, 1, 6, 0, 0, 205, 112, 184, 0, 86, 127, 0, 6, 2, 2, 0, 127, 1, 1, 128, 5, 2, 0, 128, 200, 92, 184, 0, 196, 0, 102, 0, 102, 0, 5, 0, 0, 205, 108, 186, 0, 128, 127, 0, 13, 1, 2, 103, 127, 3, 1, 0, 6, 2, 0, 128, 202, 97, 186, 0, 198, 0, 51, 0, 42, 0, 5, 1, 0, 12, 1, 0, 0, 6, 102, 187, 0, 214, 127, 0, 12, 1, 2, 0, 0, 5, 1, 0, 13, 1, 0, 0, 205, 111, 176, 0, 86, 127, 0, 8, 1, 2, 86, 127, 2, 1, 0, 8, 1, 0, 0, 204, 106, 177, 0, 205, 127, 128, 4, 2, 2, 128, 127, 3, 1, 0, 8, 1, 0, 0, 201, 92, 184, 0, 0, 120, 102, 0, 1, 1, 85, 0, 3, 1, 0, 9, 1, 0, 0, 197, 93, 176, 0, 0, 0, 85, 0, 3, 2, 42, 0, 5, 1, 217, 127, 1, 2, 192, 127, 4, 2, 205, 127, 5, 2, 86, 127, 3, 0, 0, 202, 96, 177, 0, 42, 0, 0, 9, 1, 2, 51, 0, 5, 0, 128, 5, 102, 178, 0, 187, 0, 192, 127, 214, 127, 4, 1, 128, 4, 2, 0, 128, 2, 0, 198, 0, 64, 1, 3, 0, 0, 0, 200, 0



; FIXME! BROKEN!
;   .byte 0, 197, 108,   88, 0,   0, 0,   205, 127,   4,     1,    171, 127,   6,   0

; FIXME: put this somewhere else!
; polygon_data:
    .byte $00          ; polygon type  ($00 = single top free form, $80 = double top free form)
    .byte $01          ; polygon color
    .byte $14          ; y-start           (note: 20 = $14)
    .byte $5A, $00     ; x position (L, H) (note: 90 = $005A)
    .byte $92, $7F     ; x1 incr (L, H)    (note: -100 = $FF92)
    .byte $7C, $01     ; x2 incr (L, H)    (note: 380 = $017C)
    .byte $96          ; nr of lines       (note: 150 = $96)
    .byte $02          ; next step     ($00 = stop, $01 = left incr change, $02 = right incr change, $03 = both left and right incr change)
    .byte $CA, $79     ; x2 incr (L, H)    (note: -1590 = $F9CA)
    .byte $32          ; nr of lines       (note: 50 = $32)
    .byte $00          ; next step     ($00 = stop, $01 = left incr change, $02 = right incr change, $03 = both left and right incr change)
    
    .byte $80          ; polygon type  ($00 = single top free form, $80 = double top free form)
    .byte $02          ; polygon color
    .byte $40          ; y-start           (note: 64 = $40)
    .byte $9B, $00     ; x1 position (L, H) (note: 155 = $009B)
    .byte $2C, $01     ; x2 position (L, H) (note: 300 = $012C)
    .byte $7C, $01     ; x1 incr (L, H)    (note: 380 = $017C)
    .byte $92, $7F     ; x2 incr (L, H)    (note: -100 = $FF92)
    .byte $4B          ; nr of lines       (note: 75 = $4B)
    .byte $00          ; next step     ($00 = stop, $01 = left incr change, $02 = right incr change, $03 = both left and right incr change)

    

setup_polygon_filler:

    lda #%00000101           ; DCSEL=2, ADDRSEL=1
    sta VERA_CTRL
    
    .if(USE_JUMP_TABLE)
        lda #%00110000           ; ADDR1 increment: +4 byte
    .else
        lda #%00010000           ; ADDR1 increment: +1 byte
    .endif
    sta VERA_ADDR_BANK

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
   
    lda #%11100000           ; ADDR0 increment: +320 bytes
    sta VERA_ADDR_BANK

    lda #%00000010           ; Entering *polygon filler mode*
    .if(USE_JUMP_TABLE)
        ora #%01000000           ; cache write enabled = 1
    .endif
    sta VERA_FX_CTRL
    
    rts
    
unset_polygon_filler:

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
   
    lda #%00010000           ; ADDR0 increment: +1 bytes
    sta VERA_ADDR_BANK

    lda #%00000000           ; Exiting *polygon filler mode*
    sta VERA_FX_CTRL

    rts

setup_polygon_data_address:

    lda #<polygon_data
    sta LOAD_ADDRESS
    lda #>polygon_data
    sta LOAD_ADDRESS+1
    
    rts
    
    
    
; FIXME: make this test_draw_polygon*S*_fast!
test_draw_polygon_fast:

    ldy #0
    
    ; -- Polygon type --
    lda (LOAD_ADDRESS), y
    sta TMP_POLYGON_TYPE
   
; FIXME: we need an FRAME-END code!!
; FIXME: we need an FRAME-END code!!
; FIXME: we need an FRAME-END code!!

; FIXME: technically this name is INCORRECT, since we are MIXING single and double top draws!
single_top_free_form:
; FIXME: this iny should be moved up when we have an actual jump table!
    iny
    
    ; -- Polygon color --
    
    .if(USE_JUMP_TABLE)
        ; We first need to fill the 32-bit cache with 4 times our color
        
        lda #%00001100           ; DCSEL=6, ADDRSEL=0
        sta VERA_CTRL

        lda (LOAD_ADDRESS), y
        iny
; FIXME: we can SPEED this up  if we use the alternative cache incrementer! (only 2 bytes need to be set then)
        sta VERA_FX_CACHE_L      ; cache32[7:0]
        sta VERA_FX_CACHE_M      ; cache32[15:8]
        sta VERA_FX_CACHE_H      ; cache32[23:16]
        sta VERA_FX_CACHE_U      ; cache32[31:24]
    .else
        lda (LOAD_ADDRESS), y
        iny
        ; We put it into a ZP when drawing slowly
        sta TMP_COLOR
    .endif
    
    ; -- Y-start --
    lda (LOAD_ADDRESS), y
    iny
; FIXME: expensive!?
    tax
; FIXME: how do we do DOUBLE BUFFERING here? (two sets of generated code??)
    lda Y_TO_ADDRESS_LOW, x
    sta VERA_ADDR_LOW
    lda Y_TO_ADDRESS_HIGH, x
    sta VERA_ADDR_HIGH
    lda Y_TO_ADDRESS_BANK, x
    sta VERA_ADDR_BANK

    lda #%00001000           ; DCSEL=4, ADDRSEL=0
    sta VERA_CTRL
    
; FIXME: we are MIXING single and double top drawing, so we use TMP_POLYGON_TYPE here for now!
    lda TMP_POLYGON_TYPE
    bmi set_double_x_positions
    
set_single_x_positions:
    ; -- X-position LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_POS_L
    sta VERA_FX_Y_POS_L
    
    ; -- X-position HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_POS_H
    sta VERA_FX_Y_POS_H
    
    bra done_with_x_positions
    
set_double_x_positions:
    ; -- X1-position LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_POS_L
    
    ; -- X1-position HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_POS_H

    ; -- X2-position LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_Y_POS_L
    
    ; -- X2-position HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_Y_POS_H
    
done_with_x_positions:

    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    ; -- X1 incr LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_INCR_L

    ; -- X1 incr HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_INCR_H
    
    ; -- X2 incr LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_Y_INCR_L

    ; -- X2 incr HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_Y_INCR_H
    
    .if(USE_JUMP_TABLE)
        ; -- nr of lines --
        lda (LOAD_ADDRESS), y
        iny
        
        phy   ; backup y (byte offset into data)
        
        tay   ; put nr-of-lines into y register
        
        lda VERA_DATA1   ; this will increment x1 and x2 and the fill_length value will be calculated (= x2 - x1). Also: ADDR1 will be updated with ADDR0 + x1

        lda #%00001010           ; DCSEL=5, ADDRSEL=0
        sta VERA_CTRL
        ldx VERA_FX_POLY_FILL_L  ; This contains: FILL_LENGTH >= 16, X1[1:0], FILL_LENGTH[3:0], 0
    
        jsr draw_polygon_part_using_polygon_filler_and_jump_tables

        ply   ; restore y (byte offset into data)
    .else
        ; -- nr of lines --
        lda (LOAD_ADDRESS), y
        iny
        sta NUMBER_OF_ROWS

        phy
    ; FIXME: temp solution for color!
        ldy TMP_COLOR
        jsr draw_polygon_part_using_polygon_filler_slow
        ply
    .endif
    
    
draw_next_part:
    
    ; -- next step code --
    lda (LOAD_ADDRESS), y
    sta NEXT_STEP
    beq done_drawing_polygon
    iny
    
    ; We know we have to either change the left or right increment (or both) so we need to set the appropiate DCSEL
    ldx #%00000110           ; DCSEL=3, ADDRSEL=0
    stx VERA_CTRL
    
    and #$01   ; bit 0 determines if we have to change the left increment
    beq left_increment_is_ok
    
    ; we (at least) have to change the left increment
    
    ; -- X1 incr LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_INCR_L

    ; -- X1 incr HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_X_INCR_H
    
left_increment_is_ok:
    
    lda NEXT_STEP
    and #$02   ; bit 1 determines if we have to change the right increment
    beq right_increment_is_ok
    
    ; we have to change the right increment

    ; -- X2 incr LOW --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_Y_INCR_L

    ; -- X2 incr HIGH --
    lda (LOAD_ADDRESS), y
    iny
    sta VERA_FX_Y_INCR_H

right_increment_is_ok:
    
    .if(USE_JUMP_TABLE)
        ; -- nr of lines --
        lda (LOAD_ADDRESS), y
        iny
        
        phy   ; backup y (byte offset into data)
        
        tay   ; put nr-of-lines into y register
        
        lda VERA_DATA1   ; this will increment x1 and x2 and the fill_length value will be calculated (= x2 - x1). Also: ADDR1 will be updated with ADDR0 + x1

        lda #%00001010           ; DCSEL=5, ADDRSEL=0
        sta VERA_CTRL
        ldx VERA_FX_POLY_FILL_L  ; This contains: FILL_LENGTH >= 16, X1[1:0], FILL_LENGTH[3:0], 0
    
        jsr draw_polygon_part_using_polygon_filler_and_jump_tables

        ply   ; restore y (byte offset into data)
    .else
        ; -- nr of lines --
        lda (LOAD_ADDRESS), y
        iny
        sta NUMBER_OF_ROWS

        phy
    ; FIXME: temp solution for color!
        ldy TMP_COLOR
        jsr draw_polygon_part_using_polygon_filler_slow
        ply
    .endif
    
    bra draw_next_part
    
    

done_drawing_polygon:
    iny   ; We can only get here from one place, and there we still hadnt incremented y yet
    
    rts
    
    
draw_polygon_part_using_polygon_filler_and_jump_tables:
    jmp (FILL_LINE_START_JUMP,x)
    
    
; Routine to draw a triangle part
draw_polygon_part_using_polygon_filler_slow:

    lda #%00001010        ; DCSEL=5, ADDRSEL=0
    sta VERA_CTRL

polygon_fill_triangle_row_next:

    lda VERA_DATA1   ; This will do three things (inside of VERA): 
                     ;   1) Increment the X1 and X2 positions. 
                     ;   2) Calculate the fill_length value (= x2 - x1)
                     ;   3) Set ADDR1 to ADDR0 + X1

    ; What we do below is SLOW: we are not using all the information 
    ; we get here and are *only* reconstructing the 10-bit value.
    
    lda VERA_FX_POLY_FILL_L ; This contains: FILL_LENGTH >= 16, X1[1:0],
                          ;                FILL_LENGTH[3:0], 0
    lsr
    and #%00000111        ; We keep the 3 lower bits (note that bit 3 is ALSO in the HIGH byte, so we discard it)
                          
    sta FILL_LENGTH_LOW   ; We now have 3 bits in FILL_LENGTH_LOW

    stz FILL_LENGTH_HIGH
    lda VERA_FX_POLY_FILL_H ; This contains: FILL_LENGTH[9:3], 0
    asl
    rol FILL_LENGTH_HIGH
    asl
    rol FILL_LENGTH_HIGH  ; FILL_LENGTH_HIGH now contains the two highest bits: 8 and 9
                            
    ora FILL_LENGTH_LOW
    sta FILL_LENGTH_LOW   ; FILL_LENGTH_LOW now contains all lower 8 bits
                           

    tax
    beq done_fill_triangle_pixel  ; If x = 0, we dont have to draw any pixels
                                   
polygon_fill_triangle_pixel_next:
    sty VERA_DATA1        ; This draws a single pixel
    dex
    bne polygon_fill_triangle_pixel_next
    
done_fill_triangle_pixel:

    ; We draw an additional FILL_LENGTH_HIGH * 256 pixels on this row
    lda FILL_LENGTH_HIGH
    beq polygon_fill_triangle_row_done

polygon_fill_triangle_pixel_next_256:
    ldx #0
polygon_fill_triangle_pixel_next_256_0:
    sty VERA_DATA1
    dex
    bne polygon_fill_triangle_pixel_next_256_0
    dec FILL_LENGTH_HIGH
    bne polygon_fill_triangle_pixel_next_256
    
polygon_fill_triangle_row_done:

    ; We always increment ADDR0
    lda VERA_DATA0   ; this will increment ADDR0 with 320 bytes
                     ; So +1 vertically
    
    ; We check if we have reached the end, and if so we stop
    dec NUMBER_OF_ROWS
    bne polygon_fill_triangle_row_next
    
    rts

    
    
    
generate_y_to_address_table:

; FIXME: for now, we assume the base address is 0 here!
; FIXME: this does not take into account DOUBLE BUFFERING yet!
    stz VRAM_ADDRESS
    stz VRAM_ADDRESS+1
    stz VRAM_ADDRESS+2

    ; First entry
    ldy #0
    lda VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW, y
    lda VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH, y
    lda VRAM_ADDRESS+2
    ora #%11100000           ; +320 byte increment (=%1110)
    sta Y_TO_ADDRESS_BANK, y

    ; Entries 1-255
    ldy #1
generate_next_y_to_address_entry:
    clc
    lda VRAM_ADDRESS
    adc #<320
    sta VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW, y

    lda VRAM_ADDRESS+1
    adc #>320
    sta VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH, y

    lda VRAM_ADDRESS+2
    adc #0
    sta VRAM_ADDRESS+2
    ora #%11100000           ; +320 byte increment (=%1110)
    sta Y_TO_ADDRESS_BANK, y

    iny
    bne generate_next_y_to_address_entry

    rts
    


setup_vera_for_layer0_bitmap_general:

    lda #$40                 ; 2:1 scale (320 x 240 pixels on screen)
    sta VERA_DC_HSCALE
    sta VERA_DC_VSCALE
    
    ; -- Setup Layer 0 --
    
    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL
    
    ; Enable bitmap mode and color depth = 8bpp on layer 0
    lda #(4+3)
    sta VERA_L0_CONFIG

    rts
    
    
; FIXME: this can be done more efficiantly!    
setup_vera_for_layer0_bitmap_buffer_0:

    lda VERA_DC_VIDEO
    ora #%00010000           ; Enable Layer 0
    and #%10011111           ; Disable Layer 1 and sprites
    sta VERA_DC_VIDEO

    ; -- Setup Layer 0 --
    
    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL
    
    ; Set layer0 tilebase to 0x00000 and tile width to 320 px
    lda #0
    sta VERA_L0_TILEBASE

    ; Setting VSTART/VSTOP so that we have 200 rows on screen (320x200 pixels on screen)

    lda #%00000010  ; DCSEL=1
    sta VERA_CTRL
   
    lda #20
    sta VERA_DC_VSTART
    lda #400/2+20-1
    sta VERA_DC_VSTOP
    
    rts
    
; FIXME: this can be done more efficiantly!    
setup_vera_for_layer0_bitmap_buffer_1:

    lda VERA_DC_VIDEO
    ora #%01010000           ; Enable Layer 0 and sprites
    and #%11011111           ; Disable Layer 1
    sta VERA_DC_VIDEO

    ; -- Setup Layer 0 --
    
    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL
    
    ; Buffer 1 starts at: (320*200-512) = 31*2048
    
    ; Set layer0 tilebase to 0x0F800 and tile width to 320 px
    lda #(31<<2)
    sta VERA_L0_TILEBASE

    ; Setting VSTART/VSTOP so that we have 202 rows on screen (320x200 pixels on screen)

    lda #%00000010  ; DCSEL=1
    sta VERA_CTRL
   
    lda #20-2  ; we show 2 lines of 'garbage' so the *actual* bitmap starts at 31*2048 + 640  (128 bytes after the *first* buffer ends)
    ; Note: we cover these 2 garbage-lines with five 64x64 black sprites (of which only the two last lines are actually black and have their sprite data pointed to the 128 bytes mentioned above)
    sta VERA_DC_VSTART
    lda #400/2+20-1
    sta VERA_DC_VSTOP
    
    rts

    

clear_vram_slow:

    lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    lda #0
    sta VERA_ADDR_LOW
    lda #0
    sta VERA_ADDR_HIGH

    ; FIXME: PERFORMANCE we can do this MUCH faster using CACHE writes and UNROLLING!
    
    ; We need 320*400 + 128 = 128128 bytes to be cleared
    ; This means we need 501*256 bytes to be cleared (501 = 256+245)

    lda #BACKGROUND_COLOR
    
    ; First 256*256 bytes
    ldy #0
clear_bitmap_next_256:
    ldx #0
clear_bitmap_next_1:
    sta VERA_DATA0
    inx
    bne clear_bitmap_next_1
    dey
    bne clear_bitmap_next_256

    ldy #245
clear_bitmap_next_256a:
    ldx #0
clear_bitmap_next_1a:
    sta VERA_DATA0
    inx
    bne clear_bitmap_next_1a
    dey
    bne clear_bitmap_next_256a
    
    rts

    

copy_palette_from_index_0:

    ; Starting at palette VRAM address
    
    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    ; We start at color index 0 of the palette (we preserve the first 16 default VERA colors)
    lda #<(VERA_PALETTE)
    sta VERA_ADDR_LOW
    lda #>(VERA_PALETTE)
    sta VERA_ADDR_HIGH

    ; HACK: we know we have more than 128 colors to copy (meaning: > 256 bytes), so we are just going to copy 128 colors first
    
    ldy #0
next_packed_color_256:
    lda palette_data, y
    sta VERA_DATA0
    iny
    bne next_packed_color_256

    ldy #0
next_packed_color_1:
    lda palette_data+256, y
    sta VERA_DATA0
    iny
    ; TODO: remove this? we are now assuming all 256 colors need to be copied!
    ;    cpy #<(end_of_palette_data-palette_data)
    bne next_packed_color_1
    
    rts
    
    
add_code_byte:
    sta (CODE_ADDRESS),y   ; store code byte at address (located at CODE_ADDRESS) + y
    iny                    ; increase y
    cpy #0                 ; if y == 0
    bne done_adding_code_byte
    inc CODE_ADDRESS+1     ; increment high-byte of CODE_ADDRESS
done_adding_code_byte:
    rts


    .include "fx_polygon_fill_jump_tables.s"
    .include "fx_polygon_fill_jump_tables_8bit.s"


palette_data:
  .byte $00, $00
  .byte $33, $04
  .byte $33, $04
  .byte $33, $04
  .byte $33, $04
  .byte $44, $05
  .byte $44, $05
  .byte $55, $06
  .byte $55, $06
  .byte $55, $06
  .byte $66, $07
  .byte $66, $07
  .byte $77, $08
  .byte $77, $08
  .byte $88, $09
  .byte $88, $09
  .byte $99, $09
  .byte $99, $09
  .byte $aa, $0a
  .byte $aa, $0a
  .byte $aa, $0a
  .byte $bb, $0b
  .byte $bb, $0b
  .byte $cc, $0c
  .byte $cc, $0c
  .byte $dd, $0d
  .byte $dd, $0d
  .byte $dd, $0d
  .byte $ee, $0e
  .byte $ee, $0e
  .byte $ff, $0f
  .byte $ff, $0f
  .byte $32, $02
  .byte $32, $02
  .byte $42, $02
  .byte $43, $03
  .byte $43, $03
  .byte $53, $03
  .byte $53, $03
  .byte $53, $03
  .byte $64, $03
  .byte $64, $04
  .byte $64, $04
  .byte $74, $04
  .byte $74, $04
  .byte $74, $04
  .byte $85, $04
  .byte $85, $04
  .byte $85, $04
  .byte $95, $05
  .byte $95, $05
  .byte $95, $05
  .byte $a5, $05
  .byte $a5, $05
  .byte $a5, $05
  .byte $b6, $05
  .byte $b6, $05
  .byte $b6, $05
  .byte $c6, $05
  .byte $c6, $05
  .byte $c6, $05
  .byte $d6, $05
  .byte $d6, $05
  .byte $d7, $05
  .byte $33, $02
  .byte $33, $02
  .byte $43, $03
  .byte $44, $03
  .byte $44, $03
  .byte $55, $04
  .byte $55, $04
  .byte $55, $04
  .byte $66, $04
  .byte $66, $05
  .byte $67, $05
  .byte $67, $05
  .byte $77, $05
  .byte $78, $06
  .byte $78, $06
  .byte $79, $06
  .byte $79, $06
  .byte $79, $07
  .byte $7a, $07
  .byte $8a, $07
  .byte $8a, $08
  .byte $8b, $08
  .byte $8b, $08
  .byte $9c, $09
  .byte $9c, $09
  .byte $9d, $0a
  .byte $ad, $0a
  .byte $ad, $0a
  .byte $ae, $0b
  .byte $ae, $0b
  .byte $bf, $0c
  .byte $bf, $0c
  .byte $46, $03
  .byte $56, $03
  .byte $56, $03
  .byte $57, $03
  .byte $57, $04
  .byte $57, $04
  .byte $67, $04
  .byte $68, $04
  .byte $68, $05
  .byte $68, $05
  .byte $78, $05
  .byte $79, $05
  .byte $79, $06
  .byte $89, $06
  .byte $89, $06
  .byte $8a, $07
  .byte $8a, $07
  .byte $9a, $07
  .byte $9a, $08
  .byte $9a, $08
  .byte $ab, $09
  .byte $ab, $09
  .byte $ab, $09
  .byte $ab, $0a
  .byte $bc, $0a
  .byte $bc, $0a
  .byte $bc, $0b
  .byte $cc, $0b
  .byte $cd, $0c
  .byte $dd, $0c
  .byte $dd, $0d
  .byte $de, $0d
  .byte $34, $03
  .byte $34, $03
  .byte $44, $04
  .byte $45, $04
  .byte $45, $05
  .byte $55, $05
  .byte $56, $05
  .byte $56, $06
  .byte $56, $06
  .byte $67, $06
  .byte $67, $07
  .byte $67, $07
  .byte $78, $08
  .byte $78, $08
  .byte $78, $08
  .byte $89, $09
  .byte $89, $09
  .byte $99, $0a
  .byte $9a, $0a
  .byte $9a, $0a
  .byte $aa, $0a
  .byte $aa, $0b
  .byte $aa, $0b
  .byte $ab, $0c
  .byte $bb, $0c
  .byte $bb, $0c
  .byte $bb, $0d
  .byte $cc, $0d
  .byte $cc, $0d
  .byte $dd, $0e
  .byte $dd, $0e
  .byte $ed, $0f
  .byte $40, $0a
  .byte $40, $0a
  .byte $50, $0a
  .byte $50, $0a
  .byte $50, $0a
  .byte $60, $0b
  .byte $60, $0b
  .byte $60, $0b
  .byte $70, $0b
  .byte $70, $0c
  .byte $80, $0c
  .byte $80, $0c
  .byte $90, $0c
  .byte $90, $0c
  .byte $90, $0d
  .byte $a0, $0d
  .byte $a0, $0d
  .byte $b0, $0d
  .byte $b0, $0d
  .byte $c0, $0e
  .byte $c0, $0e
  .byte $d0, $0e
  .byte $d0, $0e
  .byte $e0, $0f
  .byte $e0, $0f
  .byte $f0, $0f
  .byte $f2, $0f
  .byte $f5, $0f
  .byte $f7, $0f
  .byte $fa, $0f
  .byte $fc, $0f
  .byte $ff, $0f
  .byte $34, $03
  .byte $44, $04
  .byte $44, $04
  .byte $45, $04
  .byte $55, $05
  .byte $56, $05
  .byte $56, $05
  .byte $67, $06
  .byte $67, $06
  .byte $77, $06
  .byte $78, $07
  .byte $78, $07
  .byte $89, $07
  .byte $89, $08
  .byte $8a, $08
  .byte $9a, $08
  .byte $9a, $09
  .byte $ab, $09
  .byte $ab, $09
  .byte $ac, $0a
  .byte $ac, $0a
  .byte $bd, $0a
  .byte $bd, $0a
  .byte $be, $0b
  .byte $ce, $0b
  .byte $cf, $0b
  .byte $df, $0b
  .byte $df, $0c
  .byte $ef, $0d
  .byte $ef, $0d
  .byte $ef, $0e
  .byte $ff, $0f
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $b5, $0e
  .byte $00, $00
  .byte $b5, $0e
end_of_palette_data: