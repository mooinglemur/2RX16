; == Very crude PoC of a 128x128px tilemap rotation ==

; To build: cl65 -t cx16 -o POC-ROTAZOOM.PRG poc-rotazoom.s
; To run: x16emu.exe -prg POC-ROTAZOOM.PRG -run -ram 2048

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

VERA_L0_CONFIG    = $9F2D
VERA_L0_TILEBASE  = $9F2F

; -- VRAM addresses --

MAPDATA_VRAM_ADDRESS  = $13000  ; should be aligned to 1kB
TILEDATA_VRAM_ADDRESS = $17000  ; should be aligned to 1kB

VERA_PALETTE          = $1FA00



; === Zero page addresses ===


LOAD_ADDRESS              = $30 ; 31
CODE_ADDRESS              = $32 ; 33

VERA_ADDR_ZP_TO           = $34 ; 35 ; 36

; For affine transformation
X_SUB_PIXEL               = $40 ; 41
Y_SUB_PIXEL               = $42 ; 43

ROTATION_ANGLE            = $50

COSINE_OF_ANGLE           = $51 ; 52
SINE_OF_ANGLE             = $53 ; 53

; === RAM addresses ===

COPY_ROW_CODE               = $7800


; === Other constants ===

MAP_HEIGHT = 32
MAP_WIDTH = 32
TILEMAP_RAM_ADDRESS = tile_map_data

TILE_SIZE_BYTES = 64
NR_OF_UNIQUE_TILES = (end_of_tile_pixel_data-tile_pixel_data)/TILE_SIZE_BYTES
TILEDATA_RAM_ADDRESS = tile_pixel_data

DESTINATION_PICTURE_POS_X = 0
DESTINATION_PICTURE_POS_Y = 0


start:

    jsr setup_vera_for_layer0_bitmap

    jsr copy_palette_from_index_16
    jsr copy_tiledata_to_high_vram
    jsr copy_tilemap_to_high_vram

    jsr generate_copy_row_code

    jsr setup_and_draw_rotated_tilemap

    ; We are not returning to BASIC here...
infinite_loop:
    jmp infinite_loop
    
    rts
    
    
    
setup_vera_for_layer0_bitmap:

    lda VERA_DC_VIDEO
    ora #%00010000           ; Enable Layer 0 
    and #%10011111           ; Disable Layer 1 and sprites
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
    
    
copy_palette_from_index_16:

    ; Starting at palette VRAM address
    
    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    ; We start at color index 16 of the palette (we preserve the first 16 default VERA colors)
    lda #<(VERA_PALETTE+2*16)
    sta VERA_ADDR_LOW
    lda #>(VERA_PALETTE+2*16)
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
    cpy #<(end_of_palette_data-palette_data)
    bne next_packed_color_1
    
    rts



copy_tiledata_to_high_vram:    
    
    lda #<TILEDATA_RAM_ADDRESS
    sta LOAD_ADDRESS
    lda #>TILEDATA_RAM_ADDRESS
    sta LOAD_ADDRESS+1

    ; TODO: we are ASSUMING here that TEXTURE_VRAM_ADDRESS has its bit16 set to 1!!
    lda #%00010001      ; setting bit 16 of vram address to the highest bit in the tilebase (=1), setting auto-increment value to 1
    sta VERA_ADDR_BANK
    lda #<(TILEDATA_VRAM_ADDRESS)
    sta VERA_ADDR_LOW
    lda #>(TILEDATA_VRAM_ADDRESS)
    sta VERA_ADDR_HIGH
    
    ldx #0
copy_next_tile_to_high_vram:  

    ldy #0
copy_next_tile_pixel_high_vram:
    lda (LOAD_ADDRESS),y
    sta VERA_DATA0
    iny
    cpy #TILE_SIZE_BYTES
    bne copy_next_tile_pixel_high_vram
    inx
    
    ; Adding TILE_SIZE_BYTES to the previous data address
    clc
    lda LOAD_ADDRESS
    adc #TILE_SIZE_BYTES
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    cpx #NR_OF_UNIQUE_TILES
    bne copy_next_tile_to_high_vram
    
    rts



copy_tilemap_to_high_vram:    
    
    ; We copy a 32x32 tilemap to high VRAM

    lda #<TILEMAP_RAM_ADDRESS
    sta LOAD_ADDRESS
    lda #>TILEMAP_RAM_ADDRESS
    sta LOAD_ADDRESS+1

    ; TODO: we are ASSUMING here that MAPDATA_VRAM_ADDRESS has its bit16 set to 1!!
    lda #%00010001      ; setting bit 16 of vram address to the highest bit in the tilebase (=1), setting auto-increment value to 1
    sta VERA_ADDR_BANK
    lda #<(MAPDATA_VRAM_ADDRESS)
    sta VERA_ADDR_LOW
    lda #>(MAPDATA_VRAM_ADDRESS)
    sta VERA_ADDR_HIGH
    
    ldx #0
copy_next_tile_row_high_vram:  

    ldy #0
copy_next_horizontal_tile_high_vram:
    lda (LOAD_ADDRESS),y
    sta VERA_DATA0
    iny
    cpy #MAP_WIDTH
    bne copy_next_horizontal_tile_high_vram
    inx
    
    ; Adding MAP_WIDTH to the previous data address
    clc
    lda LOAD_ADDRESS
    adc #MAP_WIDTH
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    cpx #MAP_HEIGHT
    bne copy_next_tile_row_high_vram
    
    rts



setup_and_draw_rotated_tilemap:

    ; Setup TO VRAM start address
    
    ; FIXME: HACK we are ASSUMING we never reach the second part of VRAM here! (VERA_ADDR_ZP_TO+2 is not used here!)
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    ; Setting base address and map size
    
    lda #(TILEDATA_VRAM_ADDRESS >> 9)
    and #%11111100   ; only the 6 highest bits of the address can be set
    ; ora #%00000010   ; clip = 1 -> we are REPEATING!
    sta VERA_FX_TILEBASE

    lda #(MAPDATA_VRAM_ADDRESS >> 9)
    ora #%00000010   ; Map size = 32x32 tiles
    sta VERA_FX_MAPBASE
    
    lda #%00000011  ; affine helper mode
    ; ora #%10000010  ; transparency enabled = 1 -> currently not drawing transparent pixels
    ora #%00100000  ; cache fill enabled = 1
    ora #%01000000  ; blit write enabled = 1
    sta VERA_FX_CTRL
    
    
    lda #0
    sta ROTATION_ANGLE
    
keep_rotating:
    lda #<(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_POS_Y*320)
    sta VERA_ADDR_ZP_TO
    lda #>(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_POS_Y*320)
    sta VERA_ADDR_ZP_TO+1
    
    jsr draw_rotated_tilemap
    inc ROTATION_ANGLE
    bra keep_rotating

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    lda #%00000000  ; blit write enabled = 0, normal mode
    sta VERA_FX_CTRL

    rts
    
    

; Maybe do 15.2 degrees (as an example): 
;   cos(15.2 degrees)*256 = 247.0  -> +247 = x_delta for row, -67  x_delta for column (start of row)
;   sin(15.2 degrees)*256 = 67.1   -> +67  = y_delta for row, +247  x_delta for column (start or row)

COSINE_ROTATE = 247
SINE_ROTATE = 67

draw_rotated_tilemap:


    ldx ROTATION_ANGLE

    lda cosine_values_low, x
    sta COSINE_OF_ANGLE
    lda cosine_values_high, x
    sta COSINE_OF_ANGLE+1
    
    lda sine_values_low, x
    sta SINE_OF_ANGLE
    lda sine_values_high, x
    sta SINE_OF_ANGLE+1
    

    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    lda #128
    sta Y_SUB_PIXEL
    
    lda #256-28          ; We start a litte above the pixture, so (when rotated) the right top part fits into the drawing rectangle
    sta Y_SUB_PIXEL+1
    lda #128
    sta X_SUB_PIXEL
    lda #0
    sta X_SUB_PIXEL+1
    
    ;lda #COSINE_ROTATE       ; X increment low
    lda COSINE_OF_ANGLE       ; X increment low
    asl
    sta VERA_FX_X_INCR_L
    ;lda #0
    lda COSINE_OF_ANGLE+1
    rol                      
    and #%01111111            ; increment is only 15 bits long
    sta VERA_FX_X_INCR_H
    ;lda #SINE_ROTATE
    lda SINE_OF_ANGLE
    asl
    sta VERA_FX_Y_INCR_L      ; Y increment low
    ;lda #0
    lda SINE_OF_ANGLE+1
    rol
    and #%01111111            ; increment is only 15 bits long
    sta VERA_FX_Y_INCR_H

    ldx #0
    
rotate_copy_next_row_1:
    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    lda #%00110000           ; Setting auto-increment value to 4 byte increment (=%0011) 
    sta VERA_ADDR_BANK
    lda VERA_ADDR_ZP_TO+1
    sta VERA_ADDR_HIGH
    lda VERA_ADDR_ZP_TO
    sta VERA_ADDR_LOW

    ; Setting the position
    
    lda #%00001001           ; DCSEL=4, ADDRSEL=1
    sta VERA_CTRL
    
    ; TODO: we cannot reset the cache index here anymore. We ASSUME that we always start aligned with a 4-byte column!

    lda X_SUB_PIXEL+1
    sta VERA_FX_X_POS_L      ; X pixel position low [7:0]
    bpl x_pixel_pos_high_positive
    lda #%00000111           ; sign extending X pixel position (when negative)
    bra x_pixel_pos_high_correct
x_pixel_pos_high_positive:
    lda #%00000000
x_pixel_pos_high_correct:
    sta VERA_FX_X_POS_H      ; X subpixel position[0] = 0, X pixel position high [10:8] = 000 or 111

    lda Y_SUB_PIXEL+1
    sta VERA_FX_Y_POS_L      ; Y pixel position low [7:0]
    bpl y_pixel_pos_high_positive
    lda #%00000111           ; sign extending X pixel position (when negative)
    bra y_pixel_pos_high_correct
y_pixel_pos_high_positive:
    lda #%00000000
y_pixel_pos_high_correct:
    sta VERA_FX_Y_POS_H      ; Y subpixel position[0] = 0,  Y pixel position high [10:8] = 000 or 111
    
    ; Setting the Subpixel X/Y positions
    
    lda #%00001010           ; DCSEL=5, ADDRSEL=0
    sta VERA_CTRL
    
    lda X_SUB_PIXEL
    sta VERA_FX_X_POS_S      ; X pixel position low [-1:-8]
    lda Y_SUB_PIXEL
    sta VERA_FX_Y_POS_S      ; Y pixel position low [-1:-8]
    

    ; Copy one row of pixels
    jsr COPY_ROW_CODE
    
    ; FIXME: HACK we are ASSUMING we never reach the second part of VRAM here! (VERA_ADDR_ZP_TO+2 is not used here!)
    
    ; We increment our VERA_ADDR_ZP_TO with 320
    clc
    lda VERA_ADDR_ZP_TO
    adc #<(320)
    sta VERA_ADDR_ZP_TO
    lda VERA_ADDR_ZP_TO+1
    adc #>(320)
    sta VERA_ADDR_ZP_TO+1

    clc
    lda Y_SUB_PIXEL
    ;adc #COSINE_ROTATE
    adc COSINE_OF_ANGLE
    sta Y_SUB_PIXEL
    lda Y_SUB_PIXEL+1
    ;adc #0
    adc COSINE_OF_ANGLE+1
    sta Y_SUB_PIXEL+1
    
    sec
    lda X_SUB_PIXEL
    ;sbc #SINE_ROTATE
    sbc SINE_OF_ANGLE
    sta X_SUB_PIXEL
    lda X_SUB_PIXEL+1
    ;sbc #0
    sbc SINE_OF_ANGLE+1
    sta X_SUB_PIXEL+1
    
    inx
    cpx #200             ; nr of row we draw
    bne rotate_copy_next_row_1
    
    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL
    
    rts



generate_copy_row_code:

    lda #<COPY_ROW_CODE
    sta CODE_ADDRESS
    lda #>COPY_ROW_CODE
    sta CODE_ADDRESS+1
    
    ldy #0                 ; generated code byte counter
    
    ldx #0                 ; counts nr of copy instructions

next_copy_instruction:

    ; -- lda VERA_DATA1 ($9F24)
    lda #$AD               ; lda ....
    jsr add_code_byte
    
    lda #$24               ; VERA_DATA1
    jsr add_code_byte
    
    lda #$9F         
    jsr add_code_byte

    ; When using the cache for writing we only write 1/4th of the time, so we read 3 extra bytes here (they go into the cache)
    
    ; -- lda VERA_DATA1 ($9F24)
    lda #$AD               ; lda ....
    jsr add_code_byte
    
    lda #$24               ; VERA_DATA1
    jsr add_code_byte
    
    lda #$9F         
    jsr add_code_byte

    ; -- lda VERA_DATA1 ($9F24)
    lda #$AD               ; lda ....
    jsr add_code_byte
    
    lda #$24               ; VERA_DATA1
    jsr add_code_byte
    
    lda #$9F         
    jsr add_code_byte

    ; -- lda VERA_DATA1 ($9F24)
    lda #$AD               ; lda ....
    jsr add_code_byte
    
    lda #$24               ; VERA_DATA1
    jsr add_code_byte
    
    lda #$9F         
    jsr add_code_byte

    ; We use the cache for writing, we do not want a mask to we store 0 (stz)

    ; -- stz VERA_DATA0 ($9F23)
    lda #$9C               ; stz ....
    jsr add_code_byte

    lda #$23               ; $23
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte

    inx
    cpx #320/4
    bne next_copy_instruction

    ; -- rts --
    lda #$60
    jsr add_code_byte

    rts


    
add_code_byte:
    sta (CODE_ADDRESS),y   ; store code byte at address (located at CODE_ADDRESS) + y
    iny                    ; increase y
    cpy #0                 ; if y == 0
    bne done_adding_code_byte
    inc CODE_ADDRESS+1     ; increment high-byte of CODE_ADDRESS
done_adding_code_byte:
    rts



; Python script to generate sine and cosine bytes
;   import math
;   cycle=256
;   ampl=256   # -256 ($FF.00) to +256 ($01.00)
;   [(int(math.sin(float(i)/cycle*2.0*math.pi)*ampl) % 256) for i in range(cycle)]
;   [(int(math.sin(float(i)/cycle*2.0*math.pi)*ampl) // 256) for i in range(cycle)]
;   [(int(math.cos(float(i)/cycle*2.0*math.pi)*ampl) % 256) for i in range(cycle)]
;   [(int(math.cos(float(i)/cycle*2.0*math.pi)*ampl) // 256) for i in range(cycle)]
; Manually: replace -1 with 255!
    
sine_values_low:
    .byte 0, 6, 12, 18, 25, 31, 37, 43, 49, 56, 62, 68, 74, 80, 86, 92, 97, 103, 109, 115, 120, 126, 131, 136, 142, 147, 152, 157, 162, 167, 171, 176, 181, 185, 189, 193, 197, 201, 205, 209, 212, 216, 219, 222, 225, 228, 231, 234, 236, 238, 241, 243, 244, 246, 248, 249, 251, 252, 253, 254, 254, 255, 255, 255, 0, 255, 255, 255, 254, 254, 253, 252, 251, 249, 248, 246, 244, 243, 241, 238, 236, 234, 231, 228, 225, 222, 219, 216, 212, 209, 205, 201, 197, 193, 189, 185, 181, 176, 171, 167, 162, 157, 152, 147, 142, 136, 131, 126, 120, 115, 109, 103, 97, 92, 86, 80, 74, 68, 62, 56, 49, 43, 37, 31, 25, 18, 12, 6, 0, 250, 244, 238, 231, 225, 219, 213, 207, 200, 194, 188, 182, 176, 170, 164, 159, 153, 147, 141, 136, 130, 125, 120, 114, 109, 104, 99, 94, 89, 85, 80, 75, 71, 67, 63, 59, 55, 51, 47, 44, 40, 37, 34, 31, 28, 25, 22, 20, 18, 15, 13, 12, 10, 8, 7, 5, 4, 3, 2, 2, 1, 1, 1, 0, 1, 1, 1, 2, 2, 3, 4, 5, 7, 8, 10, 12, 13, 15, 18, 20, 22, 25, 28, 31, 34, 37, 40, 44, 47, 51, 55, 59, 63, 67, 71, 75, 80, 85, 89, 94, 99, 104, 109, 114, 120, 125, 130, 136, 141, 147, 153, 159, 164, 170, 176, 182, 188, 194, 200, 207, 213, 219, 225, 231, 238, 244, 250
sine_values_high:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
cosine_values_low:
    .byte 0, 255, 255, 255, 254, 254, 253, 252, 251, 249, 248, 246, 244, 243, 241, 238, 236, 234, 231, 228, 225, 222, 219, 216, 212, 209, 205, 201, 197, 193, 189, 185, 181, 176, 171, 167, 162, 157, 152, 147, 142, 136, 131, 126, 120, 115, 109, 103, 97, 92, 86, 80, 74, 68, 62, 56, 49, 43, 37, 31, 25, 18, 12, 6, 0, 250, 244, 238, 231, 225, 219, 213, 207, 200, 194, 188, 182, 176, 170, 164, 159, 153, 147, 141, 136, 130, 125, 120, 114, 109, 104, 99, 94, 89, 85, 80, 75, 71, 67, 63, 59, 55, 51, 47, 44, 40, 37, 34, 31, 28, 25, 22, 20, 18, 15, 13, 12, 10, 8, 7, 5, 4, 3, 2, 2, 1, 1, 1, 0, 1, 1, 1, 2, 2, 3, 4, 5, 7, 8, 10, 12, 13, 15, 18, 20, 22, 25, 28, 31, 34, 37, 40, 44, 47, 51, 55, 59, 63, 67, 71, 75, 80, 85, 89, 94, 99, 104, 109, 114, 120, 125, 130, 136, 141, 147, 153, 159, 164, 170, 176, 182, 188, 194, 200, 207, 213, 219, 225, 231, 238, 244, 250, 0, 6, 12, 18, 25, 31, 37, 43, 49, 56, 62, 68, 74, 80, 86, 92, 97, 103, 109, 115, 120, 126, 131, 136, 142, 147, 152, 157, 162, 167, 171, 176, 181, 185, 189, 193, 197, 201, 205, 209, 212, 216, 219, 222, 225, 228, 231, 234, 236, 238, 241, 243, 244, 246, 248, 249, 251, 252, 253, 254, 254, 255, 255, 255
cosine_values_high:
    .byte 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0



; ==== DATA ====

; FIXME: all this DATA is included as asm text right now, but should be *loaded* from SD instead!

palette_data:
  .byte $00, $00
  .byte $64, $0a
  .byte $a8, $0c
  .byte $44, $08
  .byte $20, $04
  .byte $10, $05
  .byte $84, $0a
  .byte $20, $06
  .byte $10, $03
  .byte $88, $0c
  .byte $74, $0a
  .byte $54, $09
  .byte $86, $0c
  .byte $54, $0a
  .byte $20, $03
  .byte $98, $0c
  .byte $32, $07
  .byte $84, $0c
  .byte $34, $07
  .byte $43, $08
  .byte $a8, $0b
  .byte $78, $0c
  .byte $83, $0b
  .byte $10, $06
  .byte $73, $0a
  .byte $68, $05
  .byte $30, $07
  .byte $a8, $0e
  .byte $ac, $0e
  .byte $84, $09
  .byte $86, $0b
  .byte $22, $06
  .byte $64, $09
  .byte $74, $09
  .byte $53, $09
  .byte $83, $0c
  .byte $68, $06
  .byte $44, $02
  .byte $98, $0e
  .byte $63, $0a
  .byte $9c, $0e
  .byte $58, $04
  .byte $63, $09
  .byte $34, $02
  .byte $76, $0b
  .byte $40, $08
  .byte $45, $04
  .byte $97, $0c
  .byte $10, $01
  .byte $b8, $0e
  .byte $88, $07
  .byte $ab, $0e
  .byte $47, $04
  .byte $78, $06
  .byte $22, $01
  .byte $b7, $0e
  .byte $57, $04
  .byte $8b, $08
  .byte $c7, $0e
  .byte $33, $08
  .byte $33, $03
  .byte $98, $0b
  .byte $76, $0c
  .byte $73, $09
  .byte $77, $06
  .byte $35, $04
  .byte $88, $0b
  .byte $68, $03
  .byte $44, $01
  .byte $97, $0b
  .byte $89, $08
  .byte $ba, $0e
  .byte $31, $08
  .byte $58, $06
  .byte $00, $02
  .byte $24, $02
  .byte $43, $03
  .byte $a7, $0e
  .byte $12, $01
  .byte $75, $0c
  .byte $66, $0a
  .byte $67, $06
  .byte $8a, $07
  .byte $53, $0a
  .byte $67, $05
  .byte $b8, $0c
  .byte $13, $02
  .byte $c8, $0e
  .byte $50, $09
  .byte $95, $0c
  .byte $f0, $0f
  .byte $48, $04
  .byte $33, $04
  .byte $77, $05
  .byte $47, $03
  .byte $34, $08
  .byte $33, $01
  .byte $24, $01
  .byte $58, $03
  .byte $80, $0b
  .byte $a7, $0c
  .byte $78, $05
  .byte $8d, $08
  .byte $36, $04
  .byte $43, $01
  .byte $48, $03
  .byte $60, $09
  .byte $97, $0e
  .byte $43, $04
  .byte $9b, $08
  .byte $9d, $08
  .byte $56, $06
  .byte $20, $08
  .byte $23, $02
  .byte $41, $07
  .byte $98, $07
  .byte $87, $07
  .byte $79, $08
  .byte $c0, $0e
  .byte $d0, $0e
  .byte $50, $0b
  .byte $57, $03
  .byte $60, $0b
  .byte $9e, $08
  .byte $00, $04
  .byte $42, $07
  .byte $12, $05
  .byte $22, $05
  .byte $34, $01
  .byte $95, $0b
  .byte $83, $09
  .byte $7a, $07
  .byte $a0, $0e
  .byte $90, $0d
  .byte $80, $0c
  .byte $78, $0b
  .byte $70, $0a
  .byte $56, $0a
  .byte $98, $08
  .byte $87, $08
  .byte $9c, $07
  .byte $9b, $07
  .byte $ab, $0d
  .byte $55, $03
  .byte $36, $02
end_of_palette_data:


tile_map_data:
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $01, $02, $03, $00, $00, $04, $05, $06, $07, $08, $09, $00, $00, $0a, $0b, $0c,   $01, $02, $03, $00, $00, $04, $05, $06, $07, $08, $09, $00, $00, $0a, $0b, $0c
  .byte $0d, $0e, $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c,   $0d, $0e, $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c
  .byte $00, $1d, $00, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $00, $28, $00,   $00, $1d, $00, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $00, $28, $00
  .byte $00, $00, $00, $29, $2a, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $00, $00, $00,   $00, $00, $00, $29, $2a, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $00, $00, $00
  .byte $00, $00, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $00, $00,   $00, $00, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $00, $00
  .byte $00, $00, $3f, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $00, $00,   $00, $00, $3f, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $00, $00
  .byte $00, $00, $00, $4b, $4c, $4d, $4e, $4f, $50, $51, $52, $53, $54, $55, $00, $00,   $00, $00, $00, $4b, $4c, $4d, $4e, $4f, $50, $51, $52, $53, $54, $55, $00, $00
  .byte $00, $00, $00, $56, $57, $58, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $00, $00,   $00, $00, $00, $56, $57, $58, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $00, $00
  .byte $00, $00, $00, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6a, $00, $00, $00,   $00, $00, $00, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6a, $00, $00, $00
  .byte $00, $6b, $00, $00, $6c, $6d, $6e, $6f, $70, $71, $72, $73, $00, $00, $74, $00,   $00, $6b, $00, $00, $6c, $6d, $6e, $6f, $70, $71, $72, $73, $00, $00, $74, $00
  .byte $75, $76, $00, $00, $00, $77, $78, $79, $7a, $7b, $7c, $00, $00, $7d, $7e, $7f,   $75, $76, $00, $00, $00, $77, $78, $79, $7a, $7b, $7c, $00, $00, $7d, $7e, $7f
  .byte $80, $81, $82, $00, $00, $83, $84, $85, $86, $87, $88, $00, $00, $89, $8a, $8b,   $80, $81, $82, $00, $00, $83, $84, $85, $86, $87, $88, $00, $00, $89, $8a, $8b
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $01, $02, $03, $00, $00, $04, $05, $06, $07, $08, $09, $00, $00, $0a, $0b, $0c,   $01, $02, $03, $00, $00, $04, $05, $06, $07, $08, $09, $00, $00, $0a, $0b, $0c
  .byte $0d, $0e, $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c,   $0d, $0e, $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c
  .byte $00, $1d, $00, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $00, $28, $00,   $00, $1d, $00, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $00, $28, $00
  .byte $00, $00, $00, $29, $2a, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $00, $00, $00,   $00, $00, $00, $29, $2a, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $00, $00, $00
  .byte $00, $00, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $00, $00,   $00, $00, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $00, $00
  .byte $00, $00, $3f, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $00, $00,   $00, $00, $3f, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $00, $00
  .byte $00, $00, $00, $4b, $4c, $4d, $4e, $4f, $50, $51, $52, $53, $54, $55, $00, $00,   $00, $00, $00, $4b, $4c, $4d, $4e, $4f, $50, $51, $52, $53, $54, $55, $00, $00
  .byte $00, $00, $00, $56, $57, $58, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $00, $00,   $00, $00, $00, $56, $57, $58, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $00, $00
  .byte $00, $00, $00, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6a, $00, $00, $00,   $00, $00, $00, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6a, $00, $00, $00
  .byte $00, $6b, $00, $00, $6c, $6d, $6e, $6f, $70, $71, $72, $73, $00, $00, $74, $00,   $00, $6b, $00, $00, $6c, $6d, $6e, $6f, $70, $71, $72, $73, $00, $00, $74, $00
  .byte $75, $76, $00, $00, $00, $77, $78, $79, $7a, $7b, $7c, $00, $00, $7d, $7e, $7f,   $75, $76, $00, $00, $00, $77, $78, $79, $7a, $7b, $7c, $00, $00, $7d, $7e, $7f
  .byte $80, $81, $82, $00, $00, $83, $84, $85, $86, $87, $88, $00, $00, $89, $8a, $8b,   $80, $81, $82, $00, $00, $83, $84, $85, $86, $87, $88, $00, $00, $89, $8a, $8b
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,   $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
end_of_tile_map_data:


tile_pixel_data:
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $66, $10, $10, $10, $10, $10, $10, $61, $8b, $10, $10, $10, $10, $10, $29, $56, $85, $10, $10, $10, $10, $10, $34, $6d, $45
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $6d, $49, $56, $34, $29, $35, $10, $10, $49, $49, $62, $50, $59, $34, $29, $90, $7d, $49, $50, $39, $34, $29, $53, $6b, $34, $42, $50, $29, $72, $29, $79, $44
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $48, $42, $34, $29, $5e, $81, $10, $44, $42, $56, $45, $29, $64
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $18, $10, $18, $15, $2a
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $15, $15, $18, $15, $15, $15, $17, $20, $32, $1b, $2a, $1b, $1b, $13, $11, $26, $21, $19
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $15, $2f, $17, $17, $17, $3d, $3d, $3d, $37, $60, $55, $3f, $12, $12, $12, $12, $1f, $24, $12, $36, $41, $47, $47, $47
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $13, $13, $13, $23, $68, $3d, $58, $20, $12, $12, $12, $12, $1f, $1f, $1c, $26, $47, $47, $5d, $3f, $24, $12, $1f, $52
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $10, $10, $10, $2f, $17, $15, $14, $18, $10, $10, $10, $28, $37, $13, $23, $17, $17, $15, $15, $1f, $19, $21, $16, $1a, $28, $11, $32
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $10, $10, $10, $10, $10, $2f, $2a, $15, $14, $14, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $40, $5b, $3b, $46, $10, $10, $10, $71, $42, $83, $34, $29, $3e, $10, $3b, $7f, $42, $45, $29, $44, $48, $10, $3b
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $5b, $5c, $5b, $3b, $5e, $10, $44, $9d, $56, $56, $34, $34, $34, $34, $49, $49, $7e, $7d, $45, $61, $39, $45, $42, $49, $49, $42, $64, $29, $29, $34, $48, $45, $64, $50, $39, $9f, $35
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $34, $5e, $10, $10, $10, $10, $10, $10, $53, $29, $40, $10, $10, $10, $10, $10, $53, $39, $44, $10, $10, $10, $10, $10, $39, $51, $44, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $34, $39, $50, $10, $10, $10, $10, $10, $29, $34, $39, $10, $10, $10, $10, $10, $3b, $29, $29, $10, $10, $10, $10, $10, $10, $3b, $29, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $48, $48, $39, $3b, $6c, $44, $51, $3e, $34, $53, $79, $4c, $54, $4c, $5c, $3e, $29, $34, $29, $48, $4c, $54, $54, $35, $29, $53, $39, $44, $7c, $54, $35, $10, $40, $5b, $3b, $66, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $44, $62, $42, $45, $48, $10
  .byte $1e, $10, $48, $34, $39, $6e, $3b, $3e, $46, $10, $5e, $48, $29, $77, $35, $46, $10, $10, $10, $40, $66, $1e, $5e, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $40
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $14, $10, $10, $10, $10, $10, $18, $14, $27, $10, $10, $10, $10, $14, $15, $2a, $23, $10, $10, $10, $14, $17, $23, $22, $13, $10, $10, $14, $15, $23, $22, $1b, $11, $40, $14, $17, $23, $22, $13, $11, $11, $14, $17, $23, $22, $13, $11, $11, $1d
  .byte $40, $14, $14, $17, $17, $23, $1b, $1b, $15, $17, $20, $13, $1b, $11, $1d, $1d, $20, $22, $1b, $11, $11, $11, $31, $11, $13, $11, $11, $1d, $1b, $31, $28, $26, $11, $1d, $11, $30, $16, $26, $21, $21, $11, $1d, $1a, $2d, $16, $26, $21, $1c, $1d, $11, $31, $21, $26, $21, $1c, $1c, $11, $1b, $21, $2d, $33, $21, $21, $19
  .byte $11, $1d, $2d, $33, $21, $19, $25, $4d, $30, $28, $26, $1c, $25, $19, $24, $36, $26, $1c, $19, $25, $19, $24, $1f, $41, $1c, $1c, $25, $19, $12, $24, $36, $41, $19, $25, $19, $12, $12, $4d, $2b, $47, $25, $19, $19, $1f, $24, $1f, $41, $7b, $19, $25, $1f, $12, $24, $2b, $36, $4a, $25, $1f, $19, $24, $12, $2b, $36, $47
  .byte $12, $2b, $47, $47, $4a, $57, $41, $43, $41, $5d, $41, $57, $43, $38, $38, $38, $2b, $4a, $41, $38, $38, $2c, $2c, $2c, $4a, $43, $38, $2c, $2c, $2c, $2c, $2c, $41, $43, $38, $2c, $2c, $2c, $2c, $2c, $57, $43, $38, $2c, $2c, $2c, $2c, $2c, $38, $43, $38, $2c, $2c, $2c, $2c, $2c, $57, $41, $38, $2c, $2c, $2c, $2c, $2c
  .byte $41, $57, $57, $67, $47, $7b, $2b, $12, $38, $38, $38, $38, $43, $41, $5d, $36, $2c, $2c, $2c, $2c, $38, $38, $67, $5d, $2c, $2c, $2c, $2c, $2c, $38, $57, $4a, $2c, $2c, $2c, $2c, $2c, $38, $43, $4a, $2c, $2c, $2c, $2c, $2c, $38, $43, $43, $2c, $2c, $2c, $2c, $2c, $38, $41, $43, $2c, $2c, $2c, $2c, $2c, $38, $43, $41
  .byte $24, $12, $12, $1f, $25, $19, $21, $21, $12, $24, $12, $12, $1f, $25, $25, $19, $36, $12, $24, $12, $12, $19, $12, $25, $36, $12, $12, $24, $12, $1f, $1f, $19, $41, $36, $2b, $12, $24, $12, $12, $25, $4a, $36, $2b, $12, $24, $12, $12, $1f, $4a, $36, $2b, $12, $24, $12, $12, $1f, $4a, $41, $36, $12, $24, $12, $12, $19
  .byte $37, $1b, $1b, $13, $2f, $17, $15, $14, $19, $1a, $37, $11, $1b, $13, $2a, $17, $19, $19, $21, $4f, $1d, $11, $1b, $22, $25, $19, $19, $26, $31, $1d, $11, $11, $19, $25, $19, $21, $92, $1d, $11, $11, $25, $19, $1c, $21, $26, $31, $1d, $11, $19, $25, $19, $21, $26, $16, $1b, $11, $19, $25, $1c, $21, $26, $16, $31, $1d
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $15, $14, $18, $10, $10, $10, $10, $10, $17, $27, $14, $14, $18, $10, $10, $10, $13, $23, $17, $15, $1e, $14, $10, $10, $11, $13, $13, $17, $27, $14, $14, $18, $11, $11, $22, $23, $17, $27, $14, $14, $11, $11, $1b, $13, $13, $20, $15, $14, $11, $11, $11, $1b, $22, $13, $20, $27
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $10, $10, $10, $10, $10, $14, $18, $10, $10, $10, $10, $10, $10, $14, $14, $18, $10, $10, $10, $10, $10
  .byte $35, $34, $29, $51, $78, $35, $10, $3b, $10, $3b, $39, $3e, $35, $10, $10, $5e, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $34, $59, $61, $39, $53, $3b, $4c, $4c, $29, $29, $39, $29, $29, $44, $4c, $35, $3b, $29, $29, $29, $29, $72, $3e, $4c, $10, $40, $48, $48, $75, $39, $3e, $35, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $40, $81, $3b, $3b, $40, $10, $10, $71, $62, $76, $9b, $34, $29, $70
  .byte $51, $7c, $3e, $10, $10, $10, $10, $10, $78, $35, $35, $10, $10, $10, $10, $10, $35, $35, $10, $10, $10, $10, $10, $10, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $44, $49, $76, $42, $61, $29, $3e, $10, $45, $84, $42, $45, $6b, $51, $3e, $10, $75, $59, $39, $6e, $70, $5c, $35, $10, $10, $29, $29, $77, $35, $35, $46, $10, $10, $10, $18, $1e, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $14, $10, $10, $10, $10, $10, $10, $18, $14, $10, $10, $10, $10, $10, $40, $14, $27, $10, $10, $10, $10, $10, $14, $15, $2a, $10, $10, $10, $10, $18, $1e, $27, $23, $10, $10, $10, $10, $10, $14, $15, $13, $10, $10, $10, $10, $14, $15, $20, $13, $10, $10, $10, $10, $14, $27, $2a, $13
  .byte $15, $20, $13, $22, $11, $11, $1d, $11, $17, $13, $22, $1b, $11, $11, $11, $1d, $13, $22, $13, $11, $11, $11, $11, $1d, $13, $22, $13, $11, $11, $11, $11, $1d, $13, $22, $11, $11, $11, $11, $11, $1b, $13, $22, $11, $11, $11, $11, $11, $1b, $13, $22, $11, $11, $11, $11, $11, $1b, $13, $22, $1b, $11, $11, $11, $11, $1d
  .byte $1d, $31, $16, $16, $33, $1c, $19, $19, $1b, $16, $2d, $21, $33, $1c, $19, $19, $31, $16, $16, $26, $21, $21, $1c, $19, $2d, $16, $16, $26, $21, $1c, $19, $19, $16, $16, $16, $16, $33, $21, $19, $19, $16, $16, $16, $21, $33, $1c, $21, $19, $16, $16, $16, $26, $21, $1c, $1c, $19, $2d, $2d, $16, $16, $33, $1c, $21, $1c
  .byte $25, $1f, $1f, $12, $24, $12, $36, $47, $25, $19, $12, $24, $12, $12, $36, $2b, $25, $1f, $1f, $12, $24, $12, $2b, $36, $25, $19, $19, $12, $24, $12, $12, $2b, $25, $1f, $1f, $12, $24, $12, $12, $2b, $19, $25, $1f, $12, $12, $24, $12, $12, $19, $25, $19, $19, $24, $12, $12, $12, $19, $19, $25, $19, $24, $12, $24, $24
  .byte $41, $43, $67, $38, $38, $2c, $2c, $2c, $47, $41, $43, $43, $43, $38, $38, $2c, $2b, $7b, $47, $4a, $43, $43, $41, $38, $36, $36, $2b, $2b, $4a, $4a, $43, $4a, $12, $2b, $36, $36, $36, $36, $47, $41, $2b, $12, $2b, $2b, $2b, $2b, $36, $36, $12, $12, $24, $2b, $2b, $2b, $2b, $2b, $12, $12, $12, $2b, $2b, $12, $12, $2b
  .byte $2c, $2c, $2c, $2c, $2c, $38, $57, $41, $38, $2c, $2c, $38, $38, $57, $4a, $47, $43, $38, $38, $43, $4a, $47, $67, $2b, $41, $4a, $43, $4a, $41, $41, $2b, $36, $47, $2b, $47, $2b, $2b, $36, $36, $2b, $36, $36, $36, $36, $36, $2b, $2b, $2b, $2b, $2b, $2b, $2b, $12, $12, $2b, $12, $12, $2b, $2b, $2b, $2b, $12, $12, $12
  .byte $4a, $2b, $36, $12, $24, $12, $1f, $1f, $2b, $36, $2b, $12, $24, $12, $1f, $19, $2b, $36, $2b, $12, $24, $12, $1f, $25, $36, $2b, $12, $12, $24, $12, $19, $25, $2b, $2b, $12, $24, $12, $1f, $19, $25, $12, $12, $12, $24, $1f, $1f, $19, $25, $12, $12, $24, $12, $1f, $25, $25, $19, $12, $24, $12, $12, $19, $19, $25, $19
  .byte $25, $19, $19, $21, $26, $16, $2d, $1d, $25, $19, $21, $21, $26, $2d, $1a, $31, $19, $19, $21, $1c, $26, $16, $31, $11, $19, $19, $21, $1c, $26, $16, $16, $31, $19, $1c, $21, $21, $26, $1a, $2d, $1a, $19, $21, $21, $33, $16, $16, $2d, $11, $19, $21, $1c, $26, $16, $16, $16, $31, $19, $1c, $21, $26, $16, $16, $2d, $1a
  .byte $11, $11, $11, $11, $1b, $22, $13, $17, $1d, $11, $11, $11, $11, $22, $13, $23, $1d, $11, $11, $11, $11, $1b, $22, $13, $1d, $11, $11, $11, $11, $11, $22, $13, $1d, $11, $11, $11, $11, $11, $22, $13, $1d, $11, $11, $11, $11, $11, $1b, $22, $1d, $11, $11, $11, $11, $11, $1b, $22, $1d, $11, $11, $11, $11, $11, $13, $22
  .byte $27, $1e, $14, $10, $10, $10, $10, $10, $17, $15, $14, $18, $10, $10, $10, $10, $3d, $15, $14, $14, $10, $10, $10, $10, $23, $17, $15, $1e, $18, $10, $10, $10, $13, $20, $15, $14, $14, $10, $10, $10, $13, $13, $2a, $27, $14, $18, $10, $10, $13, $13, $20, $17, $15, $14, $10, $10, $13, $13, $23, $2a, $27, $1e, $18, $10
  .byte $10, $64, $56, $49, $62, $29, $89, $3e, $10, $42, $50, $50, $39, $a0, $6c, $3e, $10, $3b, $34, $29, $3e, $4c, $54, $35, $10, $10, $3b, $48, $3e, $35, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $14, $27, $20, $13, $10, $10, $10, $10, $14, $27, $2a, $13, $10, $10, $10, $10, $14, $15, $3d, $13, $10, $10, $10, $10, $14, $27, $2a, $13, $10, $10, $10, $10, $14, $27, $20, $13, $10, $10, $10, $10, $14, $27, $2a, $13, $10, $10, $10, $10, $14, $27, $17, $13, $10, $10, $10, $10, $14, $27, $2a, $23
  .byte $13, $22, $11, $11, $11, $11, $11, $1d, $13, $22, $11, $11, $11, $11, $11, $1d, $13, $22, $1b, $11, $11, $11, $11, $11, $13, $22, $11, $11, $11, $11, $11, $1d, $13, $22, $11, $11, $11, $11, $11, $11, $13, $22, $11, $11, $11, $11, $11, $1d, $13, $22, $1b, $11, $11, $11, $11, $11, $13, $13, $22, $11, $11, $11, $11, $11
  .byte $11, $2d, $21, $2d, $33, $21, $21, $19, $16, $31, $2d, $21, $16, $33, $1c, $21, $1b, $11, $16, $2d, $16, $33, $21, $1c, $1a, $31, $16, $16, $16, $16, $33, $21, $1d, $1a, $31, $16, $16, $16, $16, $33, $11, $1a, $1a, $31, $16, $16, $2d, $16, $1d, $11, $1a, $11, $2d, $2d, $21, $16, $11, $1d, $1d, $1a, $2d, $16, $16, $2d
  .byte $19, $19, $19, $25, $19, $52, $12, $12, $19, $19, $19, $19, $25, $25, $12, $1f, $19, $19, $19, $19, $4e, $19, $25, $25, $16, $33, $1c, $19, $19, $25, $19, $25, $33, $21, $21, $21, $21, $1c, $19, $19, $16, $26, $21, $16, $1c, $21, $21, $1c, $16, $16, $33, $33, $33, $26, $2e, $16, $16, $16, $16, $21, $33, $16, $1c, $26
  .byte $24, $24, $24, $12, $12, $12, $12, $12, $97, $12, $12, $24, $12, $24, $12, $24, $1f, $4d, $24, $19, $4d, $1f, $24, $24, $19, $19, $25, $19, $1f, $12, $1f, $12, $25, $25, $1c, $25, $19, $19, $1f, $4d, $2e, $21, $4e, $19, $25, $19, $25, $1f, $1c, $1c, $1c, $21, $19, $25, $19, $25, $26, $26, $1c, $21, $16, $1c, $1c, $19
  .byte $12, $2b, $12, $12, $12, $12, $12, $2b, $12, $12, $24, $12, $12, $12, $24, $24, $12, $12, $12, $12, $24, $4d, $12, $1f, $4d, $52, $24, $24, $19, $19, $19, $1f, $1f, $52, $19, $1f, $19, $1f, $19, $19, $52, $1f, $19, $19, $1f, $25, $4e, $1f, $1f, $19, $25, $19, $25, $1c, $25, $4e, $4e, $25, $19, $4e, $1c, $5f, $1c, $16
  .byte $24, $12, $19, $25, $25, $25, $19, $19, $12, $1f, $19, $25, $19, $19, $19, $19, $19, $1f, $1f, $25, $19, $19, $19, $1c, $1f, $19, $25, $19, $19, $19, $19, $21, $19, $25, $19, $19, $19, $21, $1c, $1c, $25, $19, $19, $21, $1c, $1c, $1c, $21, $1c, $1c, $21, $2e, $21, $16, $26, $26, $1c, $2e, $26, $26, $33, $21, $26, $16
  .byte $19, $21, $33, $16, $16, $16, $31, $11, $1c, $1c, $33, $16, $16, $16, $31, $1a, $1c, $1c, $26, $16, $2d, $2d, $11, $1a, $21, $1c, $33, $16, $16, $2d, $1a, $11, $1c, $26, $16, $16, $16, $31, $11, $11, $33, $16, $16, $2d, $30, $16, $11, $11, $16, $16, $2d, $16, $31, $11, $11, $1d, $16, $2d, $16, $2d, $11, $11, $1d, $11
  .byte $11, $1d, $11, $11, $11, $11, $11, $22, $1d, $11, $11, $11, $11, $11, $13, $13, $11, $1d, $11, $11, $11, $11, $11, $22, $1d, $11, $11, $11, $11, $11, $1b, $13, $11, $1d, $11, $11, $11, $11, $13, $13, $1d, $11, $11, $11, $11, $11, $13, $22, $11, $11, $11, $11, $11, $11, $1b, $22, $11, $11, $11, $11, $11, $11, $22, $13
  .byte $13, $13, $13, $3d, $15, $14, $18, $10, $22, $13, $13, $23, $15, $17, $14, $10, $13, $13, $13, $23, $15, $17, $14, $18, $22, $13, $13, $23, $15, $17, $14, $18, $22, $13, $13, $23, $17, $27, $14, $18, $13, $13, $13, $23, $2a, $27, $14, $18, $13, $13, $13, $23, $17, $27, $14, $18, $13, $13, $23, $3d, $2a, $27, $14, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $14, $14, $10, $10, $10, $10, $10, $10, $17, $23, $10, $10, $10, $10, $10, $14, $32, $69, $10, $10, $10, $10, $10, $18, $30, $1f, $10, $10, $10, $10, $18, $15, $30, $12, $10, $10, $10, $10, $18, $15, $30, $12
  .byte $10, $10, $10, $10, $14, $17, $15, $23, $10, $10, $10, $10, $14, $17, $15, $2a, $10, $10, $10, $10, $14, $17, $17, $15, $15, $10, $10, $10, $14, $17, $17, $15, $17, $18, $10, $10, $14, $14, $17, $17, $1a, $15, $40, $10, $14, $14, $17, $17, $1c, $23, $18, $10, $14, $1e, $17, $17, $12, $1c, $2a, $10, $10, $14, $14, $17
  .byte $13, $13, $22, $13, $11, $11, $11, $11, $23, $13, $22, $13, $11, $11, $11, $11, $3d, $13, $13, $22, $1b, $11, $11, $11, $17, $3d, $13, $13, $22, $11, $11, $11, $15, $3d, $3d, $23, $22, $13, $11, $11, $15, $2a, $23, $3d, $23, $22, $1b, $11, $17, $15, $23, $3d, $3d, $23, $22, $1b, $17, $15, $17, $22, $20, $2a, $13, $22
  .byte $11, $11, $11, $1d, $1a, $30, $2d, $2d, $11, $11, $1d, $11, $11, $1a, $30, $16, $11, $11, $11, $1d, $1d, $1a, $11, $30, $11, $11, $11, $11, $11, $1d, $1d, $1a, $11, $11, $11, $11, $11, $1d, $11, $1d, $11, $11, $11, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $11, $11
  .byte $16, $16, $16, $16, $26, $21, $21, $19, $1a, $2d, $21, $16, $16, $33, $26, $26, $2d, $31, $16, $16, $16, $2d, $16, $16, $11, $16, $31, $1a, $16, $16, $16, $16, $1d, $1a, $11, $30, $2d, $16, $1a, $16, $11, $1a, $1a, $1a, $1a, $2d, $16, $16, $1d, $11, $1d, $1a, $1a, $1a, $31, $16, $11, $1d, $1d, $11, $1d, $11, $30, $1a
  .byte $16, $21, $19, $21, $21, $19, $1c, $21, $33, $16, $33, $33, $1c, $1c, $1c, $1c, $16, $26, $26, $16, $21, $21, $16, $16, $16, $16, $16, $26, $26, $26, $26, $26, $31, $16, $16, $21, $2d, $16, $16, $16, $1a, $16, $16, $31, $2d, $21, $2d, $1a, $31, $31, $16, $31, $1a, $16, $31, $1a, $31, $31, $2d, $11, $30, $16, $30, $30
  .byte $33, $21, $21, $2e, $16, $21, $33, $33, $19, $1c, $21, $16, $26, $33, $16, $2d, $1c, $21, $33, $2e, $1c, $26, $16, $2d, $33, $26, $16, $26, $26, $1a, $31, $31, $2d, $16, $16, $16, $16, $2d, $16, $21, $16, $16, $16, $30, $2d, $1a, $31, $2d, $16, $2d, $2d, $16, $1a, $11, $1a, $1a, $2d, $2d, $16, $1a, $1a, $11, $16, $11
  .byte $21, $26, $16, $16, $16, $26, $16, $2d, $26, $21, $16, $16, $16, $16, $1a, $31, $16, $2d, $2d, $2d, $16, $2d, $31, $11, $16, $2d, $11, $1a, $31, $11, $1a, $16, $31, $16, $1a, $11, $1a, $1a, $1d, $1a, $16, $1a, $11, $1a, $16, $1a, $11, $1a, $1a, $11, $16, $1a, $11, $1d, $1d, $1d, $11, $16, $11, $1d, $1a, $11, $11, $1d
  .byte $2d, $16, $31, $1a, $1a, $11, $1d, $11, $1a, $16, $11, $11, $1d, $1d, $11, $11, $11, $1a, $11, $1a, $1d, $11, $11, $11, $11, $11, $11, $1d, $11, $1d, $11, $11, $1a, $1a, $11, $1d, $1d, $11, $11, $11, $1d, $11, $1d, $11, $11, $11, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $11
  .byte $11, $11, $11, $11, $11, $13, $22, $13, $11, $11, $11, $11, $11, $13, $22, $13, $11, $11, $11, $1b, $13, $22, $13, $13, $11, $11, $11, $1b, $22, $13, $13, $13, $11, $11, $1b, $22, $13, $13, $13, $23, $11, $11, $13, $22, $13, $13, $23, $2a, $11, $1b, $22, $13, $13, $3d, $17, $17, $1b, $22, $13, $13, $17, $15, $23, $23
  .byte $13, $13, $23, $3d, $17, $15, $14, $10, $13, $13, $3d, $2a, $27, $1e, $10, $10, $13, $23, $2a, $15, $14, $14, $18, $10, $23, $2a, $15, $14, $14, $14, $10, $10, $2a, $15, $17, $14, $14, $10, $10, $18, $2a, $15, $17, $14, $18, $10, $40, $15, $2a, $27, $14, $14, $18, $10, $18, $23, $17, $15, $1e, $14, $10, $10, $2a, $1c
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $14, $18, $10, $10, $10, $10, $10, $15, $23, $17, $10, $10, $10, $10, $10, $17, $69, $32, $18, $10, $10, $10, $10, $1a, $1f, $30, $18, $10, $10, $10, $10, $1c, $12, $30, $15, $18, $10, $10, $10, $12, $12, $30, $15, $18, $10, $10, $10
  .byte $10, $10, $10, $10, $14, $15, $13, $1a, $10, $10, $10, $18, $14, $27, $20, $13, $10, $10, $10, $18, $14, $27, $17, $15, $10, $10, $10, $10, $14, $15, $20, $15, $10, $10, $10, $10, $18, $14, $15, $13, $10, $10, $10, $10, $10, $18, $1e, $17, $10, $10, $10, $10, $10, $10, $18, $14, $10, $10, $10, $10, $10, $10, $10, $40
  .byte $12, $1f, $1a, $15, $18, $14, $1e, $14, $1a, $65, $1a, $23, $15, $1e, $14, $1e, $15, $1c, $2e, $3c, $15, $15, $18, $1e, $18, $14, $65, $3f, $58, $17, $23, $18, $18, $18, $23, $12, $16, $3f, $16, $20, $13, $18, $18, $23, $1c, $12, $1c, $11, $20, $20, $18, $18, $17, $1b, $1d, $17, $15, $4b, $2f, $18, $18, $15, $14, $18
  .byte $17, $15, $2f, $11, $1b, $2f, $2a, $13, $14, $15, $17, $1b, $37, $11, $20, $20, $14, $15, $13, $37, $28, $26, $21, $15, $18, $17, $1b, $1a, $21, $1a, $16, $11, $18, $13, $63, $2e, $1f, $21, $55, $21, $15, $6f, $1a, $26, $19, $4d, $12, $12, $15, $3d, $13, $1a, $19, $52, $12, $12, $15, $2f, $1b, $26, $28, $2e, $1f, $12
  .byte $13, $11, $11, $11, $11, $11, $11, $11, $13, $13, $1b, $11, $11, $11, $11, $11, $20, $13, $22, $1b, $11, $11, $11, $11, $15, $20, $13, $13, $13, $11, $11, $11, $1c, $23, $20, $13, $22, $13, $13, $11, $24, $74, $23, $17, $13, $13, $13, $13, $1f, $12, $74, $3a, $17, $13, $13, $13, $12, $5d, $12, $2e, $1b, $82, $27, $17
  .byte $11, $11, $11, $1d, $11, $1d, $11, $30, $11, $11, $11, $11, $11, $11, $1d, $1d, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $1b, $11, $11, $11, $11, $11, $11, $22, $13, $13, $22, $13, $22, $1b, $13, $20, $22, $13, $1b, $11, $11, $13, $13
  .byte $31, $1a, $30, $1a, $1a, $30, $11, $1a, $1d, $30, $1d, $1a, $1a, $11, $1a, $11, $11, $1d, $11, $1d, $1d, $1d, $11, $1d, $11, $11, $1d, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $1b, $11, $11, $11, $11, $11, $11, $11, $13, $13, $13, $1b, $11, $11, $11, $11
  .byte $30, $1a, $31, $1a, $11, $1a, $1a, $1d, $11, $31, $11, $1d, $11, $11, $1d, $11, $1d, $1d, $1d, $11, $1d, $1d, $11, $11, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $1b, $13
  .byte $11, $1a, $11, $1d, $11, $1d, $1d, $11, $1d, $1d, $11, $1d, $1d, $11, $11, $11, $11, $11, $1d, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $1b, $11, $11, $11, $11, $11, $1b, $11, $13, $13, $13, $13, $13, $13, $13, $22, $13
  .byte $11, $11, $11, $11, $11, $11, $11, $1b, $11, $11, $11, $11, $11, $11, $1b, $22, $11, $11, $11, $11, $11, $1b, $13, $22, $11, $11, $11, $11, $13, $22, $13, $13, $11, $11, $1b, $22, $13, $13, $20, $17, $11, $1b, $22, $13, $13, $17, $23, $1a, $22, $22, $13, $13, $15, $11, $2e, $1f, $20, $17, $27, $58, $3c, $12, $12, $47
  .byte $22, $13, $13, $15, $20, $13, $13, $20, $13, $13, $17, $17, $13, $11, $23, $15, $13, $15, $17, $13, $11, $11, $6f, $15, $15, $20, $30, $4f, $4f, $11, $13, $17, $20, $37, $3f, $19, $3c, $3a, $13, $1b, $55, $4d, $2b, $1f, $2e, $28, $13, $13, $12, $2b, $12, $25, $16, $37, $13, $2f, $12, $1f, $16, $1a, $37, $13, $23, $27
  .byte $27, $14, $14, $10, $10, $15, $1a, $1f, $14, $1e, $14, $14, $18, $23, $1a, $65, $14, $1e, $18, $18, $15, $3c, $2e, $1c, $15, $18, $23, $17, $2a, $3f, $65, $14, $15, $20, $16, $3f, $16, $12, $23, $18, $15, $11, $1c, $12, $1c, $23, $18, $18, $15, $17, $1d, $1b, $17, $18, $18, $20, $14, $18, $14, $18, $18, $18, $2f, $4b
  .byte $12, $1a, $13, $15, $14, $10, $10, $10, $1a, $13, $20, $27, $14, $10, $10, $10, $15, $15, $17, $27, $14, $10, $10, $10, $18, $15, $20, $15, $14, $10, $10, $10, $18, $13, $15, $14, $18, $10, $10, $10, $13, $17, $1e, $18, $10, $10, $10, $10, $20, $14, $18, $10, $10, $10, $10, $10, $15, $40, $10, $10, $10, $10, $10, $10
  .byte $18, $14, $1c, $14, $15, $15, $18, $1e, $10, $18, $1c, $32, $14, $4b, $18, $14, $10, $15, $32, $3c, $2a, $11, $14, $18, $10, $18, $15, $30, $14, $16, $23, $18, $10, $10, $18, $4b, $18, $1a, $16, $15, $10, $10, $14, $20, $14, $15, $16, $8d, $10, $10, $15, $1b, $11, $18, $14, $14, $10, $10, $14, $1a, $1c, $17, $20, $18
  .byte $15, $14, $23, $1b, $13, $32, $28, $2e, $1e, $15, $15, $17, $20, $13, $22, $13, $14, $1e, $14, $15, $27, $15, $17, $20, $14, $14, $1e, $1e, $1e, $1e, $18, $15, $18, $14, $1e, $1e, $1e, $1e, $14, $1e, $18, $1e, $14, $15, $15, $14, $1e, $14, $18, $14, $27, $17, $17, $27, $15, $1e, $14, $27, $20, $13, $13, $13, $17, $15
  .byte $3f, $12, $12, $9e, $28, $16, $12, $3c, $3a, $1a, $4d, $74, $43, $52, $16, $12, $17, $13, $1a, $74, $12, $2b, $3f, $41, $15, $17, $17, $37, $55, $4d, $12, $1f, $1e, $15, $15, $2f, $13, $28, $2e, $3f, $14, $1e, $14, $15, $18, $8e, $17, $13, $1e, $1e, $14, $27, $68, $95, $73, $7a, $14, $1e, $1e, $15, $58, $68, $86, $6a
  .byte $23, $20, $20, $20, $13, $1b, $11, $11, $12, $55, $3c, $1b, $4b, $20, $20, $32, $5d, $12, $12, $12, $12, $12, $91, $1b, $2b, $5d, $67, $47, $36, $4d, $12, $12, $4d, $12, $1f, $65, $2b, $2e, $1c, $12, $28, $1a, $3f, $1f, $12, $12, $1a, $1c, $3d, $2f, $17, $23, $3c, $69, $13, $14, $6a, $6a, $87, $96, $17, $15, $18, $18
  .byte $63, $63, $32, $23, $13, $22, $22, $22, $1c, $3f, $3c, $1a, $63, $1b, $22, $13, $4b, $1a, $12, $1f, $2e, $32, $1b, $22, $12, $1a, $2e, $12, $19, $3c, $32, $11, $12, $12, $12, $12, $12, $11, $23, $1b, $12, $12, $12, $12, $1c, $23, $11, $13, $1b, $3f, $3f, $60, $32, $1b, $1b, $2a, $18, $15, $20, $13, $20, $15, $15, $17
  .byte $22, $22, $22, $22, $1b, $22, $13, $13, $13, $13, $22, $22, $13, $37, $37, $32, $22, $22, $1b, $11, $37, $60, $3c, $2e, $11, $11, $11, $37, $1c, $12, $12, $12, $11, $11, $13, $28, $19, $12, $12, $12, $13, $1a, $1d, $32, $1a, $19, $1f, $4e, $2a, $1b, $16, $1b, $11, $28, $16, $1a, $17, $15, $15, $2a, $20, $23, $14, $14
  .byte $13, $13, $1b, $1b, $22, $23, $20, $20, $37, $37, $20, $2f, $32, $99, $1a, $55, $60, $3c, $16, $12, $12, $24, $12, $12, $12, $12, $12, $24, $12, $2b, $2b, $12, $19, $12, $12, $24, $12, $12, $12, $24, $1a, $1c, $12, $12, $12, $12, $1c, $1a, $2f, $82, $1d, $2e, $3c, $23, $17, $2f, $18, $18, $18, $27, $2a, $8a, $87, $6a
  .byte $23, $3c, $55, $12, $12, $2b, $12, $1f, $12, $24, $12, $2b, $67, $65, $16, $32, $12, $36, $2b, $12, $19, $16, $13, $20, $12, $12, $52, $1c, $1a, $13, $17, $17, $25, $2e, $28, $28, $13, $17, $15, $15, $28, $13, $17, $8e, $18, $15, $14, $1e, $3d, $7a, $73, $94, $3d, $17, $15, $1e, $6a, $6a, $86, $7a, $17, $15, $1e, $1e
  .byte $2e, $28, $3a, $13, $13, $20, $17, $15, $13, $22, $20, $23, $17, $15, $15, $1e, $15, $15, $17, $27, $15, $14, $1e, $14, $15, $14, $18, $1e, $1e, $1e, $14, $14, $1e, $1e, $14, $1e, $1e, $1e, $1e, $14, $14, $14, $1e, $14, $15, $15, $14, $1e, $1e, $1e, $15, $27, $17, $17, $27, $14, $14, $15, $17, $13, $13, $13, $20, $27
  .byte $14, $1e, $18, $15, $15, $14, $3c, $14, $1e, $14, $18, $23, $20, $17, $3f, $18, $14, $1e, $18, $1c, $82, $68, $3a, $15, $14, $18, $2a, $1f, $14, $23, $14, $18, $18, $14, $19, $16, $5a, $13, $18, $10, $18, $8d, $1f, $15, $15, $23, $1e, $10, $18, $14, $14, $18, $11, $1b, $15, $10, $14, $18, $20, $17, $1c, $1a, $14, $10
  .byte $18, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $2f, $28, $19, $21, $11, $18, $10, $18, $2f, $1a, $1c, $19, $32, $18, $18, $14, $2f, $1b, $33, $19, $15, $15, $18, $14, $15, $13, $3c, $2a, $18, $15, $10, $40, $14, $17, $14, $18, $14, $1e, $10, $10, $10, $10, $10, $18, $14, $1e, $10, $10, $10, $10, $10, $10, $14, $14, $10, $10, $10, $10, $10, $10, $10, $14
  .byte $15, $20, $13, $13, $1b, $1b, $13, $17, $27, $13, $1b, $11, $4f, $3a, $37, $13, $17, $13, $11, $26, $19, $1c, $2e, $37, $17, $20, $11, $1a, $1c, $19, $1f, $19, $15, $20, $30, $11, $25, $1f, $1f, $1f, $15, $17, $13, $4f, $19, $1f, $3f, $33, $1e, $15, $27, $11, $1a, $1c, $5f, $1c, $14, $1e, $15, $27, $11, $3a, $1a, $1c
  .byte $27, $1e, $14, $1e, $27, $2a, $68, $8a, $20, $15, $1e, $1e, $1e, $15, $27, $17, $13, $20, $15, $15, $18, $1e, $1e, $18, $2e, $37, $13, $17, $17, $15, $15, $18, $25, $1c, $4f, $28, $13, $4b, $17, $2f, $12, $12, $1a, $1f, $1c, $3c, $1a, $28, $1c, $12, $3f, $3f, $24, $1f, $1c, $12, $1f, $1c, $12, $2e, $69, $26, $3f, $12
  .byte $98, $73, $88, $3d, $17, $18, $14, $1e, $80, $17, $17, $17, $15, $1e, $1e, $15, $15, $15, $15, $18, $1e, $1e, $15, $27, $18, $18, $18, $18, $15, $15, $2f, $1b, $2f, $2f, $2f, $17, $17, $32, $28, $28, $28, $28, $28, $3c, $2e, $21, $19, $1c, $19, $12, $12, $1f, $19, $19, $19, $4e, $12, $12, $24, $12, $12, $12, $1f, $25
  .byte $1e, $15, $2a, $15, $17, $23, $1b, $31, $15, $20, $13, $13, $30, $16, $1c, $21, $1b, $1b, $13, $37, $1a, $19, $19, $1f, $16, $11, $1d, $37, $21, $1f, $12, $12, $26, $1a, $30, $26, $19, $1f, $12, $12, $21, $4f, $3a, $1c, $25, $19, $12, $24, $1c, $11, $3a, $2e, $25, $19, $24, $12, $1c, $28, $37, $21, $19, $1f, $24, $12
  .byte $1b, $1b, $13, $17, $15, $15, $15, $18, $19, $28, $37, $1b, $13, $17, $2a, $2a, $1f, $19, $2e, $3a, $1b, $20, $22, $1b, $12, $19, $1c, $1a, $63, $13, $1b, $11, $12, $12, $25, $1c, $4f, $11, $11, $11, $12, $12, $19, $19, $28, $1b, $11, $1d, $24, $12, $19, $25, $26, $1b, $1d, $2d, $24, $12, $19, $25, $26, $30, $1b, $21
  .byte $1e, $1e, $1e, $14, $27, $58, $3d, $73, $15, $15, $1e, $1e, $14, $27, $17, $80, $13, $17, $15, $1e, $1e, $1e, $15, $15, $11, $11, $2f, $15, $15, $18, $18, $18, $1d, $1d, $1a, $23, $17, $17, $17, $2f, $31, $26, $33, $1c, $2e, $3c, $1a, $28, $26, $21, $25, $25, $19, $1f, $12, $12, $33, $25, $19, $1f, $12, $24, $12, $12
  .byte $73, $88, $68, $2a, $15, $1e, $14, $1e, $80, $17, $15, $15, $1e, $1e, $1e, $15, $15, $18, $1e, $1e, $18, $15, $15, $20, $18, $18, $15, $15, $17, $17, $13, $11, $2f, $2f, $17, $4b, $13, $28, $1a, $21, $28, $28, $28, $1a, $3f, $19, $16, $4e, $52, $12, $19, $1a, $16, $1f, $1a, $1f, $12, $12, $12, $2b, $1f, $28, $1f, $1f
  .byte $27, $17, $13, $1b, $1b, $13, $13, $20, $20, $13, $37, $3a, $4f, $11, $1b, $13, $13, $37, $16, $1c, $16, $37, $11, $13, $26, $1c, $1c, $19, $21, $1a, $11, $20, $1f, $1c, $12, $12, $25, $28, $1b, $20, $12, $1f, $19, $1f, $1c, $26, $13, $17, $19, $25, $25, $1c, $1a, $30, $27, $15, $1f, $19, $1a, $3a, $11, $27, $15, $1e
  .byte $15, $18, $11, $21, $19, $28, $2f, $10, $27, $18, $32, $19, $1c, $1a, $2f, $18, $17, $15, $15, $19, $33, $1b, $2f, $14, $17, $15, $18, $2a, $3c, $13, $15, $14, $15, $1e, $14, $18, $14, $17, $14, $40, $15, $1e, $14, $10, $10, $10, $10, $10, $1e, $14, $14, $18, $10, $10, $10, $10, $14, $14, $14, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $18, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $14, $14, $1e, $15, $27, $13, $11, $28, $18, $14, $14, $1e, $18, $15, $2f, $1b, $10, $14, $14, $14, $14, $1e, $15, $15, $10, $10, $14, $14, $14, $14, $1e, $1e, $10, $10, $10, $18, $14, $14, $14, $14, $10, $10, $10, $10, $14, $14, $14, $14, $10, $10, $10, $10, $10, $18, $14, $14, $10, $10, $10, $10, $10, $18, $14, $14
  .byte $21, $4e, $1f, $4e, $1c, $12, $2e, $2e, $11, $1a, $1c, $1c, $3f, $19, $69, $74, $2f, $1b, $11, $28, $1c, $1c, $3c, $28, $15, $15, $2f, $23, $1b, $1b, $20, $6f, $1e, $1e, $15, $15, $15, $17, $13, $11, $14, $14, $1e, $14, $15, $13, $11, $1d, $14, $1e, $14, $27, $2f, $11, $11, $11, $14, $1e, $15, $17, $1b, $1b, $11, $1b
  .byte $21, $24, $12, $12, $12, $1f, $25, $21, $1c, $1a, $25, $19, $12, $19, $1a, $1a, $20, $3a, $16, $19, $2e, $30, $3a, $4f, $1b, $11, $92, $28, $32, $32, $11, $32, $11, $1a, $11, $20, $6f, $1a, $1b, $28, $1a, $11, $17, $17, $16, $1a, $22, $3c, $30, $2a, $15, $30, $16, $30, $17, $2e, $20, $15, $20, $16, $1a, $1b, $27, $13
  .byte $26, $30, $26, $25, $19, $12, $24, $12, $3a, $1d, $4f, $19, $19, $12, $12, $24, $26, $3a, $28, $1c, $1f, $12, $24, $12, $16, $16, $32, $2e, $1f, $12, $24, $12, $19, $1f, $1a, $1a, $1f, $24, $12, $12, $12, $12, $1f, $5f, $19, $12, $24, $2b, $12, $12, $12, $1f, $12, $12, $24, $12, $2e, $12, $1f, $12, $12, $24, $12, $12
  .byte $24, $12, $1f, $4e, $26, $31, $1d, $2d, $12, $24, $1f, $4e, $26, $30, $1b, $11, $24, $12, $12, $1f, $1c, $28, $1b, $1b, $12, $24, $12, $19, $2e, $32, $28, $4f, $12, $24, $12, $1f, $1a, $1a, $25, $1c, $12, $24, $12, $1f, $5f, $1f, $24, $1f, $2b, $24, $12, $19, $1f, $24, $12, $12, $12, $12, $24, $12, $12, $12, $12, $2e
  .byte $33, $21, $25, $1f, $12, $12, $24, $12, $26, $21, $25, $19, $12, $1f, $5f, $21, $4f, $16, $2e, $1a, $19, $1c, $3a, $23, $1d, $3a, $28, $23, $32, $3c, $5f, $32, $3a, $1b, $1a, $11, $13, $23, $16, $4e, $3c, $22, $1b, $16, $11, $20, $20, $16, $3c, $2a, $17, $1a, $1a, $1b, $8c, $20, $1b, $14, $8f, $1a, $33, $11, $2f, $17
  .byte $12, $12, $12, $1f, $4d, $19, $1a, $25, $3f, $3f, $1c, $1a, $69, $1c, $1c, $28, $32, $1a, $2e, $1c, $1c, $28, $11, $1b, $17, $17, $23, $13, $13, $32, $2f, $15, $37, $13, $20, $17, $17, $15, $15, $1e, $21, $28, $1b, $22, $2f, $15, $14, $1e, $11, $16, $1a, $1b, $13, $15, $14, $1e, $1b, $1d, $30, $11, $1b, $20, $27, $14
  .byte $1c, $28, $11, $13, $27, $15, $1e, $14, $11, $1b, $2f, $15, $18, $1e, $14, $14, $2f, $15, $15, $1e, $14, $14, $14, $14, $15, $1e, $1e, $14, $14, $14, $18, $10, $1e, $14, $14, $14, $18, $18, $10, $10, $14, $14, $14, $14, $10, $10, $10, $10, $14, $14, $14, $14, $10, $10, $10, $10, $1e, $14, $14, $14, $18, $10, $10, $10
  .byte $14, $14, $10, $10, $10, $10, $10, $10, $14, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $44, $62, $42, $45, $48, $10, $10, $44, $49, $76, $42, $61, $29, $3e, $10, $45, $84, $42, $45, $6b, $51, $3e
  .byte $10, $10, $10, $10, $10, $18, $14, $14, $10, $10, $10, $10, $10, $18, $14, $14, $10, $10, $10, $10, $10, $10, $14, $14, $10, $10, $10, $10, $10, $10, $18, $14, $10, $10, $10, $10, $10, $10, $10, $14, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $1e, $14, $15, $20, $13, $1b, $1b, $23, $1e, $27, $17, $13, $22, $1b, $13, $17, $1e, $27, $17, $13, $13, $1b, $17, $15, $14, $27, $20, $17, $13, $1b, $15, $17, $14, $17, $15, $13, $13, $17, $17, $13, $14, $27, $17, $20, $13, $17, $20, $1b, $18, $17, $17, $15, $20, $17, $22, $1b, $10, $18, $27, $23, $2f, $17, $11, $1b
  .byte $15, $17, $1b, $16, $28, $11, $18, $2f, $17, $23, $37, $2e, $21, $16, $20, $18, $17, $13, $23, $11, $16, $16, $11, $17, $3d, $22, $13, $37, $1a, $1c, $16, $11, $1b, $13, $23, $13, $37, $52, $1c, $33, $11, $26, $16, $32, $32, $3a, $1a, $21, $1b, $3a, $52, $55, $1a, $32, $3a, $28, $15, $1b, $3a, $1c, $12, $2e, $37, $32
  .byte $1b, $63, $1b, $12, $24, $12, $12, $12, $17, $23, $17, $1c, $12, $24, $12, $12, $18, $27, $15, $1b, $12, $24, $12, $12, $20, $18, $15, $2a, $1c, $1f, $24, $12, $21, $20, $18, $14, $23, $1c, $1f, $1f, $1c, $11, $15, $18, $14, $13, $28, $1a, $1c, $26, $1b, $18, $18, $17, $20, $58, $37, $1c, $26, $20, $18, $18, $18, $18
  .byte $12, $12, $12, $24, $1f, $1a, $28, $1b, $12, $12, $12, $24, $1c, $2a, $23, $17, $12, $2b, $12, $12, $30, $15, $15, $18, $12, $24, $12, $1c, $17, $15, $18, $15, $1f, $1f, $2e, $30, $14, $18, $14, $11, $3c, $28, $1b, $17, $18, $18, $4b, $33, $3d, $2f, $14, $18, $18, $8f, $16, $28, $18, $18, $18, $18, $15, $11, $21, $16
  .byte $2f, $18, $2a, $1a, $2e, $37, $23, $15, $18, $18, $11, $26, $11, $1a, $22, $20, $18, $32, $28, $1c, $2e, $3a, $1b, $22, $1d, $16, $33, $19, $26, $30, $1b, $13, $33, $11, $19, $16, $1a, $63, $13, $11, $19, $1c, $16, $28, $32, $32, $37, $30, $16, $16, $4f, $32, $3a, $1c, $1a, $11, $3a, $32, $1b, $55, $1f, $1a, $11, $20
  .byte $17, $11, $11, $11, $1b, $13, $17, $15, $15, $17, $13, $13, $22, $13, $20, $27, $20, $15, $15, $23, $1b, $22, $20, $15, $13, $23, $17, $2f, $13, $22, $13, $20, $11, $1a, $4b, $15, $13, $13, $17, $15, $11, $1d, $1b, $15, $23, $20, $20, $15, $6f, $16, $1a, $2a, $17, $17, $17, $27, $17, $1d, $16, $1b, $15, $20, $17, $17
  .byte $14, $1e, $14, $14, $18, $10, $10, $10, $14, $1e, $14, $14, $18, $10, $10, $10, $14, $1e, $14, $18, $10, $10, $10, $10, $27, $1e, $14, $10, $10, $10, $10, $10, $17, $14, $18, $10, $10, $10, $10, $10, $14, $18, $10, $10, $10, $10, $10, $10, $17, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $44, $62, $42, $45, $48, $10, $10, $44, $49, $76, $42, $61, $29, $3e, $10, $45, $84, $42, $45, $6b, $51, $3e, $10, $75, $59, $39, $6e, $70, $5c, $35
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $66, $10, $10, $10, $10, $10, $10, $61, $8b, $10, $10, $10, $10, $10, $29, $56, $85
  .byte $10, $75, $59, $39, $6e, $70, $5c, $35, $10, $10, $29, $29, $77, $35, $35, $46, $10, $10, $10, $18, $1e, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $6d, $49, $56, $34, $29, $35, $10, $10, $49, $49, $62, $50, $59, $34, $29, $90, $7d, $49, $50, $39, $34, $29, $53, $6b
  .byte $10, $10, $17, $17, $2a, $1b, $11, $11, $10, $10, $10, $17, $20, $13, $11, $16, $10, $10, $10, $18, $17, $23, $13, $16, $10, $10, $10, $10, $18, $17, $1b, $1a, $10, $10, $10, $10, $10, $27, $58, $11, $10, $10, $10, $10, $10, $10, $17, $32, $10, $10, $10, $10, $10, $10, $17, $20, $10, $10, $10, $10, $10, $10, $5a, $2a
  .byte $15, $17, $13, $37, $3c, $19, $1f, $2e, $2f, $18, $17, $2a, $13, $28, $2e, $1f, $1a, $15, $18, $15, $17, $20, $13, $28, $16, $17, $14, $1b, $2a, $15, $15, $17, $16, $3a, $2a, $16, $16, $1a, $23, $17, $1a, $16, $1a, $1a, $28, $1c, $19, $3c, $11, $21, $1a, $20, $20, $30, $26, $16, $13, $1b, $16, $11, $20, $15, $20, $13
  .byte $60, $37, $1a, $1a, $15, $18, $14, $14, $19, $19, $19, $1c, $1a, $15, $18, $14, $28, $28, $28, $1a, $11, $11, $20, $18, $22, $1b, $1b, $17, $17, $2a, $11, $11, $15, $15, $15, $17, $17, $2f, $8c, $17, $3a, $13, $1b, $32, $1a, $28, $11, $60, $19, $2e, $3c, $19, $1c, $1c, $2e, $1c, $1a, $1a, $26, $28, $11, $11, $13, $3d
  .byte $14, $14, $14, $18, $23, $16, $3a, $32, $14, $18, $18, $20, $91, $19, $2e, $1c, $18, $20, $11, $11, $11, $28, $28, $28, $11, $11, $23, $17, $17, $20, $1b, $13, $17, $15, $15, $17, $17, $15, $15, $15, $11, $11, $11, $1a, $28, $11, $13, $1b, $1c, $1c, $1c, $2e, $1c, $1c, $2e, $2e, $17, $58, $1b, $1b, $28, $26, $26, $28
  .byte $3a, $60, $55, $3f, $1a, $1b, $20, $15, $1f, $3f, $1a, $30, $23, $2f, $15, $15, $28, $30, $23, $17, $15, $18, $18, $2f, $20, $15, $15, $15, $23, $23, $15, $32, $15, $17, $30, $2e, $16, $30, $2a, $11, $37, $2e, $19, $2e, $28, $1a, $1a, $30, $1c, $2e, $28, $30, $17, $13, $1a, $1a, $1a, $13, $20, $15, $20, $11, $16, $1a
  .byte $58, $11, $1a, $11, $13, $17, $27, $18, $1b, $1a, $1a, $11, $22, $2a, $17, $10, $11, $31, $11, $1b, $23, $17, $10, $10, $11, $16, $11, $1b, $2a, $18, $10, $10, $1a, $31, $11, $20, $17, $10, $10, $10, $16, $11, $1b, $2a, $18, $10, $10, $10, $1a, $11, $22, $2a, $10, $10, $10, $10, $1d, $13, $4b, $18, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $46, $10, $40, $5b, $3b, $46, $10, $10, $3b
  .byte $10, $10, $29, $29, $77, $35, $35, $46, $10, $10, $10, $18, $1e, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $35, $93, $9a, $45, $34, $39, $4c, $49, $7e, $85, $9c, $34, $64, $34, $45, $49, $56, $7e, $45, $64, $59, $29, $34, $6d, $93, $50, $42, $34, $29, $39
  .byte $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $46, $10, $10, $10, $10, $10, $10, $10, $29, $39, $10, $10, $10, $10, $10, $10, $53, $29, $3b, $10, $10, $10, $10, $10, $72, $44, $6b, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $34, $6d, $45, $10, $10, $10, $10, $10, $34, $39, $50, $10, $10, $10, $10, $10, $29, $34, $39, $10, $10, $10, $10, $10, $3b, $29, $29, $10, $10, $10, $10, $10, $10, $3b, $29, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $34, $42, $50, $29, $72, $29, $79, $44, $48, $48, $39, $3b, $6c, $44, $51, $3e, $34, $53, $79, $4c, $54, $4c, $5c, $3e, $29, $34, $29, $48, $4c, $54, $54, $35, $29, $53, $39, $44, $7c, $54, $35, $10, $40, $5b, $3b, $66, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $81, $10, $10, $10, $10, $10, $10, $10, $1e, $10, $10, $10, $10, $10, $10, $10, $46, $10, $10, $40, $5b, $3b, $46, $10, $10, $10, $71, $42, $83, $34, $29, $3e, $10, $10, $7f, $42, $45, $29, $44, $48, $10, $10, $35, $34, $29, $51, $78, $35, $10, $10, $10, $3b, $39, $3e, $35, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $10, $10, $10, $10, $10, $10, $10, $17, $10, $10, $10, $10, $10, $10, $10, $5a, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $20, $1b, $11, $2d, $11, $23, $15, $18, $17, $20, $1b, $11, $16, $11, $1d, $20, $18, $27, $20, $32, $1d, $31, $16, $1a, $10, $18, $27, $20, $1b, $1b, $1d, $1a, $10, $10, $18, $2a, $2f, $2a, $13, $11, $10, $10, $10, $14, $17, $17, $17, $20, $10, $10, $10, $10, $10, $15, $14, $27, $10, $10, $10, $10, $10, $10, $18, $40
  .byte $15, $4b, $32, $32, $17, $18, $18, $18, $15, $18, $15, $15, $15, $15, $17, $20, $11, $32, $2a, $3d, $1b, $11, $11, $1a, $16, $16, $1a, $5f, $21, $16, $1a, $1a, $11, $1d, $1a, $1a, $1a, $1d, $1b, $13, $23, $13, $22, $22, $4b, $23, $17, $2a, $17, $27, $2a, $2a, $14, $5a, $5a, $10, $10, $40, $10, $40, $10, $10, $10, $10
  .byte $15, $18, $18, $18, $2f, $23, $1b, $2a, $23, $2f, $15, $15, $15, $15, $15, $15, $1a, $11, $11, $32, $2a, $4b, $2a, $32, $31, $1a, $16, $16, $16, $16, $1a, $16, $1b, $1b, $13, $11, $1d, $1a, $1a, $11, $17, $2a, $17, $2a, $13, $22, $22, $22, $10, $10, $5a, $5a, $14, $2a, $17, $2a, $10, $10, $10, $10, $10, $10, $40, $10
  .byte $15, $18, $15, $4b, $11, $1a, $16, $30, $15, $20, $1b, $11, $31, $21, $30, $11, $11, $1a, $1a, $16, $1a, $1b, $11, $1b, $16, $16, $1a, $11, $11, $1b, $22, $4b, $1d, $11, $13, $13, $23, $13, $2a, $18, $13, $20, $23, $20, $3d, $27, $18, $10, $17, $27, $2a, $15, $15, $10, $10, $10, $10, $40, $10, $10, $10, $10, $10, $10
  .byte $1b, $13, $17, $10, $10, $10, $10, $10, $1b, $4b, $5a, $10, $10, $10, $10, $10, $13, $17, $10, $10, $10, $10, $10, $10, $17, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $71, $42, $83, $34, $29, $3e, $10, $3b, $7f, $42, $45, $29, $44, $48, $10, $71, $35, $34, $29, $51, $78, $35, $10, $10, $10, $3b, $39, $3e, $35, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $34, $39, $50, $59, $39, $6e, $6c, $6c, $29, $34, $39, $29, $53, $51, $70, $35, $29, $29, $29, $29, $34, $72, $3e, $4c, $10, $89, $29, $29, $29, $39, $3e, $35, $10, $10, $10, $66, $3b, $5b, $1e, $5e, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
  .byte $44, $51, $3e, $10, $10, $10, $10, $10, $4c, $5c, $35, $10, $10, $10, $10, $10, $54, $54, $46, $10, $10, $10, $10, $10, $35, $46, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
end_of_tile_pixel_data:
