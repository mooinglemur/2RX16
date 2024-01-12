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

; FIXME: REMOVE THIS!!
; FIXME: REMOVE THIS!!
; FIXME: REMOVE THIS!!
FILL_LENGTH_LOW           = $40
FILL_LENGTH_HIGH          = $41
NUMBER_OF_ROWS            = $42
TMP_COLOR                 = $43
TMP_POLYGON_TYPE          = $44
NEXT_STEP                 = $45
NR_OF_POLYGONS            = $46


LOAD_ADDRESS              = $48 ; 49
VRAM_ADDRESS              = $50 ; 51 ; 52





; === RAM addresses ===

Y_TO_ADDRESS_LOW         = $8100
Y_TO_ADDRESS_HIGH        = $8200
Y_TO_ADDRESS_BANK        = $8300


; === Other constants ===

NR_OF_BYTES_PER_LINE = 320

BACKGROUND_COLOR = 4 ; nice purple


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
    lda #94
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
    
    
    ; 200:279:215:95
polygon_data:
    .byte 0, 254, 93, 220, 0, 0, 73, 0, 84, 4, 1, 0, 0, 1, 0
    .byte 0, 254, 103, 89, 0, 128, 83, 128, 2, 2, 3, 0, 0, 0, 81, 2, 0
    .byte 128, 254, 121, 0, 0, 10, 0, 0, 0, 0, 0, 5, 0
    .byte 0, 254, 97, 33, 0, 0, 103, 188, 0, 1, 1, 192, 127, 32, 1, 0, 0, 70, 0
    .byte 128, 254, 168, 0, 0, 6, 0, 0, 0, 234, 127, 23, 2, 0, 124, 1, 0
    .byte 0, 17, 96, 128, 0, 128, 79, 170, 4, 2, 1, 213, 0, 4, 2, 0, 68, 2, 0
    .byte 128, 17, 98, 0, 0, 11, 0, 0, 0, 183, 127, 7, 0
    .byte 128, 17, 107, 0, 0, 9, 0, 0, 0, 220, 127, 14, 0
    .byte 128, 17, 126, 0, 0, 6, 0, 0, 0, 214, 127, 36, 0
    .byte 0, 17, 103, 164, 0, 171, 85, 230, 3, 3, 1, 168, 0, 37, 2, 0, 0, 57, 0
    .byte 128, 203, 0, 0, 0, 42, 0, 0, 0, 2, 0, 95, 2, 0, 85, 1, 0
    .byte 128, 66, 0, 37, 0, 41, 0, 5, 0, 2, 0, 99, 1, 192, 0, 4, 0
    .byte 128, 75, 0, 41, 0, 95, 0, 2, 0, 121, 0, 101, 2, 128, 77, 2, 0
    .byte 128, 209, 107, 24, 0, 33, 0, 0, 0, 0, 1, 1, 0
    .byte 0, 208, 107, 24, 0, 205, 127, 0, 0, 1, 2, 192, 127, 4, 0
    .byte 128, 210, 108, 24, 0, 34, 0, 192, 127, 85, 0, 3, 2, 0, 116, 1, 0
    .byte 0, 213, 111, 35, 0, 0, 116, 0, 0, 1, 1, 0, 0, 2, 0
    .byte 128, 2, 0, 66, 0, 116, 0, 2, 0, 88, 0, 58, 2, 190, 127, 31, 2, 203, 124, 19, 0
    .byte 0, 2, 89, 128, 0, 203, 124, 0, 0, 19, 1, 124, 1, 41, 0
    .byte 128, 2, 0, 116, 0, 161, 0, 88, 0, 252, 127, 55, 2, 0, 120, 3, 0
    .byte 0, 11, 87, 38, 1, 104, 253, 252, 127, 2, 1, 0, 0, 51, 2, 171, 109, 9, 0
    .byte 0, 14, 58, 136, 0, 190, 127, 188, 130, 2, 2, 95, 127, 27, 2, 104, 253, 2, 0
    .byte 0, 13, 55, 160, 0, 0, 120, 51, 30, 3, 1, 188, 130, 2, 0
    .byte 128, 2, 0, 161, 0, 173, 0, 252, 127, 0, 0, 55, 1, 81, 0, 41, 0
    .byte 128, 209, 85, 86, 0, 89, 0, 0, 0, 12, 0, 19, 1, 0, 4, 1, 0
    .byte 0, 209, 44, 89, 0, 0, 125, 0, 0, 1, 1, 0, 0, 20, 0
    .byte 0, 209, 2, 89, 0, 171, 126, 0, 0, 3, 1, 12, 0, 18, 2, 128, 126, 2, 0
    .byte 128, 209, 86, 93, 0, 97, 0, 0, 0, 0, 0, 21, 1, 0, 2, 2, 0
    .byte 0, 209, 41, 96, 0, 0, 126, 0, 0, 2, 1, 12, 0, 21, 0
    .byte 128, 209, 0, 92, 0, 96, 0, 0, 0, 0, 0, 18, 2, 171, 126, 3, 0
    .byte 0, 209, 87, 101, 0, 10, 0, 0, 5, 1, 2, 0, 0, 23, 1, 0, 2, 2, 0
    .byte 0, 209, 38, 106, 0, 0, 123, 0, 0, 1, 1, 0, 0, 24, 0
    .byte 128, 209, 0, 101, 0, 105, 0, 0, 0, 0, 0, 12, 2, 171, 126, 3, 0
    .byte 0, 209, 89, 111, 0, 0, 0, 0, 6, 1, 2, 0, 0, 25, 1, 0, 2, 3, 0
    .byte 0, 209, 33, 117, 0, 0, 126, 0, 0, 3, 1, 0, 0, 26, 0
    .byte 128, 209, 0, 111, 0, 117, 0, 0, 0, 0, 0, 5, 2, 128, 126, 4, 0
    .byte 0, 205, 98, 99, 0, 192, 127, 128, 4, 2, 2, 171, 127, 2, 1, 0, 9, 1, 0
    .byte 0, 205, 93, 101, 0, 154, 127, 170, 2, 3, 2, 192, 127, 2, 1, 128, 4, 2, 0
    .byte 0, 205, 96, 84, 0, 0, 0, 128, 7, 2, 2, 192, 127, 2, 1, 0, 7, 2, 0
    .byte 0, 206, 89, 87, 0, 147, 127, 128, 3, 4, 2, 154, 127, 3, 1, 128, 7, 2, 0
    .byte 0, 206, 95, 76, 0, 205, 127, 0, 8, 1, 2, 0, 0, 4, 0
    .byte 128, 205, 100, 75, 0, 84, 0, 0, 0, 224, 127, 8, 0
    .byte 0, 207, 88, 78, 0, 183, 127, 0, 9, 1, 2, 147, 127, 6, 1, 0, 8, 1, 0
    .byte 0, 207, 115, 128, 0, 128, 125, 128, 127, 2, 3, 0, 127, 0, 125, 2, 0
    .byte 0, 203, 104, 124, 0, 85, 0, 0, 5, 1, 2, 128, 0, 2, 0
    .byte 0, 207, 113, 129, 0, 0, 124, 128, 127, 1, 1, 86, 127, 1, 2, 128, 125, 2, 0
    .byte 0, 10, 99, 91, 0, 0, 2, 128, 2, 4, 1, 192, 2, 2, 2, 0, 2, 2, 0
    .byte 128, 205, 107, 125, 0, 130, 0, 64, 0, 0, 0, 3, 2, 0, 124, 1, 0
    .byte 0, 7, 110, 130, 0, 0, 124, 171, 127, 1, 1, 171, 127, 2, 2, 0, 124, 1, 0
    .byte 128, 198, 96, 74, 0, 79, 0, 51, 1, 0, 1, 5, 0
    .byte 0, 207, 95, 76, 0, 0, 122, 205, 127, 1, 1, 0, 0, 4, 0
    .byte 128, 206, 100, 70, 0, 75, 0, 0, 0, 0, 0, 8, 0
    .byte 0, 207, 88, 78, 0, 128, 125, 183, 127, 2, 1, 128, 127, 5, 2, 0, 122, 1, 0
    .byte 0, 198, 97, 74, 0, 0, 0, 51, 1, 3, 1, 0, 2, 2, 2, 0, 0, 1, 0
    .byte 0, 196, 96, 74, 0, 0, 1, 51, 1, 5, 2, 0, 0, 1, 0
    .byte 0, 207, 117, 123, 0, 0, 125, 0, 127, 2, 2, 192, 125, 1, 1, 86, 127, 3, 0
    .byte 0, 203, 102, 116, 0, 64, 0, 0, 4, 2, 2, 85, 0, 2, 1, 0, 8, 1, 0
    .byte 0, 207, 114, 125, 0, 128, 123, 86, 127, 2, 1, 128, 127, 1, 2, 0, 125, 3, 0
    .byte 128, 10, 99, 84, 0, 91, 0, 64, 2, 0, 2, 4, 0
    .byte 0, 205, 106, 117, 0, 0, 0, 0, 8, 1, 2, 64, 0, 4, 0
    .byte 0, 206, 100, 70, 0, 0, 125, 0, 0, 1, 1, 220, 127, 7, 0
    .byte 0, 207, 96, 70, 0, 0, 126, 0, 0, 1, 1, 192, 127, 3, 2, 0, 125, 1, 0
    .byte 128, 7, 111, 117, 0, 126, 0, 205, 127, 171, 127, 3, 2, 128, 123, 2, 0
    .byte 0, 207, 90, 73, 0, 0, 124, 128, 127, 1, 1, 214, 127, 5, 2, 0, 126, 1, 0
    .byte 128, 194, 99, 80, 0, 84, 0, 0, 0, 86, 127, 3, 0
    .byte 0, 196, 91, 69, 0, 128, 127, 214, 127, 2, 1, 192, 127, 4, 3, 192, 127, 192, 127, 4, 3, 0, 0, 220, 127, 4, 1, 0, 0, 3, 0
    .byte 0, 12, 106, 81, 0, 0, 1, 0, 2, 2, 3, 0, 2, 128, 1, 4, 0
    .byte 0, 10, 99, 84, 0, 86, 127, 64, 2, 3, 1, 0, 2, 1, 2, 0, 121, 1, 0
    .byte 128, 165, 102, 80, 0, 82, 0, 0, 0, 0, 2, 2, 3, 128, 0, 128, 0, 2, 3, 0, 2, 0, 0, 2, 0
    .byte 128, 13, 108, 85, 0, 87, 0, 128, 1, 0, 1, 4, 0
    .byte 128, 207, 120, 105, 0, 114, 0, 86, 127, 86, 127, 3, 0
    .byte 0, 197, 103, 93, 0, 0, 121, 0, 1, 1, 1, 128, 0, 2, 1, 0, 10, 1, 0
    .byte 0, 202, 101, 107, 0, 51, 0, 0, 9, 1, 2, 64, 0, 4, 0
    .byte 128, 207, 116, 108, 0, 116, 0, 64, 127, 128, 127, 4, 0
    .byte 0, 12, 106, 87, 0, 0, 0, 128, 1, 2, 1, 64, 2, 4, 0
    .byte 128, 204, 106, 108, 0, 117, 0, 51, 0, 0, 0, 5, 0
    .byte 128, 7, 111, 109, 0, 117, 0, 205, 127, 205, 127, 5, 0
    .byte 0, 205, 118, 95, 0, 0, 127, 0, 5, 2, 3, 85, 3, 86, 127, 3, 0
    .byte 128, 201, 101, 96, 0, 107, 0, 64, 0, 51, 0, 4, 1, 0, 11, 1, 0
    .byte 0, 205, 114, 97, 0, 128, 127, 128, 5, 2, 2, 64, 127, 2, 1, 0, 5, 2, 0
    .byte 0, 203, 105, 97, 0, 0, 0, 0, 11, 1, 2, 51, 0, 4, 1, 0, 12, 1, 0
    .byte 0, 6, 110, 97, 0, 0, 0, 0, 12, 1, 2, 205, 127, 3, 1, 128, 5, 2, 0
    .byte 0, 205, 116, 87, 0, 128, 127, 0, 4, 2, 3, 128, 3, 0, 127, 2, 0
    .byte 128, 201, 101, 89, 0, 96, 0, 85, 0, 64, 0, 3, 1, 0, 7, 1, 0
    .byte 0, 204, 112, 89, 0, 128, 127, 0, 4, 2, 2, 128, 127, 2, 1, 0, 4, 2, 0
; FIXME! BROKEN!   .byte 0, 197, 108, 88, 0, 0, 0, 205, 127, 4, 1, 171, 127, 6, 0
    .byte 0, 202, 104, 90, 0, 192, 127, 0, 7, 1, 2, 0, 0, 3, 1, 0, 4, 2, 0
    .byte 0, 5, 108, 89, 0, 0, 0, 0, 4, 2, 2, 0, 0, 2, 1, 0, 4, 2, 0
    .byte 0, 197, 101, 89, 0, 220, 127, 85, 0, 3, 2, 192, 127, 4, 3, 224, 127, 0, 0, 4, 2, 128, 127, 4, 0
    .byte 0, 213, 181, 40, 0, 56, 0, 102, 0, 5, 2, 0, 0, 4, 0
    .byte 0, 209, 181, 40, 0, 171, 117, 56, 0, 3, 1, 0, 0, 6, 2, 0, 117, 3, 0
    .byte 0, 208, 184, 9, 0, 192, 127, 0, 0, 4, 1, 235, 127, 5, 2, 220, 127, 7, 0
    .byte 0, 213, 186, 42, 0, 54, 0, 54, 0, 14, 0
    .byte 0, 210, 190, 42, 0, 0, 117, 76, 0, 3, 1, 220, 127, 7, 0
    .byte 128, 2, 0, 171, 0, 64, 1, 0, 0, 0, 0, 176, 1, 138, 1, 24, 0


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