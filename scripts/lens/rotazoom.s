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
VERA_DC_BORDER    = $9F2C  ; DCSEL=0

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

FRAME_NR                  = $48 ; 49
POS_AND_ROTATE_DATA       = $4A ; 4B

COSINE_OF_ANGLE           = $51 ; 52
SINE_OF_ANGLE             = $53 ; 54

TEMP_VAR                  = $55

; === RAM addresses ===

COPY_ROW_CODE               = $8800


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
    
; FIXME!
;    lda #3
;    sta VERA_DC_BORDER
    
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
    sta FRAME_NR
    sta FRAME_NR+1
    
    lda #<pos_and_rotation_data
    sta POS_AND_ROTATE_DATA
    lda #>pos_and_rotation_data
    sta POS_AND_ROTATE_DATA+1
    
    
keep_rotating:
    lda #<(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_POS_Y*320)
    sta VERA_ADDR_ZP_TO
    lda #>(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_POS_Y*320)
    sta VERA_ADDR_ZP_TO+1
    
    jsr draw_rotated_tilemap
    
; FIXME!
;tmp_loop:
;    jmp tmp_loop
    
    clc
    lda FRAME_NR
    adc #1
    sta FRAME_NR
    lda FRAME_NR+1
    adc #0
    sta FRAME_NR+1
    
    clc
    lda POS_AND_ROTATE_DATA
    adc #8
    sta POS_AND_ROTATE_DATA
    lda POS_AND_ROTATE_DATA+1
    adc #0
    sta POS_AND_ROTATE_DATA+1

; FIXME!
;    jsr wait_a_few_ms
    
    ; check if 2000 frames played (= $7D0)
    lda FRAME_NR+1
    cmp #$7
    bne keep_rotating
    lda FRAME_NR
    cmp #$D0
    bne keep_rotating
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    lda #%00000000  ; blit write enabled = 0, normal mode
    sta VERA_FX_CTRL

    rts
    
wait_a_few_ms:
    ldx #0
wait_a_few_ms_256:
    ldy #0
wait_a_few_ms_1:
    nop
    nop
    nop
    nop
    iny
    bne wait_a_few_ms_1
    inx
    bne wait_a_few_ms_256
    rts




  

draw_rotated_tilemap:

    ldy #0
    
    ; cosine_rotate
    lda (POS_AND_ROTATE_DATA), y   ; cosine_rotate_low
    sta COSINE_OF_ANGLE
    iny
    lda (POS_AND_ROTATE_DATA), y   ; cosine_rotate_high
    sta COSINE_OF_ANGLE+1
    iny
    
    ; sine_rotate
    lda (POS_AND_ROTATE_DATA), y   ; sine_rotate_low
    sta SINE_OF_ANGLE
    iny
    lda (POS_AND_ROTATE_DATA), y   ; sine_rotate_high
    sta SINE_OF_ANGLE+1
    iny

    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    ; Y position
    lda #128
    sta Y_SUB_PIXEL

    lda (POS_AND_ROTATE_DATA), y   ; y_position_low
    sta TEMP_VAR
    iny
    
    lda #0
    clc
    ; IMPORTANT! This is a ADC!
    adc TEMP_VAR
    sta Y_SUB_PIXEL+1
    
    ; FIXME: do something with y_position_high!
    ; FIXME: do something with y_position_high!
    ; FIXME: do something with y_position_high!
    lda (POS_AND_ROTATE_DATA), y   ; y_position_high
    iny
    
    ; X position
    lda #128
    sta X_SUB_PIXEL
 
    lda (POS_AND_ROTATE_DATA), y   ; x_position_low
    sta TEMP_VAR
    iny
    
    lda #0
    sec
    ; IMPORTANT! This is a SBC!
    sbc TEMP_VAR
    sta X_SUB_PIXEL+1
    
    ; FIXME: do something with x_position_high!
    ; FIXME: do something with x_position_high!
    ; FIXME: do something with x_position_high!
    lda (POS_AND_ROTATE_DATA), y   ; x_position_high
    iny
    
    lda COSINE_OF_ANGLE       ; X increment low
    asl
    sta VERA_FX_X_INCR_L
    lda COSINE_OF_ANGLE+1
    rol                      
    and #%01111111            ; increment is only 15 bits long
    sta VERA_FX_X_INCR_H
    
    lda SINE_OF_ANGLE
    asl
    sta VERA_FX_Y_INCR_L      ; Y increment low
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

; FIXME: is sign extension correct here??
; FIXME: is sign extension correct here??
; FIXME: is sign extension correct here??
    lda X_SUB_PIXEL+1
    sta VERA_FX_X_POS_L      ; X pixel position low [7:0]
    bpl x_pixel_pos_high_positive
    lda #%00000111           ; sign extending X pixel position (when negative)
    bra x_pixel_pos_high_correct
x_pixel_pos_high_positive:
    lda #%00000000
x_pixel_pos_high_correct:
    sta VERA_FX_X_POS_H      ; X subpixel position[0] = 0, X pixel position high [10:8] = 000 or 111

; FIXME: is sign extension correct here??
; FIXME: is sign extension correct here??
; FIXME: is sign extension correct here??
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
    adc COSINE_OF_ANGLE
    sta Y_SUB_PIXEL
    lda Y_SUB_PIXEL+1
    adc COSINE_OF_ANGLE+1
    sta Y_SUB_PIXEL+1
    
    sec
    lda X_SUB_PIXEL
    sbc SINE_OF_ANGLE
    sta X_SUB_PIXEL
    lda X_SUB_PIXEL+1
    sbc SINE_OF_ANGLE+1
    sta X_SUB_PIXEL+1
    
    inx
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
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $04, $0c, $0d, $0e,    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $04, $0c, $0d, $0e
  .byte $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e,    $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e
  .byte $04, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d,    $04, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d
  .byte $04, $04, $04, $2e, $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $04, $04,    $04, $04, $04, $2e, $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $04, $04
  .byte $04, $04, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $42, $43, $44, $04, $04,    $04, $04, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $42, $43, $44, $04, $04
  .byte $04, $04, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f, $50, $04, $04,    $04, $04, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f, $50, $04, $04
  .byte $04, $04, $04, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $5b, $04, $04,    $04, $04, $04, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $5b, $04, $04
  .byte $04, $04, $04, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $64, $65, $66, $04, $04,    $04, $04, $04, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $64, $65, $66, $04, $04
  .byte $04, $04, $04, $04, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $6f, $04, $04, $04,    $04, $04, $04, $04, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $6f, $04, $04, $04
  .byte $04, $70, $71, $04, $72, $73, $74, $75, $76, $77, $78, $79, $04, $04, $7a, $7b,    $04, $70, $71, $04, $72, $73, $74, $75, $76, $77, $78, $79, $04, $04, $7a, $7b
  .byte $7c, $7d, $7e, $04, $04, $7f, $80, $81, $82, $83, $84, $85, $04, $86, $87, $88,    $7c, $7d, $7e, $04, $04, $7f, $80, $81, $82, $83, $84, $85, $04, $86, $87, $88
  .byte $89, $8a, $8b, $8c, $04, $04, $8d, $8e, $8f, $90, $91, $04, $04, $92, $93, $94,    $89, $8a, $8b, $8c, $04, $04, $8d, $8e, $8f, $90, $91, $04, $04, $92, $93, $94
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $04, $0c, $0d, $0e,    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $04, $0c, $0d, $0e
  .byte $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e,    $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e
  .byte $04, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d,    $04, $1f, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d
  .byte $04, $04, $04, $2e, $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $04, $04,    $04, $04, $04, $2e, $2f, $30, $31, $32, $33, $34, $35, $36, $37, $38, $04, $04
  .byte $04, $04, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $42, $43, $44, $04, $04,    $04, $04, $39, $3a, $3b, $3c, $3d, $3e, $3f, $40, $41, $42, $43, $44, $04, $04
  .byte $04, $04, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f, $50, $04, $04,    $04, $04, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f, $50, $04, $04
  .byte $04, $04, $04, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $5b, $04, $04,    $04, $04, $04, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $5b, $04, $04
  .byte $04, $04, $04, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $64, $65, $66, $04, $04,    $04, $04, $04, $5c, $5d, $5e, $5f, $60, $61, $62, $63, $64, $65, $66, $04, $04
  .byte $04, $04, $04, $04, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $6f, $04, $04, $04,    $04, $04, $04, $04, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $6f, $04, $04, $04
  .byte $04, $70, $71, $04, $72, $73, $74, $75, $76, $77, $78, $79, $04, $04, $7a, $7b,    $04, $70, $71, $04, $72, $73, $74, $75, $76, $77, $78, $79, $04, $04, $7a, $7b
  .byte $7c, $7d, $7e, $04, $04, $7f, $80, $81, $82, $83, $84, $85, $04, $86, $87, $88,    $7c, $7d, $7e, $04, $04, $7f, $80, $81, $82, $83, $84, $85, $04, $86, $87, $88
  .byte $89, $8a, $8b, $8c, $04, $04, $8d, $8e, $8f, $90, $91, $04, $04, $92, $93, $94,    $89, $8a, $8b, $8c, $04, $04, $8d, $8e, $8f, $90, $91, $04, $04, $92, $93, $94
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
  .byte $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
end_of_tile_map_data:


tile_pixel_data:
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $00, $00, $00, $00, $00, $00, $21, $00, $00, $00, $00, $00, $00, $00, $09
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $21, $27, $27, $21, $29, $23, $24, $05, $25, $05, $06, $03, $26, $0b, $25, $0a, $0a, $0a, $05, $06, $26, $04, $05, $0a, $25, $05, $06, $0b, $0b, $06, $06, $05, $06, $28, $0b, $08, $08
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $29, $00, $00, $00, $00, $00, $00, $07, $02, $22, $00, $00, $00, $21, $09, $02, $24, $0f, $00, $00, $02, $05, $04, $02, $0f, $0f, $00, $29, $06, $05, $06
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $22, $00, $00, $00, $00, $00, $00, $26, $02, $22, $00, $00, $00, $00, $00, $02, $24, $29, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $11, $1a, $35
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $11, $0e, $1a, $1a, $2c, $0e, $18, $15, $2d, $17, $1b, $36, $15, $17, $1c, $1f, $34, $2e, $31, $2f
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $2c, $1a, $1a, $18, $18, $18, $35, $15, $16, $1c, $1f, $34, $31, $31, $2e, $31, $30, $30, $33, $3d, $3c, $3c, $30, $30, $33, $3c, $3c, $3e, $40, $43
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $13, $13, $35, $35, $35, $35, $13, $13, $31, $2f, $2f, $2f, $2f, $2f, $31, $31, $3c, $3e, $3e, $3e, $3e, $3c, $3d, $33, $43, $41, $43, $43, $43, $40, $3e, $3c
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $18, $1a, $1a, $1a, $11, $2c, $00, $31, $2e, $39, $36, $1b, $2d, $13, $1a, $33, $30, $30, $30, $2f, $2e, $39, $1f, $3c, $3c, $33, $33, $33, $33, $30, $30
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $1a, $11, $2c, $00, $00, $00, $00, $00, $1c, $16, $13, $1a, $1a, $11, $11, $00, $30, $31, $34, $1d, $1b, $16, $15, $18
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $1a, $11, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $03, $06, $0b, $0f, $00, $00, $22, $03, $05, $05, $0b, $02, $00, $00, $22, $03, $06, $07, $0f, $0f
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $0b, $05, $05, $00, $00, $20, $03, $0a, $0a, $0a, $5c, $00, $00, $07, $05, $25, $0a, $0a, $05, $29, $00, $06, $28, $05, $05, $05, $05, $22, $00, $06, $06, $28, $06, $26, $07
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $06, $0b, $27, $20, $00, $00, $00, $00, $28, $03, $0b, $02, $21, $00, $00, $00, $03, $03, $0b, $02, $08, $20, $00, $00, $0b, $02, $07, $24, $08, $29, $00, $00, $0f, $0f, $0f, $0f, $0f, $29, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $21, $00, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $03, $03, $06, $0b, $02, $0f, $09, $0c, $0b, $0b, $26, $03, $07, $08, $0c, $09, $09, $07, $0b, $0b, $0b, $02, $0f, $09, $00, $22, $27, $24, $02, $24, $0f, $09, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $00, $02, $05, $25, $05
  .byte $0f, $0f, $0c, $00, $2a, $02, $26, $02, $09, $09, $09, $00, $00, $2b, $0f, $08, $09, $09, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $20, $00, $00, $00, $00, $00, $00, $26, $0f, $20, $00, $00, $00, $00, $00
  .byte $09, $09, $22, $00, $00, $00, $00, $00, $0c, $29, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $1a, $00, $00, $00, $00, $00, $11, $1a, $15, $00, $00, $00, $00, $11, $18, $15, $17, $00, $00, $00, $11, $18, $15, $17, $1c, $00, $00, $11, $18, $15, $17, $1c, $36, $00, $00, $1a, $15, $17, $1c, $36, $1f
  .byte $00, $00, $11, $1a, $13, $2d, $17, $1c, $11, $1a, $35, $2d, $17, $36, $1f, $34, $13, $15, $17, $1d, $1f, $34, $34, $2e, $17, $1c, $36, $1f, $34, $2e, $3b, $31, $1c, $36, $1f, $34, $2e, $3b, $31, $31, $1f, $34, $34, $2e, $3b, $31, $31, $31, $1f, $34, $2e, $2e, $31, $31, $2f, $2f, $34, $2e, $2e, $3b, $31, $31, $2f, $2f
  .byte $1f, $39, $34, $2e, $31, $2f, $2f, $30, $2e, $2e, $3b, $31, $2f, $30, $30, $33, $3b, $31, $2f, $2f, $30, $30, $33, $33, $31, $2f, $2f, $30, $30, $33, $33, $3d, $2f, $30, $30, $30, $30, $33, $33, $3d, $2f, $2f, $30, $30, $33, $33, $33, $3c, $2f, $2f, $30, $30, $33, $33, $3d, $3c, $30, $30, $30, $30, $33, $33, $3d, $3c
  .byte $33, $3d, $3c, $3e, $41, $41, $43, $43, $33, $3c, $40, $40, $43, $55, $43, $56, $3c, $3e, $40, $41, $43, $55, $55, $57, $3c, $40, $41, $43, $55, $56, $56, $57, $3c, $40, $40, $43, $55, $56, $57, $57, $3e, $40, $43, $55, $55, $56, $57, $57, $3e, $40, $43, $43, $55, $55, $57, $57, $3e, $3e, $41, $55, $43, $55, $56, $57
  .byte $55, $55, $55, $55, $55, $55, $43, $41, $55, $55, $56, $56, $55, $56, $55, $55, $57, $57, $57, $57, $56, $55, $55, $55, $57, $57, $57, $57, $57, $57, $57, $55, $57, $57, $57, $57, $57, $57, $57, $55, $57, $57, $57, $57, $57, $57, $57, $56, $57, $57, $57, $57, $57, $57, $57, $56, $57, $57, $57, $57, $57, $57, $57, $55
  .byte $3c, $3e, $3c, $3d, $33, $33, $33, $30, $43, $40, $3c, $3c, $3d, $33, $33, $33, $55, $41, $40, $3c, $3c, $3d, $3d, $33, $55, $43, $41, $3e, $3c, $3c, $3d, $33, $57, $43, $41, $40, $3e, $3c, $3d, $33, $55, $55, $41, $40, $3e, $3c, $3d, $33, $56, $43, $41, $41, $3e, $3c, $3d, $33, $56, $43, $43, $41, $3e, $3c, $3c, $33
  .byte $30, $30, $30, $31, $34, $1f, $36, $1b, $33, $30, $30, $30, $2f, $3b, $34, $39, $33, $33, $30, $30, $30, $2f, $31, $34, $33, $33, $33, $30, $30, $2f, $31, $3b, $33, $33, $33, $30, $30, $2f, $2f, $31, $33, $33, $33, $30, $30, $2f, $2f, $31, $33, $33, $30, $30, $30, $2f, $2f, $31, $33, $33, $33, $30, $30, $2f, $2f, $31
  .byte $2d, $13, $1a, $38, $2c, $00, $00, $00, $36, $1b, $15, $35, $18, $1a, $2c, $00, $34, $1f, $1c, $17, $15, $18, $1a, $0e, $2e, $34, $39, $36, $1b, $15, $18, $18, $2e, $2e, $34, $1f, $1d, $1b, $15, $35, $3b, $34, $34, $1f, $1f, $1d, $1b, $2d, $31, $2e, $2e, $34, $1f, $1f, $1d, $1b, $31, $3b, $2e, $34, $34, $1f, $1f, $1c
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $1a, $2c, $00, $00, $00, $00, $00, $00, $18, $1a, $11, $00, $00, $00, $00, $00, $15, $18, $1a, $11, $00, $00, $00, $00, $17, $15, $18, $1a, $2c, $00, $00, $00, $1c, $16, $15, $18, $1a, $00, $00, $00
  .byte $00, $00, $00, $0f, $07, $02, $0c, $09, $00, $00, $00, $00, $22, $29, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $07, $26, $0b, $06, $07, $24, $00, $00, $09, $0b, $0b, $0b, $26, $07, $00, $00, $00, $21, $24, $0b, $02, $02, $00, $00, $00, $00, $20, $29, $21, $21, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $26, $05, $28, $00, $00, $00, $22, $06, $0a, $0a, $05
  .byte $0c, $09, $0f, $09, $0c, $22, $00, $00, $24, $0f, $09, $09, $09, $00, $00, $00, $08, $0f, $09, $09, $00, $00, $00, $00, $29, $22, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $07, $21, $00, $00, $00, $00, $00, $00, $0b, $24, $22, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $21, $04, $25, $0a, $04, $00, $00, $00, $21, $05, $04, $03, $0f, $00, $00, $00, $20, $07, $0b, $02, $0c, $00, $00, $00, $00, $23, $0f, $0f, $0c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $07, $08, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00, $09, $09, $2a, $00, $00, $00, $00, $00, $09, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $11, $13
  .byte $00, $1a, $13, $16, $17, $1c, $1f, $1f, $11, $18, $15, $17, $1c, $36, $1f, $1f, $1a, $15, $17, $1b, $1d, $1f, $1f, $34, $18, $15, $17, $1c, $1d, $1f, $1f, $34, $13, $16, $1c, $1c, $36, $1f, $39, $34, $15, $17, $1c, $1c, $36, $1f, $34, $34, $15, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1c, $1c, $36, $1f, $1f, $34
  .byte $34, $2e, $3b, $3b, $31, $2f, $2f, $2f, $34, $2e, $3b, $31, $31, $31, $2f, $30, $34, $2e, $3b, $31, $31, $2f, $2f, $2f, $34, $2e, $3b, $31, $31, $2f, $2f, $30, $34, $2e, $3b, $2f, $31, $31, $2f, $2f, $34, $2e, $3b, $31, $2f, $31, $2f, $30, $34, $2e, $3b, $31, $31, $2f, $2f, $2f, $34, $2e, $3b, $31, $31, $2f, $31, $2f
  .byte $30, $30, $30, $33, $33, $33, $3d, $3c, $30, $30, $30, $33, $33, $33, $33, $3c, $2f, $30, $30, $33, $33, $33, $33, $3c, $2f, $30, $30, $30, $33, $33, $33, $3d, $2f, $30, $30, $30, $33, $33, $33, $3d, $2f, $30, $30, $30, $33, $33, $33, $33, $30, $30, $30, $30, $30, $30, $33, $33, $2f, $30, $30, $30, $30, $30, $33, $33
  .byte $3c, $40, $40, $43, $43, $55, $55, $55, $3c, $3e, $41, $40, $41, $43, $43, $55, $3c, $3c, $3e, $3e, $3e, $41, $41, $43, $3c, $3c, $3c, $3e, $3e, $3e, $40, $40, $3c, $3c, $3c, $3c, $3e, $3e, $3e, $3e, $3d, $3c, $3c, $3c, $3c, $3e, $3c, $3c, $3d, $3c, $33, $3c, $3c, $3c, $3c, $3c, $33, $3d, $3d, $3c, $3d, $3c, $3c, $3c
  .byte $57, $57, $57, $57, $57, $57, $56, $55, $55, $55, $55, $56, $55, $55, $43, $43, $43, $43, $43, $43, $55, $55, $43, $41, $40, $41, $41, $40, $41, $41, $40, $41, $40, $40, $40, $40, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3e, $3c, $3c, $3e, $3c, $3e, $3c, $3c, $3c, $3e, $3c, $3c, $3c, $3c, $3c, $3c, $3c, $3c
  .byte $55, $41, $41, $40, $3e, $3c, $3c, $3d, $43, $41, $40, $3e, $3e, $3c, $3c, $33, $40, $40, $3e, $3e, $3e, $3c, $3d, $33, $3e, $3e, $3e, $3e, $3c, $3c, $33, $33, $3c, $3e, $3e, $3c, $3c, $3d, $33, $33, $3e, $3c, $3c, $3c, $3d, $3d, $33, $33, $3c, $3c, $3c, $3d, $33, $33, $33, $33, $3c, $3c, $3c, $3d, $33, $33, $33, $30
  .byte $33, $33, $33, $30, $30, $30, $2f, $31, $33, $33, $30, $30, $30, $2f, $2f, $31, $33, $33, $30, $30, $2f, $30, $2f, $31, $33, $33, $30, $30, $30, $2f, $2f, $31, $33, $30, $30, $30, $2f, $2f, $2f, $31, $33, $30, $30, $30, $2f, $2f, $31, $31, $30, $30, $30, $2f, $2f, $2f, $2f, $31, $30, $30, $30, $30, $2f, $2f, $2f, $31
  .byte $31, $3b, $2e, $34, $34, $1f, $1f, $1d, $31, $3b, $3b, $2e, $34, $1f, $1f, $1f, $31, $3b, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $34, $34, $1f, $1f, $31, $31, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $34, $34, $1f, $1f, $31, $31, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $34, $34, $1f, $1f
  .byte $1c, $1b, $2d, $13, $1a, $0e, $00, $00, $1c, $1c, $17, $15, $18, $1a, $00, $00, $36, $1c, $1b, $2d, $35, $1a, $1a, $00, $36, $1c, $1c, $17, $15, $18, $1a, $2c, $1f, $1d, $1c, $1b, $16, $13, $1a, $11, $1f, $1d, $1c, $1c, $17, $15, $13, $1a, $1f, $36, $1c, $1c, $17, $16, $15, $18, $1f, $36, $1d, $1c, $1b, $17, $2d, $18
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $21, $05, $05, $05, $26, $00, $00, $00, $29, $06, $06, $07, $0c, $00, $00, $00, $00, $09, $07, $24, $0f, $00, $00, $00, $00, $00, $22, $29, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $24, $0f, $29, $00, $00, $00, $00, $00, $09, $09, $22, $00, $00, $00, $00, $00, $09, $09, $00, $00, $00, $00, $00, $00, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $13, $00, $00, $00, $00, $00, $00, $11, $35, $00, $00, $00, $00, $00, $00, $11, $18
  .byte $2d, $17, $1c, $1c, $36, $1f, $34, $34, $2d, $17, $1c, $1c, $36, $1f, $39, $34, $2d, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1b, $1c, $36, $1f, $1f, $34, $2d, $17, $1c, $1c, $36, $1f, $1f, $34, $2d, $17, $1b, $1c, $1d, $1f, $34, $34, $15, $17, $1b, $1c, $1c, $1f, $1f, $1f, $15, $16, $17, $1c, $1c, $36, $1f, $34
  .byte $34, $2e, $3b, $3b, $31, $31, $31, $2f, $34, $2e, $3b, $3b, $31, $31, $31, $2f, $34, $2e, $3b, $3b, $31, $31, $31, $31, $34, $2e, $2e, $2e, $31, $31, $31, $31, $34, $2e, $2e, $3b, $31, $31, $31, $31, $34, $2e, $2e, $2e, $3b, $3b, $31, $31, $1f, $2e, $2e, $2e, $2e, $3b, $31, $31, $34, $34, $34, $2e, $2e, $2e, $3b, $31
  .byte $2f, $2f, $30, $30, $30, $30, $30, $30, $2f, $30, $2f, $30, $30, $30, $30, $33, $2f, $2f, $30, $2f, $30, $30, $30, $30, $31, $2f, $2f, $2f, $2f, $30, $30, $30, $31, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $31, $31, $31, $2f, $2f, $2f, $2f, $2f, $2f, $31, $31, $31, $2f, $2f, $2f, $2f, $31, $31, $31, $31, $2f, $2f, $2f, $2f
  .byte $33, $33, $33, $33, $3c, $3d, $3d, $3c, $30, $33, $33, $33, $3d, $3d, $3c, $3d, $30, $30, $33, $33, $33, $33, $33, $33, $30, $30, $30, $30, $30, $33, $33, $33, $30, $30, $30, $30, $30, $30, $30, $30, $2f, $2f, $2f, $30, $2f, $30, $30, $30, $2f, $2f, $2f, $2f, $2f, $2f, $30, $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f
  .byte $3d, $3c, $3d, $3c, $3c, $3c, $3d, $3c, $3d, $3c, $3d, $3c, $3c, $3c, $3c, $3c, $33, $3d, $3d, $33, $33, $3d, $3d, $33, $3d, $33, $33, $33, $33, $3d, $33, $30, $33, $33, $33, $33, $33, $33, $33, $33, $30, $33, $33, $33, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $2f, $30, $2f, $30, $2f, $30, $30, $2f, $2f
  .byte $3c, $3d, $33, $33, $33, $30, $30, $30, $3d, $3d, $33, $33, $33, $30, $30, $30, $33, $33, $33, $33, $33, $30, $30, $30, $33, $33, $33, $33, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $30, $2f, $30, $30, $30, $2f, $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $31, $2f, $31, $31
  .byte $30, $30, $30, $2f, $2f, $2f, $31, $31, $30, $30, $30, $30, $2f, $31, $31, $31, $30, $30, $2f, $30, $2f, $31, $31, $31, $30, $30, $2f, $2f, $2f, $2f, $31, $31, $30, $2f, $2f, $2f, $31, $31, $31, $31, $2f, $2f, $2f, $31, $31, $31, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $2e, $31, $31, $31, $31, $31, $31, $3b, $3b
  .byte $31, $3b, $3b, $2e, $34, $34, $34, $1f, $31, $31, $3b, $2e, $2e, $34, $34, $1f, $3b, $31, $3b, $2e, $2e, $34, $1f, $1f, $31, $3b, $3b, $2e, $34, $34, $1f, $1f, $3b, $3b, $2e, $2e, $34, $34, $1f, $1f, $3b, $2e, $2e, $2e, $34, $34, $1f, $1f, $3b, $2e, $2e, $34, $34, $1f, $1f, $1f, $2e, $2e, $2e, $34, $34, $34, $1f, $1f
  .byte $1f, $36, $1d, $1c, $1b, $17, $2d, $35, $1f, $36, $1d, $1c, $1b, $17, $2d, $15, $1f, $36, $1d, $1c, $1c, $17, $2d, $15, $1f, $36, $1d, $1c, $1b, $17, $2d, $15, $1f, $1d, $1c, $1c, $1b, $17, $16, $15, $1f, $36, $1c, $1c, $1b, $17, $16, $15, $36, $1d, $1c, $1c, $17, $17, $2d, $15, $36, $1d, $1c, $17, $17, $16, $16, $13
  .byte $18, $2c, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $0e, $00, $00, $00, $00, $00, $00, $18, $2c, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $00, $00, $00, $2c, $1a
  .byte $00, $00, $00, $00, $00, $00, $11, $18, $00, $0e, $00, $00, $00, $00, $11, $18, $0e, $15, $1a, $00, $00, $00, $2c, $18, $18, $2e, $1c, $0e, $00, $00, $2c, $1a, $2d, $2f, $31, $15, $11, $00, $2c, $1a, $2d, $30, $33, $34, $1a, $00, $2c, $1a, $16, $30, $33, $30, $1c, $11, $00, $0e, $17, $31, $33, $33, $31, $35, $2c, $0e
  .byte $15, $2d, $17, $1b, $1c, $1d, $1f, $1f, $15, $15, $16, $17, $1b, $1c, $36, $1f, $13, $15, $2d, $17, $17, $1b, $1c, $1f, $13, $15, $15, $2d, $17, $17, $1c, $1d, $18, $15, $15, $2d, $16, $17, $17, $1c, $18, $13, $15, $15, $16, $17, $16, $17, $18, $18, $15, $15, $2d, $17, $17, $16, $1a, $18, $13, $15, $15, $1c, $36, $17
  .byte $34, $34, $2e, $2e, $2e, $2e, $2e, $3b, $34, $34, $34, $2e, $2e, $2e, $3b, $2e, $1f, $39, $1f, $34, $2e, $2e, $2e, $2e, $1f, $1f, $34, $34, $34, $2e, $2e, $2e, $36, $1f, $1f, $34, $34, $34, $2e, $2e, $1d, $1f, $1f, $1f, $34, $34, $34, $34, $1b, $1d, $1f, $1f, $1f, $34, $34, $34, $16, $1b, $1d, $1f, $1f, $1f, $34, $34
  .byte $31, $31, $31, $31, $2f, $2f, $2f, $2f, $31, $3b, $31, $31, $31, $2f, $31, $2f, $3b, $3b, $3b, $31, $31, $31, $31, $31, $2e, $2e, $3b, $31, $31, $2e, $31, $31, $3b, $2e, $3b, $2e, $31, $3b, $31, $31, $2e, $2e, $2e, $3b, $3b, $2e, $31, $31, $34, $34, $2e, $2e, $2e, $2e, $3b, $2e, $34, $34, $34, $2e, $2e, $2e, $2e, $2e
  .byte $2f, $2f, $2f, $31, $30, $2f, $2f, $2f, $31, $31, $2f, $2f, $31, $2f, $2f, $2f, $31, $31, $2f, $31, $31, $31, $2f, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $31, $31, $31, $31, $31, $31, $31, $3b, $31, $2e, $3b, $3b, $31, $31, $31, $3b, $3b
  .byte $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $30, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f, $31, $2f, $2f, $31, $31, $31, $2f, $31, $31, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $3b, $31, $31, $3b, $31
  .byte $2f, $2f, $31, $2f, $31, $2f, $31, $31, $2f, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $31, $3b, $31, $3b, $3b, $3b, $31, $31, $31, $31, $3b, $3b, $3b, $31, $3b, $3b, $31, $3b, $31, $3b, $3b, $31, $3b, $2e, $31, $3b, $3b, $2e, $2e
  .byte $31, $31, $31, $31, $31, $31, $3b, $3b, $31, $3b, $3b, $3b, $3b, $2e, $2e, $2e, $31, $31, $3b, $31, $3b, $3b, $3b, $2e, $3b, $31, $31, $2e, $3b, $3b, $2e, $2e, $3b, $3b, $3b, $3b, $3b, $3b, $2e, $2e, $2e, $3b, $2e, $2e, $2e, $2e, $2e, $2e, $3b, $2e, $2e, $2e, $2e, $2e, $34, $34, $2e, $2e, $2e, $2e, $34, $34, $34, $34
  .byte $2e, $2e, $34, $34, $34, $1f, $1f, $1f, $2e, $34, $34, $34, $34, $1f, $1f, $36, $2e, $34, $34, $34, $1f, $1f, $36, $1d, $2e, $34, $34, $1f, $1f, $1f, $1d, $1c, $34, $34, $34, $1f, $1f, $1d, $1c, $1c, $2e, $34, $1f, $1f, $36, $1c, $1c, $17, $34, $39, $1f, $1f, $1d, $1c, $17, $16, $1f, $1f, $1f, $1d, $1d, $1b, $2d, $16
  .byte $1d, $1c, $1c, $1b, $17, $16, $15, $18, $1c, $1c, $1c, $1b, $17, $2d, $15, $18, $1c, $1c, $17, $17, $2d, $15, $13, $1a, $1c, $17, $17, $16, $15, $15, $18, $1a, $17, $17, $16, $2d, $15, $13, $1a, $2c, $17, $16, $2d, $15, $35, $18, $1a, $00, $2d, $17, $17, $15, $18, $1a, $11, $00, $1b, $1b, $2d, $15, $1a, $1a, $00, $2c
  .byte $1a, $00, $00, $00, $00, $00, $00, $00, $1a, $00, $00, $00, $0e, $00, $00, $00, $11, $00, $00, $1a, $15, $11, $00, $00, $00, $00, $0e, $1c, $2e, $18, $00, $00, $00, $11, $15, $31, $2f, $2d, $2c, $00, $00, $1a, $34, $33, $30, $2d, $0e, $00, $11, $1c, $30, $33, $30, $16, $1a, $00, $35, $31, $33, $33, $31, $17, $1a, $2c
  .byte $00, $00, $00, $00, $00, $00, $0e, $18, $00, $00, $00, $00, $00, $00, $0e, $18, $00, $00, $00, $00, $00, $00, $0e, $18, $00, $00, $00, $00, $00, $00, $2c, $1a, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $16, $1d, $2f, $33, $30, $36, $1a, $0e, $2d, $2d, $17, $31, $33, $31, $2d, $1a, $2d, $15, $1a, $35, $30, $33, $39, $15, $18, $16, $13, $1a, $1b, $33, $3a, $36, $1a, $15, $17, $18, $1a, $1f, $30, $33, $0e, $32, $15, $16, $18, $1a, $1c, $2e, $00, $11, $1a, $16, $15, $18, $1a, $15, $00, $00, $2c, $18, $1c, $2d, $1a, $1a
  .byte $1a, $1a, $18, $13, $15, $1d, $34, $1f, $1a, $1a, $1a, $18, $15, $36, $2e, $3b, $35, $18, $1a, $18, $16, $1f, $2f, $2f, $2e, $1b, $1a, $35, $1d, $2e, $30, $30, $33, $31, $15, $2d, $1f, $2f, $30, $33, $30, $2e, $15, $15, $39, $2e, $30, $33, $17, $15, $13, $35, $36, $2e, $31, $30, $1a, $1a, $1a, $18, $17, $1f, $2e, $2e
  .byte $1b, $16, $1c, $36, $1f, $1f, $1f, $1f, $2f, $1b, $17, $1c, $1d, $1f, $1f, $1f, $31, $2e, $2d, $17, $1c, $1d, $1f, $1f, $30, $30, $31, $17, $17, $1c, $1d, $36, $3c, $33, $33, $3f, $1f, $16, $1b, $1c, $3c, $3c, $3d, $3d, $33, $1f, $16, $17, $33, $3c, $3e, $3e, $3c, $3f, $1f, $16, $2f, $33, $3d, $3c, $40, $41, $30, $2e
  .byte $34, $34, $34, $34, $34, $34, $2e, $2e, $1f, $1f, $1f, $1f, $34, $34, $34, $34, $1f, $1f, $1f, $1f, $1f, $34, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $36, $1f, $1f, $1f, $1f, $1f, $1f, $1c, $1d, $1d, $36, $36, $1f, $1f, $36, $16, $17, $1b, $1c, $1d, $36, $36, $36, $31, $1d, $16, $16, $17, $1c, $1f, $34
  .byte $2e, $2e, $2e, $2e, $3b, $3b, $3b, $3b, $34, $2e, $2e, $2e, $3b, $2e, $3b, $2e, $34, $34, $2e, $2e, $34, $2e, $2e, $2e, $1f, $34, $34, $34, $34, $2e, $34, $34, $1f, $1f, $1f, $1f, $1f, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $1d, $36, $1f, $1f, $1f, $1f, $1f, $39, $1f, $1f, $36, $36, $1d, $36, $36
  .byte $3b, $31, $3b, $31, $31, $3b, $3b, $3b, $2e, $2e, $3b, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $34, $34, $34, $34, $34, $34, $34, $34, $34, $1f, $34, $34, $34, $34, $34, $34, $1f, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $36, $36, $36, $36, $36, $1f, $1f
  .byte $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $2e, $34, $34, $2e, $34, $34, $34, $2e, $34, $34, $34, $1f, $34, $34, $34, $34, $34, $34, $34, $1f, $1f, $1f, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $36, $36, $1f, $1d, $1d, $1d, $1d, $36, $1d, $36
  .byte $2e, $2e, $34, $34, $34, $34, $34, $1f, $34, $34, $34, $34, $34, $1f, $1f, $1f, $34, $34, $34, $34, $34, $1f, $1f, $36, $34, $1f, $1f, $1f, $1f, $1f, $1f, $1d, $1f, $1f, $1f, $1f, $1f, $36, $1c, $1b, $1f, $1f, $36, $36, $1c, $1c, $1b, $16, $1f, $36, $1c, $1b, $1b, $16, $17, $34, $1c, $1b, $16, $16, $1d, $31, $3f, $3d
  .byte $1f, $1f, $1d, $1c, $1b, $2d, $17, $1d, $1f, $1d, $1c, $17, $2d, $16, $1d, $34, $1d, $1c, $17, $2d, $17, $1f, $34, $2e, $1c, $17, $2d, $17, $34, $30, $2f, $3b, $16, $1b, $1f, $31, $33, $3c, $30, $31, $39, $30, $33, $3c, $3c, $3d, $30, $31, $33, $3d, $3e, $3c, $3c, $30, $2f, $34, $3c, $41, $3c, $33, $2f, $31, $34, $1d
  .byte $36, $17, $15, $18, $1a, $11, $0e, $1a, $36, $16, $13, $1a, $1a, $1a, $1a, $2d, $1f, $16, $18, $1a, $18, $35, $35, $39, $34, $1d, $15, $1a, $17, $2e, $1d, $3a, $39, $1d, $2d, $2d, $31, $33, $33, $30, $1f, $1c, $15, $15, $2e, $30, $2e, $1c, $1c, $17, $35, $13, $15, $17, $35, $1a, $17, $15, $18, $1a, $1a, $1a, $1a, $1a
  .byte $36, $30, $33, $2f, $1d, $16, $18, $2c, $31, $33, $31, $17, $2d, $2d, $18, $2c, $33, $30, $35, $1a, $15, $2d, $18, $2c, $33, $1b, $1a, $13, $16, $18, $1a, $00, $1f, $1a, $18, $17, $15, $1a, $0e, $00, $1a, $18, $16, $15, $32, $1a, $00, $00, $18, $15, $16, $1a, $11, $00, $00, $00, $2d, $1c, $18, $2c, $00, $00, $00, $00
  .byte $00, $00, $00, $0e, $36, $31, $18, $15, $00, $00, $00, $2c, $37, $30, $2d, $36, $00, $00, $00, $2c, $1a, $31, $2d, $2e, $00, $00, $00, $00, $0e, $1b, $18, $1d, $00, $00, $00, $00, $2c, $18, $16, $13, $00, $00, $00, $00, $2c, $15, $39, $18, $00, $00, $00, $00, $11, $17, $2f, $17, $00, $00, $00, $00, $38, $1d, $30, $2f
  .byte $18, $0e, $1a, $18, $15, $17, $1d, $1d, $2d, $0e, $0e, $1a, $18, $15, $15, $16, $36, $1a, $0e, $0e, $1a, $1a, $1a, $18, $31, $17, $1a, $0e, $1a, $1a, $0e, $0e, $2e, $2e, $1a, $1a, $1a, $1a, $18, $1a, $15, $36, $1a, $1a, $18, $15, $15, $15, $0e, $18, $1a, $18, $15, $16, $1b, $17, $1d, $2d, $1a, $15, $17, $1b, $1f, $1d
  .byte $1d, $1f, $3b, $30, $33, $3c, $43, $30, $16, $17, $1c, $36, $31, $33, $3c, $43, $18, $35, $15, $15, $1c, $34, $33, $3c, $1a, $1a, $1a, $18, $15, $2d, $1f, $31, $1a, $1a, $0e, $32, $32, $18, $15, $17, $18, $1a, $1a, $32, $32, $18, $44, $46, $15, $13, $1a, $32, $32, $42, $45, $47, $1d, $15, $15, $18, $32, $32, $18, $48
  .byte $2f, $33, $33, $2f, $1f, $1b, $17, $1b, $33, $3d, $3c, $3c, $33, $33, $30, $3b, $3c, $40, $40, $41, $40, $40, $3c, $3c, $3f, $33, $33, $3c, $40, $41, $40, $3c, $1f, $2e, $2f, $30, $33, $33, $3c, $33, $49, $16, $1b, $1d, $34, $2f, $3f, $33, $4a, $4b, $4d, $50, $52, $47, $54, $1c, $47, $4c, $4e, $51, $4a, $53, $4f, $44
  .byte $36, $2e, $3b, $31, $2e, $1f, $1f, $1d, $39, $1d, $36, $30, $33, $33, $2f, $34, $33, $33, $2f, $34, $31, $33, $33, $30, $30, $3d, $33, $33, $33, $33, $33, $30, $30, $30, $3d, $3d, $33, $3d, $33, $2f, $2f, $36, $31, $33, $33, $33, $30, $39, $2d, $18, $1a, $37, $34, $1f, $1c, $1d, $32, $32, $0e, $1a, $15, $16, $16, $15
  .byte $1c, $1c, $1c, $1c, $1b, $1c, $1c, $1d, $1f, $1d, $1c, $1c, $1d, $36, $1f, $1f, $1f, $1f, $1f, $36, $36, $1f, $2e, $30, $1f, $1f, $1f, $1f, $1f, $34, $30, $33, $36, $34, $36, $34, $1f, $39, $2f, $33, $1f, $1f, $1c, $1f, $2e, $34, $34, $2f, $1b, $15, $15, $15, $1b, $36, $1c, $1f, $2d, $17, $1c, $17, $16, $15, $15, $15
  .byte $36, $1f, $1f, $39, $39, $1d, $1b, $17, $2e, $2e, $3b, $34, $1f, $34, $31, $30, $33, $33, $33, $33, $33, $33, $33, $3d, $33, $33, $33, $33, $33, $3d, $3d, $3c, $33, $33, $30, $30, $33, $33, $3d, $33, $30, $30, $39, $34, $30, $33, $33, $3f, $1f, $1f, $2d, $1a, $18, $16, $1c, $58, $13, $1a, $1a, $0e, $32, $32, $44, $48
  .byte $1b, $1f, $2f, $33, $33, $3d, $3c, $40, $33, $33, $33, $3c, $3c, $3e, $41, $3c, $3c, $3c, $3e, $3e, $3c, $33, $30, $31, $3c, $3d, $33, $33, $30, $2f, $2e, $1d, $33, $33, $30, $31, $2e, $1f, $1b, $15, $2f, $34, $1d, $1b, $16, $49, $46, $5b, $59, $52, $50, $4d, $4b, $50, $47, $45, $5a, $4a, $4d, $51, $4c, $47, $46, $18
  .byte $3e, $30, $31, $1f, $1d, $1c, $1b, $16, $2f, $39, $17, $16, $16, $2d, $15, $35, $1d, $1b, $15, $13, $18, $18, $18, $1a, $2d, $15, $18, $1a, $1a, $1a, $0e, $0e, $18, $32, $32, $0e, $1a, $1a, $1a, $18, $18, $32, $32, $1a, $1a, $18, $15, $15, $18, $32, $1a, $1a, $13, $15, $17, $1b, $32, $32, $18, $15, $15, $1d, $1d, $1f
  .byte $15, $18, $18, $1a, $0e, $35, $17, $18, $18, $1a, $1a, $0e, $0e, $15, $31, $35, $1a, $1a, $0e, $0e, $1a, $1f, $2f, $13, $1a, $1a, $0e, $1a, $2d, $30, $36, $18, $1a, $1a, $1a, $1a, $30, $31, $35, $17, $15, $18, $1a, $1a, $34, $15, $18, $39, $16, $15, $18, $1a, $18, $0e, $17, $2f, $1b, $17, $15, $1a, $2d, $1d, $2f, $30
  .byte $39, $36, $1a, $00, $00, $00, $00, $00, $2e, $37, $2c, $00, $00, $00, $00, $00, $34, $1a, $2c, $00, $00, $00, $00, $00, $1b, $11, $00, $00, $00, $00, $00, $00, $18, $2c, $00, $00, $00, $00, $00, $00, $15, $2c, $00, $00, $00, $00, $00, $00, $17, $11, $00, $00, $00, $00, $00, $00, $1d, $38, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $35, $1f, $30, $30, $00, $00, $00, $0e, $15, $1f, $31, $30, $00, $00, $00, $1a, $18, $1b, $2e, $30, $00, $00, $00, $0e, $1a, $15, $1d, $2d, $00, $00, $00, $00, $00, $11, $11, $0e, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $30, $35, $18, $2d, $36, $1f, $1f, $34, $31, $1a, $35, $17, $39, $2e, $31, $2f, $2d, $1a, $18, $17, $1f, $2e, $2f, $30, $38, $1a, $13, $2d, $1f, $2e, $30, $30, $0e, $1a, $1a, $15, $1b, $34, $2f, $30, $0e, $1a, $1a, $18, $15, $1f, $31, $30, $00, $0e, $1a, $1a, $18, $15, $1f, $31, $00, $11, $38, $1a, $1a, $18, $15, $36
  .byte $34, $1d, $16, $35, $1a, $32, $32, $18, $3b, $34, $1d, $17, $15, $18, $1a, $32, $30, $30, $3b, $39, $17, $2d, $35, $18, $33, $33, $30, $2f, $2e, $1f, $1c, $16, $33, $33, $3f, $33, $30, $31, $31, $2e, $30, $30, $33, $33, $33, $30, $33, $30, $2f, $30, $33, $3f, $33, $3f, $33, $33, $2e, $2f, $30, $30, $30, $33, $30, $30
  .byte $45, $48, $4f, $4f, $4f, $48, $44, $32, $32, $18, $44, $44, $44, $42, $32, $32, $1a, $1a, $32, $32, $32, $32, $1a, $1a, $15, $13, $18, $18, $18, $18, $13, $15, $36, $1c, $1c, $1c, $1c, $1d, $1f, $34, $30, $30, $30, $30, $30, $30, $30, $30, $30, $3c, $33, $3d, $33, $33, $33, $33, $30, $33, $3c, $3c, $3c, $3d, $33, $33
  .byte $32, $1a, $1a, $35, $17, $17, $1b, $39, $1a, $18, $15, $1c, $1f, $1d, $34, $2f, $35, $2d, $1f, $34, $34, $1f, $31, $30, $1b, $39, $31, $31, $2e, $2e, $2f, $33, $31, $30, $30, $2f, $2e, $31, $30, $33, $30, $30, $30, $2f, $3b, $31, $30, $33, $33, $30, $30, $2f, $3b, $31, $30, $33, $33, $30, $30, $31, $3b, $2f, $33, $33
  .byte $31, $2f, $2f, $2e, $39, $36, $17, $15, $30, $30, $30, $30, $2f, $2e, $1f, $1c, $33, $33, $33, $33, $30, $2f, $2e, $1f, $33, $33, $3d, $33, $33, $30, $31, $39, $33, $33, $3d, $33, $33, $30, $2f, $2e, $33, $33, $3d, $33, $33, $30, $2f, $2e, $33, $3d, $3c, $33, $33, $30, $2f, $31, $33, $3d, $3c, $3d, $33, $30, $2f, $31
  .byte $15, $35, $18, $1a, $1a, $32, $32, $44, $16, $1b, $17, $15, $18, $1a, $32, $32, $1c, $1f, $1f, $36, $2d, $35, $1a, $1a, $1f, $34, $34, $2e, $1f, $17, $15, $13, $1f, $2e, $2e, $3b, $31, $31, $34, $1f, $34, $3b, $31, $2f, $2f, $30, $30, $30, $34, $31, $2f, $2f, $30, $30, $33, $33, $34, $31, $2f, $2f, $30, $33, $33, $33
  .byte $48, $4f, $4f, $4f, $48, $45, $18, $32, $42, $44, $44, $18, $18, $32, $32, $1a, $32, $32, $32, $32, $1a, $1a, $18, $35, $18, $18, $18, $18, $13, $15, $16, $1c, $1d, $1c, $1c, $1c, $1c, $36, $2e, $2f, $30, $30, $30, $30, $30, $2f, $30, $33, $33, $3d, $3c, $3d, $33, $33, $3f, $30, $3d, $3c, $3c, $3c, $3c, $3c, $33, $33
  .byte $32, $1a, $35, $16, $1d, $34, $34, $1f, $18, $15, $17, $1d, $34, $2e, $31, $2e, $2d, $17, $39, $2e, $30, $30, $30, $2f, $36, $2e, $2f, $30, $33, $33, $33, $2f, $30, $30, $3f, $33, $33, $33, $33, $2f, $30, $30, $33, $33, $30, $3f, $30, $31, $2f, $33, $33, $33, $30, $2f, $31, $1f, $30, $33, $33, $30, $2f, $2e, $36, $15
  .byte $1f, $36, $2d, $18, $35, $30, $30, $30, $34, $39, $17, $35, $1a, $31, $30, $31, $2e, $1f, $17, $18, $1a, $2d, $30, $2e, $2e, $1f, $2d, $13, $1a, $1a, $2d, $1d, $2e, $1b, $15, $1a, $1a, $0e, $2c, $11, $1f, $15, $18, $1a, $1a, $0e, $00, $00, $15, $18, $1a, $1a, $0e, $11, $00, $00, $18, $1a, $1a, $0e, $0e, $00, $00, $00
  .byte $1f, $35, $00, $00, $00, $00, $00, $00, $1f, $15, $0e, $00, $00, $00, $00, $00, $1b, $18, $1a, $00, $00, $00, $00, $00, $15, $1a, $0e, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $11, $0e, $1a, $1a, $18, $15, $00, $00, $00, $0e, $0e, $1a, $0e, $1a, $00, $00, $00, $00, $0e, $0e, $1a, $1a, $00, $00, $00, $00, $00, $0e, $0e, $0e, $00, $00, $00, $00, $00, $2c, $0e, $0e, $00, $00, $00, $00, $00, $00, $11, $11, $00, $00, $00, $00, $00, $00, $2c, $11, $00, $00, $00, $00, $00, $00, $00, $11
  .byte $1c, $1f, $2e, $2f, $30, $30, $30, $33, $18, $15, $1c, $1f, $2e, $2f, $30, $30, $1a, $1a, $18, $15, $1c, $1f, $2e, $2e, $1a, $1a, $1a, $1a, $18, $15, $16, $1b, $0e, $1a, $1a, $1a, $1a, $1a, $15, $15, $0e, $0e, $0e, $0e, $1a, $13, $13, $1c, $0e, $0e, $0e, $1a, $1a, $15, $2d, $36, $0e, $0e, $1a, $1a, $18, $15, $1b, $1f
  .byte $33, $33, $30, $30, $33, $33, $33, $33, $30, $30, $3a, $34, $31, $30, $33, $30, $34, $36, $1d, $39, $31, $2f, $2f, $34, $16, $1c, $34, $2e, $3b, $2e, $1d, $1f, $1c, $34, $2e, $2e, $39, $17, $1c, $3b, $39, $2e, $2e, $34, $17, $15, $2e, $31, $34, $34, $39, $17, $15, $36, $31, $31, $1f, $1f, $1b, $15, $16, $2e, $2f, $3b
  .byte $30, $2f, $2f, $2e, $2e, $2f, $30, $33, $31, $31, $31, $3b, $2e, $2f, $30, $33, $1f, $2e, $2e, $2f, $2e, $31, $33, $33, $34, $34, $31, $30, $2f, $2e, $30, $33, $39, $1f, $30, $33, $33, $31, $30, $33, $1b, $36, $33, $3d, $3d, $33, $30, $33, $16, $1c, $30, $33, $33, $33, $33, $33, $2d, $15, $1f, $2f, $31, $33, $3d, $3d
  .byte $33, $3d, $3c, $3d, $33, $30, $2f, $31, $33, $3c, $3d, $3d, $33, $33, $30, $2f, $33, $3d, $3c, $33, $33, $33, $30, $31, $3d, $3c, $3c, $3d, $33, $33, $30, $2e, $3d, $3c, $3c, $3d, $3d, $33, $30, $31, $3d, $3c, $3c, $3c, $3d, $33, $30, $33, $3d, $3c, $3c, $3c, $3d, $33, $33, $3d, $3d, $3c, $3c, $3c, $3c, $3d, $3d, $33
  .byte $2e, $3b, $31, $2f, $30, $30, $33, $33, $2e, $34, $2e, $2f, $2f, $30, $30, $33, $34, $2e, $2e, $2e, $31, $3b, $2e, $30, $2f, $2f, $31, $1f, $2e, $2e, $1f, $1f, $33, $33, $30, $1f, $1f, $31, $2e, $1d, $3c, $3d, $33, $39, $2d, $34, $31, $2e, $3d, $33, $30, $1d, $18, $36, $31, $2e, $30, $2f, $1f, $15, $1a, $39, $31, $31
  .byte $33, $3f, $33, $33, $33, $33, $30, $30, $2f, $31, $2e, $30, $30, $30, $30, $30, $2f, $1f, $1b, $1d, $34, $2e, $31, $3b, $31, $2f, $39, $1c, $16, $16, $17, $17, $1b, $31, $30, $3b, $1f, $1c, $2d, $15, $2d, $1b, $2e, $2f, $31, $1f, $1c, $16, $1c, $15, $1c, $2e, $31, $2e, $36, $1c, $1f, $15, $15, $1f, $2e, $39, $1f, $1d
  .byte $30, $2f, $2f, $2e, $1f, $1c, $15, $1a, $2f, $2e, $1f, $1c, $15, $18, $1a, $0e, $39, $1c, $15, $18, $1a, $1a, $0e, $0e, $15, $18, $1a, $1a, $0e, $0e, $0e, $0e, $18, $1a, $1a, $0e, $0e, $0e, $11, $11, $15, $1a, $1a, $0e, $0e, $11, $11, $11, $15, $13, $1a, $38, $0e, $0e, $11, $11, $17, $13, $1a, $1a, $0e, $0e, $0e, $2c
  .byte $1a, $1a, $0e, $0e, $00, $00, $00, $00, $0e, $0e, $0e, $00, $00, $00, $00, $00, $0e, $11, $2c, $00, $00, $00, $00, $00, $11, $2c, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $00, $02, $05, $25, $05, $00, $00, $00, $21, $04, $25, $0a, $04, $00, $00, $00, $21, $05, $04, $03, $0f
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $20, $00, $00, $00, $00, $00, $00, $26, $0f, $20, $00, $00, $00, $00, $00, $07, $08, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $0e, $0e, $1a, $13, $15, $2d, $1c, $1d, $0e, $0e, $1a, $13, $15, $17, $1c, $1d, $2c, $1a, $1a, $13, $15, $16, $1c, $1c, $00, $0e, $1a, $15, $2d, $17, $1b, $1c, $00, $2c, $1a, $35, $15, $16, $1c, $1c, $00, $00, $11, $13, $15, $17, $17, $17, $00, $00, $00, $38, $13, $2d, $2d, $15, $00, $00, $00, $00, $18, $15, $17, $17
  .byte $36, $1c, $15, $15, $1d, $31, $2f, $31, $1d, $15, $15, $17, $1d, $2e, $2f, $2f, $17, $15, $2d, $17, $1c, $34, $31, $2f, $15, $16, $1c, $1c, $1c, $36, $2e, $30, $15, $1c, $34, $2e, $3b, $34, $39, $2e, $2d, $1d, $39, $34, $2f, $2f, $2e, $39, $1c, $1f, $16, $1d, $2e, $2f, $30, $2f, $1f, $34, $17, $2d, $36, $2e, $30, $30
  .byte $36, $1a, $17, $1f, $17, $2e, $33, $3d, $3b, $15, $1a, $15, $15, $1c, $33, $33, $2f, $2e, $2d, $1a, $1a, $15, $31, $33, $30, $2f, $31, $1c, $1a, $1a, $1d, $30, $30, $2f, $2f, $31, $15, $0e, $18, $36, $34, $31, $2f, $2f, $39, $18, $0e, $35, $34, $34, $31, $30, $31, $1c, $1a, $0e, $33, $31, $34, $2e, $31, $31, $2d, $0e
  .byte $3c, $3c, $3c, $3c, $3c, $3c, $33, $31, $3d, $3c, $3c, $3c, $3c, $3d, $33, $1c, $33, $3c, $3c, $3c, $3c, $33, $2f, $15, $33, $33, $33, $33, $33, $30, $36, $1a, $2f, $30, $30, $30, $2f, $34, $13, $0e, $1c, $1f, $39, $1f, $1d, $2d, $0e, $0e, $18, $13, $13, $13, $1a, $0e, $0e, $18, $0e, $0e, $0e, $0e, $0e, $0e, $1a, $1f
  .byte $1d, $1f, $17, $1a, $15, $2e, $2f, $31, $15, $15, $1a, $1a, $1f, $31, $2f, $31, $18, $1a, $18, $36, $31, $2f, $30, $31, $0e, $35, $34, $31, $2f, $30, $2f, $34, $1a, $1f, $2f, $2f, $2f, $2f, $31, $34, $17, $31, $2f, $30, $2f, $2e, $34, $1f, $34, $2f, $3b, $31, $34, $34, $2f, $30, $2f, $31, $2e, $39, $2e, $30, $33, $2f
  .byte $1f, $17, $15, $16, $1f, $1f, $36, $1c, $1f, $1c, $17, $15, $15, $1b, $36, $1d, $39, $1d, $1b, $17, $15, $15, $1d, $1c, $1f, $1f, $1f, $36, $1d, $15, $1b, $1b, $1f, $2e, $2e, $34, $2e, $16, $16, $1c, $31, $3b, $39, $34, $2e, $1d, $15, $1c, $31, $39, $1b, $1f, $31, $39, $2d, $15, $1f, $1c, $15, $1f, $3b, $2e, $1c, $17
  .byte $17, $15, $35, $1a, $1a, $0e, $0e, $00, $1c, $2d, $15, $1a, $38, $0e, $11, $00, $1b, $2d, $15, $1a, $1a, $0e, $00, $00, $1b, $2d, $15, $18, $1a, $2c, $00, $00, $1b, $15, $15, $1a, $0e, $00, $00, $00, $2d, $16, $15, $18, $00, $00, $00, $00, $16, $15, $18, $2c, $00, $00, $00, $00, $16, $13, $11, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $00, $02, $05, $25, $05, $00, $00, $00, $21, $04, $25, $0a, $04, $00, $00, $00, $21, $05, $04, $03, $0f, $00, $00, $00, $20, $07, $0b, $02, $0c
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $20, $00, $00, $00, $00, $00, $00, $26, $0f, $20, $00, $00, $00, $00, $00, $07, $08, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00, $09, $09, $2a, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $00, $00, $00, $00, $00, $00, $21
  .byte $00, $00, $00, $20, $07, $0b, $02, $0c, $00, $00, $00, $00, $23, $0f, $0f, $0c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $21, $27, $27, $21, $29, $23, $24, $05, $25, $05, $06, $03, $26, $0b, $25, $0a, $0a, $0a, $05, $06, $26, $04, $05, $0a, $25, $05, $06, $0b, $0b
  .byte $09, $09, $2a, $00, $00, $00, $00, $00, $09, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $29, $00, $00, $00, $00, $00, $00, $07, $02, $22, $00, $00, $00, $00, $00, $02, $24, $0f, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $2c, $13, $2d, $1c, $00, $00, $00, $00, $00, $11, $15, $17, $00, $00, $00, $00, $00, $00, $1a, $2d, $00, $00, $00, $00, $00, $00, $00, $18, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $1f, $3b, $36, $18, $15, $1c, $1f, $31, $1d, $2e, $3b, $15, $1a, $13, $2d, $1c, $1b, $34, $31, $1d, $18, $15, $15, $13, $16, $1f, $31, $2e, $15, $1f, $2e, $1f, $15, $36, $2e, $2f, $39, $3b, $31, $30, $1a, $2d, $34, $31, $31, $36, $1f, $2e, $2c, $15, $1f, $34, $2f, $31, $1d, $2d, $00, $1a, $16, $1d, $2e, $31, $2e, $1b
  .byte $30, $33, $30, $30, $3a, $30, $2e, $18, $34, $31, $2f, $2f, $30, $2f, $31, $34, $15, $1c, $1f, $39, $34, $39, $1f, $1f, $17, $13, $15, $16, $16, $15, $13, $13, $3a, $34, $1c, $2d, $2d, $17, $1d, $36, $2f, $30, $30, $2e, $2e, $3b, $3a, $30, $36, $2e, $31, $30, $30, $30, $2f, $31, $18, $35, $1b, $1f, $2e, $2e, $34, $1d
  .byte $0e, $0e, $0e, $0e, $0e, $0e, $1b, $2f, $18, $0e, $0e, $0e, $18, $1d, $3b, $2f, $39, $1d, $17, $1d, $2e, $1f, $36, $1f, $15, $1c, $1d, $1d, $17, $15, $13, $35, $1c, $2d, $2d, $2d, $17, $36, $36, $1d, $30, $30, $30, $30, $30, $30, $30, $2f, $2e, $2e, $2e, $2e, $2e, $3b, $31, $30, $17, $15, $13, $13, $15, $2d, $1c, $34
  .byte $31, $2e, $31, $30, $30, $30, $2e, $36, $30, $30, $30, $30, $2e, $1f, $17, $35, $34, $34, $1f, $1d, $17, $35, $35, $15, $15, $2d, $2d, $35, $15, $1b, $2e, $34, $17, $17, $17, $1f, $31, $30, $30, $31, $2e, $2e, $31, $30, $30, $2f, $2e, $36, $30, $30, $30, $31, $2e, $36, $2d, $1b, $2e, $2e, $1f, $17, $35, $35, $1c, $34
  .byte $17, $13, $2d, $34, $31, $2e, $36, $1b, $18, $18, $1c, $2e, $31, $2e, $36, $17, $13, $35, $1f, $2e, $3b, $34, $1c, $2d, $16, $1b, $34, $31, $31, $1f, $17, $18, $39, $2e, $2e, $31, $2e, $36, $2d, $2c, $2e, $3b, $31, $2e, $1f, $17, $18, $00, $2e, $31, $31, $34, $1d, $16, $2c, $00, $31, $2f, $2e, $1f, $1b, $1a, $00, $00
  .byte $15, $38, $00, $00, $00, $00, $00, $00, $35, $2c, $00, $00, $00, $00, $00, $00, $2c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $21, $03, $06, $0b, $0f
  .byte $00, $00, $00, $00, $23, $0f, $0f, $0c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $29, $27, $27, $00, $00, $00, $21, $04, $05, $25, $05, $00, $00, $09, $05, $0a, $0a, $0a, $25, $00, $00, $26, $05, $05, $0a, $25, $04, $00, $00, $06, $06, $05, $06, $06, $06
  .byte $09, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $09, $21, $20, $00, $00, $00, $00, $00, $06, $26, $0b, $27, $20, $00, $00, $00, $04, $06, $0b, $02, $0f, $00, $00, $00, $26, $0b, $0b, $02, $24, $22, $00, $00, $02, $08, $02, $08, $0f, $29, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $09, $00, $00, $00, $00, $00, $00, $00, $21, $00, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $06, $06, $05, $06, $28, $0b, $08, $08, $03, $03, $06, $0b, $02, $0f, $09, $0c, $0b, $0b, $26, $03, $07, $08, $0c, $09, $09, $07, $0b, $0b, $0b, $02, $0f, $09, $00, $22, $27, $24, $02, $24, $0f, $09, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $02, $0f, $0f, $00, $00, $00, $00, $00, $0f, $0f, $0c, $00, $00, $00, $00, $00, $09, $09, $09, $00, $00, $21, $03, $06, $09, $09, $00, $00, $22, $03, $05, $05, $22, $00, $00, $00, $22, $03, $06, $07, $00, $00, $00, $00, $00, $0f, $07, $02, $00, $00, $00, $00, $00, $00, $22, $29, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $0b, $0f, $00, $00, $00, $00, $00, $00, $0b, $02, $29, $00, $00, $00, $00, $00, $0f, $0f, $22, $00, $00, $00, $00, $00, $0c, $09, $00, $00, $00, $00, $00, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $2c, $15, $17, $1f, $2e, $31, $2e, $00, $00, $38, $15, $1b, $1f, $34, $31, $00, $00, $00, $38, $15, $17, $36, $34, $00, $00, $00, $00, $38, $15, $17, $1c, $00, $00, $00, $00, $00, $38, $2d, $17, $00, $00, $00, $00, $00, $00, $11, $18, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $36, $15, $1a, $18, $15, $2d, $35, $1a, $3b, $2e, $1d, $17, $35, $35, $15, $17, $2e, $31, $31, $31, $2e, $34, $3b, $31, $1f, $39, $2e, $3b, $31, $31, $31, $31, $17, $1c, $36, $1f, $36, $36, $1f, $36, $35, $2d, $16, $16, $17, $17, $16, $2d, $0e, $1a, $18, $18, $18, $1a, $38, $2c, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $18, $13, $15, $35, $18, $18, $1a, $13, $1b, $1f, $34, $1f, $1d, $17, $15, $35, $31, $31, $31, $31, $3b, $31, $3b, $2e, $2e, $2e, $34, $34, $34, $2e, $2e, $31, $1d, $17, $1b, $1b, $1b, $1c, $36, $1f, $15, $35, $18, $13, $15, $15, $2d, $17, $00, $00, $00, $00, $00, $00, $2c, $0e, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $2d, $15, $18, $18, $15, $1c, $34, $31, $35, $15, $17, $1d, $34, $2e, $31, $31, $2e, $2e, $3b, $31, $31, $31, $3b, $2e, $31, $31, $31, $3b, $2e, $39, $1f, $1d, $36, $36, $1f, $1f, $1d, $1c, $1b, $17, $17, $17, $16, $16, $17, $2d, $15, $15, $1a, $1a, $1a, $1a, $1a, $1a, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $31, $2e, $39, $1d, $2d, $2c, $00, $00, $2e, $34, $36, $17, $1a, $00, $00, $00, $1f, $1d, $1b, $15, $2c, $00, $00, $00, $1c, $17, $1a, $2c, $00, $00, $00, $00, $2d, $38, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $22, $03, $05, $05, $0b, $02, $00, $00, $22, $03, $06, $07, $0f, $0f, $00, $00, $00, $0f, $07, $02, $0c, $09, $00, $00, $00, $00, $22, $29, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $29, $00, $26, $06, $06, $06, $07, $02, $22, $00, $08, $0b, $0b, $06, $0b, $02, $00, $00, $20, $24, $0b, $0b, $0b, $07, $00, $00, $00, $20, $2b, $24, $02, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $09, $09, $0f, $0f, $0f, $22, $00, $00, $0f, $5d, $09, $09, $09, $2a, $00, $00, $24, $0c, $09, $09, $29, $00, $00, $00, $08, $0c, $2b, $2a, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
end_of_tile_pixel_data:


pos_and_rotation_data:
  .byte 255, 0, 0, 0, 14, 0, 1, 0, 254, 0, 0, 0, 15, 0, 1, 0, 253, 0, 0, 0, 15, 0, 1, 0, 252, 0, 0, 0, 15, 0, 1, 0, 250, 0, 0, 0, 15, 0, 2, 0, 249, 0, 0, 0, 15, 0, 2, 0, 248, 0, 0, 0, 16, 0, 2, 0, 247, 0, 0, 0, 16, 0, 3, 0, 245, 0, 0, 0, 16, 0, 3, 0, 244, 0, 0, 0, 16, 0, 3, 0, 243, 0, 0, 0, 16, 0, 4, 0, 241, 0, 0, 0, 16, 0, 4, 0, 240, 0, 0, 0, 17, 0, 4, 0, 239, 0, 0, 0, 17, 0, 5, 0, 238, 0, 0, 0, 17, 0, 5, 0, 236, 0, 0, 0, 17, 0, 5, 0, 235, 0, 0, 0, 17, 0, 6, 0, 234, 0, 0, 0, 17, 0, 6, 0, 232, 0, 0, 0, 18, 0, 6, 0, 231, 0, 0, 0, 18, 0, 6, 0, 230, 0, 0, 0, 18, 0, 7, 0, 229, 0, 0, 0, 18, 0, 7, 0, 227, 0, 0, 0, 18, 0, 7, 0, 226, 0, 0, 0, 19, 0, 8, 0, 225, 0, 0, 0, 19, 0, 8, 0, 223, 0, 0, 0, 19, 0, 8, 0, 222, 0, 0, 0, 19, 0, 9, 0, 221, 0, 0, 0, 19, 0, 9, 0, 220, 0, 0, 0, 19, 0, 9, 0, 218, 0, 0, 0, 20, 0, 9, 0, 217, 0, 0, 0, 20, 0, 10, 0, 216, 0, 0, 0, 20, 0, 10, 0
  .byte 215, 0, 0, 0, 20, 0, 10, 0, 213, 0, 0, 0, 20, 0, 11, 0, 212, 0, 0, 0, 20, 0, 11, 0, 211, 0, 0, 0, 20, 0, 11, 0, 209, 0, 0, 0, 21, 0, 11, 0, 208, 0, 0, 0, 21, 0, 12, 0, 207, 0, 0, 0, 21, 0, 12, 0, 206, 0, 0, 0, 21, 0, 12, 0, 204, 0, 0, 0, 21, 0, 13, 0, 203, 0, 1, 0, 21, 0, 13, 0, 202, 0, 1, 0, 21, 0, 13, 0, 200, 0, 1, 0, 22, 0, 13, 0, 199, 0, 1, 0, 22, 0, 14, 0, 198, 0, 1, 0, 22, 0, 14, 0, 197, 0, 1, 0, 22, 0, 14, 0, 195, 0, 2, 0, 22, 0, 15, 0, 194, 0, 2, 0, 22, 0, 15, 0, 193, 0, 2, 0, 22, 0, 15, 0, 191, 0, 2, 0, 22, 0, 15, 0, 190, 0, 2, 0, 23, 0, 16, 0, 189, 0, 3, 0, 23, 0, 16, 0, 188, 0, 3, 0, 23, 0, 16, 0, 186, 0, 3, 0, 23, 0, 17, 0, 185, 0, 3, 0, 23, 0, 17, 0, 184, 0, 4, 0, 23, 0, 17, 0, 182, 0, 4, 0, 23, 0, 17, 0, 181, 0, 4, 0, 23, 0, 18, 0, 180, 0, 4, 0, 23, 0, 18, 0, 179, 0, 5, 0, 24, 0, 18, 0, 177, 0, 5, 0, 24, 0, 18, 0, 176, 0, 5, 0, 24, 0, 19, 0, 175, 0, 5, 0, 24, 0, 19, 0
  .byte 173, 0, 6, 0, 24, 0, 19, 0, 172, 0, 6, 0, 24, 0, 19, 0, 171, 0, 6, 0, 24, 0, 20, 0, 170, 0, 6, 0, 24, 0, 20, 0, 168, 0, 7, 0, 24, 0, 20, 0, 167, 0, 7, 0, 24, 0, 21, 0, 166, 0, 7, 0, 25, 0, 21, 0, 164, 0, 8, 0, 25, 0, 21, 0, 163, 0, 8, 0, 25, 0, 21, 0, 162, 0, 8, 0, 25, 0, 22, 0, 161, 0, 9, 0, 25, 0, 22, 0, 159, 0, 9, 0, 25, 0, 22, 0, 158, 0, 9, 0, 25, 0, 22, 0, 157, 0, 10, 0, 25, 0, 23, 0, 155, 0, 10, 0, 25, 0, 23, 0, 154, 0, 10, 0, 25, 0, 23, 0, 153, 0, 10, 0, 25, 0, 23, 0, 151, 0, 11, 0, 25, 0, 24, 0, 150, 0, 11, 0, 26, 0, 24, 0, 149, 0, 11, 0, 26, 0, 24, 0, 147, 0, 12, 0, 26, 0, 24, 0, 146, 0, 12, 0, 26, 0, 25, 0, 145, 0, 12, 0, 26, 0, 25, 0, 144, 0, 13, 0, 26, 0, 25, 0, 142, 0, 13, 0, 26, 0, 25, 0, 141, 0, 13, 0, 26, 0, 26, 0, 140, 0, 14, 0, 26, 0, 26, 0, 138, 0, 14, 0, 26, 0, 26, 0, 137, 0, 14, 0, 26, 0, 27, 0, 136, 0, 15, 0, 26, 0, 27, 0, 134, 0, 15, 0, 26, 0, 27, 0, 133, 0, 15, 0, 27, 0, 27, 0
  .byte 132, 0, 16, 0, 27, 0, 28, 0, 130, 0, 16, 0, 27, 0, 28, 0, 129, 0, 16, 0, 27, 0, 28, 0, 128, 0, 16, 0, 27, 0, 28, 0, 126, 0, 17, 0, 27, 0, 29, 0, 125, 0, 17, 0, 27, 0, 29, 0, 124, 0, 17, 0, 27, 0, 29, 0, 122, 0, 18, 0, 27, 0, 29, 0, 121, 0, 18, 0, 27, 0, 29, 0, 120, 0, 18, 0, 27, 0, 30, 0, 118, 0, 18, 0, 27, 0, 30, 0, 117, 0, 19, 0, 28, 0, 30, 0, 116, 0, 19, 0, 28, 0, 30, 0, 114, 0, 19, 0, 28, 0, 31, 0, 113, 0, 19, 0, 28, 0, 31, 0, 112, 0, 20, 0, 28, 0, 31, 0, 110, 0, 20, 0, 28, 0, 31, 0, 109, 0, 20, 0, 28, 0, 32, 0, 108, 0, 20, 0, 28, 0, 32, 0, 106, 0, 21, 0, 28, 0, 32, 0, 105, 0, 21, 0, 28, 0, 32, 0, 104, 0, 21, 0, 28, 0, 33, 0, 103, 0, 21, 0, 28, 0, 33, 0, 101, 0, 22, 0, 29, 0, 33, 0, 100, 0, 22, 0, 29, 0, 33, 0, 99, 0, 22, 0, 29, 0, 33, 0, 98, 0, 22, 0, 29, 0, 34, 0, 97, 0, 23, 0, 29, 0, 34, 0, 95, 0, 23, 0, 29, 0, 34, 0, 94, 0, 23, 0, 29, 0, 34, 0, 93, 0, 23, 0, 29, 0, 34, 0, 92, 0, 23, 0, 29, 0, 35, 0
  .byte 91, 0, 24, 0, 29, 0, 35, 0, 90, 0, 24, 0, 29, 0, 35, 0, 88, 0, 24, 0, 30, 0, 35, 0, 87, 0, 24, 0, 30, 0, 35, 0, 86, 0, 24, 0, 30, 0, 35, 0, 85, 0, 24, 0, 30, 0, 36, 0, 84, 0, 25, 0, 30, 0, 36, 0, 83, 0, 25, 0, 30, 0, 36, 0, 82, 0, 25, 0, 30, 0, 36, 0, 81, 0, 25, 0, 30, 0, 36, 0, 80, 0, 25, 0, 30, 0, 36, 0, 79, 0, 26, 0, 30, 0, 37, 0, 78, 0, 26, 0, 30, 0, 37, 0, 77, 0, 26, 0, 31, 0, 37, 0, 76, 0, 26, 0, 31, 0, 37, 0, 75, 0, 26, 0, 31, 0, 37, 0, 74, 0, 26, 0, 31, 0, 37, 0, 73, 0, 26, 0, 31, 0, 37, 0, 72, 0, 27, 0, 31, 0, 37, 0, 71, 0, 27, 0, 31, 0, 38, 0, 70, 0, 27, 0, 31, 0, 38, 0, 70, 0, 27, 0, 31, 0, 38, 0, 69, 0, 27, 0, 31, 0, 38, 0, 68, 0, 27, 0, 32, 0, 38, 0, 67, 0, 28, 0, 32, 0, 38, 0, 66, 0, 28, 0, 32, 0, 38, 0, 65, 0, 28, 0, 32, 0, 38, 0, 64, 0, 28, 0, 32, 0, 38, 0, 64, 0, 28, 0, 32, 0, 38, 0, 63, 0, 28, 0, 32, 0, 38, 0, 62, 0, 28, 0, 32, 0, 39, 0, 61, 0, 28, 0, 32, 0, 39, 0
  .byte 60, 0, 29, 0, 32, 0, 39, 0, 60, 0, 29, 0, 32, 0, 39, 0, 59, 0, 29, 0, 33, 0, 39, 0, 58, 0, 29, 0, 33, 0, 39, 0, 57, 0, 29, 0, 33, 0, 39, 0, 57, 0, 29, 0, 33, 0, 39, 0, 56, 0, 29, 0, 33, 0, 39, 0, 55, 0, 30, 0, 33, 0, 39, 0, 55, 0, 30, 0, 33, 0, 39, 0, 54, 0, 30, 0, 33, 0, 39, 0, 53, 0, 30, 0, 33, 0, 39, 0, 53, 0, 30, 0, 33, 0, 39, 0, 52, 0, 30, 0, 33, 0, 39, 0, 51, 0, 30, 0, 33, 0, 39, 0, 51, 0, 31, 0, 34, 0, 39, 0, 50, 0, 31, 0, 34, 0, 39, 0, 50, 0, 31, 0, 34, 0, 39, 0, 49, 0, 31, 0, 34, 0, 39, 0, 48, 0, 31, 0, 34, 0, 39, 0, 48, 0, 31, 0, 34, 0, 39, 0, 47, 0, 31, 0, 34, 0, 39, 0, 47, 0, 32, 0, 34, 0, 39, 0, 46, 0, 32, 0, 34, 0, 39, 0, 46, 0, 32, 0, 34, 0, 39, 0, 45, 0, 32, 0, 34, 0, 39, 0, 45, 0, 32, 0, 34, 0, 39, 0, 44, 0, 32, 0, 34, 0, 39, 0, 44, 0, 33, 0, 34, 0, 39, 0, 43, 0, 33, 0, 34, 0, 39, 0, 43, 0, 33, 0, 35, 0, 39, 0, 42, 0, 33, 0, 35, 0, 39, 0, 42, 0, 33, 0, 35, 0, 39, 0
  .byte 41, 0, 34, 0, 35, 0, 39, 0, 41, 0, 34, 0, 35, 0, 39, 0, 40, 0, 34, 0, 35, 0, 39, 0, 40, 0, 34, 0, 35, 0, 39, 0, 39, 0, 34, 0, 35, 0, 39, 0, 39, 0, 35, 0, 35, 0, 39, 0, 39, 0, 35, 0, 35, 0, 39, 0, 38, 0, 35, 0, 35, 0, 39, 0, 38, 0, 35, 0, 35, 0, 39, 0, 37, 0, 36, 0, 35, 0, 39, 0, 37, 0, 36, 0, 35, 0, 39, 0, 37, 0, 36, 0, 35, 0, 39, 0, 36, 0, 36, 0, 35, 0, 39, 0, 36, 0, 37, 0, 35, 0, 39, 0, 35, 0, 37, 0, 35, 0, 39, 0, 35, 0, 37, 0, 35, 0, 38, 0, 35, 0, 38, 0, 35, 0, 38, 0, 34, 0, 38, 0, 35, 0, 38, 0, 34, 0, 38, 0, 35, 0, 38, 0, 34, 0, 38, 0, 35, 0, 38, 0, 33, 0, 39, 0, 35, 0, 38, 0, 33, 0, 39, 0, 35, 0, 38, 0, 33, 0, 40, 0, 35, 0, 38, 0, 32, 0, 40, 0, 35, 0, 38, 0, 32, 0, 40, 0, 35, 0, 38, 0, 32, 0, 41, 0, 35, 0, 38, 0, 31, 0, 41, 0, 35, 0, 38, 0, 31, 0, 41, 0, 35, 0, 38, 0, 31, 0, 42, 0, 35, 0, 38, 0, 30, 0, 42, 0, 35, 0, 38, 0, 30, 0, 43, 0, 35, 0, 37, 0, 30, 0, 43, 0, 35, 0, 37, 0
  .byte 29, 0, 44, 0, 35, 0, 37, 0, 29, 0, 44, 0, 35, 0, 37, 0, 29, 0, 44, 0, 35, 0, 37, 0, 28, 0, 45, 0, 35, 0, 37, 0, 28, 0, 45, 0, 35, 0, 37, 0, 28, 0, 46, 0, 35, 0, 37, 0, 27, 0, 46, 0, 35, 0, 37, 0, 27, 0, 47, 0, 35, 0, 37, 0, 27, 0, 47, 0, 35, 0, 37, 0, 26, 0, 48, 0, 35, 0, 37, 0, 26, 0, 49, 0, 34, 0, 37, 0, 26, 0, 49, 0, 34, 0, 36, 0, 25, 0, 50, 0, 34, 0, 36, 0, 25, 0, 50, 0, 34, 0, 36, 0, 24, 0, 51, 0, 34, 0, 36, 0, 24, 0, 51, 0, 34, 0, 36, 0, 24, 0, 52, 0, 34, 0, 36, 0, 23, 0, 53, 0, 34, 0, 36, 0, 23, 0, 53, 0, 34, 0, 36, 0, 22, 0, 54, 0, 34, 0, 36, 0, 22, 0, 55, 0, 34, 0, 36, 0, 22, 0, 55, 0, 34, 0, 36, 0, 21, 0, 56, 0, 33, 0, 36, 0, 21, 0, 57, 0, 33, 0, 36, 0, 20, 0, 57, 0, 33, 0, 36, 0, 20, 0, 58, 0, 33, 0, 36, 0, 19, 0, 59, 0, 33, 0, 36, 0, 19, 0, 59, 0, 33, 0, 36, 0, 18, 0, 60, 0, 33, 0, 36, 0, 18, 0, 61, 0, 33, 0, 35, 0, 17, 0, 62, 0, 32, 0, 35, 0, 17, 0, 62, 0, 32, 0, 35, 0
  .byte 16, 0, 63, 0, 32, 0, 35, 0, 15, 0, 64, 0, 32, 0, 35, 0, 15, 0, 65, 0, 32, 0, 35, 0, 14, 0, 65, 0, 32, 0, 35, 0, 14, 0, 66, 0, 32, 0, 35, 0, 13, 0, 67, 0, 31, 0, 35, 0, 12, 0, 68, 0, 31, 0, 35, 0, 12, 0, 69, 0, 31, 0, 35, 0, 11, 0, 69, 0, 31, 0, 35, 0, 10, 0, 70, 0, 31, 0, 35, 0, 9, 0, 71, 0, 31, 0, 35, 0, 9, 0, 72, 0, 30, 0, 35, 0, 8, 0, 73, 0, 30, 0, 35, 0, 7, 0, 74, 0, 30, 0, 35, 0, 6, 0, 74, 0, 30, 0, 36, 0, 5, 0, 75, 0, 30, 0, 36, 0, 4, 0, 76, 0, 30, 0, 36, 0, 4, 0, 77, 0, 29, 0, 36, 0, 3, 0, 78, 0, 29, 0, 36, 0, 2, 0, 79, 0, 29, 0, 36, 0, 1, 0, 79, 0, 29, 0, 36, 0, 0, 0, 80, 0, 29, 0, 36, 0, 0, 0, 81, 0, 29, 0, 36, 0, 255, 255, 81, 0, 29, 0, 36, 0, 254, 255, 82, 0, 28, 0, 36, 0, 252, 255, 83, 0, 28, 0, 36, 0, 251, 255, 83, 0, 28, 0, 36, 0, 250, 255, 84, 0, 28, 0, 36, 0, 249, 255, 84, 0, 28, 0, 37, 0, 248, 255, 85, 0, 28, 0, 37, 0, 247, 255, 85, 0, 28, 0, 37, 0, 246, 255, 86, 0, 28, 0, 37, 0
  .byte 244, 255, 86, 0, 28, 0, 37, 0, 243, 255, 86, 0, 27, 0, 37, 0, 242, 255, 87, 0, 27, 0, 37, 0, 241, 255, 87, 0, 27, 0, 37, 0, 239, 255, 87, 0, 27, 0, 38, 0, 238, 255, 88, 0, 27, 0, 38, 0, 237, 255, 88, 0, 27, 0, 38, 0, 236, 255, 88, 0, 27, 0, 38, 0, 234, 255, 88, 0, 27, 0, 38, 0, 233, 255, 88, 0, 27, 0, 38, 0, 232, 255, 88, 0, 27, 0, 39, 0, 230, 255, 88, 0, 27, 0, 39, 0, 229, 255, 88, 0, 27, 0, 39, 0, 228, 255, 88, 0, 27, 0, 39, 0, 226, 255, 88, 0, 27, 0, 39, 0, 225, 255, 88, 0, 27, 0, 39, 0, 224, 255, 88, 0, 27, 0, 39, 0, 222, 255, 88, 0, 27, 0, 40, 0, 221, 255, 88, 0, 27, 0, 40, 0, 220, 255, 88, 0, 27, 0, 40, 0, 218, 255, 87, 0, 27, 0, 40, 0, 217, 255, 87, 0, 28, 0, 40, 0, 216, 255, 87, 0, 28, 0, 40, 0, 214, 255, 87, 0, 28, 0, 41, 0, 213, 255, 86, 0, 28, 0, 41, 0, 211, 255, 86, 0, 28, 0, 41, 0, 210, 255, 85, 0, 28, 0, 41, 0, 209, 255, 85, 0, 28, 0, 41, 0, 207, 255, 84, 0, 28, 0, 41, 0, 206, 255, 84, 0, 28, 0, 42, 0, 205, 255, 83, 0, 29, 0, 42, 0, 204, 255, 82, 0, 29, 0, 42, 0
  .byte 202, 255, 82, 0, 29, 0, 42, 0, 201, 255, 81, 0, 29, 0, 42, 0, 200, 255, 80, 0, 29, 0, 42, 0, 198, 255, 80, 0, 29, 0, 42, 0, 197, 255, 79, 0, 30, 0, 43, 0, 196, 255, 78, 0, 30, 0, 43, 0, 195, 255, 77, 0, 30, 0, 43, 0, 193, 255, 76, 0, 30, 0, 43, 0, 192, 255, 76, 0, 30, 0, 43, 0, 191, 255, 75, 0, 31, 0, 43, 0, 190, 255, 74, 0, 31, 0, 43, 0, 189, 255, 73, 0, 31, 0, 44, 0, 187, 255, 72, 0, 31, 0, 44, 0, 186, 255, 71, 0, 31, 0, 44, 0, 185, 255, 70, 0, 32, 0, 44, 0, 184, 255, 69, 0, 32, 0, 44, 0, 183, 255, 68, 0, 32, 0, 44, 0, 181, 255, 67, 0, 32, 0, 44, 0, 180, 255, 66, 0, 33, 0, 44, 0, 179, 255, 65, 0, 33, 0, 44, 0, 178, 255, 63, 0, 33, 0, 45, 0, 177, 255, 62, 0, 33, 0, 45, 0, 176, 255, 61, 0, 34, 0, 45, 0, 175, 255, 60, 0, 34, 0, 45, 0, 174, 255, 59, 0, 34, 0, 45, 0, 173, 255, 57, 0, 35, 0, 45, 0, 172, 255, 56, 0, 35, 0, 45, 0, 171, 255, 55, 0, 35, 0, 45, 0, 170, 255, 54, 0, 35, 0, 45, 0, 169, 255, 52, 0, 36, 0, 45, 0, 168, 255, 51, 0, 36, 0, 45, 0, 167, 255, 50, 0, 36, 0, 45, 0
  .byte 166, 255, 48, 0, 37, 0, 46, 0, 165, 255, 47, 0, 37, 0, 46, 0, 164, 255, 45, 0, 37, 0, 46, 0, 163, 255, 44, 0, 38, 0, 46, 0, 163, 255, 42, 0, 38, 0, 46, 0, 162, 255, 41, 0, 38, 0, 46, 0, 161, 255, 39, 0, 39, 0, 46, 0, 160, 255, 38, 0, 39, 0, 46, 0, 159, 255, 36, 0, 39, 0, 46, 0, 159, 255, 35, 0, 40, 0, 46, 0, 158, 255, 33, 0, 40, 0, 46, 0, 157, 255, 31, 0, 41, 0, 46, 0, 157, 255, 30, 0, 41, 0, 46, 0, 156, 255, 28, 0, 41, 0, 46, 0, 155, 255, 26, 0, 42, 0, 46, 0, 155, 255, 25, 0, 42, 0, 46, 0, 154, 255, 23, 0, 42, 0, 46, 0, 154, 255, 21, 0, 43, 0, 46, 0, 153, 255, 20, 0, 43, 0, 46, 0, 153, 255, 18, 0, 44, 0, 46, 0, 153, 255, 16, 0, 44, 0, 46, 0, 152, 255, 14, 0, 44, 0, 45, 0, 152, 255, 12, 0, 45, 0, 45, 0, 151, 255, 11, 0, 45, 0, 45, 0, 151, 255, 9, 0, 46, 0, 45, 0, 151, 255, 7, 0, 46, 0, 45, 0, 151, 255, 5, 0, 46, 0, 45, 0, 150, 255, 3, 0, 47, 0, 45, 0, 150, 255, 1, 0, 47, 0, 45, 0, 150, 255, 0, 0, 48, 0, 45, 0, 150, 255, 255, 255, 48, 0, 44, 0, 150, 255, 253, 255, 48, 0, 44, 0
  .byte 150, 255, 251, 255, 49, 0, 44, 0, 150, 255, 249, 255, 49, 0, 44, 0, 150, 255, 247, 255, 50, 0, 44, 0, 150, 255, 245, 255, 50, 0, 44, 0, 150, 255, 243, 255, 51, 0, 43, 0, 150, 255, 241, 255, 51, 0, 43, 0, 150, 255, 239, 255, 51, 0, 43, 0, 151, 255, 237, 255, 52, 0, 43, 0, 151, 255, 235, 255, 52, 0, 43, 0, 151, 255, 233, 255, 53, 0, 42, 0, 151, 255, 231, 255, 53, 0, 42, 0, 152, 255, 229, 255, 53, 0, 42, 0, 152, 255, 227, 255, 54, 0, 42, 0, 153, 255, 225, 255, 54, 0, 41, 0, 153, 255, 223, 255, 55, 0, 41, 0, 154, 255, 222, 255, 55, 0, 41, 0, 154, 255, 220, 255, 56, 0, 41, 0, 155, 255, 218, 255, 56, 0, 40, 0, 155, 255, 216, 255, 56, 0, 40, 0, 156, 255, 214, 255, 57, 0, 40, 0, 157, 255, 212, 255, 57, 0, 39, 0, 157, 255, 210, 255, 58, 0, 39, 0, 158, 255, 208, 255, 58, 0, 39, 0, 159, 255, 206, 255, 58, 0, 38, 0, 160, 255, 204, 255, 59, 0, 38, 0, 161, 255, 202, 255, 59, 0, 37, 0, 162, 255, 200, 255, 60, 0, 37, 0, 163, 255, 198, 255, 60, 0, 37, 0, 164, 255, 197, 255, 60, 0, 36, 0, 165, 255, 195, 255, 61, 0, 36, 0, 166, 255, 193, 255, 61, 0, 35, 0, 167, 255, 191, 255, 62, 0, 35, 0
  .byte 168, 255, 189, 255, 62, 0, 34, 0, 170, 255, 187, 255, 62, 0, 34, 0, 171, 255, 186, 255, 63, 0, 34, 0, 172, 255, 184, 255, 63, 0, 33, 0, 173, 255, 182, 255, 63, 0, 33, 0, 175, 255, 181, 255, 64, 0, 32, 0, 176, 255, 179, 255, 64, 0, 32, 0, 178, 255, 177, 255, 64, 0, 31, 0, 179, 255, 176, 255, 65, 0, 31, 0, 181, 255, 174, 255, 65, 0, 30, 0, 182, 255, 172, 255, 65, 0, 29, 0, 184, 255, 171, 255, 66, 0, 29, 0, 186, 255, 169, 255, 66, 0, 28, 0, 187, 255, 168, 255, 66, 0, 28, 0, 189, 255, 166, 255, 66, 0, 27, 0, 191, 255, 165, 255, 67, 0, 27, 0, 192, 255, 163, 255, 67, 0, 26, 0, 194, 255, 162, 255, 67, 0, 25, 0, 196, 255, 161, 255, 67, 0, 25, 0, 198, 255, 159, 255, 68, 0, 24, 0, 200, 255, 158, 255, 68, 0, 24, 0, 202, 255, 157, 255, 68, 0, 23, 0, 204, 255, 156, 255, 68, 0, 22, 0, 206, 255, 155, 255, 68, 0, 22, 0, 208, 255, 153, 255, 69, 0, 21, 0, 210, 255, 152, 255, 69, 0, 20, 0, 212, 255, 151, 255, 69, 0, 20, 0, 214, 255, 150, 255, 69, 0, 19, 0, 216, 255, 149, 255, 69, 0, 18, 0, 218, 255, 149, 255, 69, 0, 18, 0, 220, 255, 148, 255, 69, 0, 17, 0, 222, 255, 147, 255, 69, 0, 16, 0
  .byte 224, 255, 146, 255, 70, 0, 16, 0, 227, 255, 145, 255, 70, 0, 15, 0, 229, 255, 145, 255, 70, 0, 14, 0, 231, 255, 144, 255, 70, 0, 14, 0, 233, 255, 143, 255, 70, 0, 13, 0, 236, 255, 143, 255, 70, 0, 12, 0, 238, 255, 142, 255, 70, 0, 12, 0, 240, 255, 142, 255, 70, 0, 11, 0, 242, 255, 141, 255, 70, 0, 10, 0, 245, 255, 141, 255, 70, 0, 10, 0, 247, 255, 141, 255, 70, 0, 9, 0, 249, 255, 140, 255, 70, 0, 8, 0, 252, 255, 140, 255, 70, 0, 7, 0, 254, 255, 140, 255, 70, 0, 7, 0, 0, 0, 140, 255, 70, 0, 6, 0, 2, 0, 140, 255, 69, 0, 5, 0, 4, 0, 140, 255, 69, 0, 5, 0, 6, 0, 139, 255, 69, 0, 4, 0, 9, 0, 140, 255, 69, 0, 3, 0, 11, 0, 140, 255, 69, 0, 2, 0, 13, 0, 140, 255, 69, 0, 2, 0, 16, 0, 140, 255, 69, 0, 1, 0, 18, 0, 140, 255, 68, 0, 0, 0, 20, 0, 140, 255, 68, 0, 0, 0, 23, 0, 141, 255, 68, 0, 0, 0, 25, 0, 141, 255, 68, 0, 255, 255, 27, 0, 141, 255, 68, 0, 254, 255, 30, 0, 142, 255, 67, 0, 254, 255, 32, 0, 142, 255, 67, 0, 253, 255, 34, 0, 143, 255, 67, 0, 252, 255, 37, 0, 144, 255, 67, 0, 252, 255, 39, 0, 144, 255, 66, 0, 251, 255
  .byte 41, 0, 145, 255, 66, 0, 250, 255, 43, 0, 146, 255, 66, 0, 250, 255, 46, 0, 146, 255, 65, 0, 249, 255, 48, 0, 147, 255, 65, 0, 248, 255, 50, 0, 148, 255, 65, 0, 248, 255, 52, 0, 149, 255, 64, 0, 247, 255, 55, 0, 150, 255, 64, 0, 246, 255, 57, 0, 151, 255, 64, 0, 246, 255, 59, 0, 152, 255, 63, 0, 245, 255, 61, 0, 153, 255, 63, 0, 244, 255, 63, 0, 154, 255, 62, 0, 244, 255, 65, 0, 156, 255, 62, 0, 243, 255, 67, 0, 157, 255, 61, 0, 242, 255, 69, 0, 158, 255, 61, 0, 242, 255, 71, 0, 159, 255, 61, 0, 241, 255, 73, 0, 161, 255, 60, 0, 240, 255, 75, 0, 162, 255, 60, 0, 240, 255, 77, 0, 164, 255, 59, 0, 239, 255, 79, 0, 165, 255, 59, 0, 239, 255, 81, 0, 167, 255, 58, 0, 238, 255, 83, 0, 168, 255, 58, 0, 238, 255, 85, 0, 170, 255, 57, 0, 237, 255, 87, 0, 171, 255, 56, 0, 236, 255, 89, 0, 173, 255, 56, 0, 236, 255, 90, 0, 175, 255, 55, 0, 235, 255, 92, 0, 176, 255, 55, 0, 235, 255, 94, 0, 178, 255, 54, 0, 234, 255, 95, 0, 180, 255, 54, 0, 234, 255, 97, 0, 182, 255, 53, 0, 233, 255, 99, 0, 184, 255, 52, 0, 233, 255, 100, 0, 186, 255, 52, 0, 232, 255, 102, 0, 188, 255, 51, 0, 232, 255
  .byte 103, 0, 190, 255, 50, 0, 231, 255, 104, 0, 192, 255, 50, 0, 231, 255, 106, 0, 194, 255, 49, 0, 230, 255, 107, 0, 196, 255, 48, 0, 230, 255, 108, 0, 198, 255, 48, 0, 230, 255, 110, 0, 200, 255, 47, 0, 229, 255, 111, 0, 202, 255, 46, 0, 229, 255, 112, 0, 204, 255, 46, 0, 228, 255, 113, 0, 207, 255, 45, 0, 228, 255, 114, 0, 209, 255, 44, 0, 228, 255, 115, 0, 211, 255, 44, 0, 227, 255, 116, 0, 213, 255, 43, 0, 227, 255, 117, 0, 216, 255, 42, 0, 227, 255, 118, 0, 218, 255, 41, 0, 226, 255, 119, 0, 220, 255, 41, 0, 226, 255, 120, 0, 223, 255, 40, 0, 226, 255, 121, 0, 225, 255, 39, 0, 225, 255, 121, 0, 228, 255, 38, 0, 225, 255, 122, 0, 230, 255, 38, 0, 225, 255, 123, 0, 232, 255, 37, 0, 225, 255, 123, 0, 235, 255, 36, 0, 225, 255, 124, 0, 237, 255, 35, 0, 224, 255, 124, 0, 240, 255, 35, 0, 224, 255, 125, 0, 242, 255, 34, 0, 224, 255, 125, 0, 245, 255, 33, 0, 224, 255, 126, 0, 247, 255, 32, 0, 224, 255, 126, 0, 250, 255, 31, 0, 223, 255, 126, 0, 252, 255, 31, 0, 223, 255, 126, 0, 255, 255, 30, 0, 223, 255, 126, 0, 0, 0, 29, 0, 223, 255, 127, 0, 3, 0, 28, 0, 223, 255, 127, 0, 5, 0, 27, 0, 223, 255
  .byte 127, 0, 8, 0, 27, 0, 223, 255, 126, 0, 11, 0, 26, 0, 223, 255, 126, 0, 13, 0, 25, 0, 223, 255, 126, 0, 16, 0, 24, 0, 223, 255, 126, 0, 18, 0, 24, 0, 223, 255, 126, 0, 21, 0, 23, 0, 223, 255, 125, 0, 23, 0, 22, 0, 223, 255, 125, 0, 26, 0, 21, 0, 223, 255, 125, 0, 28, 0, 20, 0, 223, 255, 124, 0, 31, 0, 20, 0, 223, 255, 124, 0, 33, 0, 19, 0, 223, 255, 123, 0, 36, 0, 18, 0, 223, 255, 122, 0, 38, 0, 17, 0, 223, 255, 122, 0, 41, 0, 16, 0, 223, 255, 121, 0, 43, 0, 16, 0, 223, 255, 120, 0, 46, 0, 15, 0, 223, 255, 119, 0, 48, 0, 14, 0, 224, 255, 118, 0, 51, 0, 13, 0, 224, 255, 117, 0, 53, 0, 12, 0, 224, 255, 116, 0, 56, 0, 12, 0, 224, 255, 115, 0, 58, 0, 11, 0, 224, 255, 114, 0, 60, 0, 10, 0, 225, 255, 113, 0, 63, 0, 9, 0, 225, 255, 112, 0, 65, 0, 9, 0, 225, 255, 111, 0, 67, 0, 8, 0, 225, 255, 110, 0, 70, 0, 7, 0, 226, 255, 108, 0, 72, 0, 6, 0, 226, 255, 107, 0, 74, 0, 6, 0, 226, 255, 106, 0, 76, 0, 5, 0, 226, 255, 104, 0, 78, 0, 4, 0, 227, 255, 103, 0, 81, 0, 4, 0, 227, 255, 101, 0, 83, 0, 3, 0, 227, 255
  .byte 99, 0, 85, 0, 2, 0, 228, 255, 98, 0, 87, 0, 2, 0, 228, 255, 96, 0, 89, 0, 1, 0, 228, 255, 94, 0, 91, 0, 0, 0, 229, 255, 93, 0, 93, 0, 0, 0, 229, 255, 91, 0, 95, 0, 0, 0, 230, 255, 89, 0, 97, 0, 255, 255, 230, 255, 87, 0, 99, 0, 255, 255, 230, 255, 85, 0, 100, 0, 254, 255, 231, 255, 83, 0, 102, 0, 253, 255, 231, 255, 81, 0, 104, 0, 253, 255, 232, 255, 79, 0, 106, 0, 252, 255, 232, 255, 77, 0, 107, 0, 252, 255, 233, 255, 75, 0, 109, 0, 251, 255, 233, 255, 73, 0, 111, 0, 250, 255, 234, 255, 71, 0, 112, 0, 250, 255, 234, 255, 69, 0, 114, 0, 249, 255, 235, 255, 66, 0, 115, 0, 249, 255, 235, 255, 64, 0, 117, 0, 248, 255, 236, 255, 62, 0, 118, 0, 248, 255, 236, 255, 59, 0, 119, 0, 247, 255, 237, 255, 57, 0, 121, 0, 247, 255, 238, 255, 55, 0, 122, 0, 246, 255, 238, 255, 52, 0, 123, 0, 246, 255, 239, 255, 50, 0, 124, 0, 245, 255, 239, 255, 47, 0, 125, 0, 245, 255, 240, 255, 45, 0, 126, 0, 244, 255, 240, 255, 42, 0, 127, 0, 244, 255, 241, 255, 40, 0, 128, 0, 244, 255, 242, 255, 37, 0, 129, 0, 243, 255, 242, 255, 35, 0, 130, 0, 243, 255, 243, 255, 32, 0, 131, 0, 242, 255, 244, 255
  .byte 30, 0, 132, 0, 242, 255, 244, 255, 27, 0, 132, 0, 242, 255, 245, 255, 24, 0, 133, 0, 241, 255, 245, 255, 22, 0, 134, 0, 241, 255, 246, 255, 19, 0, 134, 0, 241, 255, 247, 255, 16, 0, 135, 0, 240, 255, 247, 255, 14, 0, 135, 0, 240, 255, 248, 255, 11, 0, 135, 0, 240, 255, 249, 255, 8, 0, 136, 0, 240, 255, 249, 255, 5, 0, 136, 0, 239, 255, 250, 255, 3, 0, 136, 0, 239, 255, 251, 255, 0, 0, 136, 0, 239, 255, 251, 255, 254, 255, 137, 0, 239, 255, 252, 255, 252, 255, 137, 0, 239, 255, 253, 255, 249, 255, 137, 0, 238, 255, 253, 255, 246, 255, 137, 0, 238, 255, 254, 255, 243, 255, 136, 0, 238, 255, 255, 255, 241, 255, 136, 0, 238, 255, 255, 255, 238, 255, 136, 0, 238, 255, 0, 0, 235, 255, 136, 0, 238, 255, 0, 0, 232, 255, 135, 0, 238, 255, 1, 0, 230, 255, 135, 0, 237, 255, 1, 0, 227, 255, 135, 0, 237, 255, 2, 0, 224, 255, 134, 0, 237, 255, 3, 0, 221, 255, 134, 0, 237, 255, 3, 0, 219, 255, 133, 0, 237, 255, 4, 0, 216, 255, 132, 0, 237, 255, 5, 0, 213, 255, 132, 0, 237, 255, 5, 0, 211, 255, 131, 0, 237, 255, 6, 0, 208, 255, 130, 0, 237, 255, 7, 0, 205, 255, 129, 0, 237, 255, 7, 0, 203, 255, 128, 0, 237, 255, 8, 0
  .byte 200, 255, 127, 0, 238, 255, 9, 0, 197, 255, 126, 0, 238, 255, 9, 0, 195, 255, 125, 0, 238, 255, 10, 0, 192, 255, 124, 0, 238, 255, 11, 0, 190, 255, 123, 0, 238, 255, 11, 0, 187, 255, 121, 0, 238, 255, 12, 0, 185, 255, 120, 0, 238, 255, 13, 0, 182, 255, 119, 0, 238, 255, 13, 0, 180, 255, 117, 0, 239, 255, 14, 0, 177, 255, 116, 0, 239, 255, 14, 0, 175, 255, 114, 0, 239, 255, 15, 0, 173, 255, 113, 0, 239, 255, 16, 0, 170, 255, 111, 0, 239, 255, 16, 0, 168, 255, 110, 0, 240, 255, 17, 0, 166, 255, 108, 0, 240, 255, 17, 0, 164, 255, 106, 0, 240, 255, 18, 0, 161, 255, 104, 0, 240, 255, 19, 0, 159, 255, 103, 0, 241, 255, 19, 0, 157, 255, 101, 0, 241, 255, 20, 0, 155, 255, 99, 0, 241, 255, 20, 0, 153, 255, 97, 0, 242, 255, 21, 0, 151, 255, 95, 0, 242, 255, 21, 0, 149, 255, 93, 0, 242, 255, 22, 0, 147, 255, 91, 0, 243, 255, 22, 0, 145, 255, 89, 0, 243, 255, 23, 0, 143, 255, 86, 0, 243, 255, 23, 0, 141, 255, 84, 0, 244, 255, 24, 0, 140, 255, 82, 0, 244, 255, 24, 0, 138, 255, 80, 0, 245, 255, 25, 0, 136, 255, 77, 0, 245, 255, 25, 0, 135, 255, 75, 0, 245, 255, 26, 0, 133, 255, 73, 0, 246, 255, 26, 0
  .byte 131, 255, 70, 0, 246, 255, 27, 0, 130, 255, 68, 0, 247, 255, 27, 0, 128, 255, 65, 0, 247, 255, 27, 0, 127, 255, 63, 0, 248, 255, 28, 0, 126, 255, 60, 0, 248, 255, 28, 0, 124, 255, 58, 0, 249, 255, 29, 0, 123, 255, 55, 0, 249, 255, 29, 0, 122, 255, 52, 0, 249, 255, 29, 0, 121, 255, 50, 0, 250, 255, 30, 0, 120, 255, 47, 0, 250, 255, 30, 0, 119, 255, 44, 0, 251, 255, 30, 0, 118, 255, 42, 0, 252, 255, 31, 0, 117, 255, 39, 0, 252, 255, 31, 0, 116, 255, 36, 0, 253, 255, 31, 0, 115, 255, 33, 0, 253, 255, 31, 0, 114, 255, 31, 0, 254, 255, 32, 0, 114, 255, 28, 0, 254, 255, 32, 0, 113, 255, 25, 0, 255, 255, 32, 0, 112, 255, 22, 0, 255, 255, 32, 0, 112, 255, 19, 0, 0, 0, 32, 0, 111, 255, 16, 0, 0, 0, 33, 0, 111, 255, 13, 0, 0, 0, 33, 0, 110, 255, 10, 0, 0, 0, 33, 0, 110, 255, 8, 0, 1, 0, 33, 0, 110, 255, 5, 0, 2, 0, 33, 0, 110, 255, 2, 0, 2, 0, 33, 0, 109, 255, 0, 0, 3, 0, 33, 0, 109, 255, 253, 255, 3, 0, 33, 0, 109, 255, 250, 255, 4, 0, 34, 0, 109, 255, 247, 255, 4, 0, 34, 0, 110, 255, 244, 255, 5, 0, 34, 0, 110, 255, 241, 255, 6, 0, 34, 0
  .byte 110, 255, 238, 255, 6, 0, 34, 0, 110, 255, 235, 255, 7, 0, 34, 0, 110, 255, 232, 255, 7, 0, 34, 0, 111, 255, 229, 255, 8, 0, 34, 0, 111, 255, 226, 255, 8, 0, 34, 0, 112, 255, 223, 255, 9, 0, 33, 0, 112, 255, 220, 255, 10, 0, 33, 0, 113, 255, 218, 255, 10, 0, 33, 0, 114, 255, 215, 255, 11, 0, 33, 0, 114, 255, 212, 255, 11, 0, 33, 0, 115, 255, 209, 255, 12, 0, 33, 0, 116, 255, 206, 255, 12, 0, 33, 0, 117, 255, 203, 255, 13, 0, 33, 0, 118, 255, 200, 255, 14, 0, 33, 0, 119, 255, 198, 255, 14, 0, 32, 0, 120, 255, 195, 255, 15, 0, 32, 0, 121, 255, 192, 255, 15, 0, 32, 0, 122, 255, 189, 255, 16, 0, 32, 0, 124, 255, 186, 255, 16, 0, 31, 0, 125, 255, 184, 255, 17, 0, 31, 0, 126, 255, 181, 255, 17, 0, 31, 0, 128, 255, 178, 255, 18, 0, 31, 0, 129, 255, 176, 255, 18, 0, 30, 0, 131, 255, 173, 255, 19, 0, 30, 0, 132, 255, 171, 255, 19, 0, 30, 0, 134, 255, 168, 255, 20, 0, 29, 0, 136, 255, 166, 255, 20, 0, 29, 0, 138, 255, 163, 255, 21, 0, 29, 0, 139, 255, 161, 255, 21, 0, 28, 0, 141, 255, 158, 255, 22, 0, 28, 0, 143, 255, 156, 255, 22, 0, 28, 0, 145, 255, 154, 255, 22, 0, 27, 0
  .byte 147, 255, 151, 255, 23, 0, 27, 0, 149, 255, 149, 255, 23, 0, 26, 0, 151, 255, 147, 255, 24, 0, 26, 0, 153, 255, 145, 255, 24, 0, 26, 0, 155, 255, 142, 255, 24, 0, 25, 0, 158, 255, 140, 255, 25, 0, 25, 0, 160, 255, 138, 255, 25, 0, 24, 0, 162, 255, 136, 255, 26, 0, 24, 0, 165, 255, 134, 255, 26, 0, 23, 0, 167, 255, 132, 255, 26, 0, 23, 0, 169, 255, 131, 255, 27, 0, 22, 0, 172, 255, 129, 255, 27, 0, 22, 0, 174, 255, 127, 255, 27, 0, 21, 0, 177, 255, 125, 255, 27, 0, 21, 0, 179, 255, 124, 255, 28, 0, 20, 0, 182, 255, 122, 255, 28, 0, 20, 0, 185, 255, 120, 255, 28, 0, 19, 0, 187, 255, 119, 255, 28, 0, 18, 0, 190, 255, 117, 255, 29, 0, 18, 0, 193, 255, 116, 255, 29, 0, 17, 0, 196, 255, 115, 255, 29, 0, 17, 0, 198, 255, 113, 255, 29, 0, 16, 0, 201, 255, 112, 255, 29, 0, 15, 0, 204, 255, 111, 255, 30, 0, 15, 0, 207, 255, 110, 255, 30, 0, 14, 0, 210, 255, 109, 255, 30, 0, 14, 0, 213, 255, 108, 255, 30, 0, 13, 0, 216, 255, 107, 255, 30, 0, 12, 0, 219, 255, 106, 255, 30, 0, 12, 0, 222, 255, 105, 255, 30, 0, 11, 0, 225, 255, 104, 255, 30, 0, 10, 0, 228, 255, 103, 255, 30, 0, 10, 0
  .byte 231, 255, 103, 255, 30, 0, 9, 0, 234, 255, 102, 255, 30, 0, 8, 0, 237, 255, 101, 255, 30, 0, 8, 0, 240, 255, 101, 255, 30, 0, 7, 0, 243, 255, 101, 255, 30, 0, 6, 0, 246, 255, 100, 255, 30, 0, 6, 0, 249, 255, 100, 255, 30, 0, 5, 0, 253, 255, 100, 255, 30, 0, 4, 0, 0, 0, 99, 255, 30, 0, 4, 0, 2, 0, 99, 255, 30, 0, 3, 0, 5, 0, 99, 255, 30, 0, 2, 0, 8, 0, 99, 255, 30, 0, 2, 0, 11, 0, 99, 255, 30, 0, 1, 0, 14, 0, 100, 255, 30, 0, 0, 0, 18, 0, 100, 255, 29, 0, 0, 0, 21, 0, 100, 255, 29, 0, 0, 0, 24, 0, 100, 255, 29, 0, 255, 255, 27, 0, 101, 255, 29, 0, 255, 255, 30, 0, 101, 255, 29, 0, 254, 255, 33, 0, 102, 255, 28, 0, 254, 255, 36, 0, 102, 255, 28, 0, 253, 255, 39, 0, 103, 255, 28, 0, 252, 255, 43, 0, 104, 255, 27, 0, 252, 255, 46, 0, 104, 255, 27, 0, 251, 255, 49, 0, 105, 255, 27, 0, 250, 255, 52, 0, 106, 255, 26, 0, 250, 255, 55, 0, 107, 255, 26, 0, 249, 255, 58, 0, 108, 255, 26, 0, 248, 255, 61, 0, 109, 255, 25, 0, 248, 255, 64, 0, 110, 255, 25, 0, 247, 255, 67, 0, 112, 255, 24, 0, 247, 255, 70, 0, 113, 255, 24, 0, 246, 255
  .byte 73, 0, 114, 255, 24, 0, 245, 255, 76, 0, 115, 255, 23, 0, 245, 255, 78, 0, 117, 255, 23, 0, 244, 255, 81, 0, 118, 255, 22, 0, 244, 255, 84, 0, 120, 255, 22, 0, 243, 255, 87, 0, 122, 255, 21, 0, 242, 255, 90, 0, 123, 255, 21, 0, 242, 255, 92, 0, 125, 255, 20, 0, 241, 255, 95, 0, 127, 255, 20, 0, 241, 255, 98, 0, 129, 255, 19, 0, 240, 255, 100, 0, 130, 255, 18, 0, 240, 255, 103, 0, 132, 255, 18, 0, 239, 255, 105, 0, 134, 255, 17, 0, 239, 255, 108, 0, 136, 255, 17, 0, 238, 255, 110, 0, 139, 255, 16, 0, 238, 255, 113, 0, 141, 255, 15, 0, 237, 255, 115, 0, 143, 255, 15, 0, 237, 255, 118, 0, 145, 255, 14, 0, 236, 255, 120, 0, 147, 255, 13, 0, 236, 255, 122, 0, 150, 255, 13, 0, 236, 255, 124, 0, 152, 255, 12, 0, 235, 255, 126, 0, 155, 255, 11, 0, 235, 255, 129, 0, 157, 255, 11, 0, 234, 255, 131, 0, 160, 255, 10, 0, 234, 255, 133, 0, 162, 255, 9, 0, 234, 255, 135, 0, 165, 255, 8, 0, 233, 255, 137, 0, 167, 255, 8, 0, 233, 255, 138, 0, 170, 255, 7, 0, 233, 255, 140, 0, 173, 255, 6, 0, 232, 255, 142, 0, 176, 255, 5, 0, 232, 255, 144, 0, 178, 255, 4, 0, 232, 255, 145, 0, 181, 255, 4, 0, 232, 255
  .byte 147, 0, 184, 255, 3, 0, 231, 255, 148, 0, 187, 255, 2, 0, 231, 255, 150, 0, 190, 255, 1, 0, 231, 255, 151, 0, 193, 255, 0, 0, 231, 255, 153, 0, 196, 255, 0, 0, 230, 255, 154, 0, 199, 255, 0, 0, 230, 255, 155, 0, 202, 255, 255, 255, 230, 255, 156, 0, 205, 255, 254, 255, 230, 255, 157, 0, 208, 255, 253, 255, 230, 255, 159, 0, 211, 255, 252, 255, 230, 255, 160, 0, 215, 255, 251, 255, 230, 255, 160, 0, 218, 255, 250, 255, 230, 255, 161, 0, 221, 255, 250, 255, 229, 255, 162, 0, 224, 255, 249, 255, 229, 255, 163, 0, 227, 255, 248, 255, 229, 255, 164, 0, 231, 255, 247, 255, 229, 255, 164, 0, 234, 255, 246, 255, 229, 255, 165, 0, 237, 255, 245, 255, 229, 255, 165, 0, 240, 255, 244, 255, 229, 255, 166, 0, 244, 255, 243, 255, 230, 255, 166, 0, 247, 255, 242, 255, 230, 255, 166, 0, 250, 255, 241, 255, 230, 255, 166, 0, 254, 255, 241, 255, 230, 255, 167, 0, 0, 0, 240, 255, 230, 255, 167, 0, 3, 0, 239, 255, 230, 255, 167, 0, 7, 0, 238, 255, 230, 255, 167, 0, 10, 0, 237, 255, 230, 255, 167, 0, 14, 0, 236, 255, 231, 255, 166, 0, 17, 0, 235, 255, 231, 255, 166, 0, 20, 0, 234, 255, 231, 255, 166, 0, 24, 0, 233, 255, 231, 255, 165, 0, 27, 0, 232, 255, 231, 255
  .byte 165, 0, 30, 0, 231, 255, 232, 255, 164, 0, 34, 0, 231, 255, 232, 255, 164, 0, 37, 0, 230, 255, 232, 255, 163, 0, 40, 0, 229, 255, 233, 255, 162, 0, 43, 0, 228, 255, 233, 255, 162, 0, 47, 0, 227, 255, 233, 255, 161, 0, 50, 0, 226, 255, 234, 255, 160, 0, 53, 0, 225, 255, 234, 255, 159, 0, 57, 0, 224, 255, 235, 255, 158, 0, 60, 0, 224, 255, 235, 255, 157, 0, 63, 0, 223, 255, 235, 255, 156, 0, 66, 0, 222, 255, 236, 255, 154, 0, 69, 0, 221, 255, 236, 255, 153, 0, 72, 0, 220, 255, 237, 255, 152, 0, 76, 0, 219, 255, 237, 255, 150, 0, 79, 0, 218, 255, 238, 255, 149, 0, 82, 0, 218, 255, 238, 255, 147, 0, 85, 0, 217, 255, 239, 255, 145, 0, 88, 0, 216, 255, 240, 255, 144, 0, 91, 0, 215, 255, 240, 255, 142, 0, 94, 0, 214, 255, 241, 255, 140, 0, 97, 0, 214, 255, 241, 255, 138, 0, 99, 0, 213, 255, 242, 255, 136, 0, 102, 0, 212, 255, 243, 255, 134, 0, 105, 0, 211, 255, 243, 255, 132, 0, 108, 0, 211, 255, 244, 255, 130, 0, 111, 0, 210, 255, 245, 255, 128, 0, 113, 0, 209, 255, 245, 255, 126, 0, 116, 0, 209, 255, 246, 255, 124, 0, 118, 0, 208, 255, 247, 255, 121, 0, 121, 0, 207, 255, 248, 255, 119, 0, 123, 0, 206, 255, 248, 255
  .byte 117, 0, 126, 0, 206, 255, 249, 255, 114, 0, 128, 0, 205, 255, 250, 255, 112, 0, 131, 0, 205, 255, 251, 255, 109, 0, 133, 0, 204, 255, 252, 255, 106, 0, 135, 0, 203, 255, 252, 255, 104, 0, 138, 0, 203, 255, 253, 255, 101, 0, 140, 0, 202, 255, 254, 255, 98, 0, 142, 0, 202, 255, 255, 255, 96, 0, 144, 0, 201, 255, 0, 0, 93, 0, 146, 0, 201, 255, 0, 0, 90, 0, 148, 0, 200, 255, 1, 0, 87, 0, 150, 0, 200, 255, 1, 0, 84, 0, 152, 0, 199, 255, 2, 0, 81, 0, 153, 0, 199, 255, 3, 0, 78, 0, 155, 0, 198, 255, 4, 0, 75, 0, 157, 0, 198, 255, 5, 0, 72, 0, 158, 0, 197, 255, 6, 0, 69, 0, 160, 0, 197, 255, 7, 0, 65, 0, 161, 0, 196, 255, 8, 0, 62, 0, 163, 0, 196, 255, 9, 0, 59, 0, 164, 0, 196, 255, 10, 0, 56, 0, 165, 0, 195, 255, 11, 0, 52, 0, 166, 0, 195, 255, 12, 0, 49, 0, 168, 0, 195, 255, 13, 0, 46, 0, 169, 0, 194, 255, 14, 0, 42, 0, 170, 0, 194, 255, 15, 0, 39, 0, 171, 0, 194, 255, 16, 0, 36, 0, 172, 0, 194, 255, 17, 0, 32, 0, 172, 0, 193, 255, 18, 0, 29, 0, 173, 0, 193, 255, 19, 0, 25, 0, 174, 0, 193, 255, 20, 0, 22, 0, 174, 0, 193, 255, 21, 0
  .byte 18, 0, 175, 0, 193, 255, 22, 0, 15, 0, 175, 0, 193, 255, 23, 0, 11, 0, 176, 0, 192, 255, 24, 0, 8, 0, 176, 0, 192, 255, 25, 0, 4, 0, 176, 0, 192, 255, 26, 0, 1, 0, 177, 0, 192, 255, 28, 0, 254, 255, 177, 0, 192, 255, 29, 0, 251, 255, 177, 0, 192, 255, 30, 0, 247, 255, 177, 0, 192, 255, 31, 0, 244, 255, 177, 0, 192, 255, 32, 0, 240, 255, 176, 0, 192, 255, 33, 0, 236, 255, 176, 0, 192, 255, 34, 0, 233, 255, 176, 0, 192, 255, 35, 0, 229, 255, 176, 0, 192, 255, 36, 0, 226, 255, 175, 0, 193, 255, 37, 0, 222, 255, 175, 0, 193, 255, 38, 0, 219, 255, 174, 0, 193, 255, 39, 0, 215, 255, 173, 0, 193, 255, 40, 0, 212, 255, 173, 0, 193, 255, 41, 0, 208, 255, 172, 0, 193, 255, 42, 0, 205, 255, 171, 0, 194, 255, 43, 0, 201, 255, 170, 0, 194, 255, 44, 0, 198, 255, 169, 0, 194, 255, 45, 0, 194, 255, 168, 0, 194, 255, 46, 0, 191, 255, 167, 0, 195, 255, 48, 0, 188, 255, 165, 0, 195, 255, 49, 0, 184, 255, 164, 0, 195, 255, 50, 0, 181, 255, 163, 0, 196, 255, 51, 0, 178, 255, 161, 0, 196, 255, 52, 0, 174, 255, 160, 0, 196, 255, 53, 0, 171, 255, 158, 0, 197, 255, 54, 0, 168, 255, 157, 0, 197, 255, 55, 0
  .byte 165, 255, 155, 0, 198, 255, 55, 0, 162, 255, 153, 0, 198, 255, 56, 0, 158, 255, 151, 0, 199, 255, 57, 0, 155, 255, 150, 0, 199, 255, 58, 0, 152, 255, 148, 0, 200, 255, 59, 0, 149, 255, 146, 0, 200, 255, 60, 0, 146, 255, 144, 0, 201, 255, 61, 0, 143, 255, 141, 0, 201, 255, 62, 0, 141, 255, 139, 0, 202, 255, 63, 0, 138, 255, 137, 0, 202, 255, 64, 0, 135, 255, 135, 0, 203, 255, 65, 0, 132, 255, 132, 0, 204, 255, 66, 0, 129, 255, 130, 0, 204, 255, 66, 0, 127, 255, 127, 0, 205, 255, 67, 0, 124, 255, 125, 0, 206, 255, 68, 0, 121, 255, 122, 0, 206, 255, 69, 0, 119, 255, 120, 0, 207, 255, 70, 0, 116, 255, 117, 0, 208, 255, 71, 0, 114, 255, 114, 0, 208, 255, 71, 0, 112, 255, 111, 0, 209, 255, 72, 0, 109, 255, 109, 0, 210, 255, 73, 0, 107, 255, 106, 0, 211, 255, 74, 0, 105, 255, 103, 0, 211, 255, 74, 0, 103, 255, 100, 0, 212, 255, 75, 0, 101, 255, 97, 0, 213, 255, 76, 0, 99, 255, 94, 0, 214, 255, 76, 0, 97, 255, 91, 0, 215, 255, 77, 0, 95, 255, 87, 0, 215, 255, 78, 0, 93, 255, 84, 0, 216, 255, 78, 0, 91, 255, 81, 0, 217, 255, 79, 0, 90, 255, 78, 0, 218, 255, 79, 0, 88, 255, 74, 0, 219, 255, 80, 0
  .byte 86, 255, 71, 0, 220, 255, 81, 0, 85, 255, 68, 0, 221, 255, 81, 0, 83, 255, 64, 0, 221, 255, 82, 0, 82, 255, 61, 0, 222, 255, 82, 0, 81, 255, 57, 0, 223, 255, 83, 0, 79, 255, 54, 0, 224, 255, 83, 0, 78, 255, 50, 0, 225, 255, 84, 0, 77, 255, 47, 0, 226, 255, 84, 0, 76, 255, 43, 0, 227, 255, 85, 0, 75, 255, 40, 0, 228, 255, 85, 0, 74, 255, 36, 0, 229, 255, 85, 0, 73, 255, 32, 0, 230, 255, 86, 0, 73, 255, 29, 0, 231, 255, 86, 0, 72, 255, 25, 0, 232, 255, 86, 0, 71, 255, 21, 0, 233, 255, 87, 0, 71, 255, 18, 0, 234, 255, 87, 0, 70, 255, 14, 0, 235, 255, 87, 0, 70, 255, 10, 0, 236, 255, 88, 0, 70, 255, 7, 0, 237, 255, 88, 0, 69, 255, 3, 0, 238, 255, 88, 0, 69, 255, 0, 0, 239, 255, 88, 0, 69, 255, 252, 255, 240, 255, 88, 0, 69, 255, 249, 255, 241, 255, 89, 0, 69, 255, 245, 255, 242, 255, 89, 0, 69, 255, 241, 255, 243, 255, 89, 0, 70, 255, 237, 255, 244, 255, 89, 0, 70, 255, 234, 255, 245, 255, 89, 0, 70, 255, 230, 255, 246, 255, 89, 0, 71, 255, 226, 255, 247, 255, 89, 0, 71, 255, 222, 255, 248, 255, 89, 0, 72, 255, 219, 255, 249, 255, 89, 0, 73, 255, 215, 255, 250, 255, 89, 0
  .byte 73, 255, 211, 255, 251, 255, 89, 0, 74, 255, 208, 255, 252, 255, 89, 0, 75, 255, 204, 255, 253, 255, 89, 0, 76, 255, 200, 255, 254, 255, 89, 0, 77, 255, 197, 255, 255, 255, 89, 0, 78, 255, 193, 255, 0, 0, 89, 0, 79, 255, 189, 255, 0, 0, 89, 0, 81, 255, 186, 255, 1, 0, 88, 0, 82, 255, 182, 255, 2, 0, 88, 0, 83, 255, 179, 255, 2, 0, 88, 0, 85, 255, 175, 255, 3, 0, 88, 0, 86, 255, 172, 255, 4, 0, 88, 0, 88, 255, 168, 255, 5, 0, 87, 0, 90, 255, 165, 255, 6, 0, 87, 0, 91, 255, 161, 255, 7, 0, 87, 0, 93, 255, 158, 255, 8, 0, 87, 0, 95, 255, 155, 255, 9, 0, 86, 0, 97, 255, 152, 255, 10, 0, 86, 0, 99, 255, 148, 255, 11, 0, 86, 0, 101, 255, 145, 255, 12, 0, 85, 0, 103, 255, 142, 255, 13, 0, 85, 0, 106, 255, 139, 255, 13, 0, 84, 0, 108, 255, 136, 255, 14, 0, 84, 0, 110, 255, 133, 255, 15, 0, 84, 0, 113, 255, 130, 255, 16, 0, 83, 0, 115, 255, 127, 255, 17, 0, 83, 0, 118, 255, 124, 255, 18, 0, 82, 0, 120, 255, 121, 255, 18, 0, 82, 0, 123, 255, 118, 255, 19, 0, 81, 0, 125, 255, 116, 255, 20, 0, 81, 0, 128, 255, 113, 255, 21, 0, 80, 0, 131, 255, 110, 255, 21, 0, 80, 0
  .byte 134, 255, 108, 255, 22, 0, 79, 0, 137, 255, 105, 255, 23, 0, 78, 0, 140, 255, 103, 255, 24, 0, 78, 0, 143, 255, 100, 255, 24, 0, 77, 0, 146, 255, 98, 255, 25, 0, 77, 0, 149, 255, 96, 255, 26, 0, 76, 0, 152, 255, 93, 255, 26, 0, 75, 0, 155, 255, 91, 255, 27, 0, 75, 0, 159, 255, 89, 255, 28, 0, 74, 0, 162, 255, 87, 255, 28, 0, 73, 0, 165, 255, 85, 255, 29, 0, 73, 0, 169, 255, 83, 255, 29, 0, 72, 0, 172, 255, 81, 255, 30, 0, 71, 0, 176, 255, 80, 255, 31, 0, 70, 0, 179, 255, 78, 255, 31, 0, 70, 0, 183, 255, 76, 255, 32, 0, 69, 0, 186, 255, 75, 255, 32, 0, 68, 0, 190, 255, 73, 255, 33, 0, 67, 0, 194, 255, 72, 255, 33, 0, 67, 0, 197, 255, 70, 255, 33, 0, 66, 0, 201, 255, 69, 255, 34, 0, 65, 0, 205, 255, 68, 255, 34, 0, 64, 0, 208, 255, 67, 255, 35, 0, 63, 0, 212, 255, 66, 255, 35, 0, 63, 0, 216, 255, 65, 255, 35, 0, 62, 0, 220, 255, 64, 255, 36, 0, 61, 0, 224, 255, 63, 255, 36, 0, 60, 0, 227, 255, 62, 255, 36, 0, 59, 0, 231, 255, 62, 255, 37, 0, 59, 0, 235, 255, 61, 255, 37, 0, 58, 0, 239, 255, 61, 255, 37, 0, 57, 0, 243, 255, 60, 255, 37, 0, 56, 0
  .byte 247, 255, 60, 255, 38, 0, 55, 0, 251, 255, 60, 255, 38, 0, 54, 0, 255, 255, 59, 255, 38, 0, 53, 0, 2, 0, 59, 255, 38, 0, 53, 0, 6, 0, 59, 255, 38, 0, 52, 0, 10, 0, 59, 255, 38, 0, 51, 0, 14, 0, 59, 255, 38, 0, 50, 0, 18, 0, 59, 255, 38, 0, 49, 0, 21, 0, 60, 255, 38, 0, 48, 0, 25, 0, 60, 255, 39, 0, 47, 0, 29, 0, 61, 255, 39, 0, 47, 0, 33, 0, 61, 255, 39, 0, 46, 0, 37, 0, 62, 255, 39, 0, 45, 0, 41, 0, 62, 255, 38, 0, 44, 0, 45, 0, 63, 255, 38, 0, 43, 0, 49, 0, 64, 255, 38, 0, 42, 0, 53, 0, 65, 255, 38, 0, 41, 0, 57, 0, 66, 255, 38, 0, 41, 0, 61, 0, 67, 255, 38, 0, 40, 0, 64, 0, 68, 255, 38, 0, 39, 0, 68, 0, 69, 255, 38, 0, 38, 0, 72, 0, 70, 255, 38, 0, 37, 0, 76, 0, 71, 255, 37, 0, 36, 0, 80, 0, 73, 255, 37, 0, 36, 0, 83, 0, 74, 255, 37, 0, 35, 0, 87, 0, 76, 255, 37, 0, 34, 0, 91, 0, 77, 255, 36, 0, 33, 0, 95, 0, 79, 255, 36, 0, 32, 0, 98, 0, 80, 255, 36, 0, 32, 0, 102, 0, 82, 255, 36, 0, 31, 0, 106, 0, 84, 255, 35, 0, 30, 0, 109, 0, 86, 255, 35, 0, 29, 0
  .byte 113, 0, 88, 255, 35, 0, 28, 0, 116, 0, 90, 255, 34, 0, 28, 0, 120, 0, 92, 255, 34, 0, 27, 0, 123, 0, 94, 255, 33, 0, 26, 0, 127, 0, 96, 255, 33, 0, 25, 0, 130, 0, 98, 255, 33, 0, 24, 0, 134, 0, 101, 255, 32, 0, 24, 0, 137, 0, 103, 255, 32, 0, 23, 0, 140, 0, 106, 255, 31, 0, 22, 0, 144, 0, 108, 255, 31, 0, 22, 0, 147, 0, 111, 255, 30, 0, 21, 0, 150, 0, 113, 255, 30, 0, 20, 0, 154, 0, 116, 255, 29, 0, 19, 0, 157, 0, 119, 255, 29, 0, 19, 0, 160, 0, 122, 255, 28, 0, 18, 0, 163, 0, 124, 255, 28, 0, 17, 0, 166, 0, 127, 255, 27, 0, 17, 0, 169, 0, 130, 255, 26, 0, 16, 0, 172, 0, 133, 255, 26, 0, 15, 0, 175, 0, 137, 255, 25, 0, 15, 0, 178, 0, 140, 255, 24, 0, 14, 0, 181, 0, 143, 255, 24, 0, 14, 0, 183, 0, 146, 255, 23, 0, 13, 0, 186, 0, 150, 255, 22, 0, 12, 0, 189, 0, 153, 255, 22, 0, 12, 0, 191, 0, 157, 255, 21, 0, 11, 0, 194, 0, 160, 255, 20, 0, 11, 0, 197, 0, 164, 255, 19, 0, 10, 0, 199, 0, 168, 255, 19, 0, 10, 0, 201, 0, 171, 255, 18, 0, 9, 0, 204, 0, 175, 255, 17, 0, 9, 0, 206, 0, 179, 255, 16, 0, 8, 0
  .byte 208, 0, 183, 255, 15, 0, 8, 0, 210, 0, 187, 255, 15, 0, 7, 0, 213, 0, 191, 255, 14, 0, 7, 0, 215, 0, 195, 255, 13, 0, 6, 0, 217, 0, 199, 255, 12, 0, 6, 0, 219, 0, 203, 255, 11, 0, 5, 0, 220, 0, 207, 255, 10, 0, 5, 0, 222, 0, 211, 255, 9, 0, 5, 0, 224, 0, 216, 255, 8, 0, 4, 0, 226, 0, 220, 255, 7, 0, 4, 0, 227, 0, 225, 255, 7, 0, 4, 0, 229, 0, 229, 255, 6, 0, 3, 0, 230, 0, 233, 255, 5, 0, 3, 0, 231, 0, 238, 255, 4, 0, 3, 0, 233, 0, 243, 255, 3, 0, 3, 0, 234, 0, 247, 255, 2, 0, 2, 0, 235, 0, 252, 255, 1, 0, 2, 0, 236, 0, 0, 0, 0, 0, 2, 0, 237, 0, 4, 0, 0, 0, 2, 0, 238, 0, 9, 0, 255, 255, 2, 0, 239, 0, 14, 0, 254, 255, 2, 0, 239, 0, 19, 0, 252, 255, 2, 0, 240, 0, 24, 0, 251, 255, 1, 0, 240, 0, 29, 0, 250, 255, 1, 0, 241, 0, 34, 0, 249, 255, 1, 0, 241, 0, 39, 0, 248, 255, 1, 0, 241, 0, 44, 0, 247, 255, 1, 0, 242, 0, 49, 0, 246, 255, 1, 0, 242, 0, 54, 0, 245, 255, 1, 0, 242, 0, 59, 0, 244, 255, 1, 0, 241, 0, 64, 0, 243, 255, 2, 0, 241, 0, 69, 0, 241, 255, 2, 0
  .byte 241, 0, 74, 0, 240, 255, 2, 0, 241, 0, 80, 0, 239, 255, 2, 0, 240, 0, 85, 0, 238, 255, 2, 0, 239, 0, 90, 0, 237, 255, 2, 0, 239, 0, 95, 0, 236, 255, 3, 0, 238, 0, 100, 0, 235, 255, 3, 0, 237, 0, 106, 0, 234, 255, 3, 0, 236, 0, 111, 0, 232, 255, 4, 0, 235, 0, 116, 0, 231, 255, 4, 0, 234, 0, 122, 0, 230, 255, 4, 0, 232, 0, 127, 0, 229, 255, 5, 0, 231, 0, 132, 0, 228, 255, 5, 0, 229, 0, 137, 0, 227, 255, 5, 0, 228, 0, 143, 0, 225, 255, 6, 0, 226, 0, 148, 0, 224, 255, 6, 0, 224, 0, 153, 0, 223, 255, 7, 0, 222, 0, 158, 0, 222, 255, 8, 0, 220, 0, 164, 0, 221, 255, 8, 0, 218, 0, 169, 0, 220, 255, 9, 0, 215, 0, 174, 0, 219, 255, 9, 0, 213, 0, 179, 0, 217, 255, 10, 0, 210, 0, 185, 0, 216, 255, 11, 0, 208, 0, 190, 0, 215, 255, 11, 0, 205, 0, 195, 0, 214, 255, 12, 0, 202, 0, 200, 0, 213, 255, 13, 0, 199, 0, 205, 0, 212, 255, 14, 0, 196, 0, 210, 0, 211, 255, 14, 0, 193, 0, 215, 0, 210, 255, 15, 0, 189, 0, 220, 0, 209, 255, 16, 0, 186, 0, 225, 0, 208, 255, 17, 0, 182, 0, 230, 0, 206, 255, 18, 0, 178, 0, 235, 0, 205, 255, 19, 0
  .byte 175, 0, 240, 0, 204, 255, 20, 0, 171, 0, 244, 0, 203, 255, 21, 0, 167, 0, 249, 0, 202, 255, 22, 0, 163, 0, 254, 0, 201, 255, 23, 0, 158, 0, 2, 1, 200, 255, 24, 0, 154, 0, 7, 1, 199, 255, 25, 0, 149, 0, 11, 1, 198, 255, 26, 0, 145, 0, 16, 1, 198, 255, 28, 0, 140, 0, 20, 1, 197, 255, 29, 0, 135, 0, 24, 1, 196, 255, 30, 0, 130, 0, 29, 1, 195, 255, 31, 0, 125, 0, 33, 1, 194, 255, 33, 0, 120, 0, 37, 1, 193, 255, 34, 0, 115, 0, 41, 1, 192, 255, 35, 0, 110, 0, 45, 1, 192, 255, 37, 0, 104, 0, 49, 1, 191, 255, 38, 0, 99, 0, 52, 1, 190, 255, 39, 0, 93, 0, 56, 1, 189, 255, 41, 0, 87, 0, 60, 1, 189, 255, 42, 0, 81, 0, 63, 1, 188, 255, 44, 0, 75, 0, 66, 1, 187, 255, 45, 0, 69, 0, 70, 1, 187, 255, 47, 0, 63, 0, 73, 1, 186, 255, 48, 0, 57, 0, 76, 1, 185, 255, 50, 0, 50, 0, 79, 1, 185, 255, 52, 0, 44, 0, 82, 1, 184, 255, 53, 0, 37, 0, 84, 1, 184, 255, 55, 0, 31, 0, 87, 1, 183, 255, 57, 0, 24, 0, 90, 1, 183, 255, 58, 0, 17, 0, 92, 1, 182, 255, 60, 0, 10, 0, 94, 1, 182, 255, 62, 0, 3, 0, 96, 1, 182, 255, 64, 0
  .byte 253, 255, 98, 1, 181, 255, 65, 0, 246, 255, 100, 1, 181, 255, 67, 0, 239, 255, 102, 1, 181, 255, 69, 0, 231, 255, 103, 1, 181, 255, 71, 0, 224, 255, 105, 1, 180, 255, 73, 0, 217, 255, 106, 1, 180, 255, 74, 0, 209, 255, 107, 1, 180, 255, 76, 0, 201, 255, 108, 1, 180, 255, 78, 0, 194, 255, 109, 1, 180, 255, 80, 0, 186, 255, 110, 1, 180, 255, 82, 0, 178, 255, 111, 1, 180, 255, 84, 0, 171, 255, 111, 1, 180, 255, 86, 0, 163, 255, 111, 1, 180, 255, 88, 0, 155, 255, 112, 1, 180, 255, 90, 0, 147, 255, 112, 1, 180, 255, 92, 0, 139, 255, 111, 1, 181, 255, 94, 0, 131, 255, 111, 1, 181, 255, 96, 0, 123, 255, 111, 1, 181, 255, 98, 0, 115, 255, 110, 1, 182, 255, 100, 0, 106, 255, 109, 1, 182, 255, 102, 0, 98, 255, 108, 1, 182, 255, 104, 0, 90, 255, 107, 1, 183, 255, 106, 0, 82, 255, 105, 1, 183, 255, 108, 0, 74, 255, 104, 1, 184, 255, 110, 0, 65, 255, 102, 1, 184, 255, 112, 0, 57, 255, 100, 1, 185, 255, 114, 0, 49, 255, 98, 1, 186, 255, 116, 0, 40, 255, 96, 1, 187, 255, 118, 0, 32, 255, 94, 1, 187, 255, 120, 0, 24, 255, 91, 1, 188, 255, 122, 0, 16, 255, 88, 1, 189, 255, 125, 0, 7, 255, 85, 1, 190, 255, 127, 0
  .byte 255, 254, 82, 1, 191, 255, 129, 0, 247, 254, 79, 1, 192, 255, 131, 0, 239, 254, 75, 1, 193, 255, 133, 0, 231, 254, 72, 1, 194, 255, 135, 0, 222, 254, 68, 1, 195, 255, 137, 0, 214, 254, 64, 1, 196, 255, 139, 0, 206, 254, 60, 1, 198, 255, 141, 0, 198, 254, 55, 1, 199, 255, 143, 0, 190, 254, 51, 1, 200, 255, 145, 0, 182, 254, 46, 1, 202, 255, 147, 0, 174, 254, 41, 1, 203, 255, 149, 0, 167, 254, 36, 1, 204, 255, 150, 0, 159, 254, 30, 1, 206, 255, 152, 0, 151, 254, 25, 1, 208, 255, 154, 0, 143, 254, 19, 1, 209, 255, 156, 0, 136, 254, 13, 1, 211, 255, 158, 0, 128, 254, 7, 1, 213, 255, 160, 0, 121, 254, 1, 1, 214, 255, 162, 0, 114, 254, 250, 0, 216, 255, 163, 0, 107, 254, 243, 0, 218, 255, 165, 0, 99, 254, 237, 0, 220, 255, 167, 0, 92, 254, 230, 0, 222, 255, 169, 0, 86, 254, 222, 0, 224, 255, 170, 0, 79, 254, 215, 0, 226, 255, 172, 0, 72, 254, 207, 0, 228, 255, 174, 0, 66, 254, 200, 0, 230, 255, 175, 0, 59, 254, 192, 0, 232, 255, 177, 0, 53, 254, 184, 0, 234, 255, 178, 0, 47, 254, 175, 0, 236, 255, 180, 0, 41, 254, 167, 0, 239, 255, 181, 0, 35, 254, 158, 0, 241, 255, 183, 0, 29, 254, 150, 0, 243, 255, 184, 0
  .byte 23, 254, 141, 0, 246, 255, 185, 0, 18, 254, 132, 0, 248, 255, 187, 0, 13, 254, 122, 0, 251, 255, 188, 0, 7, 254, 113, 0, 253, 255, 189, 0, 2, 254, 103, 0, 0, 0, 190, 0, 254, 253, 94, 0, 1, 0, 192, 0, 249, 253, 84, 0, 4, 0, 193, 0, 244, 253, 74, 0, 7, 0, 194, 0, 240, 253, 64, 0, 9, 0, 195, 0, 236, 253, 53, 0, 12, 0, 196, 0, 232, 253, 43, 0, 15, 0, 197, 0, 228, 253, 33, 0, 18, 0, 198, 0, 225, 253, 22, 0, 20, 0, 198, 0, 222, 253, 11, 0, 23, 0, 199, 0, 219, 253, 0, 0, 26, 0, 200, 0, 216, 253, 246, 255, 29, 0, 201, 0, 213, 253, 235, 255, 32, 0, 201, 0, 210, 253, 224, 255, 35, 0, 202, 0, 208, 253, 212, 255, 38, 0, 202, 0, 206, 253, 201, 255, 41, 0, 203, 0, 204, 253, 189, 255, 44, 0, 203, 0, 203, 253, 177, 255, 47, 0, 203, 0, 201, 253, 166, 255, 50, 0, 204, 0, 200, 253, 154, 255, 54, 0, 204, 0, 199, 253, 142, 255, 57, 0, 204, 0, 199, 253, 130, 255, 60, 0, 204, 0, 198, 253, 118, 255, 63, 0, 204, 0, 198, 253, 105, 255, 66, 0, 204, 0, 198, 253, 93, 255, 70, 0, 204, 0, 199, 253, 81, 255, 73, 0, 204, 0, 199, 253, 68, 255, 76, 0, 204, 0, 200, 253, 56, 255, 79, 0, 203, 0
  .byte 201, 253, 44, 255, 83, 0, 203, 0, 202, 253, 31, 255, 86, 0, 203, 0, 204, 253, 19, 255, 89, 0, 202, 0, 206, 253, 6, 255, 92, 0, 202, 0, 208, 253, 249, 254, 96, 0, 201, 0, 211, 253, 237, 254, 99, 0, 200, 0, 213, 253, 224, 254, 102, 0, 200, 0, 216, 253, 212, 254, 106, 0, 199, 0, 219, 253, 199, 254, 109, 0, 198, 0, 223, 253, 186, 254, 112, 0, 197, 0, 227, 253, 174, 254, 116, 0, 196, 0, 231, 253, 161, 254, 119, 0, 195, 0, 235, 253, 148, 254, 122, 0, 194, 0, 240, 253, 136, 254, 125, 0, 192, 0, 245, 253, 123, 254, 129, 0, 191, 0, 250, 253, 111, 254, 132, 0, 190, 0, 255, 253, 98, 254, 135, 0, 188, 0, 5, 254, 86, 254, 139, 0, 187, 0, 11, 254, 74, 254, 142, 0, 185, 0, 17, 254, 61, 254, 145, 0, 183, 0, 24, 254, 49, 254, 148, 0, 182, 0, 31, 254, 37, 254, 151, 0, 180, 0, 38, 254, 25, 254, 155, 0, 178, 0, 45, 254, 13, 254, 158, 0, 176, 0, 53, 254, 1, 254, 161, 0, 174, 0, 61, 254, 245, 253, 164, 0, 172, 0, 69, 254, 234, 253, 167, 0, 170, 0, 78, 254, 222, 253, 170, 0, 168, 0, 87, 254, 211, 253, 173, 0, 165, 0, 96, 254, 199, 253, 176, 0, 163, 0, 105, 254, 188, 253, 179, 0, 160, 0, 115, 254, 177, 253, 182, 0, 158, 0
  .byte 125, 254, 166, 253, 185, 0, 155, 0, 135, 254, 156, 253, 188, 0, 153, 0, 146, 254, 145, 253, 190, 0, 150, 0, 156, 254, 135, 253, 193, 0, 147, 0, 167, 254, 124, 253, 196, 0, 144, 0, 179, 254, 114, 253, 198, 0, 141, 0, 190, 254, 104, 253, 201, 0, 138, 0, 202, 254, 95, 253, 204, 0, 135, 0, 214, 254, 85, 253, 206, 0, 132, 0, 226, 254, 76, 253, 209, 0, 129, 0, 239, 254, 67, 253, 211, 0, 126, 0, 252, 254, 58, 253, 213, 0, 123, 0, 9, 255, 49, 253, 216, 0, 119, 0, 22, 255, 41, 253, 218, 0, 116, 0, 35, 255, 33, 253, 220, 0, 112, 0, 49, 255, 25, 253, 222, 0, 109, 0, 63, 255, 17, 253, 224, 0, 105, 0, 77, 255, 10, 253, 226, 0, 101, 0, 92, 255, 2, 253, 228, 0, 98, 0, 106, 255, 251, 252, 230, 0, 94, 0, 121, 255, 245, 252, 232, 0, 90, 0, 136, 255, 238, 252, 234, 0, 86, 0, 151, 255, 232, 252, 235, 0, 82, 0, 167, 255, 226, 252, 237, 0, 78, 0, 182, 255, 221, 252, 238, 0, 74, 0, 198, 255, 216, 252, 240, 0, 70, 0, 214, 255, 211, 252, 241, 0, 66, 0, 230, 255, 206, 252, 243, 0, 62, 0, 247, 255, 202, 252, 244, 0, 58, 0, 6, 0, 197, 252, 245, 0, 54, 0, 23, 0, 194, 252, 246, 0, 49, 0, 40, 0, 190, 252, 247, 0, 45, 0
  .byte 57, 0, 187, 252, 248, 0, 41, 0, 74, 0, 185, 252, 249, 0, 36, 0, 91, 0, 182, 252, 249, 0, 32, 0, 108, 0, 180, 252, 250, 0, 27, 0, 126, 0, 178, 252, 251, 0, 23, 0, 143, 0, 177, 252, 251, 0, 18, 0, 161, 0, 176, 252, 251, 0, 14, 0, 179, 0, 175, 252, 252, 0, 9, 0, 197, 0, 175, 252, 252, 0, 5, 0, 215, 0, 175, 252, 252, 0, 0, 0, 233, 0, 176, 252, 252, 0, 252, 255, 251, 0, 176, 252, 252, 0, 248, 255, 13, 1, 178, 252, 252, 0, 243, 255, 31, 1, 179, 252, 251, 0, 238, 255, 50, 1, 181, 252, 251, 0, 234, 255, 68, 1, 184, 252, 251, 0, 229, 255, 86, 1, 186, 252, 250, 0, 224, 255, 105, 1, 189, 252, 249, 0, 220, 255, 123, 1, 193, 252, 249, 0, 215, 255, 141, 1, 197, 252, 248, 0, 210, 255, 160, 1, 201, 252, 247, 0, 205, 255, 178, 1, 206, 252, 246, 0, 201, 255, 197, 1, 211, 252, 245, 0, 196, 255, 215, 1, 216, 252, 243, 0, 191, 255, 233, 1, 222, 252, 242, 0, 186, 255, 252, 1, 228, 252, 241, 0, 182, 255, 14, 2, 235, 252, 239, 0, 177, 255, 32, 2, 242, 252, 237, 0, 172, 255, 50, 2, 250, 252, 236, 0, 168, 255, 68, 2, 2, 253, 234, 0, 163, 255, 86, 2, 10, 253, 232, 0, 158, 255, 104, 2, 19, 253, 230, 0, 154, 255
  .byte 122, 2, 28, 253, 227, 0, 149, 255, 140, 2, 37, 253, 225, 0, 145, 255, 157, 2, 47, 253, 223, 0, 140, 255, 174, 2, 57, 253, 220, 0, 136, 255, 192, 2, 68, 253, 218, 0, 131, 255, 209, 2, 79, 253, 215, 0, 127, 255, 226, 2, 91, 253, 212, 0, 122, 255, 243, 2, 103, 253, 209, 0, 118, 255, 3, 3, 115, 253, 207, 0, 114, 255, 20, 3, 128, 253, 203, 0, 109, 255, 36, 3, 141, 253, 200, 0, 105, 255, 52, 3, 154, 253, 197, 0, 101, 255, 68, 3, 168, 253, 194, 0, 97, 255, 84, 3, 182, 253, 190, 0, 93, 255, 99, 3, 197, 253, 187, 0, 89, 255, 114, 3, 212, 253, 183, 0, 85, 255, 129, 3, 227, 253, 179, 0, 81, 255, 144, 3, 243, 253, 175, 0, 77, 255, 158, 3, 3, 254, 171, 0, 73, 255, 173, 3, 19, 254, 167, 0, 70, 255, 186, 3, 36, 254, 163, 0, 66, 255, 200, 3, 53, 254, 159, 0, 63, 255, 213, 3, 71, 254, 155, 0, 59, 255, 226, 3, 89, 254, 150, 0, 56, 255, 239, 3, 107, 254, 146, 0, 52, 255, 251, 3, 126, 254, 141, 0, 49, 255, 7, 4, 144, 254, 137, 0, 46, 255, 19, 4, 164, 254, 132, 0, 43, 255, 31, 4, 183, 254, 127, 0, 40, 255, 42, 4, 203, 254, 122, 0, 37, 255, 52, 4, 223, 254, 118, 0, 34, 255, 62, 4, 243, 254, 112, 0, 32, 255
  .byte 72, 4, 8, 255, 107, 0, 29, 255, 82, 4, 29, 255, 102, 0, 26, 255, 91, 4, 50, 255, 97, 0, 24, 255, 100, 4, 72, 255, 92, 0, 22, 255, 108, 4, 94, 255, 86, 0, 19, 255, 116, 4, 116, 255, 81, 0, 17, 255, 123, 4, 138, 255, 75, 0, 15, 255, 131, 4, 161, 255, 70, 0, 13, 255, 137, 4, 184, 255, 64, 0, 11, 255, 143, 4, 207, 255, 58, 0, 10, 255, 149, 4, 230, 255, 53, 0, 8, 255, 154, 4, 253, 255, 47, 0, 7, 255, 159, 4, 20, 0, 41, 0, 5, 255, 164, 4, 44, 0, 35, 0, 4, 255, 168, 4, 68, 0, 29, 0, 3, 255, 171, 4, 92, 0, 23, 0, 2, 255, 174, 4, 117, 0, 17, 0, 1, 255, 176, 4, 141, 0, 11, 0, 0, 255, 178, 4, 166, 0, 5, 0, 0, 255, 180, 4, 191, 0, 0, 0, 255, 254, 181, 4, 216, 0, 250, 255, 255, 254, 181, 4, 241, 0, 244, 255, 254, 254, 181, 4, 10, 1, 237, 255, 254, 254, 181, 4, 35, 1, 231, 255, 254, 254, 180, 4, 60, 1, 225, 255, 254, 254, 178, 4, 86, 1, 219, 255, 254, 254, 176, 4, 111, 1, 212, 255, 255, 254, 173, 4, 137, 1, 206, 255, 255, 254, 170, 4, 163, 1, 200, 255, 0, 255, 166, 4, 188, 1, 193, 255, 1, 255, 162, 4, 214, 1, 187, 255, 2, 255, 157, 4, 239, 1, 181, 255, 3, 255
  .byte 152, 4, 9, 2, 174, 255, 4, 255, 146, 4, 35, 2, 168, 255, 5, 255, 140, 4, 60, 2, 161, 255, 7, 255, 133, 4, 86, 2, 155, 255, 8, 255, 125, 4, 112, 2, 149, 255, 10, 255, 117, 4, 137, 2, 142, 255, 12, 255, 109, 4, 163, 2, 136, 255, 14, 255, 99, 4, 188, 2, 130, 255, 16, 255, 90, 4, 213, 2, 124, 255, 18, 255, 79, 4, 238, 2, 117, 255, 21, 255, 69, 4, 7, 3, 111, 255, 23, 255, 57, 4, 32, 3, 105, 255, 26, 255, 45, 4, 57, 3, 99, 255, 29, 255, 33, 4, 82, 3, 93, 255, 31, 255, 20, 4, 106, 3, 87, 255, 35, 255, 6, 4, 131, 3, 81, 255, 38, 255, 248, 3, 155, 3, 75, 255, 41, 255, 233, 3, 179, 3, 69, 255, 45, 255, 218, 3, 202, 3, 63, 255, 48, 255, 202, 3, 226, 3, 57, 255, 52, 255, 186, 3, 249, 3, 51, 255, 56, 255, 169, 3, 16, 4, 45, 255, 60, 255, 152, 3, 39, 4, 40, 255, 64, 255, 134, 3, 61, 4, 34, 255, 68, 255, 116, 3, 83, 4, 29, 255, 73, 255, 97, 3, 105, 4, 23, 255, 77, 255, 77, 3, 127, 4, 18, 255, 82, 255, 57, 3, 148, 4, 13, 255, 87, 255, 37, 3, 169, 4, 7, 255, 92, 255, 16, 3, 190, 4, 2, 255, 97, 255, 250, 2, 210, 4, 253, 254, 102, 255, 228, 2, 230, 4, 248, 254, 108, 255
  .byte 206, 2, 249, 4, 243, 254, 113, 255, 183, 2, 13, 5, 239, 254, 119, 255, 160, 2, 31, 5, 234, 254, 124, 255, 136, 2, 50, 5, 230, 254, 130, 255, 111, 2, 68, 5, 225, 254, 136, 255, 87, 2, 85, 5, 221, 254, 142, 255, 61, 2, 102, 5, 217, 254, 148, 255, 36, 2, 119, 5, 212, 254, 154, 255, 10, 2, 135, 5, 208, 254, 161, 255, 239, 1, 150, 5, 204, 254, 167, 255, 212, 1, 166, 5, 201, 254, 174, 255, 185, 1, 180, 5, 197, 254, 180, 255, 157, 1, 194, 5, 194, 254, 187, 255, 129, 1, 208, 5, 190, 254, 194, 255, 101, 1, 221, 5, 187, 254, 201, 255, 72, 1, 234, 5, 184, 254, 208, 255, 42, 1, 246, 5, 181, 254, 215, 255, 13, 1, 1, 6, 178, 254, 222, 255, 239, 0, 12, 6, 175, 254, 230, 255, 209, 0, 22, 6, 173, 254, 237, 255, 178, 0, 32, 6, 170, 254, 244, 255, 147, 0, 41, 6, 168, 254, 252, 255, 116, 0, 50, 6, 166, 254, 3, 0, 85, 0, 58, 6, 164, 254, 10, 0, 53, 0, 65, 6, 162, 254, 18, 0, 21, 0, 72, 6, 160, 254, 26, 0, 246, 255, 78, 6, 159, 254, 34, 0, 213, 255, 84, 6, 157, 254, 42, 0, 181, 255, 89, 6, 156, 254, 50, 0, 148, 255, 93, 6, 155, 254, 58, 0, 115, 255, 96, 6, 154, 254, 66, 0, 82, 255, 99, 6, 154, 254, 74, 0
  .byte 48, 255, 101, 6, 153, 254, 82, 0, 15, 255, 103, 6, 153, 254, 90, 0, 237, 254, 104, 6, 152, 254, 99, 0, 203, 254, 104, 6, 152, 254, 107, 0, 169, 254, 104, 6, 152, 254, 115, 0, 135, 254, 102, 6, 153, 254, 124, 0, 101, 254, 100, 6, 153, 254, 132, 0, 66, 254, 98, 6, 154, 254, 140, 0, 32, 254, 95, 6, 155, 254, 149, 0, 254, 253, 91, 6, 156, 254, 157, 0, 219, 253, 86, 6, 157, 254, 166, 0, 185, 253, 80, 6, 158, 254, 174, 0, 150, 253, 74, 6, 160, 254, 182, 0, 116, 253, 67, 6, 162, 254, 191, 0, 81, 253, 60, 6, 163, 254, 199, 0, 47, 253, 51, 6, 165, 254, 208, 0, 13, 253, 42, 6, 168, 254, 216, 0, 234, 252, 32, 6, 170, 254, 225, 0, 200, 252, 22, 6, 173, 254, 233, 0, 166, 252, 11, 6, 176, 254, 241, 0, 132, 252, 255, 5, 179, 254, 250, 0, 98, 252, 242, 5, 182, 254, 2, 1, 65, 252, 229, 5, 185, 254, 10, 1, 31, 252, 214, 5, 189, 254, 18, 1, 254, 251, 199, 5, 192, 254, 26, 1, 221, 251, 184, 5, 196, 254, 35, 1, 188, 251, 167, 5, 200, 254, 43, 1, 155, 251, 150, 5, 205, 254, 51, 1, 122, 251, 133, 5, 209, 254, 59, 1, 90, 251, 114, 5, 214, 254, 66, 1, 58, 251, 95, 5, 218, 254, 74, 1, 27, 251, 75, 5, 223, 254, 82, 1
  .byte 251, 250, 54, 5, 228, 254, 90, 1, 220, 250, 33, 5, 234, 254, 97, 1, 189, 250, 11, 5, 239, 254, 105, 1, 159, 250, 244, 4, 245, 254, 112, 1, 129, 250, 220, 4, 251, 254, 119, 1, 100, 250, 196, 4, 1, 255, 127, 1, 71, 250, 171, 4, 7, 255, 134, 1, 43, 250, 145, 4, 14, 255, 141, 1, 15, 250, 118, 4, 20, 255, 147, 1, 244, 249, 91, 4, 27, 255, 154, 1, 218, 249, 63, 4, 34, 255, 160, 1, 192, 249, 34, 4, 41, 255, 167, 1, 167, 249, 5, 4, 49, 255, 173, 1, 142, 249, 230, 3, 56, 255, 179, 1, 118, 249, 200, 3, 64, 255, 185, 1, 95, 249, 168, 3, 71, 255, 190, 1, 72, 249, 136, 3, 79, 255, 196, 1, 50, 249, 104, 3, 87, 255, 201, 1, 29, 249, 71, 3, 96, 255, 206, 1, 9, 249, 37, 3, 104, 255, 211, 1, 245, 248, 3, 3, 113, 255, 216, 1, 226, 248, 224, 2, 121, 255, 220, 1, 208, 248, 189, 2, 130, 255, 225, 1, 191, 248, 154, 2, 139, 255, 229, 1, 174, 248, 117, 2, 148, 255, 233, 1, 159, 248, 81, 2, 157, 255, 237, 1, 144, 248, 44, 2, 166, 255, 240, 1, 130, 248, 7, 2, 175, 255, 243, 1, 117, 248, 225, 1, 185, 255, 247, 1, 105, 248, 187, 1, 194, 255, 249, 1, 93, 248, 149, 1, 204, 255, 252, 1, 83, 248, 110, 1, 213, 255, 255, 1
  .byte 73, 248, 71, 1, 223, 255, 1, 2, 65, 248, 32, 1, 233, 255, 3, 2, 57, 248, 248, 0, 243, 255, 5, 2, 50, 248, 209, 0, 252, 255, 6, 2, 44, 248, 169, 0, 5, 0, 7, 2, 39, 248, 129, 0, 15, 0, 9, 2, 35, 248, 89, 0, 25, 0, 9, 2, 32, 248, 48, 0, 35, 0, 10, 2, 29, 248, 8, 0, 45, 0, 10, 2, 28, 248, 225, 255, 55, 0, 11, 2, 28, 248, 184, 255, 65, 0, 11, 2, 28, 248, 144, 255, 75, 0, 10, 2, 30, 248, 103, 255, 85, 0, 10, 2, 32, 248, 63, 255, 96, 0, 9, 2, 36, 248, 22, 255, 106, 0, 8, 2, 40, 248, 238, 254, 116, 0, 7, 2, 45, 248, 198, 254, 126, 0, 5, 2, 51, 248, 158, 254, 136, 0, 3, 2, 58, 248, 118, 254, 145, 0, 2, 2, 67, 248, 78, 254, 155, 0, 255, 1, 75, 248, 39, 254, 165, 0, 253, 1, 85, 248, 255, 253, 175, 0, 250, 1, 96, 248, 216, 253, 185, 0, 247, 1, 108, 248, 177, 253, 194, 0, 244, 1, 120, 248, 139, 253, 204, 0, 241, 1, 134, 248, 100, 253, 213, 0, 238, 1, 148, 248, 62, 253, 223, 0, 234, 1, 163, 248, 25, 253, 232, 0, 230, 1, 180, 248, 244, 252, 241, 0, 226, 1, 196, 248, 207, 252, 250, 0, 221, 1, 214, 248, 170, 252, 3, 1, 217, 1, 233, 248, 135, 252, 12, 1, 212, 1
  .byte 252, 248, 99, 252, 21, 1, 207, 1, 16, 249, 64, 252, 30, 1, 202, 1, 37, 249, 30, 252, 38, 1, 196, 1, 59, 249, 252, 251, 47, 1, 191, 1, 82, 249, 218, 251, 55, 1, 185, 1, 105, 249, 185, 251, 63, 1, 179, 1, 129, 249, 153, 251, 71, 1, 173, 1, 154, 249, 121, 251, 79, 1, 166, 1, 179, 249, 90, 251, 87, 1, 160, 1, 206, 249, 60, 251, 94, 1, 153, 1, 232, 249, 30, 251, 102, 1, 146, 1, 4, 250, 1, 251, 109, 1, 139, 1, 32, 250, 228, 250, 116, 1, 132, 1, 61, 250, 200, 250, 123, 1, 125, 1, 90, 250, 173, 250, 129, 1, 117, 1, 120, 250, 147, 250, 136, 1, 110, 1, 150, 250, 121, 250, 142, 1, 102, 1, 181, 250, 97, 250, 148, 1, 94, 1, 213, 250, 73, 250, 154, 1, 86, 1, 245, 250, 49, 250, 160, 1, 78, 1, 22, 251, 27, 250, 165, 1, 69, 1, 55, 251, 5, 250, 171, 1, 61, 1, 88, 251, 240, 249, 176, 1, 53, 1, 122, 251, 220, 249, 181, 1, 44, 1, 156, 251, 201, 249, 186, 1, 35, 1, 191, 251, 183, 249, 190, 1, 26, 1, 226, 251, 165, 249, 194, 1, 18, 1, 5, 252, 149, 249, 198, 1, 9, 1, 41, 252, 133, 249, 202, 1, 255, 0, 77, 252, 118, 249, 206, 1, 246, 0, 113, 252, 104, 249, 209, 1, 237, 0, 149, 252, 91, 249, 212, 1, 228, 0
  .byte 186, 252, 79, 249, 215, 1, 219, 0, 223, 252, 67, 249, 218, 1, 209, 0, 4, 253, 57, 249, 221, 1, 200, 0, 41, 253, 47, 249, 223, 1, 190, 0, 78, 253, 39, 249, 225, 1, 181, 0, 115, 253, 31, 249, 227, 1, 172, 0, 153, 253, 24, 249, 228, 1, 162, 0, 190, 253, 18, 249, 230, 1, 153, 0, 228, 253, 13, 249, 231, 1, 143, 0, 9, 254, 9, 249, 232, 1, 134, 0, 47, 254, 6, 249, 232, 1, 124, 0, 84, 254, 4, 249, 233, 1, 115, 0, 122, 254, 3, 249, 233, 1, 105, 0, 159, 254, 2, 249, 233, 1, 96, 0, 196, 254, 3, 249, 233, 1, 86, 0, 233, 254, 4, 249, 232, 1, 77, 0, 14, 255, 6, 249, 232, 1, 67, 0, 50, 255, 9, 249, 231, 1, 58, 0, 87, 255, 13, 249, 230, 1, 49, 0, 123, 255, 18, 249, 228, 1, 40, 0, 159, 255, 24, 249, 227, 1, 31, 0, 195, 255, 31, 249, 225, 1, 22, 0, 230, 255, 38, 249, 223, 1, 13, 0, 8, 0, 46, 249, 221, 1, 4, 0, 43, 0, 55, 249, 218, 1, 252, 255, 77, 0, 65, 249, 216, 1, 243, 255, 111, 0, 76, 249, 213, 1, 235, 255, 145, 0, 88, 249, 210, 1, 226, 255, 178, 0, 100, 249, 207, 1, 218, 255, 210, 0, 113, 249, 203, 1, 209, 255, 243, 0, 127, 249, 200, 1, 201, 255, 18, 1, 141, 249, 196, 1, 193, 255
  .byte 50, 1, 157, 249, 192, 1, 185, 255, 80, 1, 173, 249, 188, 1, 177, 255, 110, 1, 189, 249, 184, 1, 170, 255, 140, 1, 207, 249, 179, 1, 162, 255, 169, 1, 225, 249, 175, 1, 155, 255, 197, 1, 243, 249, 170, 1, 148, 255, 225, 1, 6, 250, 165, 1, 141, 255, 252, 1, 26, 250, 160, 1, 134, 255, 23, 2, 47, 250, 155, 1, 127, 255, 49, 2, 68, 250, 149, 1, 120, 255, 74, 2, 89, 250, 144, 1, 114, 255, 98, 2, 112, 250, 138, 1, 108, 255, 122, 2, 134, 250, 132, 1, 102, 255, 145, 2, 157, 250, 126, 1, 96, 255, 167, 2, 181, 250, 120, 1, 90, 255, 189, 2, 205, 250, 114, 1, 85, 255, 210, 2, 230, 250, 108, 1, 79, 255, 230, 2, 254, 250, 102, 1, 74, 255, 249, 2, 24, 251, 95, 1, 69, 255, 12, 3, 49, 251, 89, 1, 64, 255, 30, 3, 75, 251, 82, 1, 60, 255, 47, 3, 102, 251, 75, 1, 56, 255, 63, 3, 128, 251, 68, 1, 51, 255, 78, 3, 155, 251, 62, 1, 47, 255, 93, 3, 182, 251, 55, 1, 44, 255, 106, 3, 210, 251, 48, 1, 40, 255, 119, 3, 237, 251, 41, 1, 37, 255, 131, 3, 9, 252, 34, 1, 34, 255, 143, 3, 37, 252, 27, 1, 31, 255, 153, 3, 64, 252, 19, 1, 28, 255, 163, 3, 92, 252, 12, 1, 25, 255, 172, 3, 120, 252, 5, 1, 23, 255
  .byte 181, 3, 148, 252, 254, 0, 21, 255, 188, 3, 175, 252, 247, 0, 19, 255, 195, 3, 203, 252, 240, 0, 17, 255, 202, 3, 231, 252, 233, 0, 15, 255, 207, 3, 2, 253, 226, 0, 14, 255, 212, 3, 30, 253, 219, 0, 13, 255, 216, 3, 57, 253, 212, 0, 11, 255, 219, 3, 84, 253, 205, 0, 10, 255, 222, 3, 111, 253, 198, 0, 10, 255, 224, 3, 138, 253, 191, 0, 9, 255, 225, 3, 165, 253, 184, 0, 9, 255, 226, 3, 191, 253, 178, 0, 8, 255, 226, 3, 218, 253, 171, 0, 8, 255, 226, 3, 244, 253, 164, 0, 8, 255, 224, 3, 13, 254, 158, 0, 9, 255, 222, 3, 39, 254, 151, 0, 9, 255, 220, 3, 64, 254, 145, 0, 9, 255, 217, 3, 89, 254, 138, 0, 10, 255, 213, 3, 114, 254, 132, 0, 11, 255, 209, 3, 138, 254, 126, 0, 12, 255, 204, 3, 162, 254, 120, 0, 13, 255, 199, 3, 186, 254, 114, 0, 14, 255, 193, 3, 209, 254, 108, 0, 16, 255, 186, 3, 232, 254, 102, 0, 17, 255, 179, 3, 255, 254, 96, 0, 19, 255, 171, 3, 21, 255, 90, 0, 21, 255, 163, 3, 42, 255, 85, 0, 23, 255, 155, 3, 64, 255, 79, 0, 25, 255, 146, 3, 85, 255, 74, 0, 27, 255, 136, 3, 105, 255, 69, 0, 29, 255, 126, 3, 125, 255, 63, 0, 32, 255, 116, 3, 145, 255, 58, 0, 34, 255
  .byte 105, 3, 164, 255, 53, 0, 37, 255, 94, 3, 182, 255, 49, 0, 40, 255, 82, 3, 200, 255, 44, 0, 42, 255, 70, 3, 218, 255, 39, 0, 45, 255, 58, 3, 235, 255, 35, 0, 48, 255, 45, 3, 252, 255, 31, 0, 51, 255, 32, 3, 11, 0, 26, 0, 55, 255, 19, 3, 26, 0, 22, 0, 58, 255, 5, 3, 41, 0, 18, 0, 61, 255, 248, 2, 56, 0, 15, 0, 65, 255, 233, 2, 70, 0, 11, 0, 68, 255, 219, 2, 83, 0, 7, 0, 72, 255, 204, 2, 96, 0, 4, 0, 75, 255, 190, 2, 109, 0, 1, 0, 79, 255, 174, 2, 120, 0, 255, 255, 82, 255, 159, 2, 132, 0, 252, 255, 86, 255, 144, 2, 142, 0, 249, 255, 90, 255, 128, 2, 152, 0, 246, 255, 94, 255, 113, 2, 162, 0, 244, 255, 98, 255, 97, 2, 171, 0, 241, 255, 102, 255, 81, 2, 179, 0, 239, 255, 105, 255, 65, 2, 187, 0, 237, 255, 109, 255, 49, 2, 194, 0, 235, 255, 113, 255, 33, 2, 201, 0, 233, 255, 117, 255, 16, 2, 207, 0, 231, 255, 121, 255, 0, 2, 213, 0, 230, 255, 125, 255, 240, 1, 218, 0, 228, 255, 129, 255, 224, 1, 222, 0, 227, 255, 133, 255, 208, 1, 226, 0, 226, 255, 137, 255, 192, 1, 229, 0, 225, 255, 141, 255, 175, 1, 232, 0, 224, 255, 145, 255, 160, 1, 234, 0, 223, 255, 149, 255
  .byte 144, 1, 236, 0, 223, 255, 153, 255, 128, 1, 237, 0, 222, 255, 157, 255, 112, 1, 238, 0, 222, 255, 161, 255, 97, 1, 238, 0, 222, 255, 165, 255, 81, 1, 238, 0, 222, 255, 169, 255, 66, 1, 237, 0, 222, 255, 172, 255, 51, 1, 235, 0, 222, 255, 176, 255, 36, 1, 233, 0, 222, 255, 180, 255, 21, 1, 231, 0, 223, 255, 183, 255, 7, 1, 228, 0, 223, 255, 187, 255, 249, 0, 224, 0, 224, 255, 190, 255, 235, 0, 220, 0, 225, 255, 194, 255, 221, 0, 216, 0, 226, 255, 197, 255, 208, 0, 211, 0, 227, 255, 200, 255, 194, 0, 206, 0, 228, 255, 204, 255, 182, 0, 200, 0, 229, 255, 207, 255, 169, 0, 194, 0, 231, 255, 210, 255, 157, 0, 187, 0, 232, 255, 213, 255, 145, 0, 180, 0, 234, 255, 216, 255, 133, 0, 173, 0, 235, 255, 219, 255, 122, 0, 165, 0, 237, 255, 222, 255, 111, 0, 157, 0, 239, 255, 224, 255, 101, 0, 149, 0, 241, 255, 227, 255, 91, 0, 140, 0, 243, 255, 229, 255, 81, 0, 131, 0, 245, 255, 232, 255, 72, 0, 121, 0, 247, 255, 234, 255, 63, 0, 111, 0, 250, 255, 236, 255, 55, 0, 101, 0, 252, 255, 238, 255, 47, 0, 91, 0, 254, 255, 240, 255, 39, 0, 80, 0, 0, 0, 242, 255, 32, 0, 69, 0, 2, 0, 244, 255, 25, 0, 58, 0, 5, 0, 245, 255
  .byte 19, 0, 47, 0, 8, 0, 247, 255, 14, 0, 35, 0, 10, 0, 248, 255, 8, 0, 23, 0, 13, 0, 250, 255, 4, 0, 11, 0, 16, 0, 251, 255, 0, 0, 0, 0, 19, 0, 252, 255, 253, 255, 244, 255, 22, 0, 253, 255, 249, 255, 231, 255, 25, 0, 254, 255, 247, 255, 218, 255, 28, 0, 254, 255, 244, 255, 206, 255, 31, 0, 255, 255, 242, 255, 193, 255, 34, 0, 255, 255, 241, 255, 180, 255, 37, 0, 255, 255, 240, 255, 167, 255, 40, 0, 0, 0, 240, 255, 154, 255, 43, 0, 0, 0, 241, 255, 141, 255, 46, 0, 0, 0, 241, 255, 128, 255, 49, 0, 255, 255, 243, 255, 114, 255, 52, 0, 255, 255, 245, 255, 101, 255, 56, 0, 255, 255, 247, 255, 88, 255, 59, 0, 254, 255, 250, 255, 75, 255, 62, 0, 253, 255, 253, 255, 62, 255, 65, 0, 252, 255, 0, 0, 49, 255, 68, 0, 251, 255, 5, 0, 36, 255, 71, 0, 250, 255, 10, 0, 23, 255, 74, 0, 249, 255, 15, 0, 11, 255, 77, 0, 248, 255, 21, 0, 254, 254, 80, 0, 246, 255, 28, 0, 242, 254, 83, 0, 244, 255, 35, 0, 230, 254, 86, 0, 243, 255, 42, 0, 218, 254, 89, 0, 241, 255, 50, 0, 206, 254, 91, 0, 239, 255, 59, 0, 194, 254, 94, 0, 237, 255, 67, 0, 183, 254, 97, 0, 235, 255, 77, 0, 172, 254, 99, 0, 232, 255
  .byte 87, 0, 161, 254, 102, 0, 230, 255, 97, 0, 150, 254, 104, 0, 227, 255, 108, 0, 140, 254, 107, 0, 224, 255, 119, 0, 129, 254, 109, 0, 222, 255, 131, 0, 120, 254, 111, 0, 219, 255, 143, 0, 110, 254, 114, 0, 216, 255, 156, 0, 101, 254, 116, 0, 212, 255, 169, 0, 92, 254, 118, 0, 209, 255, 182, 0, 84, 254, 120, 0, 206, 255, 196, 0, 76, 254, 122, 0, 202, 255, 210, 0, 68, 254, 123, 0, 199, 255, 225, 0, 61, 254, 125, 0, 195, 255, 240, 0, 54, 254, 126, 0, 191, 255, 255, 0, 48, 254, 128, 0, 188, 255, 15, 1, 42, 254, 129, 0, 184, 255, 31, 1, 36, 254, 130, 0, 180, 255, 48, 1, 31, 254, 132, 0, 176, 255, 64, 1, 26, 254, 133, 0, 171, 255, 81, 1, 22, 254, 133, 0, 167, 255, 99, 1, 19, 254, 134, 0, 163, 255, 116, 1, 16, 254, 135, 0, 159, 255, 134, 1, 13, 254, 135, 0, 154, 255, 152, 1, 11, 254, 136, 0, 150, 255, 170, 1, 9, 254, 136, 0, 145, 255, 189, 1, 8, 254, 136, 0, 140, 255, 208, 1, 8, 254, 136, 0, 136, 255, 227, 1, 8, 254, 136, 0, 131, 255, 246, 1, 8, 254, 135, 0, 126, 255, 9, 2, 9, 254, 135, 0, 122, 255, 28, 2, 11, 254, 134, 0, 117, 255, 48, 2, 14, 254, 133, 0, 112, 255, 68, 2, 16, 254, 133, 0, 107, 255
  .byte 87, 2, 20, 254, 132, 0, 102, 255, 107, 2, 24, 254, 130, 0, 97, 255, 127, 2, 29, 254, 129, 0, 92, 255, 147, 2, 34, 254, 128, 0, 87, 255, 167, 2, 40, 254, 126, 0, 82, 255, 187, 2, 46, 254, 124, 0, 77, 255, 208, 2, 54, 254, 122, 0, 72, 255, 228, 2, 61, 254, 120, 0, 67, 255, 248, 2, 70, 254, 118, 0, 62, 255, 12, 3, 79, 254, 115, 0, 57, 255, 32, 3, 88, 254, 113, 0, 52, 255, 51, 3, 99, 254, 110, 0, 47, 255, 71, 3, 110, 254, 107, 0, 43, 255, 91, 3, 121, 254, 104, 0, 38, 255, 110, 3, 133, 254, 101, 0, 33, 255, 130, 3, 146, 254, 97, 0, 28, 255, 149, 3, 159, 254, 94, 0, 23, 255, 168, 3, 173, 254, 90, 0, 19, 255, 187, 3, 188, 254, 86, 0, 14, 255, 205, 3, 203, 254, 82, 0, 9, 255, 224, 3, 219, 254, 78, 0, 5, 255, 242, 3, 236, 254, 74, 0, 0, 255, 4, 4, 253, 254, 70, 0, 252, 254, 21, 4, 14, 255, 65, 0, 247, 254, 39, 4, 33, 255, 60, 0, 243, 254, 56, 4, 52, 255, 55, 0, 239, 254, 72, 4, 71, 255, 50, 0, 235, 254, 89, 4, 91, 255, 45, 0, 231, 254, 104, 4, 112, 255, 40, 0, 227, 254, 120, 4, 133, 255, 34, 0, 223, 254, 135, 4, 155, 255, 29, 0, 219, 254, 150, 4, 177, 255, 23, 0, 216, 254
  .byte 164, 4, 200, 255, 17, 0, 212, 254, 178, 4, 223, 255, 11, 0, 209, 254, 191, 4, 247, 255, 5, 0, 206, 254, 204, 4, 15, 0, 0, 0, 202, 254, 216, 4, 40, 0, 249, 255, 199, 254, 228, 4, 65, 0, 243, 255, 197, 254, 240, 4, 91, 0, 236, 255, 194, 254, 250, 4, 118, 0, 229, 255, 191, 254, 5, 5, 145, 0, 222, 255, 189, 254, 14, 5, 172, 0, 215, 255, 186, 254, 23, 5, 200, 0, 208, 255, 184, 254, 32, 5, 228, 0, 201, 255, 182, 254, 40, 5, 1, 1, 194, 255, 180, 254, 47, 5, 30, 1, 186, 255, 178, 254, 54, 5, 59, 1, 179, 255, 177, 254, 59, 5, 89, 1, 171, 255, 175, 254, 65, 5, 120, 1, 163, 255, 174, 254, 69, 5, 150, 1, 156, 255, 173, 254, 73, 5, 181, 1, 148, 255, 172, 254, 76, 5, 212, 1, 140, 255, 171, 254, 79, 5, 244, 1, 132, 255, 171, 254, 81, 5, 19, 2, 124, 255, 171, 254, 82, 5, 52, 2, 115, 255, 170, 254, 82, 5, 84, 2, 107, 255, 170, 254, 82, 5, 116, 2, 99, 255, 171, 254, 80, 5, 149, 2, 91, 255, 171, 254, 78, 5, 182, 2, 82, 255, 172, 254, 76, 5, 215, 2, 74, 255, 172, 254, 72, 5, 249, 2, 65, 255, 173, 254, 68, 5, 26, 3, 57, 255, 174, 254, 62, 5, 60, 3, 48, 255, 176, 254, 57, 5, 93, 3, 40, 255, 177, 254
  .byte 50, 5, 127, 3, 31, 255, 179, 254, 42, 5, 161, 3, 22, 255, 181, 254, 34, 5, 195, 3, 14, 255, 183, 254, 24, 5, 229, 3, 5, 255, 186, 254, 14, 5, 7, 4, 252, 254, 188, 254, 3, 5, 41, 4, 244, 254, 191, 254, 248, 4, 75, 4, 235, 254, 194, 254, 235, 4, 108, 4, 227, 254, 197, 254, 222, 4, 142, 4, 218, 254, 201, 254, 207, 4, 176, 4, 209, 254, 205, 254, 192, 4, 210, 4, 201, 254, 208, 254, 176, 4, 243, 4, 192, 254, 213, 254, 159, 4, 20, 5, 184, 254, 217, 254, 141, 4, 54, 5, 175, 254, 221, 254, 123, 4, 86, 5, 167, 254, 226, 254, 103, 4, 119, 5, 159, 254, 231, 254
end_of_pos_and_rotation_data:
