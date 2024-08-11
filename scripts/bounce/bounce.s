; == Very crude PoC for the bounce/JellyPic part of the 2R demo ==

; To build: cl65 -t cx16 -o BOUNCE.PRG bounce.s
; To run: x16emu.exe -prg BOUNCE.PRG -run

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

; Kernal API functions
SETNAM            = $FFBD  ; set filename
SETLFS            = $FFBA  ; Set LA, FA, and SA
LOAD              = $FFD5  ; Load a file into main memory or VRAM

; -- VRAM addresses --

MAPDATA_VRAM_ADDRESS  = $1F000  ; should be aligned to 1kB
TILEDATA_VRAM_ADDRESS = $10000  ; should be aligned to 1kB

VERA_PALETTE          = $1FA00



; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

LOAD_ADDRESS              = $30 ; 31
CODE_ADDRESS              = $32 ; 33

VERA_ADDR_ZP_TO           = $34 ; 35 ; 36

; For affine transformation
X_SUB_PIXEL               = $40 ; 41 ; 42
Y_SUB_PIXEL               = $43 ; 44 ; 45

FRAME_NR                  = $48 ; 49
POS_AND_BEND_DATA         = $4A ; 4B
POS_AND_BEND_BANK         = $4C

X_INCREMENT               = $51 ; 52
Y_INCREMENT               = $53 ; 54

TEMP_VAR                  = $55


; === RAM addresses ===

COPY_ROW_CODE               = $8800
POS_AND_BEND_RAM_ADDRESS    = $A000

; === Other constants ===

DESTINATION_PICTURE_POS_X = 0
DESTINATION_PICTURE_POS_Y = 0

POS_AND_BEND_START_BANK  = $01


start:

; FIXME: clear VRAM/BUFFER!

    jsr setup_vera_for_layer0_bitmap

    jsr copy_palette_from_index_0
    
    jsr load_tilemap_into_vram
    jsr load_tiledata_into_vram
    ; FIXME: REMOVE: jsr load_pos_and_bend_data_into_banked_ram

    jsr generate_copy_row_code

    jsr setup_and_draw_bouncing_tilemap

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
    
; This is for debugging:
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




setup_and_draw_bouncing_tilemap:

    ; Setup TO VRAM start address
    
    ; FIXME: HACK we are ASSUMING we never reach the second part of VRAM here! (VERA_ADDR_ZP_TO+2 is not used here!)
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    ; Setting base address and map size
    
    lda #(TILEDATA_VRAM_ADDRESS >> 9)
    and #%11111100   ; only the 6 highest bits of the address can be set
    ora #%00000010   ; clip = 1
    sta VERA_FX_TILEBASE

    lda #(MAPDATA_VRAM_ADDRESS >> 9)
    ora #%00000010   ; Map size = 32x32 tiles
    sta VERA_FX_MAPBASE
    
    lda #%00000011  ; affine helper mode
    ; ora #%10000010  ; transparency enabled = 1 -> currently not drawing transparent pixels
    ora #%00100000  ; cache fill enabled = 1
    ora #%01000000  ; blit write enabled = 1
    sta VERA_FX_CTRL
    
    
    lda #POS_AND_BEND_START_BANK
    sta POS_AND_BEND_BANK
    sta RAM_BANK
    
    lda #0
    sta FRAME_NR
    sta FRAME_NR+1
    
    lda #<POS_AND_BEND_RAM_ADDRESS
    sta POS_AND_BEND_DATA
    lda #>POS_AND_BEND_RAM_ADDRESS
    sta POS_AND_BEND_DATA+1
    
    
keep_bouncing:
    lda #<(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_POS_Y*320)
    sta VERA_ADDR_ZP_TO
    lda #>(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_POS_Y*320)
    sta VERA_ADDR_ZP_TO+1
    
    ; FIXME: replace this with a proper vsync-wait!
    jsr dumb_wait_for_vsync
    
    jsr draw_bended_tilemap
    
; FIXME!
; FIXME!
; FIXME!
tmp_loop:
    bra tmp_loop
    
    
    
    clc
    lda FRAME_NR
    adc #1
    sta FRAME_NR
    lda FRAME_NR+1
    adc #0
    sta FRAME_NR+1
    
    clc
    lda POS_AND_BEND_DATA
    adc #10
    sta POS_AND_BEND_DATA
    lda POS_AND_BEND_DATA+1
    adc #0
    sta POS_AND_BEND_DATA+1
    
    ; If we reached $BE00 we should switch to the next bank and start at $A000 again
    lda POS_AND_BEND_DATA+1
    cmp #$BE
    bne pos_and_bend_bank_is_ok
    
    lda #<POS_AND_BEND_RAM_ADDRESS
    sta POS_AND_BEND_DATA
    lda #>POS_AND_BEND_RAM_ADDRESS
    sta POS_AND_BEND_DATA+1
    
    inc POS_AND_BEND_BANK
    lda POS_AND_BEND_BANK
    sta RAM_BANK
    
pos_and_bend_bank_is_ok:

;    jsr wait_a_few_ms
    
    ; check if 2000 frames played (= $7D0)
    lda FRAME_NR+1
    cmp #$7
    bne keep_bouncing
    lda FRAME_NR
    cmp #$D0
    bne keep_bouncing
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    lda #%00000000  ; blit write enabled = 0, normal mode
    sta VERA_FX_CTRL

    rts
    
; For debugging
wait_a_few_ms:
    ldx #8
wait_a_few_ms_256:
    ldy #0
wait_a_few_ms_1:
    nop
    nop
    nop
    nop
    iny
    bne wait_a_few_ms_1
    dex
    bne wait_a_few_ms_256
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



y_64_to_tiledata_offset:
    .byte 0*24, 1*24, 2*24, 3*24 


x_pos_per_width:
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e, $1f, $20


x_inc_low_per_width:
  .byte $3e, $37, $30, $2a, $23, $1d, $17, $11, $0b, $05, $00, $fa, $f5, $ef, $ea, $e5, $e0, $db, $d7, $d2, $cd, $c9, $c4, $c0, $bc, $b8, $b4, $b0, $ac, $a8, $a4, $a0, $9d


x_inc_high_per_width:
  .byte $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01  

  
; curve data (containing a series of width indexes)
curve_data:
  .byte $0a, $0a, $0a, $0b, $0b, $0c, $0c, $0d, $0d, $0d, $0e, $0e, $0f, $0f, $10, $10, $10, $11, $11, $12, $12, $12, $13, $13, $14, $14, $14, $15, $15, $15, $16, $16, $17, $17, $17, $18, $18, $18, $19, $19, $19, $19, $1a, $1a, $1a, $1b, $1b, $1b, $1b, $1c, $1c, $1c, $1c, $1d, $1d, $1d, $1d, $1d, $1e, $1e, $1e, $1e, $1e, $1e, $1e, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1e, $1e, $1e, $1e, $1e, $1e, $1e, $1d, $1d, $1d, $1d, $1d, $1c, $1c, $1c, $1c, $1b, $1b, $1b, $1b, $1a, $1a, $1a, $19, $19, $19, $19, $18, $18, $18, $17, $17, $17, $16, $16, $15, $15, $15, $14, $14, $14, $13, $13, $12, $12, $12, $11, $11, $10, $10, $10, $0f, $0f, $0e, $0e, $0d, $0d, $0d, $0c, $0c, $0b, $0b, $0a, $0a  

draw_bended_tilemap:


; FIXME!
; FIXME!
; FIXME!
    bra do_hardcoded_data

    ldy #0
    
    ; x increment
;    lda (POS_AND_BEND_DATA), y   ; cosine_rotate_low
;    sta X_INCREMENT
;    iny
;    lda (POS_AND_BEND_DATA), y   ; cosine_rotate_high
;    sta X_INCREMENT+1
;    iny
    
    ; y increment
    lda (POS_AND_BEND_DATA), y   ; sine_rotate_low
    sta Y_INCREMENT
    iny
    lda (POS_AND_BEND_DATA), y   ; sine_rotate_high
    sta Y_INCREMENT+1
    iny

    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    ; starting X position
;    lda (POS_AND_BEND_DATA), y   ; x_position_sub
;    sta X_SUB_PIXEL
;    iny
    
;    lda (POS_AND_BEND_DATA), y   ; x_position_low
;    sta X_SUB_PIXEL+1
;    iny
    
;    lda (POS_AND_BEND_DATA), y   ; x_position_high
;    sta X_SUB_PIXEL+2
;    iny
    
    ; starting Y position
;    lda (POS_AND_BEND_DATA), y   ; y_position_sub
;    sta Y_SUB_PIXEL
;    iny

;    lda (POS_AND_BEND_DATA), y   ; y_position_low
;    sta Y_SUB_PIXEL+1
;    iny
    
;    lda (POS_AND_BEND_DATA), y   ; y_position_high
;    sta Y_SUB_PIXEL+2
;    iny
    
; FIXME!
; FIXME!
; FIXME!
    bra skip_hardcoded_data

; FIXME!
; FIXME!
; FIXME!
do_hardcoded_data:    
    


    ; x_increment
;    lda #200   ; x_increment_low
;    sta X_INCREMENT
;    lda #0   ; x_increment_high
;    sta X_INCREMENT+1
    
    ; y_increment
    lda #40  ; y_increment_low
    sta Y_INCREMENT
    lda #1   ; y_increment_high
    sta Y_INCREMENT+1

    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    ; starting X position
;    lda #0   ; x_position_sub
;    sta X_SUB_PIXEL
    
;    lda #0   ; x_position_low
;    sta X_SUB_PIXEL+1
    
;    lda #0   ; x_position_high
;    sta X_SUB_PIXEL+2
    
    ; starting Y position
    lda #0   ; y_position_sub
    sta Y_SUB_PIXEL

    lda #0   ; y_position_low
    sta Y_SUB_PIXEL+1
    
    lda #0   ; y_position_high
    sta Y_SUB_PIXEL+2


    
    
; FIXME!
; FIXME!
; FIXME!
skip_hardcoded_data:
    
;    lda X_INCREMENT           ; X increment low
;    asl
;    sta VERA_FX_X_INCR_L
;    lda X_INCREMENT+1
;    rol                      
;    and #%01111111            ; increment is only 15 bits long
;    sta VERA_FX_X_INCR_H

; FIXME: no need to set this again each row!    
    ; y_increment this always 0 within one row
    lda #0
    asl
    sta VERA_FX_Y_INCR_L      ; Y increment low
    lda #0
    rol
    and #%01111111            ; increment is only 15 bits long
    sta VERA_FX_Y_INCR_H

    ldx #0
    
bend_copy_next_row_1:

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL


    lda Y_SUB_PIXEL+1
    and #%11000000    ; we want to know the y_pos % 64, so we take the top 2 bits
; FIXME: rotate left instead?
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    
    tay
    lda y_64_to_tiledata_offset,y
    sta TEMP_VAR

    lda #(TILEDATA_VRAM_ADDRESS >> 9)
; FIXME! clean this up!
    ora TEMP_VAR
    and #%11111100   ; only the 6 highest bits of the address can be set
    ora #%00000010   ; clip = 1
    sta VERA_FX_TILEBASE


    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL
    
    ldy curve_data, x

; FIXME: TEMP SOLUTION! use x to determine the width index, THEN lookup the pos based on THAT!
    lda x_inc_low_per_width,y
    sta VERA_FX_X_INCR_L
    
; FIXME: TEMP SOLUTION! use x to determine the width index, THEN lookup the pos based on THAT!
    lda x_inc_high_per_width,y
    sta VERA_FX_X_INCR_H

    lda #%00110000           ; Setting auto-increment value to 4 byte increment (=%0011) 
    sta VERA_ADDR_BANK
    lda VERA_ADDR_ZP_TO+1
    sta VERA_ADDR_HIGH
    lda VERA_ADDR_ZP_TO
    sta VERA_ADDR_LOW

    ; Setting the position
    
    lda #%00001001           ; DCSEL=4, ADDRSEL=1
    sta VERA_CTRL
    
;    lda X_SUB_PIXEL+1
;    sta VERA_FX_X_POS_L      ; X pixel position low [7:0]
    
;    lda X_SUB_PIXEL+2
;    and #%00000111
;    sta VERA_FX_X_POS_H      ; X subpixel position[0] = 0, X pixel position high [10:8] = 000 or 111


; FIXME: set X position based on curve data!
; FIXME: set X position based on curve data!
; FIXME: set X position based on curve data!

; FIXME: TEMP SOLUTION! use x to determine the width index, THEN lookup the pos based on THAT!
    lda x_pos_per_width,y
    sta VERA_FX_X_POS_L      ; X pixel position low [7:0]
    stz VERA_FX_X_POS_H      ; X subpixel position[0] = 0, X pixel position high [10:8] = 000 or 111
    

    lda Y_SUB_PIXEL+1
    sta VERA_FX_Y_POS_L      ; Y pixel position low [7:0]

    lda Y_SUB_PIXEL+2
    and #%00000111
    sta VERA_FX_Y_POS_H      ; Y subpixel position[0] = 0,  Y pixel position high [10:8] = 000 or 111
    
    ; Setting the Subpixel X/Y positions
    lda #%00001010           ; DCSEL=5, ADDRSEL=0
    sta VERA_CTRL
    
    ; lda X_SUB_PIXEL
; FIXME: correct to set this to .5?
    lda #$80        
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

; FIXME: this needs to change!?
    clc
    lda Y_SUB_PIXEL
    adc Y_INCREMENT
    sta Y_SUB_PIXEL
    lda Y_SUB_PIXEL+1
    adc Y_INCREMENT+1
    sta Y_SUB_PIXEL+1
 
; FIXME: this needs to change! 
;    sec
;    lda X_SUB_PIXEL
;    sbc SINE_OF_ANGLE
;    sta X_SUB_PIXEL
;    lda X_SUB_PIXEL+1
;    sbc SINE_OF_ANGLE+1
;    sta X_SUB_PIXEL+1
    
    inx
; FIXME: this needs to change!
; FIXME: this needs to change!
; FIXME: this needs to change!
    cpx #200             ; nr of rows we draw
    beq bend_copy_done
    jmp bend_copy_next_row_1
bend_copy_done:    
    
    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL
    
    rts





tilemap_filename:      .byte    "bounce-tilemap.dat" 
end_tilemap_filename:

load_tilemap_into_vram:

    lda #(end_tilemap_filename-tilemap_filename) ; Length of filename
    ldx #<tilemap_filename      ; Low byte of Fname address
    ldy #>tilemap_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    jsr SETLFS
 
    lda #3            ; load into Bank 1 of VRAM (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<MAPDATA_VRAM_ADDRESS
    ldy #>MAPDATA_VRAM_ADDRESS
    jsr LOAD
    bcc tilemap_loaded
    ; FIXME: do proper error handling!
    stp

tilemap_loaded:
    rts



tiledata_filename:      .byte    "bounce-tiledata.dat" 
end_tiledata_filename:

load_tiledata_into_vram:

    lda #(end_tiledata_filename-tiledata_filename) ; Length of filename
    ldx #<tiledata_filename      ; Low byte of Fname address
    ldy #>tiledata_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    jsr SETLFS
 
    lda #3            ; load into Bank 1 of VRAM (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<TILEDATA_VRAM_ADDRESS
    ldy #>TILEDATA_VRAM_ADDRESS
    jsr LOAD
    bcc tiledata_loaded
    ; FIXME: do proper error handling!
    stp

tiledata_loaded:
    rts


pos_and_bend_filename:      .byte    "bouncing-pos-bend.dat" 
end_pos_and_bend_filename:

load_pos_and_bend_data_into_banked_ram:

    lda #(end_pos_and_bend_filename-pos_and_bend_filename) ; Length of filename
    ldx #<pos_and_bend_filename      ; Low byte of Fname address
    ldy #>pos_and_bend_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    
    jsr SETLFS
    
    lda #POS_AND_BEND_START_BANK
    sta RAM_BANK
    
    lda #0            ; load into Fixed RAM (current RAM Bank) (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<POS_AND_BEND_RAM_ADDRESS
    ldy #>POS_AND_BEND_RAM_ADDRESS
    jsr LOAD
    bcc pos_and_bend_loaded
    ; FIXME: do proper error handling!
    stp
pos_and_bend_loaded:

    stz RAM_BANK

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

    ; We use the cache for writing, we do not want a mask so we store 0 (stz)

    ; -- stz VERA_DATA0 ($9F23)
    lda #$9C               ; stz ....
    jsr add_code_byte

    lda #$23               ; $23
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte

    inx
; FIXME: we need a different WIDTH here!
; FIXME: we need a different WIDTH here!
; FIXME: we need a different WIDTH here!
    cpx #240/4
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
  .byte $aa, $0a
  .byte $bb, $0b
  .byte $88, $08
  .byte $99, $09
  .byte $cc, $0c
  .byte $67, $06
  .byte $9a, $09
  .byte $dd, $0d
  .byte $78, $07
  .byte $11, $01
  .byte $77, $07
  .byte $23, $02
  .byte $56, $05
  .byte $ff, $0f
  .byte $bc, $0b
  .byte $12, $01
  .byte $45, $04
  .byte $34, $03
  .byte $21, $04
  .byte $ee, $0e
  .byte $55, $05
  .byte $10, $03
  .byte $42, $06
  .byte $94, $0d
  .byte $33, $03
  .byte $64, $08
  .byte $84, $0c
  .byte $53, $07
  .byte $a5, $0d
  .byte $86, $0a
  .byte $83, $0c
  .byte $b6, $0e
  .byte $75, $09
  .byte $31, $05
  .byte $54, $08
  .byte $73, $0b
  .byte $b7, $0d
  .byte $a5, $0e
  .byte $97, $0b
  .byte $32, $05
  .byte $53, $08
  .byte $c9, $0e
  .byte $a9, $0c
  .byte $b9, $0d
  .byte $21, $03
  .byte $83, $0b
  .byte $32, $06
  .byte $c8, $0d
  .byte $76, $0a
  .byte $10, $04
  .byte $de, $0d
  .byte $62, $09
  .byte $98, $0b
  .byte $da, $0e
  .byte $a6, $0e
  .byte $75, $0a
  .byte $62, $0a
  .byte $31, $06
  .byte $ab, $09
  .byte $23, $01
  .byte $c7, $0e
  .byte $b5, $0f
  .byte $ba, $0d
  .byte $43, $05
  .byte $eb, $0f
  .byte $89, $07
  .byte $d9, $0f
  .byte $ec, $0e
  .byte $87, $09
  .byte $84, $0b
  .byte $02, $00
  .byte $45, $03
  .byte $a8, $0b
  .byte $93, $0d
  .byte $41, $06
  .byte $67, $05
  .byte $76, $09
  .byte $a6, $0d
  .byte $55, $06
  .byte $b8, $0e
  .byte $24, $02
  .byte $ac, $09
  .byte $97, $0c
  .byte $a7, $0b
  .byte $73, $0c
  .byte $46, $04
  .byte $cd, $0b
  .byte $98, $0c
  .byte $00, $02
  .byte $cb, $0d
  .byte $68, $06
  .byte $46, $03
  .byte $a3, $0e
  .byte $94, $0e
  .byte $ca, $0e
  .byte $93, $0e
  .byte $44, $06
  .byte $fd, $0f
  .byte $42, $08
  .byte $fb, $0f
  .byte $61, $0b
  .byte $24, $01
  .byte $8a, $08
  
; FIXME: we dont need all these non-colors!
; FIXME: we dont need all these non-colors!
; FIXME: we dont need all these non-colors!
  
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
  .byte $00, $00
end_of_palette_data:


