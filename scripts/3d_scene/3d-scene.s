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


start:

    sei
    
    jsr setup_vera_for_layer0_bitmap
    
    ; FIXME: REMOVE! jsr change_palette_color
    jsr copy_palette_from_index_0
    jsr clear_screen_slow
    
    jsr generate_y_to_address_table
    
    jsr setup_polygon_filler
    jsr setup_polygon_data_address
    
; FIXME: UGLY HACK: fixed amount of polygons!
    lda #105
;    lda #86
; FIXME: nr 86 is BROKEN!
; FIXME: nr 86 is BROKEN!
; FIXME: nr 86 is BROKEN!
;    lda #21
;    lda #92
    sta NR_OF_POLYGONS
    
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


    jsr unset_polygon_filler
    
    
    ; We are not returning to BASIC here...
infinite_loop:
    jmp infinite_loop
    
    rts
    
    
polygon_data:
    .byte 0, 254, 23, 64, 1, 23, 114, 52, 115, 23, 1, 0, 0, 2, 0
    .byte 0, 254, 20, 64, 1, 52, 115, 178, 115, 25, 1, 0, 0, 1, 0
    .byte 0, 254, 43, 52, 0, 79, 0, 103, 1, 62, 2, 200, 120, 9, 0
    .byte 0, 254, 77, 64, 1, 187, 120, 0, 0, 19, 2, 187, 120, 25, 1, 0, 0, 19, 0
    .byte 0, 254, 117, 157, 0, 103, 121, 111, 1, 10, 1, 217, 0, 73, 0
    .byte 0, 17, 34, 64, 1, 0, 101, 0, 0, 10, 1, 94, 1, 36, 2, 227, 120, 26, 0
    .byte 0, 17, 20, 64, 1, 0, 108, 52, 115, 16, 1, 0, 0, 9, 0
    .byte 0, 17, 94, 64, 1, 93, 121, 0, 0, 25, 1, 97, 1, 81, 0
    .byte 0, 35, 128, 98, 0, 21, 0, 234, 0, 72, 0
    .byte 128, 140, 0, 22, 0, 64, 1, 205, 125, 0, 0, 10, 1, 0, 0, 10, 2, 171, 114, 24, 0
    .byte 128, 67, 0, 62, 0, 82, 0, 23, 0, 17, 0, 44, 1, 137, 1, 13, 0
    .byte 128, 76, 0, 82, 0, 132, 0, 17, 0, 9, 0, 52, 2, 103, 118, 5, 0
    .byte 128, 205, 0, 156, 0, 15, 1, 8, 0, 249, 127, 65, 2, 0, 123, 22, 0
    .byte 128, 195, 0, 128, 0, 156, 0, 10, 0, 8, 0, 73, 1, 0, 2, 14, 0
    .byte 128, 78, 0, 0, 0, 38, 0, 0, 0, 25, 0, 89, 2, 106, 126, 1, 1, 9, 0, 28, 0
    .byte 0, 206, 5, 83, 0, 205, 127, 128, 3, 2, 2, 192, 127, 3, 1, 0, 7, 1, 0
    .byte 0, 207, 2, 84, 0, 171, 127, 85, 2, 3, 3, 128, 3, 128, 127, 2, 0
    .byte 128, 207, 0, 86, 0, 89, 0, 0, 127, 0, 2, 2, 3, 85, 2, 86, 127, 3, 0
    .byte 128, 207, 0, 73, 0, 78, 0, 128, 127, 0, 3, 2, 3, 170, 3, 171, 127, 3, 0
    .byte 128, 207, 0, 78, 0, 86, 0, 0, 3, 0, 127, 2, 0
    .byte 0, 207, 22, 109, 0, 0, 127, 0, 127, 2, 3, 0, 125, 0, 125, 1, 0
    .byte 0, 7, 20, 110, 0, 0, 126, 128, 127, 1, 1, 171, 127, 1, 2, 0, 127, 2, 0
    .byte 0, 206, 2, 72, 0, 183, 127, 170, 3, 3, 2, 192, 124, 4, 0
    .byte 128, 206, 17, 108, 0, 110, 0, 0, 0, 0, 0, 3, 2, 0, 126, 1, 0
    .byte 0, 205, 14, 107, 0, 85, 0, 0, 3, 1, 2, 0, 0, 2, 0
    .byte 0, 207, 1, 66, 0, 183, 127, 0, 6, 1, 2, 183, 127, 6, 1, 0, 6, 1, 0
    .byte 0, 11, 4, 80, 0, 85, 1, 109, 1, 6, 1, 128, 1, 1, 2, 85, 1, 3, 0
    .byte 0, 207, 0, 73, 0, 0, 121, 128, 127, 1, 1, 0, 6, 1, 0
    .byte 0, 207, 24, 107, 0, 0, 122, 0, 125, 1, 3, 0, 127, 0, 126, 3, 0
    .byte 128, 7, 21, 103, 0, 108, 0, 128, 127, 171, 127, 3, 2, 0, 122, 1, 0
    .byte 128, 206, 17, 103, 0, 108, 0, 0, 0, 0, 0, 4, 0
    .byte 0, 205, 13, 103, 0, 0, 0, 0, 4, 1, 2, 85, 0, 3, 0
    .byte 128, 200, 0, 68, 0, 71, 0, 192, 0, 192, 0, 4, 0
    .byte 0, 207, 1, 66, 0, 0, 125, 183, 127, 1, 1, 171, 127, 6, 0
    .byte 0, 196, 2, 72, 0, 0, 2, 0, 4, 1, 2, 0, 4, 1, 0
    .byte 128, 199, 0, 66, 0, 67, 0, 0, 127, 204, 0, 1, 1, 128, 1, 4, 0
    .byte 128, 207, 0, 63, 0, 66, 0, 0, 0, 0, 0, 1, 2, 0, 125, 1, 0
    .byte 0, 199, 0, 68, 0, 192, 0, 192, 0, 4, 0
    .byte 128, 11, 4, 76, 0, 80, 0, 85, 1, 85, 1, 6, 0
    .byte 0, 206, 27, 92, 0, 0, 126, 0, 6, 1, 3, 0, 6, 0, 126, 1, 0
    .byte 0, 207, 24, 95, 0, 0, 127, 0, 6, 1, 2, 0, 127, 2, 1, 0, 6, 1, 0
    .byte 0, 9, 2, 72, 0, 128, 127, 64, 0, 4, 3, 0, 1, 128, 127, 2, 0
    .byte 0, 10, 6, 70, 0, 153, 0, 0, 1, 2, 2, 128, 0, 2, 2, 0, 0, 1, 0
    .byte 0, 196, 2, 72, 0, 64, 0, 0, 2, 2, 2, 86, 127, 2, 1, 0, 1, 1, 0
    .byte 128, 7, 21, 97, 0, 103, 0, 86, 127, 128, 127, 3, 1, 0, 6, 1, 0
    .byte 128, 207, 2, 61, 0, 63, 0, 214, 127, 171, 127, 6, 0
    .byte 0, 206, 16, 97, 0, 0, 0, 0, 6, 1, 2, 0, 0, 4, 0
    .byte 0, 12, 10, 73, 0, 0, 0, 0, 1, 1, 1, 85, 1, 2, 2, 64, 1, 4, 0
    .byte 0, 205, 12, 97, 0, 0, 0, 0, 6, 1, 2, 0, 0, 3, 1, 0, 6, 1, 0
    .byte 0, 207, 0, 63, 0, 0, 127, 0, 127, 2, 0
    .byte 0, 11, 4, 76, 0, 86, 127, 85, 1, 3, 1, 0, 2, 2, 1, 0, 6, 1, 0
    .byte 128, 13, 13, 76, 0, 78, 0, 64, 1, 102, 1, 4, 1, 0, 4, 1, 0
    .byte 0, 166, 6, 73, 0, 128, 127, 0, 1, 1, 2, 0, 2, 1, 1, 128, 0, 1, 2, 128, 0, 1, 1, 0, 1, 1, 2, 128, 127, 2, 0
    .byte 0, 201, 9, 78, 0, 128, 0, 0, 6, 1, 2, 192, 0, 1, 1, 170, 2, 3, 0
    .byte 0, 13, 11, 79, 0, 128, 127, 170, 2, 2, 1, 102, 1, 1, 2, 128, 127, 4, 0
    .byte 0, 205, 24, 85, 0, 0, 125, 85, 2, 1, 1, 170, 2, 2, 2, 0, 126, 1, 0
    .byte 0, 198, 0, 62, 0, 0, 127, 154, 127, 2, 1, 0, 0, 3, 0
    .byte 0, 198, 0, 62, 0, 192, 127, 192, 127, 8, 0
    .byte 0, 198, 0, 61, 0, 128, 127, 128, 127, 2, 0
    .byte 0, 198, 0, 62, 0, 128, 127, 128, 127, 2, 0
    .byte 0, 206, 21, 87, 0, 86, 127, 170, 2, 3, 3, 85, 2, 0, 127, 3, 0
    .byte 0, 7, 18, 89, 0, 86, 127, 170, 2, 3, 3, 170, 2, 86, 127, 3, 0
    .byte 0, 205, 14, 89, 0, 0, 0, 0, 4, 2, 2, 0, 0, 2, 1, 170, 2, 3, 0
    .byte 0, 204, 10, 89, 0, 0, 0, 0, 4, 2, 2, 0, 0, 2, 1, 0, 4, 2, 0
    .byte 0, 205, 21, 79, 0, 128, 127, 0, 2, 2, 1, 0, 2, 1, 2, 0, 125, 1, 0
    .byte 0, 205, 19, 81, 0, 0, 127, 0, 3, 2, 3, 0, 2, 86, 127, 3, 0
    .byte 0, 6, 15, 83, 0, 128, 127, 0, 2, 3, 2, 86, 127, 1, 1, 0, 3, 2, 0
    .byte 0, 199, 9, 83, 0, 214, 127, 0, 0, 3, 2, 0, 0, 3, 3, 128, 127, 128, 127, 4, 2, 0, 127, 2, 2, 128, 127, 2, 0
    .byte 0, 205, 12, 83, 0, 0, 0, 0, 3, 2, 2, 0, 0, 1, 1, 0, 2, 3, 0
    .byte 0, 204, 9, 83, 0, 0, 0, 0, 6, 1, 2, 0, 0, 2, 1, 0, 3, 2, 0
    .byte 0, 45, 51, 74, 0, 0, 127, 61, 0, 26, 1, 0, 11, 3, 0
    .byte 0, 33, 31, 48, 0, 217, 126, 245, 126, 13, 1, 26, 127, 10, 0
    .byte 0, 47, 51, 74, 0, 32, 126, 0, 127, 16, 1, 102, 0, 10, 0
    .byte 0, 44, 31, 48, 0, 228, 127, 76, 1, 20, 2, 32, 126, 16, 0
    .byte 0, 45, 31, 48, 0, 26, 125, 228, 127, 10, 1, 246, 0, 26, 0
    .byte 0, 39, 35, 6, 0, 200, 0, 182, 7, 7, 2, 43, 127, 30, 0
    .byte 0, 36, 42, 60, 0, 43, 127, 42, 1, 24, 2, 43, 119, 6, 0
    .byte 0, 44, 116, 102, 0, 0, 112, 134, 127, 4, 1, 19, 1, 40, 0
    .byte 0, 42, 120, 38, 0, 108, 0, 19, 1, 40, 2, 64, 126, 12, 0
    .byte 0, 40, 35, 6, 0, 176, 127, 200, 0, 19, 1, 0, 0, 14, 1, 192, 8, 4, 0
    .byte 0, 38, 66, 88, 0, 43, 119, 26, 126, 6, 1, 214, 127, 24, 0
    .byte 0, 44, 72, 35, 0, 205, 125, 214, 127, 5, 1, 94, 0, 19, 0
    .byte 0, 39, 120, 38, 0, 118, 127, 108, 0, 24, 1, 64, 1, 28, 0
    .byte 0, 39, 68, 0, 0, 0, 0, 192, 8, 1, 1, 0, 3, 3, 2, 205, 125, 5, 0
    .byte 0, 47, 144, 25, 0, 128, 125, 235, 125, 2, 1, 0, 126, 10, 0
    .byte 0, 37, 35, 6, 0, 128, 126, 176, 127, 4, 1, 0, 0, 15, 0
    .byte 0, 47, 120, 38, 0, 79, 127, 118, 127, 24, 2, 128, 125, 2, 0
    .byte 0, 43, 69, 0, 0, 0, 0, 0, 3, 2, 1, 61, 1, 6, 2, 94, 0, 19, 0
    .byte 0, 45, 66, 88, 0, 64, 127, 71, 0, 44, 1, 213, 7, 6, 0
    .byte 0, 39, 128, 0, 0, 0, 0, 28, 1, 18, 2, 0, 126, 10, 0
    .byte 0, 45, 110, 55, 0, 77, 126, 213, 7, 6, 2, 0, 112, 4, 0
    .byte 0, 34, 66, 88, 0, 26, 126, 64, 127, 30, 1, 182, 1, 14, 0
    .byte 0, 41, 71, 0, 0, 0, 0, 61, 1, 25, 2, 32, 124, 8, 0
    .byte 0, 40, 122, 0, 0, 0, 0, 213, 0, 6, 1, 28, 1, 18, 0
    .byte 0, 35, 96, 31, 0, 32, 124, 182, 1, 8, 1, 0, 0, 4, 1, 128, 27, 2, 0
    .byte 0, 45, 108, 0, 0, 0, 0, 128, 27, 2, 2, 8, 127, 12, 1, 213, 0, 24, 0
    .byte 128, 131, 0, 250, 0, 64, 1, 250, 127, 0, 0, 117, 1, 54, 2, 33, 0
    .byte 128, 131, 0, 46, 1, 64, 1, 244, 127, 0, 0, 182, 1, 176, 1, 16, 0
    .byte 0, 47, 177, 163, 0, 145, 127, 245, 127, 23, 0
    .byte 0, 33, 148, 10, 0, 86, 126, 24, 127, 6, 1, 0, 0, 5, 0
    .byte 0, 33, 126, 107, 0, 152, 123, 242, 125, 22, 1, 24, 127, 11, 1, 0, 0, 19, 0
    .byte 0, 45, 126, 107, 0, 27, 0, 25, 1, 51, 2, 179, 127, 23, 0
    .byte 0, 35, 126, 107, 0, 242, 125, 70, 127, 52, 1, 0, 0, 22, 0
    .byte 0, 45, 126, 107, 0, 201, 127, 27, 0, 74, 0
    .byte 0, 32, 126, 107, 0, 70, 127, 201, 127, 74, 0
    

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
    
    lda #%00010000           ; ADDR1 increment: +1 byte
    sta VERA_ADDR_BANK

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
   
    lda #%11100000           ; ADDR0 increment: +320 bytes
    sta VERA_ADDR_BANK

    lda #%00000010           ; Entering *polygon filler mode*
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
    lda (LOAD_ADDRESS), y
    iny
; FIXME: for now we put it into a ZP, but we *SHOULD* fill the cache with this color!
    sta TMP_COLOR

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
    
    ; -- nr of lines --
    lda (LOAD_ADDRESS), y
    iny
    sta NUMBER_OF_ROWS

    phy
; FIXME: temp solution for color!
    ldy TMP_COLOR
    jsr draw_polygon_part_using_polygon_filler_slow
    ply
    
    
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
    
    ; -- nr of lines --
    lda (LOAD_ADDRESS), y
    iny
    sta NUMBER_OF_ROWS

    phy
; FIXME: temp solution for color!
    ldy TMP_COLOR
    jsr draw_polygon_part_using_polygon_filler_slow
    ply
    
    bra draw_next_part
    
    

done_drawing_polygon:
    iny   ; We can only get here from one place, and there we still hadnt incremented y yet
    
    rts
    
    
    
    
    
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
    
    
    
setup_vera_for_layer0_bitmap:

    lda VERA_DC_VIDEO
    ora #%01010000           ; Enable Layer 0 and sprites
    and #%11011111           ; Disable Layer 1
    sta VERA_DC_VIDEO

    lda #$40                 ; 2:1 scale (320 x 240 pixels on screen)
    sta VERA_DC_HSCALE
    sta VERA_DC_VSCALE
    
    ; -- Setup Layer 0 --
    
    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL
    
    ; Enable bitmap mode and color depth = 8bpp on layer 0
    lda #(4+3)
    sta VERA_L0_CONFIG

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
    

clear_screen_slow:

    lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    lda #0
    sta VERA_ADDR_LOW
    lda #0
    sta VERA_ADDR_HIGH

    ; FIXME: PERFORMANCE we can do this MUCH faster using CACHE writes and UNROLLING!
    
    ; We need 320*240 = 76800 bytes to be cleared
    ; This means we need 300*256 bytes to be cleared (300 = 256+44)

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

    ldy #44
clear_bitmap_next_256a:
    ldx #0
clear_bitmap_next_1a:
    sta VERA_DATA0
    inx
    bne clear_bitmap_next_1a
    dey
    bne clear_bitmap_next_256a
    
    rts

change_palette_color:

    ; -- Change some colors in the palette
    
    lda #%00010001           ; Setting bit 16 of vram address to the highest bit in the tilebase (=1), setting auto-increment value to 1
    sta VERA_ADDR_BANK
    
    lda #$FA
    sta VERA_ADDR_HIGH
    lda #$08                 ; We use color 4 in the pallete (each color takes 2 bytes)
    sta VERA_ADDR_LOW

    lda #$05                 ; gb
    sta VERA_DATA0
    lda #$05                 ; -r
    sta VERA_DATA0
    
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