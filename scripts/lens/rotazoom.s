; == Very crude PoC of a 128x128px tilemap rotation ==

; To build: cl65 -t cx16 -o ROTAZOOM.PRG rotazoom.s
; To run: x16emu.exe -prg ROTAZOOM.PRG -run -ram 2048

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

    jsr copy_palette_from_index_0
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

; OLD    lda #$40                 ; 2:1 scale (320 x 240 pixels on screen)
    lda #$20                 ; 4:1 scale (160 x 120 pixels on screen)
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
    
    
copy_palette_from_index_0:

    ; Starting at palette VRAM address
    
    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    ; We start at color index 0 of the palette 
    lda #<(VERA_PALETTE)
    sta VERA_ADDR_LOW
    lda #>(VERA_PALETTE)
    sta VERA_ADDR_HIGH

    ; HACK: we know we have more than 128 colors to copy (meaning: > 256 bytes), so we are just going to copy 128 colors first
    
; FIXME: do we *actually* have more than 128 colors?
; FIXME: do we *actually* have more than 128 colors?
; FIXME: do we *actually* have more than 128 colors?
    
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
    ; ora #%00000010   ; clip = 1 -> we are REPEATING. So no clipping.
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

    ; Y position
    lda #128
    sta Y_SUB_PIXEL
    lda #14
    sta Y_SUB_PIXEL+1
    
    ; X position
    lda #128
    sta X_SUB_PIXEL
    lda #256-16
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
;    cpx #200             ; nr of row we draw
    cpx #100             ; nr of row we draw
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
; OLD    cpx #320/4
    cpx #160/4
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
  .byte $34, $02
  .byte $56, $04
  .byte $68, $05
  .byte $79, $06
  .byte $79, $07
  .byte $68, $06
  .byte $57, $04
  .byte $46, $03
  .byte $34, $02
  .byte $8a, $08
  .byte $57, $05
  .byte $35, $03
  .byte $00, $03
  .byte $00, $03
  .byte $45, $03
  .byte $9b, $08
  .byte $00, $02
  .byte $10, $04
  .byte $20, $05
  .byte $21, $06
  .byte $21, $06
  .byte $31, $07
  .byte $32, $07
  .byte $10, $05
  .byte $10, $04
  .byte $10, $04
  .byte $42, $07
  .byte $42, $08
  .byte $43, $08
  .byte $53, $09
  .byte $53, $09
  .byte $01, $00
  .byte $23, $02
  .byte $12, $01
  .byte $11, $00
  .byte $46, $04
  .byte $8a, $07
  .byte $67, $05
  .byte $34, $03
  .byte $78, $06
  .byte $22, $01
  .byte $11, $01
  .byte $23, $01
  .byte $00, $01
  .byte $31, $06
  .byte $64, $0a
  .byte $75, $0b
  .byte $86, $0b
  .byte $75, $0a
  .byte $00, $04
  .byte $97, $0c
  .byte $64, $09
  .byte $21, $05
  .byte $53, $08
  .byte $32, $06
  .byte $10, $03
  .byte $54, $09
  .byte $76, $0b
  .byte $65, $0a
  .byte $a8, $0d
  .byte $98, $0c
  .byte $a9, $0d
  .byte $86, $0c
  .byte $b9, $0d
  .byte $b9, $0e
  .byte $00, $05
  .byte $ba, $0e
  .byte $10, $06
  .byte $20, $07
  .byte $30, $07
  .byte $60, $0a
  .byte $30, $08
  .byte $40, $08
  .byte $a0, $0d
  .byte $d0, $0f
  .byte $90, $0c
  .byte $d0, $0e
  .byte $b0, $0e
  .byte $40, $09
  .byte $b0, $0d
  .byte $c0, $0e
  .byte $80, $0b
  .byte $70, $0b
  .byte $41, $09
  .byte $ca, $0e
  .byte $cb, $0e
  .byte $cb, $0f
  .byte $41, $08
  .byte $60, $09
  .byte $60, $0b
  .byte $20, $06
  .byte $89, $07
  .byte $35, $02
end_of_palette_data:


tile_map_data:
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $01, $02, $03, $04, $00, $05, $06, $07, $08, $09, $0a, $0b, $00, $0c, $0d, $0e,    $01, $02, $03, $04, $00, $05, $06, $07, $08, $09, $0a, $0b, $00, $0c, $0d, $0e
  .byte $00, $0f, $10, $00, $11, $12, $13, $14, $15, $16, $17, $18, $19, $00, $1a, $1b,    $00, $0f, $10, $00, $11, $12, $13, $14, $15, $16, $17, $18, $19, $00, $1a, $1b
  .byte $00, $1c, $1d, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a,    $00, $1c, $1d, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a
  .byte $00, $00, $00, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $33, $34, $35, $00, $00,    $00, $00, $00, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $33, $34, $35, $00, $00
  .byte $00, $00, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $00, $00,    $00, $00, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $00, $00
  .byte $00, $00, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $00, $00,    $00, $00, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $00, $00
  .byte $00, $00, $00, $4e, $4f, $50, $51, $52, $53, $54, $55, $56, $57, $58, $00, $00,    $00, $00, $00, $4e, $4f, $50, $51, $52, $53, $54, $55, $56, $57, $58, $00, $00
  .byte $00, $00, $00, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $00, $00,    $00, $00, $00, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $00, $00
  .byte $00, $00, $00, $00, $64, $65, $66, $67, $68, $69, $6a, $6b, $6c, $00, $00, $00,    $00, $00, $00, $00, $64, $65, $66, $67, $68, $69, $6a, $6b, $6c, $00, $00, $00
  .byte $00, $6d, $6e, $00, $00, $6f, $70, $71, $72, $73, $74, $75, $00, $00, $76, $77,    $00, $6d, $6e, $00, $00, $6f, $70, $71, $72, $73, $74, $75, $00, $00, $76, $77
  .byte $78, $79, $7a, $00, $00, $7b, $7c, $7d, $7e, $7f, $80, $81, $00, $82, $83, $84,    $78, $79, $7a, $00, $00, $7b, $7c, $7d, $7e, $7f, $80, $81, $00, $82, $83, $84
  .byte $85, $86, $87, $88, $00, $00, $89, $8a, $8b, $8c, $8d, $00, $00, $8e, $8f, $90,    $85, $86, $87, $88, $00, $00, $89, $8a, $8b, $8c, $8d, $00, $00, $8e, $8f, $90
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                                                                                           
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $01, $02, $03, $04, $00, $05, $06, $07, $08, $09, $0a, $0b, $00, $0c, $0d, $0e,    $01, $02, $03, $04, $00, $05, $06, $07, $08, $09, $0a, $0b, $00, $0c, $0d, $0e
  .byte $00, $0f, $10, $00, $11, $12, $13, $14, $15, $16, $17, $18, $19, $00, $1a, $1b,    $00, $0f, $10, $00, $11, $12, $13, $14, $15, $16, $17, $18, $19, $00, $1a, $1b
  .byte $00, $1c, $1d, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a,    $00, $1c, $1d, $1e, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a
  .byte $00, $00, $00, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $33, $34, $35, $00, $00,    $00, $00, $00, $2b, $2c, $2d, $2e, $2f, $30, $31, $32, $33, $34, $35, $00, $00
  .byte $00, $00, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $00, $00,    $00, $00, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $00, $00
  .byte $00, $00, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $00, $00,    $00, $00, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $00, $00
  .byte $00, $00, $00, $4e, $4f, $50, $51, $52, $53, $54, $55, $56, $57, $58, $00, $00,    $00, $00, $00, $4e, $4f, $50, $51, $52, $53, $54, $55, $56, $57, $58, $00, $00
  .byte $00, $00, $00, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $00, $00,    $00, $00, $00, $59, $5a, $5b, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $00, $00
  .byte $00, $00, $00, $00, $64, $65, $66, $67, $68, $69, $6a, $6b, $6c, $00, $00, $00,    $00, $00, $00, $00, $64, $65, $66, $67, $68, $69, $6a, $6b, $6c, $00, $00, $00
  .byte $00, $6d, $6e, $00, $00, $6f, $70, $71, $72, $73, $74, $75, $00, $00, $76, $77,    $00, $6d, $6e, $00, $00, $6f, $70, $71, $72, $73, $74, $75, $00, $00, $76, $77
  .byte $78, $79, $7a, $00, $00, $7b, $7c, $7d, $7e, $7f, $80, $81, $00, $82, $83, $84,    $78, $79, $7a, $00, $00, $7b, $7c, $7d, $7e, $7f, $80, $81, $00, $82, $83, $84
  .byte $85, $86, $87, $88, $00, $00, $89, $8a, $8b, $8c, $8d, $00, $00, $8e, $8f, $90,    $85, $86, $87, $88, $00, $00, $89, $8a, $8b, $8c, $8d, $00, $00, $8e, $8f, $90
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
end_of_tile_map_data:


tile_pixel_data:
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $00, $00, $00, $00, $00, $00, $21, $00, $00, $00, $00, $00, $00, $00, $09, $00, $00, $00, $00, $00, $00, $00, $21, $00, $00, $00, $00, $00, $00, $00, $22
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $21, $27, $27, $21, $29, $23, $24, $05, $25, $05, $06, $03, $26, $0b, $25, $0a, $0a, $0a, $05, $06, $26, $04, $05, $0a, $25, $05, $06, $0b, $0b, $06, $06, $05, $06, $28, $0b, $08, $08, $03, $03, $06, $0b, $02, $0f, $09, $0c, $0b, $0b, $26, $03, $07, $08, $0c, $09
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $29, $00, $00, $00, $00, $00, $00, $07, $02, $22, $00, $00, $00, $21, $09, $02, $24, $0f, $00, $00, $02, $05, $04, $02, $0f, $0f, $00, $29, $06, $05, $06, $0f, $0f, $0c, $00, $2a, $02, $26, $02, $09, $09, $09, $00, $00, $2b, $0f, $08
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $22, $00, $00, $00, $00, $00, $00, $26, $02, $22, $00, $00, $00, $00, $00, $02, $24, $29, $00, $00, $00, $00, $00, $09, $09, $22, $00, $00, $00, $00, $00, $0c, $29, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $11, $1a, $35, $00, $00, $11, $1a, $13, $2d, $17, $1c, $11, $1a, $35, $2d, $17, $36, $1f, $34
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $11, $0e, $1a, $1a, $2c, $0e, $18, $15, $2d, $17, $1b, $36, $15, $17, $1c, $1f, $34, $2e, $31, $2f, $1f, $39, $34, $2e, $31, $2f, $2f, $30, $2e, $2e, $3b, $31, $2f, $30, $30, $33
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $2c, $1a, $1a, $18, $18, $18, $35, $15, $16, $1c, $1f, $34, $31, $31, $2e, $31, $30, $30, $33, $3d, $3c, $3c, $30, $30, $33, $3c, $3c, $3e, $40, $43, $33, $3d, $3c, $3e, $41, $41, $43, $43, $33, $3c, $40, $40, $43, $55, $43, $56
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $13, $13, $35, $35, $35, $35, $13, $13, $31, $2f, $2f, $2f, $2f, $2f, $31, $31, $3c, $3e, $3e, $3e, $3e, $3c, $3d, $33, $43, $41, $43, $43, $43, $40, $3e, $3c, $55, $55, $55, $55, $55, $55, $43, $41, $55, $55, $56, $56, $55, $56, $55, $55
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $18, $1a, $1a, $1a, $11, $2c, $00, $31, $2e, $39, $36, $1b, $2d, $13, $1a, $33, $30, $30, $30, $2f, $2e, $39, $1f, $3c, $3c, $33, $33, $33, $33, $30, $30, $3c, $3e, $3c, $3d, $33, $33, $33, $30, $43, $40, $3c, $3c, $3d, $33, $33, $33
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $1a, $11, $2c, $00, $00, $00, $00, $00, $1c, $16, $13, $1a, $1a, $11, $11, $00, $30, $31, $34, $1d, $1b, $16, $15, $18, $30, $30, $30, $31, $34, $1f, $36, $1b, $33, $30, $30, $30, $2f, $3b, $34, $39
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $1a, $11, $00, $00, $00, $00, $00, $00, $2d, $13, $1a, $38, $2c, $00, $00, $00, $36, $1b, $15, $35, $18, $1a, $2c, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $03, $06, $0b, $0f, $00, $00, $22, $03, $05, $05, $0b, $02, $00, $00, $22, $03, $06, $07, $0f, $0f, $00, $00, $00, $0f, $07, $02, $0c, $09, $00, $00, $00, $00, $22, $29, $22, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $0b, $05, $05, $00, $00, $20, $03, $0a, $0a, $0a, $5c, $00, $00, $07, $05, $25, $0a, $0a, $05, $29, $00, $06, $28, $05, $05, $05, $05, $22, $00, $06, $06, $28, $06, $26, $07, $00, $00, $07, $26, $0b, $06, $07, $24, $00, $00, $09, $0b, $0b, $0b, $26, $07
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $06, $0b, $27, $20, $00, $00, $00, $00, $28, $03, $0b, $02, $21, $00, $00, $00, $03, $03, $0b, $02, $08, $20, $00, $00, $0b, $02, $07, $24, $08, $29, $00, $00, $0f, $0f, $0f, $0f, $0f, $29, $00, $00, $0c, $09, $0f, $09, $0c, $22, $00, $00, $24, $0f, $09, $09, $09, $00, $00, $00
  .byte $09, $07, $0b, $0b, $0b, $02, $0f, $09, $00, $22, $27, $24, $02, $24, $0f, $09, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $00, $02, $05, $25, $05, $00, $00, $00, $21, $04, $25, $0a, $04, $00, $00, $00, $21, $05, $04, $03, $0f
  .byte $09, $09, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $20, $00, $00, $00, $00, $00, $00, $26, $0f, $20, $00, $00, $00, $00, $00, $07, $08, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $2c, $1a, $00, $00, $00, $00, $00, $11, $1a, $15, $00, $00, $00, $00, $11, $18, $15, $17, $00, $00, $00, $11, $18, $15, $17, $1c, $00, $00, $11, $18, $15, $17, $1c, $36, $00, $00, $1a, $15, $17, $1c, $36, $1f, $00, $1a, $13, $16, $17, $1c, $1f, $1f, $11, $18, $15, $17, $1c, $36, $1f, $1f
  .byte $13, $15, $17, $1d, $1f, $34, $34, $2e, $17, $1c, $36, $1f, $34, $2e, $3b, $31, $1c, $36, $1f, $34, $2e, $3b, $31, $31, $1f, $34, $34, $2e, $3b, $31, $31, $31, $1f, $34, $2e, $2e, $31, $31, $2f, $2f, $34, $2e, $2e, $3b, $31, $31, $2f, $2f, $34, $2e, $3b, $3b, $31, $2f, $2f, $2f, $34, $2e, $3b, $31, $31, $31, $2f, $30
  .byte $3b, $31, $2f, $2f, $30, $30, $33, $33, $31, $2f, $2f, $30, $30, $33, $33, $3d, $2f, $30, $30, $30, $30, $33, $33, $3d, $2f, $2f, $30, $30, $33, $33, $33, $3c, $2f, $2f, $30, $30, $33, $33, $3d, $3c, $30, $30, $30, $30, $33, $33, $3d, $3c, $30, $30, $30, $33, $33, $33, $3d, $3c, $30, $30, $30, $33, $33, $33, $33, $3c
  .byte $3c, $3e, $40, $41, $43, $55, $55, $57, $3c, $40, $41, $43, $55, $56, $56, $57, $3c, $40, $40, $43, $55, $56, $57, $57, $3e, $40, $43, $55, $55, $56, $57, $57, $3e, $40, $43, $43, $55, $55, $57, $57, $3e, $3e, $41, $55, $43, $55, $56, $57, $3c, $40, $40, $43, $43, $55, $55, $55, $3c, $3e, $41, $40, $41, $43, $43, $55
  .byte $57, $57, $57, $57, $56, $55, $55, $55, $57, $57, $57, $57, $57, $57, $57, $55, $57, $57, $57, $57, $57, $57, $57, $55, $57, $57, $57, $57, $57, $57, $57, $56, $57, $57, $57, $57, $57, $57, $57, $56, $57, $57, $57, $57, $57, $57, $57, $55, $57, $57, $57, $57, $57, $57, $56, $55, $55, $55, $55, $56, $55, $55, $43, $43
  .byte $55, $41, $40, $3c, $3c, $3d, $3d, $33, $55, $43, $41, $3e, $3c, $3c, $3d, $33, $57, $43, $41, $40, $3e, $3c, $3d, $33, $55, $55, $41, $40, $3e, $3c, $3d, $33, $56, $43, $41, $41, $3e, $3c, $3d, $33, $56, $43, $43, $41, $3e, $3c, $3c, $33, $55, $41, $41, $40, $3e, $3c, $3c, $3d, $43, $41, $40, $3e, $3e, $3c, $3c, $33
  .byte $33, $33, $30, $30, $30, $2f, $31, $34, $33, $33, $33, $30, $30, $2f, $31, $3b, $33, $33, $33, $30, $30, $2f, $2f, $31, $33, $33, $33, $30, $30, $2f, $2f, $31, $33, $33, $30, $30, $30, $2f, $2f, $31, $33, $33, $33, $30, $30, $2f, $2f, $31, $33, $33, $33, $30, $30, $30, $2f, $31, $33, $33, $30, $30, $30, $2f, $2f, $31
  .byte $34, $1f, $1c, $17, $15, $18, $1a, $0e, $2e, $34, $39, $36, $1b, $15, $18, $18, $2e, $2e, $34, $1f, $1d, $1b, $15, $35, $3b, $34, $34, $1f, $1f, $1d, $1b, $2d, $31, $2e, $2e, $34, $1f, $1f, $1d, $1b, $31, $3b, $2e, $34, $34, $1f, $1f, $1c, $31, $3b, $2e, $34, $34, $1f, $1f, $1d, $31, $3b, $3b, $2e, $34, $1f, $1f, $1f
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $1a, $2c, $00, $00, $00, $00, $00, $00, $18, $1a, $11, $00, $00, $00, $00, $00, $15, $18, $1a, $11, $00, $00, $00, $00, $17, $15, $18, $1a, $2c, $00, $00, $00, $1c, $16, $15, $18, $1a, $00, $00, $00, $1c, $1b, $2d, $13, $1a, $0e, $00, $00, $1c, $1c, $17, $15, $18, $1a, $00, $00
  .byte $00, $00, $00, $21, $24, $0b, $02, $02, $00, $00, $00, $00, $20, $29, $21, $21, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $26, $05, $28, $00, $00, $00, $22, $06, $0a, $0a, $05, $00, $00, $00, $21, $05, $05, $05, $26, $00, $00, $00, $29, $06, $06, $07, $0c
  .byte $08, $0f, $09, $09, $00, $00, $00, $00, $29, $22, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $07, $21, $00, $00, $00, $00, $00, $00, $0b, $24, $22, $00, $00, $00, $00, $00, $24, $0f, $29, $00, $00, $00, $00, $00, $09, $09, $22, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $20, $07, $0b, $02, $0c, $00, $00, $00, $00, $23, $0f, $0f, $0c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $09, $09, $2a, $00, $00, $00, $00, $00, $09, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13
  .byte $1a, $15, $17, $1b, $1d, $1f, $1f, $34, $18, $15, $17, $1c, $1d, $1f, $1f, $34, $13, $16, $1c, $1c, $36, $1f, $39, $34, $15, $17, $1c, $1c, $36, $1f, $34, $34, $15, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1c, $1c, $36, $1f, $34, $34, $2d, $17, $1c, $1c, $36, $1f, $39, $34
  .byte $34, $2e, $3b, $31, $31, $2f, $2f, $2f, $34, $2e, $3b, $31, $31, $2f, $2f, $30, $34, $2e, $3b, $2f, $31, $31, $2f, $2f, $34, $2e, $3b, $31, $2f, $31, $2f, $30, $34, $2e, $3b, $31, $31, $2f, $2f, $2f, $34, $2e, $3b, $31, $31, $2f, $31, $2f, $34, $2e, $3b, $3b, $31, $31, $31, $2f, $34, $2e, $3b, $3b, $31, $31, $31, $2f
  .byte $2f, $30, $30, $33, $33, $33, $33, $3c, $2f, $30, $30, $30, $33, $33, $33, $3d, $2f, $30, $30, $30, $33, $33, $33, $3d, $2f, $30, $30, $30, $33, $33, $33, $33, $30, $30, $30, $30, $30, $30, $33, $33, $2f, $30, $30, $30, $30, $30, $33, $33, $2f, $2f, $30, $30, $30, $30, $30, $30, $2f, $30, $2f, $30, $30, $30, $30, $33
  .byte $3c, $3c, $3e, $3e, $3e, $41, $41, $43, $3c, $3c, $3c, $3e, $3e, $3e, $40, $40, $3c, $3c, $3c, $3c, $3e, $3e, $3e, $3e, $3d, $3c, $3c, $3c, $3c, $3e, $3c, $3c, $3d, $3c, $33, $3c, $3c, $3c, $3c, $3c, $33, $3d, $3d, $3c, $3d, $3c, $3c, $3c, $33, $33, $33, $33, $3c, $3d, $3d, $3c, $30, $33, $33, $33, $3d, $3d, $3c, $3d
  .byte $43, $43, $43, $43, $55, $55, $43, $41, $40, $41, $41, $40, $41, $41, $40, $41, $40, $40, $40, $40, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3c, $3c, $3e, $3c, $3e, $3c, $3c, $3c, $3e, $3c, $3c, $3c, $3c, $3c, $3c, $3c, $3c, $3d, $3c, $3d, $3c, $3c, $3c, $3d, $3c, $3d, $3c, $3d, $3c, $3c, $3c, $3c, $3c
  .byte $40, $40, $3e, $3e, $3e, $3c, $3d, $33, $3e, $3e, $3e, $3e, $3c, $3c, $33, $33, $3c, $3e, $3e, $3c, $3c, $3d, $33, $33, $3e, $3c, $3c, $3c, $3d, $3d, $33, $33, $3c, $3c, $3c, $3d, $33, $33, $33, $33, $3c, $3c, $3c, $3d, $33, $33, $33, $30, $3c, $3d, $33, $33, $33, $30, $30, $30, $3d, $3d, $33, $33, $33, $30, $30, $30
  .byte $33, $33, $30, $30, $2f, $30, $2f, $31, $33, $33, $30, $30, $30, $2f, $2f, $31, $33, $30, $30, $30, $2f, $2f, $2f, $31, $33, $30, $30, $30, $2f, $2f, $31, $31, $30, $30, $30, $2f, $2f, $2f, $2f, $31, $30, $30, $30, $30, $2f, $2f, $2f, $31, $30, $30, $30, $2f, $2f, $2f, $31, $31, $30, $30, $30, $30, $2f, $31, $31, $31
  .byte $31, $3b, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $34, $34, $1f, $1f, $31, $31, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $34, $34, $1f, $1f, $31, $31, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $34, $34, $1f, $1f, $31, $3b, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $2e, $34, $34, $1f
  .byte $36, $1c, $1b, $2d, $35, $1a, $1a, $00, $36, $1c, $1c, $17, $15, $18, $1a, $2c, $1f, $1d, $1c, $1b, $16, $13, $1a, $11, $1f, $1d, $1c, $1c, $17, $15, $13, $1a, $1f, $36, $1c, $1c, $17, $16, $15, $18, $1f, $36, $1d, $1c, $1b, $17, $2d, $18, $1f, $36, $1d, $1c, $1b, $17, $2d, $35, $1f, $36, $1d, $1c, $1b, $17, $2d, $15
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $00, $18, $2c, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $09, $07, $24, $0f, $00, $00, $00, $00, $00, $22, $29, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $09, $09, $00, $00, $00, $00, $00, $00, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $35, $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $11, $18, $00, $0e, $00, $00, $00, $00, $11, $18
  .byte $2d, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1b, $1c, $36, $1f, $1f, $34, $2d, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1b, $1c, $1d, $1f, $34, $34, $15, $17, $1b, $1c, $1c, $1f, $1f, $1f, $15, $16, $17, $1c, $1c, $36, $1f, $34, $15, $2d, $17, $1b, $1c, $1d, $1f, $1f, $15, $15, $16, $17, $1b, $1c, $36, $1f
  .byte $34, $2e, $3b, $3b, $31, $31, $31, $31, $34, $2e, $2e, $2e, $31, $31, $31, $31, $34, $2e, $2e, $3b, $31, $31, $31, $31, $34, $2e, $2e, $2e, $3b, $3b, $31, $31, $1f, $2e, $2e, $2e, $2e, $3b, $31, $31, $34, $34, $34, $2e, $2e, $2e, $3b, $31, $34, $34, $2e, $2e, $2e, $2e, $2e, $3b, $34, $34, $34, $2e, $2e, $2e, $3b, $2e
  .byte $2f, $2f, $30, $2f, $30, $30, $30, $30, $31, $2f, $2f, $2f, $2f, $30, $30, $30, $31, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $31, $31, $31, $2f, $2f, $2f, $2f, $2f, $2f, $31, $31, $31, $2f, $2f, $2f, $2f, $31, $31, $31, $31, $2f, $2f, $2f, $2f, $31, $31, $31, $31, $2f, $2f, $2f, $2f, $31, $3b, $31, $31, $31, $2f, $31, $2f
  .byte $30, $30, $33, $33, $33, $33, $33, $33, $30, $30, $30, $30, $30, $33, $33, $33, $30, $30, $30, $30, $30, $30, $30, $30, $2f, $2f, $2f, $30, $2f, $30, $30, $30, $2f, $2f, $2f, $2f, $2f, $2f, $30, $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $31, $30, $2f, $2f, $2f, $31, $31, $2f, $2f, $31, $2f, $2f, $2f
  .byte $33, $3d, $3d, $33, $33, $3d, $3d, $33, $3d, $33, $33, $33, $33, $3d, $33, $30, $33, $33, $33, $33, $33, $33, $33, $33, $30, $33, $33, $33, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $2f, $30, $2f, $30, $2f, $30, $30, $2f, $2f, $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $30, $2f, $2f, $2f, $2f
  .byte $33, $33, $33, $33, $33, $30, $30, $30, $33, $33, $33, $33, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $2f, $30, $30, $30, $2f, $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $31, $2f, $31, $31, $2f, $2f, $31, $2f, $31, $2f, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $31
  .byte $30, $30, $2f, $30, $2f, $31, $31, $31, $30, $30, $2f, $2f, $2f, $2f, $31, $31, $30, $2f, $2f, $2f, $31, $31, $31, $31, $2f, $2f, $2f, $31, $31, $31, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $2e, $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $3b, $3b, $3b, $3b, $2e, $2e, $2e
  .byte $3b, $31, $3b, $2e, $2e, $34, $1f, $1f, $31, $3b, $3b, $2e, $34, $34, $1f, $1f, $3b, $3b, $2e, $2e, $34, $34, $1f, $1f, $3b, $2e, $2e, $2e, $34, $34, $1f, $1f, $3b, $2e, $2e, $34, $34, $1f, $1f, $1f, $2e, $2e, $2e, $34, $34, $34, $1f, $1f, $2e, $2e, $34, $34, $34, $1f, $1f, $1f, $2e, $34, $34, $34, $34, $1f, $1f, $36
  .byte $1f, $36, $1d, $1c, $1c, $17, $2d, $15, $1f, $36, $1d, $1c, $1b, $17, $2d, $15, $1f, $1d, $1c, $1c, $1b, $17, $16, $15, $1f, $36, $1c, $1c, $1b, $17, $16, $15, $36, $1d, $1c, $1c, $17, $17, $2d, $15, $36, $1d, $1c, $17, $17, $16, $16, $13, $1d, $1c, $1c, $1b, $17, $16, $15, $18, $1c, $1c, $1c, $1b, $17, $2d, $15, $18
  .byte $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $2c, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $0e, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $2c, $1a, $00, $00, $00, $00, $00, $00, $0e, $18, $00, $00, $00, $00, $00, $00, $0e, $18
  .byte $0e, $15, $1a, $00, $00, $00, $2c, $18, $18, $2e, $1c, $0e, $00, $00, $2c, $1a, $2d, $2f, $31, $15, $11, $00, $2c, $1a, $2d, $30, $33, $34, $1a, $00, $2c, $1a, $16, $30, $33, $30, $1c, $11, $00, $0e, $17, $31, $33, $33, $31, $35, $2c, $0e, $16, $1d, $2f, $33, $30, $36, $1a, $0e, $2d, $2d, $17, $31, $33, $31, $2d, $1a
  .byte $13, $15, $2d, $17, $17, $1b, $1c, $1f, $13, $15, $15, $2d, $17, $17, $1c, $1d, $18, $15, $15, $2d, $16, $17, $17, $1c, $18, $13, $15, $15, $16, $17, $16, $17, $18, $18, $15, $15, $2d, $17, $17, $16, $1a, $18, $13, $15, $15, $1c, $36, $17, $1a, $1a, $18, $13, $15, $1d, $34, $1f, $1a, $1a, $1a, $18, $15, $36, $2e, $3b
  .byte $1f, $39, $1f, $34, $2e, $2e, $2e, $2e, $1f, $1f, $34, $34, $34, $2e, $2e, $2e, $36, $1f, $1f, $34, $34, $34, $2e, $2e, $1d, $1f, $1f, $1f, $34, $34, $34, $34, $1b, $1d, $1f, $1f, $1f, $34, $34, $34, $16, $1b, $1d, $1f, $1f, $1f, $34, $34, $1b, $16, $1c, $36, $1f, $1f, $1f, $1f, $2f, $1b, $17, $1c, $1d, $1f, $1f, $1f
  .byte $3b, $3b, $3b, $31, $31, $31, $31, $31, $2e, $2e, $3b, $31, $31, $2e, $31, $31, $3b, $2e, $3b, $2e, $31, $3b, $31, $31, $2e, $2e, $2e, $3b, $3b, $2e, $31, $31, $34, $34, $2e, $2e, $2e, $2e, $3b, $2e, $34, $34, $34, $2e, $2e, $2e, $2e, $2e, $34, $34, $34, $34, $34, $34, $2e, $2e, $1f, $1f, $1f, $1f, $34, $34, $34, $34
  .byte $31, $31, $2f, $31, $31, $31, $2f, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $31, $31, $31, $31, $31, $31, $31, $3b, $31, $2e, $3b, $3b, $31, $31, $31, $3b, $3b, $2e, $2e, $2e, $2e, $3b, $3b, $3b, $3b, $34, $2e, $2e, $2e, $3b, $2e, $3b, $2e
  .byte $2f, $2f, $2f, $2f, $2f, $31, $2f, $2f, $31, $31, $31, $2f, $31, $31, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $3b, $31, $31, $3b, $31, $3b, $31, $3b, $31, $31, $3b, $3b, $3b, $2e, $2e, $3b, $2e, $2e, $2e, $2e, $2e
  .byte $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $31, $3b, $3b, $3b, $31, $31, $31, $31, $3b, $3b, $3b, $31, $3b, $3b, $31, $3b, $31, $3b, $3b, $31, $3b, $2e, $31, $3b, $3b, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e
  .byte $31, $31, $3b, $31, $3b, $3b, $3b, $2e, $3b, $31, $31, $2e, $3b, $3b, $2e, $2e, $3b, $3b, $3b, $3b, $3b, $3b, $2e, $2e, $2e, $3b, $2e, $2e, $2e, $2e, $2e, $2e, $3b, $2e, $2e, $2e, $2e, $2e, $34, $34, $2e, $2e, $2e, $2e, $34, $34, $34, $34, $2e, $2e, $34, $34, $34, $34, $34, $1f, $34, $34, $34, $34, $34, $1f, $1f, $1f
  .byte $2e, $34, $34, $34, $1f, $1f, $36, $1d, $2e, $34, $34, $1f, $1f, $1f, $1d, $1c, $34, $34, $34, $1f, $1f, $1d, $1c, $1c, $2e, $34, $1f, $1f, $36, $1c, $1c, $17, $34, $39, $1f, $1f, $1d, $1c, $17, $16, $1f, $1f, $1f, $1d, $1d, $1b, $2d, $16, $1f, $1f, $1d, $1c, $1b, $2d, $17, $1d, $1f, $1d, $1c, $17, $2d, $16, $1d, $34
  .byte $1c, $1c, $17, $17, $2d, $15, $13, $1a, $1c, $17, $17, $16, $15, $15, $18, $1a, $17, $17, $16, $2d, $15, $13, $1a, $2c, $17, $16, $2d, $15, $35, $18, $1a, $00, $2d, $17, $17, $15, $18, $1a, $11, $00, $1b, $1b, $2d, $15, $1a, $1a, $00, $2c, $36, $17, $15, $18, $1a, $11, $0e, $1a, $36, $16, $13, $1a, $1a, $1a, $1a, $2d
  .byte $11, $00, $00, $1a, $15, $11, $00, $00, $00, $00, $0e, $1c, $2e, $18, $00, $00, $00, $11, $15, $31, $2f, $2d, $2c, $00, $00, $1a, $34, $33, $30, $2d, $0e, $00, $11, $1c, $30, $33, $30, $16, $1a, $00, $35, $31, $33, $33, $31, $17, $1a, $2c, $36, $30, $33, $2f, $1d, $16, $18, $2c, $31, $33, $31, $17, $2d, $2d, $18, $2c
  .byte $00, $00, $00, $00, $00, $00, $0e, $18, $00, $00, $00, $00, $00, $00, $2c, $1a, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $2d, $15, $1a, $35, $30, $33, $39, $15, $18, $16, $13, $1a, $1b, $33, $3a, $36, $1a, $15, $17, $18, $1a, $1f, $30, $33, $0e, $32, $15, $16, $18, $1a, $1c, $2e, $00, $11, $1a, $16, $15, $18, $1a, $15, $00, $00, $2c, $18, $1c, $2d, $1a, $1a, $00, $00, $00, $0e, $36, $31, $18, $15, $00, $00, $00, $2c, $37, $30, $2d, $36
  .byte $35, $18, $1a, $18, $16, $1f, $2f, $2f, $2e, $1b, $1a, $35, $1d, $2e, $30, $30, $33, $31, $15, $2d, $1f, $2f, $30, $33, $30, $2e, $15, $15, $39, $2e, $30, $33, $17, $15, $13, $35, $36, $2e, $31, $30, $1a, $1a, $1a, $18, $17, $1f, $2e, $2e, $18, $0e, $1a, $18, $15, $17, $1d, $1d, $2d, $0e, $0e, $1a, $18, $15, $15, $16
  .byte $31, $2e, $2d, $17, $1c, $1d, $1f, $1f, $30, $30, $31, $17, $17, $1c, $1d, $36, $3c, $33, $33, $3f, $1f, $16, $1b, $1c, $3c, $3c, $3d, $3d, $33, $1f, $16, $17, $33, $3c, $3e, $3e, $3c, $3f, $1f, $16, $2f, $33, $3d, $3c, $40, $41, $30, $2e, $1d, $1f, $3b, $30, $33, $3c, $43, $30, $16, $17, $1c, $36, $31, $33, $3c, $43
  .byte $1f, $1f, $1f, $1f, $1f, $34, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $36, $1f, $1f, $1f, $1f, $1f, $1f, $1c, $1d, $1d, $36, $36, $1f, $1f, $36, $16, $17, $1b, $1c, $1d, $36, $36, $36, $31, $1d, $16, $16, $17, $1c, $1f, $34, $2f, $33, $33, $2f, $1f, $1b, $17, $1b, $33, $3d, $3c, $3c, $33, $33, $30, $3b
  .byte $34, $34, $2e, $2e, $34, $2e, $2e, $2e, $1f, $34, $34, $34, $34, $2e, $34, $34, $1f, $1f, $1f, $1f, $1f, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $1d, $36, $1f, $1f, $1f, $1f, $1f, $39, $1f, $1f, $36, $36, $1d, $36, $36, $36, $2e, $3b, $31, $2e, $1f, $1f, $1d, $39, $1d, $36, $30, $33, $33, $2f, $34
  .byte $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $34, $34, $34, $34, $34, $34, $34, $34, $34, $1f, $34, $34, $34, $34, $34, $34, $1f, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $36, $36, $36, $36, $36, $1f, $1f, $1c, $1c, $1c, $1c, $1b, $1c, $1c, $1d, $1f, $1d, $1c, $1c, $1d, $36, $1f, $1f
  .byte $2e, $2e, $2e, $2e, $34, $34, $2e, $34, $34, $34, $2e, $34, $34, $34, $1f, $34, $34, $34, $34, $34, $34, $34, $1f, $1f, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $36, $1f, $1d, $1d, $1d, $1d, $36, $1d, $36, $36, $1f, $1f, $39, $39, $1d, $1b, $17, $2e, $2e, $3b, $34, $1f, $34, $31, $30
  .byte $34, $34, $34, $34, $34, $1f, $1f, $36, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1d, $1f, $1f, $1f, $1f, $1f, $36, $1c, $1b, $1f, $1f, $36, $36, $1c, $1c, $1b, $16, $1f, $36, $1c, $1b, $1b, $16, $17, $34, $1c, $1b, $16, $16, $1d, $31, $3f, $3d, $1b, $1f, $2f, $33, $33, $3d, $3c, $40, $33, $33, $33, $3c, $3c, $3e, $41, $3c
  .byte $1d, $1c, $17, $2d, $17, $1f, $34, $2e, $1c, $17, $2d, $17, $34, $30, $2f, $3b, $16, $1b, $1f, $31, $33, $3c, $30, $31, $39, $30, $33, $3c, $3c, $3d, $30, $31, $33, $3d, $3e, $3c, $3c, $30, $2f, $34, $3c, $41, $3c, $33, $2f, $31, $34, $1d, $3e, $30, $31, $1f, $1d, $1c, $1b, $16, $2f, $39, $17, $16, $16, $2d, $15, $35
  .byte $1f, $16, $18, $1a, $18, $35, $35, $39, $34, $1d, $15, $1a, $17, $2e, $1d, $3a, $39, $1d, $2d, $2d, $31, $33, $33, $30, $1f, $1c, $15, $15, $2e, $30, $2e, $1c, $1c, $17, $35, $13, $15, $17, $35, $1a, $17, $15, $18, $1a, $1a, $1a, $1a, $1a, $15, $18, $18, $1a, $0e, $35, $17, $18, $18, $1a, $1a, $0e, $0e, $15, $31, $35
  .byte $33, $30, $35, $1a, $15, $2d, $18, $2c, $33, $1b, $1a, $13, $16, $18, $1a, $00, $1f, $1a, $18, $17, $15, $1a, $0e, $00, $1a, $18, $16, $15, $32, $1a, $00, $00, $18, $15, $16, $1a, $11, $00, $00, $00, $2d, $1c, $18, $2c, $00, $00, $00, $00, $39, $36, $1a, $00, $00, $00, $00, $00, $2e, $37, $2c, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $2c, $1a, $31, $2d, $2e, $00, $00, $00, $00, $0e, $1b, $18, $1d, $00, $00, $00, $00, $2c, $18, $16, $13, $00, $00, $00, $00, $2c, $15, $39, $18, $00, $00, $00, $00, $11, $17, $2f, $17, $00, $00, $00, $00, $38, $1d, $30, $2f, $00, $00, $00, $00, $35, $1f, $30, $30, $00, $00, $00, $0e, $15, $1f, $31, $30
  .byte $36, $1a, $0e, $0e, $1a, $1a, $1a, $18, $31, $17, $1a, $0e, $1a, $1a, $0e, $0e, $2e, $2e, $1a, $1a, $1a, $1a, $18, $1a, $15, $36, $1a, $1a, $18, $15, $15, $15, $0e, $18, $1a, $18, $15, $16, $1b, $17, $1d, $2d, $1a, $15, $17, $1b, $1f, $1d, $30, $35, $18, $2d, $36, $1f, $1f, $34, $31, $1a, $35, $17, $39, $2e, $31, $2f
  .byte $18, $35, $15, $15, $1c, $34, $33, $3c, $1a, $1a, $1a, $18, $15, $2d, $1f, $31, $1a, $1a, $0e, $32, $32, $18, $15, $17, $18, $1a, $1a, $32, $32, $18, $44, $46, $15, $13, $1a, $32, $32, $42, $45, $47, $1d, $15, $15, $18, $32, $32, $18, $48, $34, $1d, $16, $35, $1a, $32, $32, $18, $3b, $34, $1d, $17, $15, $18, $1a, $32
  .byte $3c, $40, $40, $41, $40, $40, $3c, $3c, $3f, $33, $33, $3c, $40, $41, $40, $3c, $1f, $2e, $2f, $30, $33, $33, $3c, $33, $49, $16, $1b, $1d, $34, $2f, $3f, $33, $4a, $4b, $4d, $50, $52, $47, $54, $1c, $47, $4c, $4e, $51, $4a, $53, $4f, $44, $45, $48, $4f, $4f, $4f, $48, $44, $32, $32, $18, $44, $44, $44, $42, $32, $32
  .byte $33, $33, $2f, $34, $31, $33, $33, $30, $30, $3d, $33, $33, $33, $33, $33, $30, $30, $30, $3d, $3d, $33, $3d, $33, $2f, $2f, $36, $31, $33, $33, $33, $30, $39, $2d, $18, $1a, $37, $34, $1f, $1c, $1d, $32, $32, $0e, $1a, $15, $16, $16, $15, $32, $1a, $1a, $35, $17, $17, $1b, $39, $1a, $18, $15, $1c, $1f, $1d, $34, $2f
  .byte $1f, $1f, $1f, $36, $36, $1f, $2e, $30, $1f, $1f, $1f, $1f, $1f, $34, $30, $33, $36, $34, $36, $34, $1f, $39, $2f, $33, $1f, $1f, $1c, $1f, $2e, $34, $34, $2f, $1b, $15, $15, $15, $1b, $36, $1c, $1f, $2d, $17, $1c, $17, $16, $15, $15, $15, $31, $2f, $2f, $2e, $39, $36, $17, $15, $30, $30, $30, $30, $2f, $2e, $1f, $1c
  .byte $33, $33, $33, $33, $33, $33, $33, $3d, $33, $33, $33, $33, $33, $3d, $3d, $3c, $33, $33, $30, $30, $33, $33, $3d, $33, $30, $30, $39, $34, $30, $33, $33, $3f, $1f, $1f, $2d, $1a, $18, $16, $1c, $58, $13, $1a, $1a, $0e, $32, $32, $44, $48, $15, $35, $18, $1a, $1a, $32, $32, $44, $16, $1b, $17, $15, $18, $1a, $32, $32
  .byte $3c, $3c, $3e, $3e, $3c, $33, $30, $31, $3c, $3d, $33, $33, $30, $2f, $2e, $1d, $33, $33, $30, $31, $2e, $1f, $1b, $15, $2f, $34, $1d, $1b, $16, $49, $46, $5b, $59, $52, $50, $4d, $4b, $50, $47, $45, $5a, $4a, $4d, $51, $4c, $47, $46, $18, $48, $4f, $4f, $4f, $48, $45, $18, $32, $42, $44, $44, $18, $18, $32, $32, $1a
  .byte $1d, $1b, $15, $13, $18, $18, $18, $1a, $2d, $15, $18, $1a, $1a, $1a, $0e, $0e, $18, $32, $32, $0e, $1a, $1a, $1a, $18, $18, $32, $32, $1a, $1a, $18, $15, $15, $18, $32, $1a, $1a, $13, $15, $17, $1b, $32, $32, $18, $15, $15, $1d, $1d, $1f, $32, $1a, $35, $16, $1d, $34, $34, $1f, $18, $15, $17, $1d, $34, $2e, $31, $2e
  .byte $1a, $1a, $0e, $0e, $1a, $1f, $2f, $13, $1a, $1a, $0e, $1a, $2d, $30, $36, $18, $1a, $1a, $1a, $1a, $30, $31, $35, $17, $15, $18, $1a, $1a, $34, $15, $18, $39, $16, $15, $18, $1a, $18, $0e, $17, $2f, $1b, $17, $15, $1a, $2d, $1d, $2f, $30, $1f, $36, $2d, $18, $35, $30, $30, $30, $34, $39, $17, $35, $1a, $31, $30, $31
  .byte $34, $1a, $2c, $00, $00, $00, $00, $00, $1b, $11, $00, $00, $00, $00, $00, $00, $18, $2c, $00, $00, $00, $00, $00, $00, $15, $2c, $00, $00, $00, $00, $00, $00, $17, $11, $00, $00, $00, $00, $00, $00, $1d, $38, $00, $00, $00, $00, $00, $00, $1f, $35, $00, $00, $00, $00, $00, $00, $1f, $15, $0e, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $1a, $18, $1b, $2e, $30, $00, $00, $00, $0e, $1a, $15, $1d, $2d, $00, $00, $00, $00, $00, $11, $11, $0e, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $2d, $1a, $18, $17, $1f, $2e, $2f, $30, $38, $1a, $13, $2d, $1f, $2e, $30, $30, $0e, $1a, $1a, $15, $1b, $34, $2f, $30, $0e, $1a, $1a, $18, $15, $1f, $31, $30, $00, $0e, $1a, $1a, $18, $15, $1f, $31, $00, $11, $38, $1a, $1a, $18, $15, $36, $00, $00, $11, $0e, $1a, $1a, $18, $15, $00, $00, $00, $0e, $0e, $1a, $0e, $1a
  .byte $30, $30, $3b, $39, $17, $2d, $35, $18, $33, $33, $30, $2f, $2e, $1f, $1c, $16, $33, $33, $3f, $33, $30, $31, $31, $2e, $30, $30, $33, $33, $33, $30, $33, $30, $2f, $30, $33, $3f, $33, $3f, $33, $33, $2e, $2f, $30, $30, $30, $33, $30, $30, $1c, $1f, $2e, $2f, $30, $30, $30, $33, $18, $15, $1c, $1f, $2e, $2f, $30, $30
  .byte $1a, $1a, $32, $32, $32, $32, $1a, $1a, $15, $13, $18, $18, $18, $18, $13, $15, $36, $1c, $1c, $1c, $1c, $1d, $1f, $34, $30, $30, $30, $30, $30, $30, $30, $30, $30, $3c, $33, $3d, $33, $33, $33, $33, $30, $33, $3c, $3c, $3c, $3d, $33, $33, $33, $33, $30, $30, $33, $33, $33, $33, $30, $30, $3a, $34, $31, $30, $33, $30
  .byte $35, $2d, $1f, $34, $34, $1f, $31, $30, $1b, $39, $31, $31, $2e, $2e, $2f, $33, $31, $30, $30, $2f, $2e, $31, $30, $33, $30, $30, $30, $2f, $3b, $31, $30, $33, $33, $30, $30, $2f, $3b, $31, $30, $33, $33, $30, $30, $31, $3b, $2f, $33, $33, $30, $2f, $2f, $2e, $2e, $2f, $30, $33, $31, $31, $31, $3b, $2e, $2f, $30, $33
  .byte $33, $33, $33, $33, $30, $2f, $2e, $1f, $33, $33, $3d, $33, $33, $30, $31, $39, $33, $33, $3d, $33, $33, $30, $2f, $2e, $33, $33, $3d, $33, $33, $30, $2f, $2e, $33, $3d, $3c, $33, $33, $30, $2f, $31, $33, $3d, $3c, $3d, $33, $30, $2f, $31, $33, $3d, $3c, $3d, $33, $30, $2f, $31, $33, $3c, $3d, $3d, $33, $33, $30, $2f
  .byte $1c, $1f, $1f, $36, $2d, $35, $1a, $1a, $1f, $34, $34, $2e, $1f, $17, $15, $13, $1f, $2e, $2e, $3b, $31, $31, $34, $1f, $34, $3b, $31, $2f, $2f, $30, $30, $30, $34, $31, $2f, $2f, $30, $30, $33, $33, $34, $31, $2f, $2f, $30, $33, $33, $33, $2e, $3b, $31, $2f, $30, $30, $33, $33, $2e, $34, $2e, $2f, $2f, $30, $30, $33
  .byte $32, $32, $32, $32, $1a, $1a, $18, $35, $18, $18, $18, $18, $13, $15, $16, $1c, $1d, $1c, $1c, $1c, $1c, $36, $2e, $2f, $30, $30, $30, $30, $30, $2f, $30, $33, $33, $3d, $3c, $3d, $33, $33, $3f, $30, $3d, $3c, $3c, $3c, $3c, $3c, $33, $33, $33, $3f, $33, $33, $33, $33, $30, $30, $2f, $31, $2e, $30, $30, $30, $30, $30
  .byte $2d, $17, $39, $2e, $30, $30, $30, $2f, $36, $2e, $2f, $30, $33, $33, $33, $2f, $30, $30, $3f, $33, $33, $33, $33, $2f, $30, $30, $33, $33, $30, $3f, $30, $31, $2f, $33, $33, $33, $30, $2f, $31, $1f, $30, $33, $33, $30, $2f, $2e, $36, $15, $30, $2f, $2f, $2e, $1f, $1c, $15, $1a, $2f, $2e, $1f, $1c, $15, $18, $1a, $0e
  .byte $2e, $1f, $17, $18, $1a, $2d, $30, $2e, $2e, $1f, $2d, $13, $1a, $1a, $2d, $1d, $2e, $1b, $15, $1a, $1a, $0e, $2c, $11, $1f, $15, $18, $1a, $1a, $0e, $00, $00, $15, $18, $1a, $1a, $0e, $11, $00, $00, $18, $1a, $1a, $0e, $0e, $00, $00, $00, $1a, $1a, $0e, $0e, $00, $00, $00, $00, $0e, $0e, $0e, $00, $00, $00, $00, $00
  .byte $1b, $18, $1a, $00, $00, $00, $00, $00, $15, $1a, $0e, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $0e, $0e, $1a, $1a, $00, $00, $00, $00, $00, $0e, $0e, $0e, $00, $00, $00, $00, $00, $2c, $0e, $0e, $00, $00, $00, $00, $00, $00, $11, $11, $00, $00, $00, $00, $00, $00, $2c, $11, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $1a, $1a, $18, $15, $1c, $1f, $2e, $2e, $1a, $1a, $1a, $1a, $18, $15, $16, $1b, $0e, $1a, $1a, $1a, $1a, $1a, $15, $15, $0e, $0e, $0e, $0e, $1a, $13, $13, $1c, $0e, $0e, $0e, $1a, $1a, $15, $2d, $36, $0e, $0e, $1a, $1a, $18, $15, $1b, $1f, $0e, $0e, $1a, $13, $15, $2d, $1c, $1d, $0e, $0e, $1a, $13, $15, $17, $1c, $1d
  .byte $34, $36, $1d, $39, $31, $2f, $2f, $34, $16, $1c, $34, $2e, $3b, $2e, $1d, $1f, $1c, $34, $2e, $2e, $39, $17, $1c, $3b, $39, $2e, $2e, $34, $17, $15, $2e, $31, $34, $34, $39, $17, $15, $36, $31, $31, $1f, $1f, $1b, $15, $16, $2e, $2f, $3b, $36, $1c, $15, $15, $1d, $31, $2f, $31, $1d, $15, $15, $17, $1d, $2e, $2f, $2f
  .byte $1f, $2e, $2e, $2f, $2e, $31, $33, $33, $34, $34, $31, $30, $2f, $2e, $30, $33, $39, $1f, $30, $33, $33, $31, $30, $33, $1b, $36, $33, $3d, $3d, $33, $30, $33, $16, $1c, $30, $33, $33, $33, $33, $33, $2d, $15, $1f, $2f, $31, $33, $3d, $3d, $36, $1a, $17, $1f, $17, $2e, $33, $3d, $3b, $15, $1a, $15, $15, $1c, $33, $33
  .byte $33, $3d, $3c, $33, $33, $33, $30, $31, $3d, $3c, $3c, $3d, $33, $33, $30, $2e, $3d, $3c, $3c, $3d, $3d, $33, $30, $31, $3d, $3c, $3c, $3c, $3d, $33, $30, $33, $3d, $3c, $3c, $3c, $3d, $33, $33, $3d, $3d, $3c, $3c, $3c, $3c, $3d, $3d, $33, $3c, $3c, $3c, $3c, $3c, $3c, $33, $31, $3d, $3c, $3c, $3c, $3c, $3d, $33, $1c
  .byte $34, $2e, $2e, $2e, $31, $3b, $2e, $30, $2f, $2f, $31, $1f, $2e, $2e, $1f, $1f, $33, $33, $30, $1f, $1f, $31, $2e, $1d, $3c, $3d, $33, $39, $2d, $34, $31, $2e, $3d, $33, $30, $1d, $18, $36, $31, $2e, $30, $2f, $1f, $15, $1a, $39, $31, $31, $1d, $1f, $17, $1a, $15, $2e, $2f, $31, $15, $15, $1a, $1a, $1f, $31, $2f, $31
  .byte $2f, $1f, $1b, $1d, $34, $2e, $31, $3b, $31, $2f, $39, $1c, $16, $16, $17, $17, $1b, $31, $30, $3b, $1f, $1c, $2d, $15, $2d, $1b, $2e, $2f, $31, $1f, $1c, $16, $1c, $15, $1c, $2e, $31, $2e, $36, $1c, $1f, $15, $15, $1f, $2e, $39, $1f, $1d, $1f, $17, $15, $16, $1f, $1f, $36, $1c, $1f, $1c, $17, $15, $15, $1b, $36, $1d
  .byte $39, $1c, $15, $18, $1a, $1a, $0e, $0e, $15, $18, $1a, $1a, $0e, $0e, $0e, $0e, $18, $1a, $1a, $0e, $0e, $0e, $11, $11, $15, $1a, $1a, $0e, $0e, $11, $11, $11, $15, $13, $1a, $38, $0e, $0e, $11, $11, $17, $13, $1a, $1a, $0e, $0e, $0e, $2c, $17, $15, $35, $1a, $1a, $0e, $0e, $00, $1c, $2d, $15, $1a, $38, $0e, $11, $00
  .byte $0e, $11, $2c, $00, $00, $00, $00, $00, $11, $2c, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $00, $02, $05, $25, $05, $00, $00, $00, $21, $04, $25, $0a, $04, $00, $00, $00, $21, $05, $04, $03, $0f, $00, $00, $00, $20, $07, $0b, $02, $0c, $00, $00, $00, $00, $23, $0f, $0f, $0c
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $20, $00, $00, $00, $00, $00, $00, $26, $0f, $20, $00, $00, $00, $00, $00, $07, $08, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00, $09, $09, $2a, $00, $00, $00, $00, $00, $09, $2a, $00, $00, $00, $00, $00, $00
  .byte $2c, $1a, $1a, $13, $15, $16, $1c, $1c, $00, $0e, $1a, $15, $2d, $17, $1b, $1c, $00, $2c, $1a, $35, $15, $16, $1c, $1c, $00, $00, $11, $13, $15, $17, $17, $17, $00, $00, $00, $38, $13, $2d, $2d, $15, $00, $00, $00, $00, $18, $15, $17, $17, $00, $00, $00, $00, $2c, $13, $2d, $1c, $00, $00, $00, $00, $00, $11, $15, $17
  .byte $17, $15, $2d, $17, $1c, $34, $31, $2f, $15, $16, $1c, $1c, $1c, $36, $2e, $30, $15, $1c, $34, $2e, $3b, $34, $39, $2e, $2d, $1d, $39, $34, $2f, $2f, $2e, $39, $1c, $1f, $16, $1d, $2e, $2f, $30, $2f, $1f, $34, $17, $2d, $36, $2e, $30, $30, $1f, $3b, $36, $18, $15, $1c, $1f, $31, $1d, $2e, $3b, $15, $1a, $13, $2d, $1c
  .byte $2f, $2e, $2d, $1a, $1a, $15, $31, $33, $30, $2f, $31, $1c, $1a, $1a, $1d, $30, $30, $2f, $2f, $31, $15, $0e, $18, $36, $34, $31, $2f, $2f, $39, $18, $0e, $35, $34, $34, $31, $30, $31, $1c, $1a, $0e, $33, $31, $34, $2e, $31, $31, $2d, $0e, $30, $33, $30, $30, $3a, $30, $2e, $18, $34, $31, $2f, $2f, $30, $2f, $31, $34
  .byte $33, $3c, $3c, $3c, $3c, $33, $2f, $15, $33, $33, $33, $33, $33, $30, $36, $1a, $2f, $30, $30, $30, $2f, $34, $13, $0e, $1c, $1f, $39, $1f, $1d, $2d, $0e, $0e, $18, $13, $13, $13, $1a, $0e, $0e, $18, $0e, $0e, $0e, $0e, $0e, $0e, $1a, $1f, $0e, $0e, $0e, $0e, $0e, $0e, $1b, $2f, $18, $0e, $0e, $0e, $18, $1d, $3b, $2f
  .byte $18, $1a, $18, $36, $31, $2f, $30, $31, $0e, $35, $34, $31, $2f, $30, $2f, $34, $1a, $1f, $2f, $2f, $2f, $2f, $31, $34, $17, $31, $2f, $30, $2f, $2e, $34, $1f, $34, $2f, $3b, $31, $34, $34, $2f, $30, $2f, $31, $2e, $39, $2e, $30, $33, $2f, $31, $2e, $31, $30, $30, $30, $2e, $36, $30, $30, $30, $30, $2e, $1f, $17, $35
  .byte $39, $1d, $1b, $17, $15, $15, $1d, $1c, $1f, $1f, $1f, $36, $1d, $15, $1b, $1b, $1f, $2e, $2e, $34, $2e, $16, $16, $1c, $31, $3b, $39, $34, $2e, $1d, $15, $1c, $31, $39, $1b, $1f, $31, $39, $2d, $15, $1f, $1c, $15, $1f, $3b, $2e, $1c, $17, $17, $13, $2d, $34, $31, $2e, $36, $1b, $18, $18, $1c, $2e, $31, $2e, $36, $17
  .byte $1b, $2d, $15, $1a, $1a, $0e, $00, $00, $1b, $2d, $15, $18, $1a, $2c, $00, $00, $1b, $15, $15, $1a, $0e, $00, $00, $00, $2d, $16, $15, $18, $00, $00, $00, $00, $16, $15, $18, $2c, $00, $00, $00, $00, $16, $13, $11, $00, $00, $00, $00, $00, $15, $38, $00, $00, $00, $00, $00, $00, $35, $2c, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $00, $02, $05, $25, $05, $00, $00, $00, $21, $04, $25, $0a, $04, $00, $00, $00, $21, $05, $04, $03, $0f, $00, $00, $00, $20, $07, $0b, $02, $0c, $00, $00, $00, $00, $23, $0f, $0f, $0c, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $21, $20, $00, $00, $00, $00, $00, $00, $26, $0f, $20, $00, $00, $00, $00, $00, $07, $08, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00, $09, $09, $2a, $00, $00, $00, $00, $00, $09, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $00, $00, $00, $00, $00, $00, $21, $00, $00, $00, $00, $00, $00, $00, $09, $00, $00, $00, $00, $00, $00, $00, $21
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $21, $27, $27, $21, $29, $23, $24, $05, $25, $05, $06, $03, $26, $0b, $25, $0a, $0a, $0a, $05, $06, $26, $04, $05, $0a, $25, $05, $06, $0b, $0b, $06, $06, $05, $06, $28, $0b, $08, $08, $03, $03, $06, $0b, $02, $0f, $09, $0c
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $29, $00, $00, $00, $00, $00, $00, $07, $02, $22, $00, $00, $00, $00, $00, $02, $24, $0f, $00, $00, $00, $00, $00, $02, $0f, $0f, $00, $00, $00, $00, $00, $0f, $0f, $0c, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $1a, $2d, $00, $00, $00, $00, $00, $00, $00, $18, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $1b, $34, $31, $1d, $18, $15, $15, $13, $16, $1f, $31, $2e, $15, $1f, $2e, $1f, $15, $36, $2e, $2f, $39, $3b, $31, $30, $1a, $2d, $34, $31, $31, $36, $1f, $2e, $2c, $15, $1f, $34, $2f, $31, $1d, $2d, $00, $1a, $16, $1d, $2e, $31, $2e, $1b, $00, $2c, $15, $17, $1f, $2e, $31, $2e, $00, $00, $38, $15, $1b, $1f, $34, $31
  .byte $15, $1c, $1f, $39, $34, $39, $1f, $1f, $17, $13, $15, $16, $16, $15, $13, $13, $3a, $34, $1c, $2d, $2d, $17, $1d, $36, $2f, $30, $30, $2e, $2e, $3b, $3a, $30, $36, $2e, $31, $30, $30, $30, $2f, $31, $18, $35, $1b, $1f, $2e, $2e, $34, $1d, $36, $15, $1a, $18, $15, $2d, $35, $1a, $3b, $2e, $1d, $17, $35, $35, $15, $17
  .byte $39, $1d, $17, $1d, $2e, $1f, $36, $1f, $15, $1c, $1d, $1d, $17, $15, $13, $35, $1c, $2d, $2d, $2d, $17, $36, $36, $1d, $30, $30, $30, $30, $30, $30, $30, $2f, $2e, $2e, $2e, $2e, $2e, $3b, $31, $30, $17, $15, $13, $13, $15, $2d, $1c, $34, $18, $13, $15, $35, $18, $18, $1a, $13, $1b, $1f, $34, $1f, $1d, $17, $15, $35
  .byte $34, $34, $1f, $1d, $17, $35, $35, $15, $15, $2d, $2d, $35, $15, $1b, $2e, $34, $17, $17, $17, $1f, $31, $30, $30, $31, $2e, $2e, $31, $30, $30, $2f, $2e, $36, $30, $30, $30, $31, $2e, $36, $2d, $1b, $2e, $2e, $1f, $17, $35, $35, $1c, $34, $2d, $15, $18, $18, $15, $1c, $34, $31, $35, $15, $17, $1d, $34, $2e, $31, $31
  .byte $13, $35, $1f, $2e, $3b, $34, $1c, $2d, $16, $1b, $34, $31, $31, $1f, $17, $18, $39, $2e, $2e, $31, $2e, $36, $2d, $2c, $2e, $3b, $31, $2e, $1f, $17, $18, $00, $2e, $31, $31, $34, $1d, $16, $2c, $00, $31, $2f, $2e, $1f, $1b, $1a, $00, $00, $31, $2e, $39, $1d, $2d, $2c, $00, $00, $2e, $34, $36, $17, $1a, $00, $00, $00
  .byte $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $03, $06, $0b, $0f, $00, $00, $22, $03, $05, $05, $0b, $02, $00, $00, $22, $03, $06, $07, $0f, $0f
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $21, $04, $05, $25, $05, $00, $00, $09, $05, $0a, $0a, $0a, $25, $00, $00, $26, $05, $05, $0a, $25, $04, $00, $00, $06, $06, $05, $06, $06, $06, $29, $00, $26, $06, $06, $06, $07, $02, $22, $00, $08, $0b, $0b, $06, $0b, $02
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $09, $21, $20, $00, $00, $00, $00, $00, $06, $26, $0b, $27, $20, $00, $00, $00, $04, $06, $0b, $02, $0f, $00, $00, $00, $26, $0b, $0b, $02, $24, $22, $00, $00, $02, $08, $02, $08, $0f, $29, $00, $00, $09, $09, $0f, $0f, $0f, $22, $00, $00, $0f, $5d, $09, $09, $09, $2a, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $0b, $0b, $26, $03, $07, $08, $0c, $09, $09, $07, $0b, $0b, $0b, $02, $0f, $09, $00, $22, $27, $24, $02, $24, $0f, $09, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $09, $09, $09, $00, $00, $21, $03, $06, $09, $09, $00, $00, $22, $03, $05, $05, $22, $00, $00, $00, $22, $03, $06, $07, $00, $00, $00, $00, $00, $0f, $07, $02, $00, $00, $00, $00, $00, $00, $22, $29, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $0b, $0f, $00, $00, $00, $00, $00, $00, $0b, $02, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00, $0c, $09, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $38, $15, $17, $36, $34, $00, $00, $00, $00, $38, $15, $17, $1c, $00, $00, $00, $00, $00, $38, $2d, $17, $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $2e, $31, $31, $31, $2e, $34, $3b, $31, $1f, $39, $2e, $3b, $31, $31, $31, $31, $17, $1c, $36, $1f, $36, $36, $1f, $36, $35, $2d, $16, $16, $17, $17, $16, $2d, $0e, $1a, $18, $18, $18, $1a, $38, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $31, $31, $31, $31, $3b, $31, $3b, $2e, $2e, $2e, $34, $34, $34, $2e, $2e, $31, $1d, $17, $1b, $1b, $1b, $1c, $36, $1f, $15, $35, $18, $13, $15, $15, $2d, $17, $00, $00, $00, $00, $00, $00, $2c, $0e, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $2e, $2e, $3b, $31, $31, $31, $3b, $2e, $31, $31, $31, $3b, $2e, $39, $1f, $1d, $36, $36, $1f, $1f, $1d, $1c, $1b, $17, $17, $17, $16, $16, $17, $2d, $15, $15, $1a, $1a, $1a, $1a, $1a, $1a, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $1f, $1d, $1b, $15, $2c, $00, $00, $00, $1c, $17, $1a, $2c, $00, $00, $00, $00, $2d, $38, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $0f, $07, $02, $0c, $09, $00, $00, $00, $00, $22, $29, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $20, $24, $0b, $0b, $0b, $07, $00, $00, $00, $20, $2b, $24, $02, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $24, $0c, $09, $09, $29, $00, $00, $00, $08, $0c, $2b, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
end_of_tile_pixel_data:
