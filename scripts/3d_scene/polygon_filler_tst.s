; == PoC of the FOREST part of the 2R demo  ==

; To build: cl65 -t cx16 -o POLYGON-TST.PRG polygon_filler_tst.s
; To run: x16emu.exe -prg POLYGON-TST.PRG -run

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

VERA_L0_CONFIG    = $9F2D
VERA_L0_TILEBASE  = $9F2F



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

FILL_LENGTH_LOW           = $40
FILL_LENGTH_HIGH          = $41
NUMBER_OF_ROWS            = $42


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

; === Other constants ===

TRIANGLE_TOP_POINT_X = 90
TRIANGLE_TOP_POINT_Y = 20

BACKGROUND_COLOR = 4 ; nice purple

USE_JUMP_TABLE = 0
DEBUG = 0

; Jump table specific constants
TEST_JUMP_TABLE = 0   ; This turns off the iteration in-between the jump-table calls
USE_SOFT_FILL_LEN = 0 ; This turns off reading from 9F2B and 9F2C (for fill length data) and instead reads from USE_SOFT_FILL_LEN-variables
DO_4BIT = 0
DO_2BIT = 0


start:

    sei
    
    jsr setup_vera_for_layer0_bitmap
    
    .if(USE_JUMP_TABLE)
        jsr generate_fill_line_end_code
        jsr generate_fill_line_end_jump
        jsr generate_fill_line_start_code_and_jump
    .endif
    
    
    jsr change_palette_color
    jsr clear_screen
    
    jsr test_draw_triangle

    
    ; We are not returning to BASIC here...
infinite_loop:
    jmp infinite_loop
    
    rts
    
    
   
test_draw_triangle:

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
   
    lda #%11100000           ; ADDR0 increment: +320 bytes
    sta VERA_ADDR_BANK
    
    ; Note: we are setting ADDR0 to the leftmost pixel of a pixel row.
    lda #>(TRIANGLE_TOP_POINT_Y*320)
    sta VERA_ADDR_HIGH
    lda #<(TRIANGLE_TOP_POINT_Y*320)
    sta VERA_ADDR_LOW

    lda #%00000010           ; Entering *polygon filler mode*
    sta VERA_FX_CTRL
    
    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL
    
    ; IMPORTANT: these increments are *HALF* steps!
    lda #<(-110)             ; X1 increment low (signed)
    sta VERA_FX_X_INCR_L
    lda #>(-110)             ; X1 increment high (signed)
    and #%01111111           ; increment is only 15-bits long
    sta VERA_FX_X_INCR_H
    lda #<(380)              ; X2 increment low (signed)
    sta VERA_FX_Y_INCR_L
    lda #>(380)              ; X2 increment high (signed)
    and #%01111111           ; increment is only 15-bits long
    sta VERA_FX_Y_INCR_H

    ; Setting x1 and x2 pixel position
    
    lda #%00001001           ; DCSEL=4, ADDRSEL=1
    sta VERA_CTRL
    
    lda #<TRIANGLE_TOP_POINT_X
    sta VERA_FX_X_POS_L      ; X (=X1) pixel position low [7:0]
    sta VERA_FX_Y_POS_L      ; Y (=X2) pixel position low [7:0]
    
    lda #>TRIANGLE_TOP_POINT_X
    sta VERA_FX_X_POS_H      ; X (=X1) pixel position high [10:8]
    ora #%00100000           ; Reset subpixel position
    sta VERA_FX_Y_POS_H      ; Y (=X2) pixel position high [10:8]

    lda #%00010000           ; ADDR1 increment: +1 byte
    sta VERA_ADDR_BANK

    .if(USE_JUMP_TABLE)
    .else
        ldy #1                ; White color
        lda #150              ; Hardcoded amount of lines to draw
        sta NUMBER_OF_ROWS

        jsr draw_polygon_part_using_polygon_filler
    .endif
    
    
    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL
    
    ; NOTE that these increments are *HALF* steps!!
    lda #<(-1590)             ; X2 increment low
    sta VERA_FX_Y_INCR_L
    lda #>(-1590)             ; X2 increment high
    and #%01111111            ; increment is only 15-bits long
    sta VERA_FX_Y_INCR_H

    .if(USE_JUMP_TABLE)
    .else
        lda #50
        sta NUMBER_OF_ROWS
        jsr draw_polygon_part_using_polygon_filler
    .endif

    rts
    
    

; Routine to draw a triangle part
draw_polygon_part_using_polygon_filler:

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

    rts
    

clear_screen:

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

