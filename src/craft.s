.import graceful_fail

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

.importzp SONG_BANK
.import play_song

.macpack longbranch

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
VERA_SPRITES      = $1FC00

; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

; === RAM addresses ===

POLYFILL_TBLS_AND_CODE_RAM_ADDRESS = $8400 ; to $9E00
FILL_LINE_START_JUMP     = $9000   ; this is the actual jump table of 256 bytes 

POLYGON_DATA_RAM_ADDRESS = $A000
POLYGON_DATA_RAM_BANK    = $20      ; polygon data starts at this RAM bank

; === Other constants ===

BACKGROUND_COLOR = 0
BLACK_COLOR = 254     ; this is a non-transparant black color
STARTING_BACKGROUND_COLOR = $16  ; this is the color of the first wall shown

LOAD_FILE = 1
USE_JUMP_TABLE = 1
DEBUG = 0

NUMBER_OF_FRAMES = (1802*5/9)-2

LAST_RING_BANK = $3F

.segment "CRAFT_ZP": zeropage

; Temp vars
TMP1:
	.res 1
TMP2:
	.res 1
TMP3:
	.res 1
TMP4:
	.res 1

; For generating code and loading/storing
CODE_ADDRESS:
	.res 2
LOAD_ADDRESS:
	.res 2
STORE_ADDRESS:
	.res 2

; Used by the slow polygon filler
FILL_LENGTH_LOW:
	.res 1
FILL_LENGTH_HIGH:
	.res 1
NUMBER_OF_ROWS:
	.res 1

; FIXME: REMOVE THIS!?
TMP_COLOR:
	.res 1
TMP_POLYGON_TYPE:
	.res 1

NEXT_STEP:
	.res 1
NR_OF_POLYGONS:
	.res 1
NR_OF_FRAMES:
	.res 2
BUFFER_NR:
	.res 1
SPRITE_X:
	.res 2
CURRENT_RAM_BANK:
	.res 1

VRAM_ADDRESS:
	.res 3

STREAM_RAM_BANK:
	.res 1
STREAM_ADDR:
	.res 2

TO_READ:
	.res 3

.segment "CRAFT_BSS"
.segment "CRAFT_BSS_A"

Y_TO_ADDRESS_LOW_0:
	.res 256
Y_TO_ADDRESS_HIGH_0:
	.res 256
Y_TO_ADDRESS_BANK_0:
	.res 256

Y_TO_ADDRESS_LOW_1:
	.res 256
Y_TO_ADDRESS_HIGH_1:
	.res 256
Y_TO_ADDRESS_BANK_1:
	.res 256

CLEAR_256_BYTES_CODE:   ; takes up to 00F0+rts (256 bytes to clear = 80 * stz = 80 * 3 bytes)
	.res 256


.include "x16.inc"
.include "macros.inc"

.segment "CRAFT"
entry:
	LOADFILE "MUSIC5.ZSM", SONG_BANK, $a000

	jsr play_song

	WAITVSYNC 3

	stz target_palette
	stz target_palette+1
	lda #$ff
	sta target_palette+256
	lda #$0f
	sta target_palette+257

	ldx #2
:   lda #$ff
	sta target_palette,x
	inx
	lda #$0f
	sta target_palette,x
	inx
	bne :-

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	PALETTE_FADE_FULL 1

	WAITVSYNC 10

	jsr setup_vera_for_cross_fade

	jsr generate_clear_256_bytes_code

	jsr cross_fade
	; This clears (almost) the entire VRAM and sets it to the STARTING_BACKGROUND_COLOR
;	jsr clear_screen_fast_4_bytes
	jsr initialize_buffers

	jsr copy_palette_from_index_0

	LOADFILE "POLYFILL-8BIT-TBLS-AND-CODE.DAT", 0, POLYFILL_TBLS_AND_CODE_RAM_ADDRESS ; low RAM, python codegen

	jsr generate_y_to_address_table_0
	jsr generate_y_to_address_table_1

	; This also fills their buffers two 64-pixel rows of black (non transparant) pixels
	jsr setup_covering_sprites

	jsr setup_vera_for_layer0_bitmap_general

	WAITVSYNC

	; We start with showing buffer 1 while filling buffer 0
	jsr setup_vera_for_layer0_bitmap_buffer_1
	stz BUFFER_NR

	OPENFILE "U2E-POLYGONS.DAT"
	sta TO_READ
	stx TO_READ+1
	sty TO_READ+2

	ldx #1
	jsr X16::Kernal::CHKIN

	lda #POLYGON_DATA_RAM_BANK
	sta CURRENT_RAM_BANK
	sta STREAM_RAM_BANK

	lda #<POLYGON_DATA_RAM_ADDRESS
	sta STREAM_ADDR
	lda #>POLYGON_DATA_RAM_ADDRESS
	sta STREAM_ADDR+1

	jsr stream_fill_buffer

	jsr setup_polygon_filler
	jsr setup_polygon_data_address

	MUSIC_SYNC $D1
	jsr draw_all_frames

	jsr unset_polygon_filler

	MUSIC_SYNC $D4

	ldx #0
:	lda #$ff
	sta target_palette,x
	sta target_palette3,x
	inx
	lda #$0f
	sta target_palette,x
	sta target_palette3,x
	inx
	bne :-

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	PALETTE_FADE_FULL 1

	rts

.proc cross_fade
	; white to black
	stz target_palette+(2*$0f)
	stz target_palette+(2*$0f)+1
	ldy #$0f
	lda #$ff
	; stays white
	sta target_palette+(2*$f0)
	sty target_palette+(2*$f0)+1
	; black to white
	sta target_palette+(2*$ff)
	sty target_palette+(2*$ff)+1

	lda #0
	jsr setup_palette_fade
	lda #192
	jsr setup_palette_fade4

	PALETTE_FADE_FULL 2
	rts
.endproc

.proc setup_vera_for_cross_fade
	VERA_SET_ADDR ((Vera::VRAM_palette)+506), 1
	; we're setting up 3 colors for the cross fade
	; $0F = white -> black
	; $F0 = stays white
	; $FF = black -> white
	; and $00 is always black
	VERA_SET_ADDR ((Vera::VRAM_palette)+(2*$00)), 1
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	VERA_SET_ADDR ((Vera::VRAM_palette)+(2*$0F)), 1
	lda #$ff
	sta Vera::Reg::Data0
	lda #$0f
	sta Vera::Reg::Data0
	VERA_SET_ADDR ((Vera::VRAM_palette)+(2*$F0)), 1
	lda #$ff
	sta Vera::Reg::Data0
	lda #$0f
	sta Vera::Reg::Data0
	VERA_SET_ADDR ((Vera::VRAM_palette)+(2*$FF)), 1
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0

	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	lda #%01000000
	sta Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	VERA_SET_ADDR $00000, 3

	WAITVSYNC
	; and now we have to rush the changes in
    stz VERA_CTRL
    lda #$40                 ; 2:1 scale (320 x 240 pixels on screen)
    sta VERA_DC_HSCALE
    sta VERA_DC_VSCALE

	lda #(1 << 1)
	sta VERA_CTRL

	lda #20
	sta VERA_DC_VSTART
	lda #(240-20)
	sta VERA_DC_VSTOP
	stz VERA_DC_HSTART
	lda #$a0
	sta VERA_DC_HSTOP

    ; -- Setup Layer 0 --
    stz VERA_CTRL

    ; Enable bitmap mode and color depth = 8bpp on layer 0
    lda #(4+3)
    sta VERA_L0_CONFIG

	; Enable layer 0 only
    lda VERA_DC_VIDEO
    ora #%00010000           ; Enable Layer 0
    and #%10011111           ; Disable Layer 1 and sprites
    sta VERA_DC_VIDEO

	; setup FX cache params
	lda #(6 << 1) ; DCSEL = 6
	sta Vera::Reg::Ctrl

	stz VERA_FX_CACHE_L
	stz VERA_FX_CACHE_M
	stz VERA_FX_CACHE_H
	stz VERA_FX_CACHE_U

	; top section
	ldy #25
topthird:
.repeat 16 ; black on left
	stz Vera::Reg::Data0
.endrepeat
	lda #$0f ; white which will be black
	sta VERA_FX_CACHE_H
	sta VERA_FX_CACHE_U
	stz Vera::Reg::Data0
	sta VERA_FX_CACHE_L
	sta VERA_FX_CACHE_M
.repeat 45
	stz Vera::Reg::Data0
.endrepeat
	stz VERA_FX_CACHE_U ; black on right
	stz Vera::Reg::Data0
	stz VERA_FX_CACHE_L
	stz VERA_FX_CACHE_M
	stz VERA_FX_CACHE_H
.repeat 17
	stz Vera::Reg::Data0
.endrepeat
	dey
	jne topthird

	lda #$ff
	sta VERA_FX_CACHE_L
	sta VERA_FX_CACHE_M
	sta VERA_FX_CACHE_H
	sta VERA_FX_CACHE_U

	ldy #150
middlethird:
.repeat 16 ; black which will be white on left
	stz Vera::Reg::Data0
.endrepeat
	lda #$f0 ; stays white
	sta VERA_FX_CACHE_H
	sta VERA_FX_CACHE_U
	stz Vera::Reg::Data0
	sta VERA_FX_CACHE_L
	sta VERA_FX_CACHE_M
.repeat 45
	stz Vera::Reg::Data0
.endrepeat
	lda #$ff
	sta VERA_FX_CACHE_U
	stz Vera::Reg::Data0
	sta VERA_FX_CACHE_L
	sta VERA_FX_CACHE_M
	sta VERA_FX_CACHE_H
.repeat 17
	stz Vera::Reg::Data0
.endrepeat
	dey
	jne middlethird


	stz VERA_FX_CACHE_L
	stz VERA_FX_CACHE_M
	stz VERA_FX_CACHE_H
	stz VERA_FX_CACHE_U

	; bottom section
	ldy #24
bottomthird:
.repeat 16 ; black on left
	stz Vera::Reg::Data0
.endrepeat
	lda #$0f ; white which will be black
	sta VERA_FX_CACHE_H
	sta VERA_FX_CACHE_U
	stz Vera::Reg::Data0
	sta VERA_FX_CACHE_L
	sta VERA_FX_CACHE_M
.repeat 45
	stz Vera::Reg::Data0
.endrepeat
	stz VERA_FX_CACHE_U ; black on right
	stz Vera::Reg::Data0
	stz VERA_FX_CACHE_L
	stz VERA_FX_CACHE_M
	stz VERA_FX_CACHE_H
.repeat 17
	stz Vera::Reg::Data0
.endrepeat
	dey
	jne bottomthird

	; final row
.repeat 80
	stz Vera::Reg::Data0
.endrepeat

	; cancel fx
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc draw_polygon_fast

    ldy #0

    ; -- Polygon type --
    lda (LOAD_ADDRESS), y
    sta TMP_POLYGON_TYPE

    ; FIXME: its better to use a FRAME-END code!

; FIXME: technically this name is INCORRECT, since we are MIXING single and double top draws!
single_top_free_form:
; FIXME: this iny should be moved up when we have an actual jump table!
    iny

    ; -- Polygon color --

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

    ; -- Y-start --

    ; FIXME: we can do this more efficiently!
    lda BUFFER_NR
    bne do_y_to_address_1

do_y_to_address_0:
    lda (LOAD_ADDRESS), y
    iny

    tax
    lda Y_TO_ADDRESS_LOW_0, x
    sta VERA_ADDR_LOW
    lda Y_TO_ADDRESS_HIGH_0, x
    sta VERA_ADDR_HIGH
    lda Y_TO_ADDRESS_BANK_0, x
    sta VERA_ADDR_BANK

    bra y_to_address_done

do_y_to_address_1:
    lda (LOAD_ADDRESS), y
    iny

    tax
    lda Y_TO_ADDRESS_LOW_1, x
    sta VERA_ADDR_LOW
    lda Y_TO_ADDRESS_HIGH_1, x
    sta VERA_ADDR_HIGH
    lda Y_TO_ADDRESS_BANK_1, x
    sta VERA_ADDR_BANK

y_to_address_done:


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

	phy   ; backup y (byte offset into data)

	tay   ; put nr-of-lines into y register

	lda VERA_DATA1   ; this will increment x1 and x2 and the fill_length value will be calculated (= x2 - x1). Also: ADDR1 will be updated with ADDR0 + x1

	lda #%00001010           ; DCSEL=5, ADDRSEL=0
	sta VERA_CTRL
	ldx VERA_FX_POLY_FILL_L  ; This contains: FILL_LENGTH >= 16, X1[1:0], FILL_LENGTH[3:0], 0

	jsr draw_polygon_part_using_polygon_filler_and_jump_tables

	ply   ; restore y (byte offset into data)


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

	phy   ; backup y (byte offset into data)

	tay   ; put nr-of-lines into y register

	lda VERA_DATA1   ; this will increment x1 and x2 and the fill_length value will be calculated (= x2 - x1). Also: ADDR1 will be updated with ADDR0 + x1

	lda #%00001010           ; DCSEL=5, ADDRSEL=0
	sta VERA_CTRL
	ldx VERA_FX_POLY_FILL_L  ; This contains: FILL_LENGTH >= 16, X1[1:0], FILL_LENGTH[3:0], 0

	jsr draw_polygon_part_using_polygon_filler_and_jump_tables

	ply   ; restore y (byte offset into data)

    bra draw_next_part


done_drawing_polygon:
    iny   ; We can only get here from one place, and there we still hadnt incremented y yet
    rts

draw_polygon_part_using_polygon_filler_and_jump_tables:
    jmp (FILL_LINE_START_JUMP,x)
.endproc


.proc draw_all_frames

; FIXME: HARDCODED!
; FIXME when the 16-bit number goes negative we have detect the end, BUT this means the NR_OF_FRAMES should be initially filled with nr_of_frames-1 !
; FIXME: shoulnt this be 1030?
    lda #<NUMBER_OF_FRAMES
    sta NR_OF_FRAMES
    lda #>NUMBER_OF_FRAMES
    sta NR_OF_FRAMES+1

	WAITVSYNC
	jsr X16::Kernal::RDTIM
	sta lastjiffy

draw_next_frame:
	jsr lazy_read
	lda CURRENT_RAM_BANK
	sta RAM_BANK

    ldy #0
    ; -- Nr of polygons in this frame --

    lda (LOAD_ADDRESS), y
    cmp #255                  ; if nr of polygon is 255, this means we have to switch to the next RAM bank!
    bne polygon_count_is_ok

    inc CURRENT_RAM_BANK

    ; We set the new RAM Bank and we set the LOAD_ADDRESS to the start of the new RAM Bank
    jsr setup_polygon_data_address

    ; -- Nr of polygons in this frame --
    lda (LOAD_ADDRESS), y

polygon_count_is_ok:
    sta NR_OF_POLYGONS

; FIXME: we can probably *avoid* incrementing LOAD_ADDRESS each frame here! (but now we set y to 0 each polygon, so we need to think about a cleaner/better way to implement this)
    clc
    lda LOAD_ADDRESS
    adc #1
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    lda NR_OF_POLYGONS
    beq done_drawing_polygons  ; if nr of polygons is 0, we are done drawing polygons for this frame   

draw_next_polygon:
    jsr draw_polygon_fast

    clc
    tya                 ; y contained the nr of bytes we read for the previous polygon
    adc LOAD_ADDRESS
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    dec NR_OF_POLYGONS
    bne draw_next_polygon

done_drawing_polygons:
	jsr X16::Kernal::RDTIM
	sec
	sbc lastjiffy
	cmp #2
	bcc pumpit
	;sta $9fb9
	lda lastjiffy
	clc
	adc #3
	sta lastjiffy

	WAITVSYNC

    ; Every frame we switch to which buffer we write to and which one we show
    lda #1
    eor BUFFER_NR
    sta BUFFER_NR

    ; If we are going to fill buffer 1 (not 0) then we show buffer 0
    bne show_buffer_0
show_buffer_1:
    jsr setup_vera_for_layer0_bitmap_buffer_1
    bra done_switching_buffer
show_buffer_0:
    jsr setup_vera_for_layer0_bitmap_buffer_0
done_switching_buffer:

    sec
    lda NR_OF_FRAMES
    sbc #1
    sta NR_OF_FRAMES
    lda NR_OF_FRAMES+1
    sbc #0
    sta NR_OF_FRAMES+1

    bpl draw_next_frame

    rts
pumpit:
	jsr stream_pump
	bra done_drawing_polygons
lastjiffy:
	.byte 0
.endproc


.proc setup_polygon_filler

    lda #%00000101           ; DCSEL=2, ADDRSEL=1
    sta VERA_CTRL

	lda #%00110000           ; ADDR1 increment: +4 byte
    sta VERA_ADDR_BANK

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL

    lda #%11100000           ; ADDR0 increment: +320 bytes
    sta VERA_ADDR_BANK

    lda #%00000010           ; Entering *polygon filler mode*
    ora #%01000000           ; cache write enabled = 1
    sta VERA_FX_CTRL
    rts
.endproc

.proc unset_polygon_filler

    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL

    lda #%00010000           ; ADDR0 increment: +1 bytes
    sta VERA_ADDR_BANK

    lda #%00000000           ; Exiting *polygon filler mode*
    sta VERA_FX_CTRL

    rts
.endproc

.proc setup_polygon_data_address
	lda #<POLYGON_DATA_RAM_ADDRESS
    sta LOAD_ADDRESS
	lda #>POLYGON_DATA_RAM_ADDRESS
    sta LOAD_ADDRESS+1

	lda CURRENT_RAM_BANK
	cmp #(LAST_RING_BANK+1)
	bcc :+
	lda #POLYGON_DATA_RAM_BANK
	sta CURRENT_RAM_BANK
:	sta RAM_BANK

    rts
.endproc

.proc stream_fill_buffer
:	jsr stream_read
	bcs end
	lda syncval
	cmp #$D1
	bcc :-
end:
	rts
.endproc

.proc stream_pump
	jsr stream_read
	bcs end
	jsr stream_read
	bcs end
	jsr stream_read
	bcs end
	jsr stream_read
	bcs end
	jsr stream_read
	bcs end
	jsr stream_read
	bcc continue
end:
	rts
continue:
	; fall through
.endproc

.proc lazy_read
	lda STREAM_RAM_BANK
	sec
	sbc CURRENT_RAM_BANK
	bcs :+
	adc #(LAST_RING_BANK+1)-POLYGON_DATA_RAM_BANK
:	;sta $9fba
	cmp #3
	bcc stream_pump ; dangerously low

	; fall through
.endproc

.proc stream_read
	lda TO_READ+2
	bmi err
	lda STREAM_RAM_BANK
	sec
	sbc CURRENT_RAM_BANK
	bcc below
doread:
	ldx STREAM_ADDR
	ldy STREAM_ADDR+1
	lda STREAM_RAM_BANK
	sta X16::Reg::RAMBank
	cmp #LAST_RING_BANK
	bcc normal_read
	lda CURRENT_RAM_BANK
	cmp #POLYGON_DATA_RAM_BANK
	beq done ; carry set, we reached the end of the ring while the polygon cursor is at the start
	cpy #$be
	bcc normal_read
	beq be_read
	; we're in $bf
	txa
	eor #$ff
	inc
	beq read_255 ; 256 left but no way to ask for it
	bra mp
be_read:
	cpx #0
	beq normal_read
read_255:
	lda #255
	bra mp
normal_read:
	lda #0
mp:
	clc
	jsr X16::Kernal::MACPTR
	bcs gf
	stx TMP1
	sty TMP2
	txa
	adc STREAM_ADDR
	sta STREAM_ADDR
	tya
	adc STREAM_ADDR+1
	cmp #$c0
	bcc nowrap
	sbc #$20
	ldy X16::Reg::RAMBank
	cpy #(LAST_RING_BANK+1)
	bcc :+
	ldy #POLYGON_DATA_RAM_BANK
:	sty STREAM_RAM_BANK
nowrap:
	sta STREAM_ADDR+1
	; deduct from remaining count
	lda TO_READ
	sec
	sbc TMP1
	sta TO_READ
	lda TO_READ+1
	sbc TMP2
	sta TO_READ+1
	bcs :+
	dec TO_READ+2
	bmi file_is_done
:	clc
	rts
below:
	cmp #$ff
	bne doread
err:
	sec
done:
	rts
gf:
	jmp graceful_fail
file_is_done:
	lda #1
	jsr X16::Kernal::CLOSE
	jsr X16::Kernal::CLRCHN
	sec
	rts
.endproc

.proc setup_vera_for_layer0_bitmap_general

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
.endproc

; FIXME: this can be done more efficiently!
.proc setup_vera_for_layer0_bitmap_buffer_0

    ; -- Setup Layer 0 --

    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL

    lda VERA_DC_VIDEO
    ora #%00010000           ; Enable Layer 0
    and #%10011111           ; Disable Layer 1 and sprites
    sta VERA_DC_VIDEO

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
.endproc

; FIXME: this can be done more efficiently!
.proc setup_vera_for_layer0_bitmap_buffer_1

    ; -- Setup Layer 0 --

    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL

    lda VERA_DC_VIDEO
    ora #%01010000           ; Enable Layer 0 and sprites
    and #%11011111           ; Disable Layer 1
    sta VERA_DC_VIDEO

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
.endproc


.proc setup_covering_sprites
    ; We setup 5 covering 64x64 sprites that contain 2 rows of black pixels at the bottom (actually we flip the sprite vertically, so its at the top of their buffer)
    ; We can use the 128 bytes available between the two bitmap buffer for these black pixels. Note: these pixels cannot be 0, since that would make them transparant!

    ; We first fill these 128 with a non-transparant black color
    ; The buffer of these sprites is at 320*200 (right after the end of the first buffer) = 64000 = $0FA00

    lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to 1
    sta VERA_ADDR_BANK
    lda #<($FA00)
    sta VERA_ADDR_LOW
    lda #>($FA00)
    sta VERA_ADDR_HIGH

    lda #BLACK_COLOR
    ldx #128
next_black_pixel:
    sta VERA_DATA0
    dex
    bne next_black_pixel

    ; We then setup the actual 5 sprites

    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    lda #<(VERA_SPRITES)
    sta VERA_ADDR_LOW
    lda #>(VERA_SPRITES)
    sta VERA_ADDR_HIGH

    ldx #0

    stz SPRITE_X
    stz SPRITE_X+1

setup_next_sprite:

    ; The buffer of these sprites is at 320*200 (right after the end of the first buffer) = 64000 = $0FA00

    ; Address (12:5)
    lda #<($FA00>>5)
    sta VERA_DATA0

    ; Mode,	-	, Address (16:13)
    lda #<($FA00>>13)
    ora #%10000000 ; 8bpp
    sta VERA_DATA0

    ; X (7:0)
    lda SPRITE_X
    sta VERA_DATA0

    ; X (9:8)
    lda SPRITE_X+1
    sta VERA_DATA0

    ; Y (7:0)
    lda #<(-62)
    sta VERA_DATA0

    ; Y (9:8)
    lda #>(-64)
    sta VERA_DATA0

    ; Collision mask	Z-depth	V-flip	H-flip
    lda #%00001110   ; Z-depth = in front of all layers, v-flip = 1
    sta VERA_DATA0

    ; Sprite height,	Sprite width,	Palette offset
    lda #%11110000 ; 64x64, 0 palette offset
    sta VERA_DATA0

    clc
    lda SPRITE_X
    adc #64
    sta SPRITE_X
    lda SPRITE_X+1
    adc #0
    sta SPRITE_X+1

    inx

    cpx #5
    bne setup_next_sprite

    rts
.endproc

.proc generate_y_to_address_table_0
    ; Buffer 0 starts at $00000
	; +25*320
	; = $01F40

	BUF0=$01F40

    lda #<BUF0
    sta VRAM_ADDRESS
    lda #>BUF0
    sta VRAM_ADDRESS+1
	lda #^BUF0
    sta VRAM_ADDRESS+2

    ; First entry
    ldy #0
    lda VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW_0, y
    lda VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH_0, y
    lda VRAM_ADDRESS+2
    ora #%11100000           ; +320 byte increment (=%1110)
    sta Y_TO_ADDRESS_BANK_0, y

    ; Entries 1-255
    ldy #1
generate_next_y_to_address_entry_0:
    clc
    lda VRAM_ADDRESS
    adc #<320
    sta VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW_0, y

    lda VRAM_ADDRESS+1
    adc #>320
    sta VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH_0, y

    lda VRAM_ADDRESS+2
    adc #0
    sta VRAM_ADDRESS+2
    ora #%11100000           ; +320 byte increment (=%1110)
    sta Y_TO_ADDRESS_BANK_0, y

    iny
    bne generate_next_y_to_address_entry_0

    rts
.endproc

.proc generate_y_to_address_table_1
    ; Buffer 1 starts at 31*2048 + 640 = 64128 = $0FA80
	; Plus 25*320
	; = $119C0
	BUF1 = $119C0

    lda #<BUF1
    sta VRAM_ADDRESS
    lda #>BUF1
    sta VRAM_ADDRESS+1
	lda #^BUF1
    sta VRAM_ADDRESS+2

    ; First entry
    ldy #0
    lda VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW_1, y
    lda VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH_1, y
    lda VRAM_ADDRESS+2
    ora #%11100000           ; +320 byte increment (=%1110)
    sta Y_TO_ADDRESS_BANK_1, y

    ; Entries 1-255
    ldy #1
generate_next_y_to_address_entry_1:
    clc
    lda VRAM_ADDRESS
    adc #<320
    sta VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW_1, y

    lda VRAM_ADDRESS+1
    adc #>320
    sta VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH_1, y

    lda VRAM_ADDRESS+2
    adc #0
    sta VRAM_ADDRESS+2
    ora #%11100000           ; +320 byte increment (=%1110)
    sta Y_TO_ADDRESS_BANK_1, y

    iny
    bne generate_next_y_to_address_entry_1

    rts
.endproc

.proc initialize_buffers
	; draw the white rectangle on both buffers, clear everything else
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	lda #%01000000
	sta Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	VERA_SET_ADDR $00000, 3

	lda #(6 << 1) ; DCSEL = 6
	sta Vera::Reg::Ctrl

    stz VERA_FX_CACHE_L
    stz VERA_FX_CACHE_M
    stz VERA_FX_CACHE_H
    stz VERA_FX_CACHE_U

	ldy #8
	ldx #208
s0:
	stz Vera::Reg::Data0
	dex
	bne s0
	dey
	bne s0

	lda #$ff
    sta VERA_FX_CACHE_L
    sta VERA_FX_CACHE_M
    sta VERA_FX_CACHE_H
    sta VERA_FX_CACHE_U

	ldy #47
	ldx #224
s1:
	stz Vera::Reg::Data0
	dex
	bne s1
	dey
	bne s1

    stz VERA_FX_CACHE_L
    stz VERA_FX_CACHE_M
    stz VERA_FX_CACHE_H
    stz VERA_FX_CACHE_U

	ldy #16
	ldx #192
s2:
	stz Vera::Reg::Data0
	dex
	bne s2
	dey
	bne s2

	lda #$ff
    sta VERA_FX_CACHE_L
    sta VERA_FX_CACHE_M
    sta VERA_FX_CACHE_H
    sta VERA_FX_CACHE_U

	ldy #47
	ldx #224
s3:
	stz Vera::Reg::Data0
	dex
	bne s3
	dey
	bne s3


    stz VERA_FX_CACHE_L
    stz VERA_FX_CACHE_M
    stz VERA_FX_CACHE_H
    stz VERA_FX_CACHE_U

	ldy #8
	ldx #208
s4:
	stz Vera::Reg::Data0
	dex
	bne s4
	dey
	bne s4

	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	rts
.endproc

.proc clear_screen_fast_4_bytes

    ; We first need to fill the 32-bit cache with 4 times our background color

    lda #%00001100           ; DCSEL=6, ADDRSEL=0
    sta VERA_CTRL

    ; TODO: we *could* use 'one byte cache cycling' so we have to set only *one* byte of the cache here
    lda #STARTING_BACKGROUND_COLOR
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

    ; Two full frame buffers + 2 extra 320-rows + two 64-rows for the covering sprites (not precise, but good enough)
    ; 128768 * 1 byte / 256 = 503 iterations = 256 + 247 iterations
    ldx #0
clear_next_256_bytes_256:
    jsr CLEAR_256_BYTES_CODE
    dex
    bne clear_next_256_bytes_256

    ldx #247
clear_next_256_bytes:
    jsr CLEAR_256_BYTES_CODE
    dex
    bne clear_next_256_bytes 

    lda #%00000000           ; transparent writes = 0, blit write = 0, cache fill enabled = 0, one byte cache cycling = 0, 16bit hop = 0, 4bit mode = 0, normal addr1 mode 
    sta VERA_FX_CTRL

    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL

    rts
.endproc

.proc generate_clear_256_bytes_code

    lda #<CLEAR_256_BYTES_CODE
    sta CODE_ADDRESS
    lda #>CLEAR_256_BYTES_CODE
    sta CODE_ADDRESS+1

    ldy #0                 ; generated code byte counter

    ; -- We generate 64 clear (stz) instructions --

    ldx #64                ; counts nr of clear instructions
next_clear_instruction:

    ; -- stz VERA_DATA0 ($9F23)
    lda #$9C               ; stz ....
    jsr add_code_byte

    lda #$23               ; $23
    jsr add_code_byte

    lda #$9F               ; $9F
    jsr add_code_byte

    dex
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

.proc copy_palette_from_index_0
	VERA_SET_ADDR Vera::VRAM_palette, 1

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
	bne next_packed_color_1

	rts
.endproc


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
	.byte $64, $04
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
	.byte $23, $01
	.byte $23, $01
	.byte $34, $02
	.byte $34, $02
	.byte $34, $02
	.byte $45, $03
	.byte $45, $03
	.byte $45, $03
	.byte $56, $04
	.byte $56, $04
	.byte $56, $04
	.byte $67, $05
	.byte $67, $05
	.byte $67, $05
	.byte $79, $06
	.byte $79, $06
	.byte $79, $06
	.byte $7a, $07
	.byte $7a, $07
	.byte $7a, $07
	.byte $8b, $08
	.byte $8b, $08
	.byte $8b, $08
	.byte $9c, $09
	.byte $9c, $09
	.byte $9c, $09
	.byte $ad, $0a
	.byte $ad, $0a
	.byte $ae, $0b
	.byte $ae, $0b
	.byte $bf, $0c
	.byte $bf, $0c
	.byte $34, $02
	.byte $45, $03
	.byte $45, $03
	.byte $45, $03
	.byte $56, $04
	.byte $56, $04
	.byte $56, $04
	.byte $67, $04
	.byte $67, $05
	.byte $67, $05
	.byte $78, $06
	.byte $78, $06
	.byte $78, $06
	.byte $88, $07
	.byte $88, $07
	.byte $88, $07
	.byte $99, $08
	.byte $99, $08
	.byte $99, $08
	.byte $aa, $09
	.byte $aa, $09
	.byte $aa, $09
	.byte $bb, $0a
	.byte $bb, $0a
	.byte $bb, $0a
	.byte $cc, $0b
	.byte $cc, $0b
	.byte $cc, $0b
	.byte $dd, $0c
	.byte $dd, $0c
	.byte $de, $0d
	.byte $de, $0d
	.byte $22, $03
	.byte $22, $03
	.byte $33, $04
	.byte $33, $04
	.byte $44, $05
	.byte $44, $05
	.byte $55, $06
	.byte $55, $06
	.byte $55, $06
	.byte $66, $07
	.byte $66, $07
	.byte $66, $07
	.byte $77, $08
	.byte $77, $08
	.byte $77, $08
	.byte $88, $09
	.byte $88, $09
	.byte $88, $09
	.byte $99, $0a
	.byte $99, $0a
	.byte $99, $0a
	.byte $aa, $0b
	.byte $aa, $0b
	.byte $bb, $0c
	.byte $bb, $0c
	.byte $bb, $0c
	.byte $cc, $0d
	.byte $cc, $0d
	.byte $cc, $0d
	.byte $dd, $0e
	.byte $dd, $0e
	.byte $ee, $0f
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
	.byte $45, $04
	.byte $45, $04
	.byte $45, $04
	.byte $56, $05
	.byte $56, $05
	.byte $56, $05
	.byte $67, $06
	.byte $67, $06
	.byte $67, $06
	.byte $79, $07
	.byte $79, $07
	.byte $79, $07
	.byte $8a, $08
	.byte $8a, $08
	.byte $8a, $08
	.byte $9b, $09
	.byte $9b, $09
	.byte $9b, $09
	.byte $ac, $0a
	.byte $ac, $0a
	.byte $ac, $0a
	.byte $be, $0b
	.byte $be, $0b
	.byte $bd, $0b
	.byte $bd, $0b
	.byte $ce, $0c
	.byte $ce, $0c
	.byte $df, $0d
	.byte $df, $0d
	.byte $ef, $0e
	.byte $ef, $0e
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
	.byte $ff, $ff
end_of_palette_data:
