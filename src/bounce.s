.import setup_palette_fade
.import setup_palette_fade2
.import setup_palette_fade3
.import setup_palette_fade4

.import apply_palette_fade_step
.import apply_palette_fade_step2
.import apply_palette_fade_step3
.import apply_palette_fade_step4

.import flush_palette
.import flush_palette2
.import flush_palette3
.import flush_palette4

.import target_palette
.import target_palette2
.import target_palette3
.import target_palette4

.import graceful_fail

.macpack longbranch

.include "x16.inc"
.include "macros.inc"

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

VERA_DC_HSTART    = $9F29  ; DCSEL=1
VERA_DC_HSTOP     = $9F2A  ; DCSEL=1
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

VERA_FX_CACHE_L   = $9F29  ; DCSEL=6
VERA_FX_ACCUM_RESET = $9F29  ; DCSEL=6
VERA_FX_CACHE_M   = $9F2A  ; DCSEL=6
VERA_FX_ACCUM     = $9F2A  ; DCSEL=6
VERA_FX_CACHE_H   = $9F2B  ; DCSEL=6
VERA_FX_CACHE_U   = $9F2C  ; DCSEL=6

VERA_L0_CONFIG    = $9F2D
VERA_L0_TILEBASE  = $9F2F

; -- VRAM addresses --

MAPDATA_VRAM_ADDRESS  = $1F000  ; should be aligned to 1kB
TILEDATA_VRAM_ADDRESS = $10000  ; should be aligned to 1kB

VERA_PALETTE          = $1FA00

; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

; === RAM addresses ===

CURVE_DATA_ADDRESS          = $5900  ; up to 9A00 (16640 bytes)

COPY_ROW_CODE               = $9A00
CLEAR_ROW_CODE              = $9E00

; === Other constants ===

DESTINATION_PICTURE_POS_X = 0
DESTINATION_PICTURE_BOTTOM_POS_Y = 199  ; We draw from bottom to top

.segment "BOUNCE_ZP": zeropage

LOAD_ADDRESS:
	.res 2
CODE_ADDRESS:
	.res 2

VERA_ADDR_ZP_TO:
	.res 3
FRAME_BOTTOM_Y_ADDRESS:
	.res 2
FRAME_CURVE_ADDRESS:
	.res 2

; For affine transformation
X_SUB_PIXEL:
	.res 3
Y_SUB_PIXEL:
	.res 3

FRAME_NR:
	.res 2

X_INCREMENT:
	.res 2
Y_INCREMENT:
	.res 2

TEMP_VAR:
	.res 1

.segment "BOUNCE_BSS"

.assert * < CURVE_DATA_ADDRESS, error, "BOUNCE_BSS impinges on external BOUNCE-CURVES.DAT"

.segment "BOUNCE"
entry:

	LOADFILE "BOUNCE-CURVES.DAT", 0, CURVE_DATA_ADDRESS

	LOADFILE "BOUNCE-TILEMAP.DAT", 0, .loword(MAPDATA_VRAM_ADDRESS), ^MAPDATA_VRAM_ADDRESS
	LOADFILE "BOUNCE-TILEDATA.DAT", 0, .loword(TILEDATA_VRAM_ADDRESS), ^TILEDATA_VRAM_ADDRESS

    jsr generate_copy_row_code
    jsr generate_clear_row_code
    jsr clear_screen_fast_4_bytes

	WAITVSYNC
    jsr setup_vera_for_layer0_bitmap
    jsr copy_palette_from_index_0

    jsr setup_and_draw_bouncing_tilemap


	MUSIC_SYNC $CC

	rts

.proc copy_palette_from_index_0
	VERA_SET_ADDR VERA_PALETTE, 1

    ldy #0
next_packed_color_256:
    lda palette_data, y
    sta VERA_DATA0
    iny
    bne next_packed_color_256

next_packed_color_512:
    lda palette_data+256, y
    sta VERA_DATA0
    iny
    bne next_packed_color_512

    rts
.endproc

.proc generate_copy_row_code

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
    cpx #240/4
    bne next_copy_instruction

    ; -- rts --
    lda #$60
    jsr add_code_byte

    rts
.endproc

.proc generate_clear_row_code

    lda #<CLEAR_ROW_CODE
    sta CODE_ADDRESS
    lda #>CLEAR_ROW_CODE
    sta CODE_ADDRESS+1

    ldy #0                 ; generated code byte counter

    ldx #0                 ; counts nr of clear instructions

next_clear_instruction:

    ; We use the cache for writing, we do not want a mask so we store 0 (stz)

    ; -- stz VERA_DATA0 ($9F23)
    lda #$9C               ; stz ....
    jsr add_code_byte

    lda #$23               ; $23
    jsr add_code_byte

    lda #$9F               ; $9F
    jsr add_code_byte

    inx
    cpx #240/4
    bne next_clear_instruction

    ; -- rts --
    lda #$60
    jsr add_code_byte

    rts
.endproc

.proc add_code_byte
    sta (CODE_ADDRESS),y   ; store code byte at address (located at CODE_ADDRESS) + y
    iny                    ; increase y
    cpy #0                 ; if y == 0
    bne done_adding_code_byte
    inc CODE_ADDRESS+1     ; increment high-byte of CODE_ADDRESS
done_adding_code_byte:
    rts
.endproc


.proc clear_screen_fast_4_bytes

    ; We first need to fill the 32-bit cache with 4 times our background color

    lda #%00001100           ; DCSEL=6, ADDRSEL=0
    sta VERA_CTRL

    ; TODO: we *could* use 'one byte cache cycling' so we have to set only *one* byte of the cache here
    lda #0
    sta VERA_FX_CACHE_L      ; cache32[7:0]
    sta VERA_FX_CACHE_M      ; cache32[15:8]
    sta VERA_FX_CACHE_H      ; cache32[23:16]
    sta VERA_FX_CACHE_U      ; cache32[31:24]

    ; We setup blit writes

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL

    lda #%01000000           ; transparent writes = 0, blit write = 1, cache fill enabled = 0, one byte cache cycling = 0, 16bit hop = 0, 4bit mode = 0, normal addr1 mode 
    sta VERA_FX_CTRL

    ; -- Set the starting VRAM address --
    lda #%00110000           ; Setting bit 16 of vram address to the highest bit (=0), setting auto-increment value to 4 bytes
    sta VERA_ADDR_BANK

    ; We start at the very beginning of VRAM
    lda #0
    sta VERA_ADDR_HIGH
    lda #0
    sta VERA_ADDR_LOW

    ldx #134
clear_next_row:
    jsr CLEAR_ROW_CODE       ; we need to clear the entire buffer, but this routine only does 240px
	jsr CLEAR_ROW_CODE       ; so this loop overshoots a little, which is fine
    dex
    bne clear_next_row

    lda #%00000000           ; transparent writes = 0, blit write = 0, cache fill enabled = 0, one byte cache cycling = 0, 16bit hop = 0, 4bit mode = 0, normal addr1 mode 
    sta VERA_FX_CTRL

    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL

    rts
.endproc

.proc setup_vera_for_layer0_bitmap

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

    lda #22
    sta VERA_DC_HSTART
    lda #286/2-1
    sta VERA_DC_HSTOP

    rts
.endproc

.proc setup_and_draw_bouncing_tilemap

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


    lda #0
    sta FRAME_NR
    sta FRAME_NR+1

	WAITVSYNC
	jsr X16::Kernal::RDTIM
	sta lastjiffy

keep_bouncing:
    lda #<(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_BOTTOM_POS_Y*320)
    sta VERA_ADDR_ZP_TO
    lda #>(DESTINATION_PICTURE_POS_X+DESTINATION_PICTURE_BOTTOM_POS_Y*320)
    sta VERA_ADDR_ZP_TO+1

; enforce 30fps, but don't care about actual vsync if we're behind
vsync:
	jsr X16::Kernal::RDTIM
	sec
	sbc lastjiffy
	cmp #2
	bcc vsync
	lda lastjiffy
	clc
	adc #2
	sta lastjiffy

    jsr draw_bended_tilemap

    clc
    lda FRAME_NR
    adc #1
    sta FRAME_NR
    lda FRAME_NR+1
    adc #0
    sta FRAME_NR+1

    ; check if 225 frames played
    lda FRAME_NR+1
    cmp #(>225)
    bne keep_bouncing
    lda FRAME_NR
    cmp #(<225)
    bne keep_bouncing

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL

    lda #%00000000  ; blit write enabled = 0, normal mode
    sta VERA_FX_CTRL

    rts
lastjiffy:
	.byte 0
.endproc

.proc draw_bended_tilemap

    ; Calculate the address to the (current frame) bottom y
    clc
    lda #<frame_y_bottom_start
    adc FRAME_NR
    sta FRAME_BOTTOM_Y_ADDRESS
    lda #>frame_y_bottom_start
    adc FRAME_NR+1
    sta FRAME_BOTTOM_Y_ADDRESS+1

    ; Get the y bottom start
    ldy #0
    lda (FRAME_BOTTOM_Y_ADDRESS), y
    sta TEMP_VAR

    beq done_clearing_lines

clear_next_line:

    lda #%00110000           ; Setting auto-increment value to 4 byte increment (=%0011) 
    sta VERA_ADDR_BANK
    lda VERA_ADDR_ZP_TO+1
    sta VERA_ADDR_HIGH
    lda VERA_ADDR_ZP_TO
    sta VERA_ADDR_LOW

    ; Clear one row of pixels
    jsr CLEAR_ROW_CODE

    ; We decrement our VERA_ADDR_ZP_TO with 320
    sec
    lda VERA_ADDR_ZP_TO
    sbc #<(320)
    sta VERA_ADDR_ZP_TO
    lda VERA_ADDR_ZP_TO+1
    sbc #>(320)
    sta VERA_ADDR_ZP_TO+1

    ; When we reach the top of the screen we get a negative address. If we do we stop.
    bcs keep_clearing
    jmp bend_copy_done

keep_clearing:
    dec TEMP_VAR
    bne clear_next_line

done_clearing_lines:

    ; Calculate the address to the (current frame) curve index 

    clc
    lda #<frame_curve_indexes
    adc FRAME_NR
    sta FRAME_CURVE_ADDRESS
    lda #>frame_curve_indexes
    adc FRAME_NR+1
    sta FRAME_CURVE_ADDRESS+1

    ; Get the curve index
    ldy #0
    lda (FRAME_CURVE_ADDRESS), y
    sta TEMP_VAR

    ; Base address for curve

    clc
    lda #<(CURVE_DATA_ADDRESS)
    sta LOAD_ADDRESS
    lda #>(CURVE_DATA_ADDRESS)
    adc TEMP_VAR
    sta LOAD_ADDRESS+1

    ; y_increment

    ldy #254
    lda (LOAD_ADDRESS), y
    sta Y_INCREMENT
    ldy #255
    lda (LOAD_ADDRESS), y
    sta Y_INCREMENT+1

    ; starting Y position
    lda #$80   ; y_position_sub  ; FIXME: correct that this is set to 0.5?
    sta Y_SUB_PIXEL
    lda #199   ; y_position_low
    sta Y_SUB_PIXEL+1
    lda #0   ; y_position_high
    sta Y_SUB_PIXEL+2

    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    ; y_increment this always 0 within one row
    lda #0
    asl
    sta VERA_FX_Y_INCR_L      ; Y increment low
    lda #0
    rol
    and #%01111111            ; increment is only 15 bits long
    sta VERA_FX_Y_INCR_H

    ldy #0

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

    tax
    lda y_64_to_tiledata_offset, x
    sta TEMP_VAR

    lda #(TILEDATA_VRAM_ADDRESS >> 9)
    ora TEMP_VAR
    and #%11111100   ; only the 6 highest bits of the address can be set
    ora #%00000010   ; clip = 1
    sta VERA_FX_TILEBASE


    lda #%00000110           ; DCSEL=3, ADDRSEL=0
    sta VERA_CTRL

    ; We use y to determine the width index (within a curve), THEN lookup the x_pos/x_incr based on the width index
    lda (LOAD_ADDRESS), y
    tax

    lda x_inc_low_per_width, x
    sta VERA_FX_X_INCR_L

    lda x_inc_high_per_width, x
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

    lda x_pos_per_width, x
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
    lda #$80    ; TODO: correct to set this to .5?
    sta VERA_FX_X_POS_S      ; X pixel position low [-1:-8]
    lda Y_SUB_PIXEL
    sta VERA_FX_Y_POS_S      ; Y pixel position low [-1:-8]


    ; Copy one row of pixels
    jsr COPY_ROW_CODE

    ; We decrement our our sub pixels
    sec
    lda Y_SUB_PIXEL
    sbc Y_INCREMENT
    sta Y_SUB_PIXEL
    lda Y_SUB_PIXEL+1
    sbc Y_INCREMENT+1
    sta Y_SUB_PIXEL+1

    ; FIXME: HACK we are ASSUMING we never reach the second part of VRAM here! (VERA_ADDR_ZP_TO+2 is not used here!)

    ; We decrement our VERA_ADDR_ZP_TO with 320
    sec
    lda VERA_ADDR_ZP_TO
    sbc #<(320)
    sta VERA_ADDR_ZP_TO
    lda VERA_ADDR_ZP_TO+1
    sbc #>(320)
    sta VERA_ADDR_ZP_TO+1

    ; When we reach the top of the screen we get a negative address. If we do we stop.
    bcc bend_copy_done

    iny

    jmp bend_copy_next_row_1
bend_copy_done:

    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL

    rts
.endproc

y_64_to_tiledata_offset:
    .byte 0*24, 1*24, 2*24, 3*24 

; Per row width data
x_pos_per_width:
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
  .byte $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e, $1f
  .byte $20
x_inc_low_per_width:
  .byte $3e, $37, $30, $2a, $23, $1d, $17, $11, $0b, $05, $00, $fa, $f5, $ef, $ea, $e5
  .byte $e0, $db, $d7, $d2, $cd, $c9, $c4, $c0, $bc, $b8, $b4, $b0, $ac, $a8, $a4, $a0
  .byte $9d
x_inc_high_per_width:
  .byte $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01
  .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
  .byte $01

; Per curve data is loaded using 'CURVES.DAT'

; Per frame data
frame_y_bottom_start:
  .byte 200, 199, 198, 197, 195, 193, 191, 189, 187, 184, 182, 179, 176, 172, 169, 165
  .byte 161, 157, 153, 149, 144, 139, 134, 129, 124, 118, 112, 106, 100, 94, 88, 81
  .byte 74, 67, 60, 52, 45, 37, 29, 21, 12, 4, 1, 1, 1, 2, 2, 2, 2
  .byte 3, 3, 3, 3, 4, 4, 3, 2, 2, 2, 4, 5, 7, 8, 11, 12
  .byte 17, 19, 25, 28, 34, 37, 43, 46, 52, 54, 58, 60, 61, 62, 61, 61
  .byte 59, 59, 56, 55, 52, 51, 50, 49, 49, 48, 49, 50, 51, 52, 54, 55
  .byte 56, 56, 56, 56, 54, 53, 50, 48, 43, 40, 34, 32, 25, 22, 17, 14
  .byte 10, 7, 4, 2, 2, 3, 4, 5, 6, 6, 5, 4, 4, 5, 4, 4
  .byte 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 3, 2, 2, 2, 3, 4
  .byte 6, 7, 10, 12, 15, 17, 20, 22, 23, 24, 25, 25, 23, 23, 19, 18
  .byte 14, 12, 7, 5, 5, 5, 8, 10, 12, 14, 16, 17, 18, 18, 18, 17
  .byte 16, 15, 12, 11, 8, 6, 3, 1, 2, 2, 4, 5, 7, 8, 9, 9
  .byte 9, 9, 8, 7, 4, 3, 3, 3, 5, 5, 6, 6, 5, 5, 4, 3
  .byte 3, 3, 4, 5, 6, 6, 6, 6, 6, 6, 5, 5, 4, 3, 1, 0
frame_curve_indexes:
  .byte 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44
  .byte 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 44
  .byte 44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 27, 19, 15, 9, 5, 2
  .byte 0, 0, 0, 3, 5, 11, 14, 23, 28, 37, 42, 50, 54, 58, 61, 63
  .byte 64, 63, 62, 57, 55, 49, 46, 39, 36, 30, 28, 25, 24, 24, 25, 28
  .byte 30, 36, 39, 46, 49, 55, 57, 60, 62, 62, 62, 59, 57, 52, 49, 43
  .byte 40, 35, 32, 29, 27, 27, 27, 29, 30, 35, 37, 43, 46, 51, 54, 57
  .byte 59, 60, 61, 59, 58, 51, 47, 38, 33, 27, 24, 20, 19, 15, 14, 13
  .byte 13, 14, 15, 19, 21, 26, 28, 34, 37, 43, 47, 52, 55, 59, 61, 61
  .byte 62, 60, 58, 54, 51, 45, 42, 37, 34, 30, 28, 27, 26, 28, 29, 33
  .byte 35, 40, 43, 48, 51, 51, 51, 47, 45, 41, 39, 36, 34, 33, 32, 32
  .byte 32, 35, 36, 39, 41, 45, 47, 50, 52, 50, 50, 46, 44, 40, 38, 35
  .byte 34, 33, 32, 33, 33, 36, 37, 37, 37, 36, 35, 36, 36, 37, 38, 41
  .byte 42, 43, 43, 43, 42, 42, 42, 42, 42, 42, 42, 43, 43, 44, 44, 44
  .byte 44

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
.repeat 128
	.byte $00, $00
.endrepeat
