.include "x16.inc"
.include "macros.inc"

.include "flow.inc"

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

.import galois16o

.import scenevector

.macpack longbranch
.feature string_escapes

; JeffreyH battle scene constants

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

VERA_L1_CONFIG    = $9F34
VERA_L1_TILEBASE  = $9F36

VERA_PALETTE      = $1FA00
VERA_SPRITES      = $1FC00

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

; === RAM addresses ===

POLYFILL_TBLS_AND_CODE_RAM_ADDRESS = $8400 ; to $9E00
FILL_LINE_START_JUMP     = $9000   ; this is the actual jump table of 256 bytes 

POLYGON_DATA_RAM_ADDRESS = $A000
POLYGON_DATA_RAM_BANK    = $20      ; polygon data starts at this RAM bank

; ==== VRAM addresses ====

FRAME_BUFFER_0_ADDR      = $00000
FRAME_BUFFER_1_ADDR      = $0C000

; === Other constants ===

BACKGROUND_COLOR = 0

LOAD_FILE = 1
USE_JUMP_TABLE = 1
DEBUG = 0

VSYNC_BIT         = $01

; ^^ end battle scene constants
; vv other constants

DISABLE_LAYER1_ON_LINE = 270

TEMP_4BPP_BMP_ADDR = $18000
TILE_MAPBASE = $0D000
SHOCKWAVE_FX_TILEMAP = $10000
PRAXIS_FX_TILEMAP = $10800
SHOCKWAVE_FX_TILEBASE = $11000
PRAXIS_FX_TILEBASE = $19000
PLANET_AREA_X = 144
PLANET_AREA_Y = 80
PLANET_AREA = $00000 + (PLANET_AREA_Y * 320) + PLANET_AREA_X
PLANET_BACKDROP_SPRITE = $1D000

SCRATCH_BANK = $20

.segment "INTRO_ZP": zeropage
frameno:
	.res 1
tmpptr:
	.res 2
scratch:
	.res 1
fx_y_val:
	.res 3
planet_fx_y_val:
	.res 3
fadingout:
	.res 1

; JeffreyH battle scene ZP

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
	.res 2
NR_OF_FRAMES:
	.res 2
BUFFER_NR:
	.res 1
CURRENT_RAM_BANK:
	.res 1

VRAM_ADDRESS:
	.res 3


.segment "INTRO_BSS"
tileno:
	.res 2
lastsync:
	.res 1
text_linger:
	.res 1
bmprow:
	.res 1
tiletmp:
	.res 2

.segment "INTRO_BSS_A"
; battle scene RAM
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

CLEAR_256_BYTES_CODE: ; takes up to 00F0+rts (256 bytes to clear = 80 * stz = 80 * 3 bytes)
	.res 256

.assert * <= POLYFILL_TBLS_AND_CODE_RAM_ADDRESS, error, "INTRO_BSS_A impinges on external codegen POLYFILL-8BIT-TBLS-AND-CODE.DAT"

.segment "INTRO"
entry:
	; memory init
	stz frameno

	jsr setup_vera_and_tiles
.ifdef SKIP_SONG1
	bra dotitilecard ; jump ahead to song 2 if set in main
.endif
	jsr opening_text
	jsr bgscroller_with_text
	jsr prepare_for_ship
	jsr battle_scene
	jsr prepare_for_praxis
	MUSIC_SYNC $0d
	jsr praxis_explosion

	MUSIC_SYNC $0F
dotitilecard:
	jmp titlecard
	; tail call

.proc setup_our_interrupt_handler
	php
	sei

	; enable our handler
	lda #<our_handler
	sta scenevector+2
	lda #>our_handler
	sta scenevector+3
	lda #$ea ; NOP
	sta scenevector

	; set line interrupt
	lda #<DISABLE_LAYER1_ON_LINE
	sta Vera::Reg::IRQLineL
	lda #>DISABLE_LAYER1_ON_LINE
	lsr
	ror
	tsb Vera::Reg::IEN

	; enable line interrupt
	lda Vera::Reg::IEN
	and #%10001101
	ora #%00000010
	sta Vera::Reg::IEN

	plp
	rts
.endproc

.proc unregister_our_interrupt_handler
	php
	sei

	; disable our handler
	lda #$60 ; RTS
	sta scenevector

	; disable line interrupt
	lda Vera::Reg::IEN
	and #%00001101
	sta Vera::Reg::IEN

	plp
	rts
.endproc

.proc our_handler
	lda Vera::Reg::ISR
	lsr
	bcs vsync
	lsr
	bcs line
	rts
line:
	lda #%00100000
	trb Vera::Reg::DCVideo
	lda #2
	sta Vera::Reg::ISR
	rts
vsync:
	lda #%00100000
	tsb Vera::Reg::DCVideo
	rts
.endproc

.proc battle_scene
	jsr generate_clear_256_bytes_code
	jsr copy_palette_from_index_0

	stz BUFFER_NR
	jsr clear_screen_fast_4_bytes
	lda #1
	sta BUFFER_NR
	jsr clear_screen_fast_4_bytes

	LOADFILE "POLYFILL-8BIT-TBLS-AND-CODE.DAT", 0, POLYFILL_TBLS_AND_CODE_RAM_ADDRESS ; low RAM, python codegen

	jsr generate_y_to_address_table_0
	jsr generate_y_to_address_table_1

	LOADFILE "U2A-POLYGONS.DAT", POLYGON_DATA_RAM_BANK, POLYGON_DATA_RAM_ADDRESS

	jsr clear_first_96k_of_vram

	jsr setup_vera_for_layer1_bitmap_general

	; We start with showing buffer 1 while filling buffer 0
	jsr setup_vera_for_layer1_bitmap_buffer_1
	stz BUFFER_NR

	jsr setup_our_interrupt_handler

	MUSIC_SYNC $0B

	lda #POLYGON_DATA_RAM_BANK
	sta CURRENT_RAM_BANK
	jsr setup_polygon_data_address
	jsr draw_all_frames

	jsr disable_layer1
	jsr unregister_our_interrupt_handler

	rts

.endproc

.proc clear_first_96k_of_vram
	lda #(6 << 1)
	sta Vera::Reg::Ctrl

	stz $9f29
	stz $9f2a
	stz $9f2b
	stz $9f2c

	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda #%01000000
	sta Vera::Reg::FXCtrl

	stz Vera::Reg::Ctrl
	VERA_SET_ADDR $00000, 3

	ldy #12
	ldx #0
loop:
.repeat 8
	stz Vera::Reg::Data0
.endrepeat
	dex
	bne loop
	dey
	bne loop

	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	stz Vera::Reg::FXCtrl

	stz Vera::Reg::Ctrl

	rts
.endproc

.proc disable_layer1
	lda #%00100000
	trb Vera::Reg::DCVideo
	rts
.endproc

.proc draw_all_frames

; FIXME: HARDCODED!
; FIXME when the 16-bit number goes negative we have detect the end, BUT this means the NR_OF_FRAMES should be initially filled with nr_of_frames-1 !
; FIXME: shoulnt this be 299?
	lda #<(149)
	sta NR_OF_FRAMES
	lda #>(149)
	sta NR_OF_FRAMES+1

	WAITVSYNC
	jsr X16::Kernal::RDTIM
	sta lastjiffy

draw_next_frame:
	jsr setup_polygon_filler

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
	WAITVSYNC
	jsr X16::Kernal::RDTIM
	sec
	sbc lastjiffy
	cmp #3
	bcc done_drawing_polygons
	lda lastjiffy
	clc
	adc #3
	sta lastjiffy

	; Every frame we switch to which buffer we write to and which one we show
	lda #1
	eor BUFFER_NR
	sta BUFFER_NR

	; If we are going to fill buffer 1 (not 0) then we show buffer 0
	bne show_buffer_0
show_buffer_1:
	jsr setup_vera_for_layer1_bitmap_buffer_1
	bra done_switching_buffer
show_buffer_0:
	jsr setup_vera_for_layer1_bitmap_buffer_0
done_switching_buffer:


	jsr unset_polygon_filler

	jsr clear_screen_fast_4_bytes

	sec
	lda NR_OF_FRAMES
	sbc #1
	sta NR_OF_FRAMES
	lda NR_OF_FRAMES+1
	sbc #0
	sta NR_OF_FRAMES+1

	bpl draw_next_frame

	rts
lastjiffy:
	.byte 0
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

.proc setup_polygon_data_address

	lda #<POLYGON_DATA_RAM_ADDRESS
	sta LOAD_ADDRESS
	lda #>POLYGON_DATA_RAM_ADDRESS
	sta LOAD_ADDRESS+1

	lda CURRENT_RAM_BANK
	sta RAM_BANK

	rts
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

.proc setup_vera_for_layer1_bitmap_buffer_0
	; Set layer1 tilebase to FRAME_BUFFER_0_ADDR and tile width to 320 px
	lda #((>FRAME_BUFFER_0_ADDR)>>1)
	sta VERA_L1_TILEBASE
	rts
.endproc

.proc setup_vera_for_layer1_bitmap_buffer_1
	; Set layer1 tilebase to FRAME_BUFFER_1_ADDR and tile width to 320 px
	lda #((>FRAME_BUFFER_1_ADDR)>>1)
	sta VERA_L1_TILEBASE
	rts
.endproc

.proc setup_vera_for_layer1_bitmap_general
	; -- Setup Layer 1 --
	lda #%00000000           ; DCSEL=0, ADDRSEL=0
	sta VERA_CTRL

	lda #%00100000
	tsb VERA_DC_VIDEO

	; Enable bitmap mode and color depth = 8bpp on layer 0
	lda #(4+3)
	sta VERA_L1_CONFIG

	rts
.endproc

.proc generate_y_to_address_table_0
	; due to a quirk of earlier design, we're a pixel high in the tile map
	; so our Y start is at 24 instead of 25
	BUF0 = FRAME_BUFFER_0_ADDR + (24*320)

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
	; due to a quirk of earlier design, we're a pixel high in the tile map
	; so our Y start is at 24 instead of 25
	BUF1 = FRAME_BUFFER_1_ADDR + (24*320)

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

.proc clear_screen_fast_4_bytes

	; We first need to fill the 32-bit cache with 4 times our background color

	lda #%00001100           ; DCSEL=6, ADDRSEL=0
	sta VERA_CTRL

	; TODO: we *could* use 'one byte cache cycling' so we have to set only *one* byte of the cache here
	lda #BACKGROUND_COLOR
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

	; Depending of the current BUFFER_NR we set the address to that buffer (to clear)
	lda BUFFER_NR
	beq set_to_clear_buffer_0

	lda #>FRAME_BUFFER_1_ADDR
	sta VERA_ADDR_HIGH
	lda #<FRAME_BUFFER_1_ADDR
	sta VERA_ADDR_LOW

	bra done_setting_clear_buffer

set_to_clear_buffer_0:

	lda #>FRAME_BUFFER_0_ADDR
	sta VERA_ADDR_HIGH
	lda #<FRAME_BUFFER_0_ADDR
	sta VERA_ADDR_LOW

done_setting_clear_buffer:

	; 320x120 * 1 byte / 256 = 150 iterations
	ldx #150

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

.proc copy_palette_from_index_0
	VERA_SET_ADDR Vera::VRAM_palette, 1

	ldy #0
next_packed_color_256:
	lda battle_palette_data, y
	sta VERA_DATA0
	iny
	bne next_packed_color_256

	ldy #0
next_packed_color_1:
	lda battle_palette_data+256, y
	sta VERA_DATA0
	iny
	cpy #<(end_of_battle_palette_data-battle_palette_data)
	bne next_packed_color_1

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

.proc setup_vera_and_tiles
	ldx #128
blackpal:
	stz target_palette-128,x
	inx
	bne blackpal

	lda #0
	jsr setup_palette_fade

	PALETTE_FADE 3

	; load BG tiles
	LOADFILE "TITLEBG.VTS", 0, $0000, 0

	; load title font
	LOADFILE "TITLEFONT.VTS", 0, $8000, 1

	; show no layers
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	sta Vera::Reg::DCVideo

	; border = index 0
	stz Vera::Reg::DCBorder

	; 320x240
	lda #$40
	sta Vera::Reg::DCHScale
	sta Vera::Reg::DCVScale

	; letterbox for 320x~200
	lda #$02
	sta Vera::Reg::Ctrl
	lda #21 ; instead of 20 to force tile alignment which was wrongly set to a multiple of 4
	sta Vera::Reg::DCVStart
	lda #221
	sta Vera::Reg::DCVStop
	stz Vera::Reg::DCHStart
	lda #$a0
	sta Vera::Reg::DCHStop
	stz Vera::Reg::Ctrl

	; set up layer 0 as tilemap
	lda #%00010010 ; 4bpp 64x32
	sta Vera::Reg::L0Config
	lda #%00000011 ; $00000 16x16
	sta Vera::Reg::L0TileBase
	; mapbase is at $0D000
	lda #(TILE_MAPBASE >> 9)
	sta Vera::Reg::L0MapBase

	; reset tilemap scroll
	stz Vera::Reg::L0HScrollL
	stz Vera::Reg::L0HScrollH
	stz Vera::Reg::L0VScrollL
	stz Vera::Reg::L0VScrollH

	; put the tiles in place
	VERA_SET_ADDR TILE_MAPBASE, 1

	ldy #64
tbgtloopi:
	lda #<400
	sta Vera::Reg::Data0
	lda #>400
	sta Vera::Reg::Data0
	dey
	bne tbgtloopi

	stz tileno
	stz tileno+1

tbgtloop0:
	ldy #40
tbgtloop1:
	lda tileno
	sta Vera::Reg::Data0
	lda tileno+1
	sta Vera::Reg::Data0
	inc tileno
	bne :+
	inc tileno+1
:	dey
	bne tbgtloop1
	ldy #24
	lda tileno+1
	beq tbgtloop3
	lda tileno
	cmp #<400
	bcc tbgtloop3
	ldy #0
tbgtloop2:
	lda #<400
	sta Vera::Reg::Data0
	lda #>400
	sta Vera::Reg::Data0
	dey
	bne tbgtloop2
	bra tbgtloop4
tbgtloop3:
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	dey
	bne tbgtloop3
	bra tbgtloop0
tbgtloop4:
	DISABLE_SPRITES

	WAITVSYNC ; prevent showing glitched previous state of layer

	; enable layer 0 + sprites
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$50
	sta Vera::Reg::DCVideo

	rts
.endproc

.proc opening_text
	; first few text cards go here

	lda syncval
	sta lastsync
prebgloop:
	WAITVSYNC
	inc frameno
	lda syncval
	cmp lastsync
	jeq nosync

	sta lastsync
	cmp #3
	beq card1
	cmp #4
	beq card2
	cmp #5
	jeq card3
	cmp #6
	jne nosync
	rts
card1:
	SPRITE_TEXT $42, 60, 1, "A showcase by"
	SPRITE_TEXT $6a, 85, 1, "Team FX"
	jmp docolor
card2:
	SPRITE_TEXT $53, 60, 1, "Presented at"
	SPRITE_TEXT $3f, 85, 1, "VCF Midwest 19"
	SPRITE_TEXT $3d, 110, 1, "September 2024"
	bra docolor
card3:
	SPRITE_TEXT $95, 70, 1, "in"
	SPRITE_TEXT $30, 100, 1, "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e"
	bra docolor
docolor:
	lda #$55
	sta target_palette+2
	lda #$05
	sta target_palette+3
	lda #$aa
	sta target_palette+4
	lda #$0a
	sta target_palette+5
	lda #$ff
	sta target_palette+6
	lda #$0f
	sta target_palette+7
	lda #16
	jsr setup_palette_fade
	lda #160
	sta text_linger
nosync:
	lda frameno
	and #1
	jne prebgloop
	jsr apply_palette_fade_step
	jsr flush_palette

	lda text_linger
	jeq prebgloop
	cmp #16
	beq text_fadeout
	dec text_linger
	jne prebgloop

	; we just faded out.  Hide sprites
	DISABLE_SPRITES
	jmp prebgloop
text_fadeout:
	dec text_linger
	; switch to fading it out
	lda #$11
	sta target_palette+2
	stz target_palette+4
	stz target_palette+6
	lda #$01
	sta target_palette+3
	sta target_palette+5
	sta target_palette+7

	lda #16
	jsr setup_palette_fade

	jmp prebgloop
.endproc

.proc bgscroller_with_text
	ldx #32
:	lda titlepal-1,x
	sta target_palette-1,x
	dex
	bne :-

	lda #0
	jsr setup_palette_fade

	; slow scroll during fade-in

tbgscrollloop:
	WAITVSYNC
	inc frameno

	lda frameno
	and #3
	bne nopal

	jsr apply_palette_fade_step
	jsr flush_palette

nopal:
	lda frameno
	and #7
	bne noscroll
	; should we scroll?
	lda Vera::Reg::L0HScrollH
	and #$0f
	beq doscroll
	lda Vera::Reg::L0HScrollL
	cmp #<320
	bcc doscroll
	; we scroll-stopped, next sub to shuffle tiles around to high VRAM
	rts
doscroll:
	inc Vera::Reg::L0HScrollL
	bne noscroll
	inc Vera::Reg::L0HScrollH
noscroll:
	lda syncval
	cmp lastsync
	jeq nosync1

	sta lastsync

	cmp #7
	beq card4
	cmp #8
	jeq card5
	cmp #9
	jeq card6
	cmp #$0a
	jeq card7
	cmp #$0e
	bne tbgscrollloop
	rts
card4:
	SPRITE_TEXT $2a, 70, 1, "Second Reality X16"
	jmp docolor1
card5:
	SPRITE_TEXT $80, 40, 1, "Music"
	SPRITE_TEXT $53, 70, 1, "arranged by"
	SPRITE_TEXT $52, 100, 1, "MooingLemur"
	jmp docolor1
card6:
	SPRITE_TEXT $84, 40, 1, "Code"
	SPRITE_TEXT $69, 70, 1, "JeffreyH"
	SPRITE_TEXT $52, 100, 1, "MooingLemur"
	jmp docolor1
card7:
	SPRITE_TEXT $58, 40, 1,    "Inspired by"
	SPRITE_TEXT $45, 70, 1,  "Second Reality"
	SPRITE_TEXT $3a, 97, 1,  "by Future Crew"
	bra docolor1
docolor1:
	lda #$55
	sta target_palette+2
	lda #$05
	sta target_palette+3
	lda #$aa
	sta target_palette+4
	lda #$0a
	sta target_palette+5
	lda #$ff
	sta target_palette+6
	lda #$0f
	sta target_palette+7
	lda #16
	jsr setup_palette_fade
	lda #160
	sta text_linger
nosync1:
	lda frameno
	and #3
	cmp #1
	jne skippal

	jsr apply_palette_fade_step
	jsr flush_palette

skippal:
	lda frameno
	and #1
	jne tbgscrollloop

	lda text_linger
	jeq tbgscrollloop
	cmp #16
	beq text_fadeout1
	dec text_linger
	jne tbgscrollloop

	; we just faded out.  Hide sprites
	DISABLE_SPRITES
	jmp tbgscrollloop
text_fadeout1:
	dec text_linger
	; switch to fading it out
	lda #$11
	sta target_palette+2
	stz target_palette+4
	stz target_palette+6
	lda #$01
	sta target_palette+3
	sta target_palette+5
	sta target_palette+7

	lda #16
	jsr setup_palette_fade

	jmp tbgscrollloop
.endproc

.proc prepare_for_ship
	; we're done with the text sprites entirely
	; but in case we're out of sync, disable the sprites
	; explicitly here
	DISABLE_SPRITES
	; copy the tile data for what is visible on screen now to a 4bpp bitmap
	; which can fit in just under 32k
	; We have plenty of time, so we can afford for this to take a few frames

	; point DATA1 to our destination
	lda #1
	sta Vera::Reg::Ctrl

	VERA_SET_ADDR TEMP_4BPP_BMP_ADDR, 3 ; we'll take advantage of cache writes

	lda #(2 << 1)
	sta Vera::Reg::Ctrl ; DCSEL=2

	lda #$60
	sta Vera::Reg::FXCtrl
	stz $9f2c ; reset cache index

	stz Vera::Reg::Ctrl

	stz bmprow
	stz tileno ; repurposing this: which tile are we on in this row
tile2bmploop:
	lda bmprow
	; divide by 16 to get tile row
	; then multiply by 64 to get tile index
	; this is collapsed to
	; - drop low nibble
	; - multiply by 4
	; multiply by 2 to get index
	and #$f0
	stz tiletmp+1
.repeat 3
	asl
	rol tiletmp+1
.endrepeat
	adc #38 ; first tile is 19 tiles (38 bytes) in on this row
	sta tiletmp
	lda tiletmp+1
	adc #0
	sta tiletmp+1

	; add this row's tile index
	lda tileno
	asl ; account for each tile idx taking two bytes
	adc tiletmp
	sta tiletmp
	lda tiletmp+1
	adc #0
	sta tiletmp+1

	; point to tilemap
	lda #<TILE_MAPBASE
	; no carry expected
	adc tiletmp
	sta Vera::Reg::AddrL
	lda #>TILE_MAPBASE
	adc tiletmp+1
	sta Vera::Reg::AddrM
	lda #(^TILE_MAPBASE | $10)
	sta Vera::Reg::AddrH

	; find the offset within the tile
	; which is bmprow mod 16
	; multiplied by 8
	lda bmprow
	and #$0f
	asl
	asl
	asl
	sta tiletmp+1

	; two dummy reads to realign the FX cache index
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0

	; extract the tile index
	lda Vera::Reg::Data0
	sta tiletmp
	lda Vera::Reg::Data0
	and #$03

	; multiply the tile index by 128 (8 bytes per row x 16 rows)
	; which means we can instead divide by 2
	lsr
	ror tiletmp
	lda #0
	ror

	; .A contains either $80 or $00
	; tile data source is $00000
	; add the offset within the tile
	adc tiletmp+1
	sta Vera::Reg::AddrL
	lda tiletmp
	; no carry expected
	sta Vera::Reg::AddrM
	lda #$10
	sta Vera::Reg::AddrH

	; copy the data
.repeat 2
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0
	lda Vera::Reg::Data0
	stz Vera::Reg::Data1
.endrepeat

	inc tileno
	lda tileno
	cmp #20
	jcc tile2bmploop
	stz tileno
	inc bmprow
	lda bmprow
	cmp #192
	jcc tile2bmploop

	; turn off FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl ; DCSEL=2

	stz Vera::Reg::FXCtrl
	stz Vera::Reg::Ctrl

	; copy our palette to the last 16 colors
	VERA_SET_ADDR ((Vera::VRAM_palette)+(240*2)), 1
	ldy #0
:	lda titlepal,y
	sta Vera::Reg::Data0
	iny
	cpy #32
	bcc :-

	; we're done with the tile -> bitmap conversion
	WAITVSYNC

	; let's repoint layer 0 to the bitmap
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L0Config
	lda #((TEMP_4BPP_BMP_ADDR >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	lda #15
	sta Vera::Reg::L0HScrollH ; palette offset

	; also let's set VSTOP earlier so we're clear of the registar area of VRAM
	lda #%00000010  ; DCSEL=1
	sta Vera::Reg::Ctrl

	sta Vera::Reg::Ctrl
	lda #21 ; instead of 20 to force tile alignment which was wrongly set to a multiple of 4
	sta Vera::Reg::DCVStart
	lda #200 ; cuts off some noise later
	sta Vera::Reg::DCVStop

	stz Vera::Reg::Ctrl

	rts
.endproc

.proc prepare_for_praxis
	; now transition 4bpp bitmap to 8bpp bitmap

	VERA_SET_ADDR $00000, 1

	lda #1
	sta Vera::Reg::Ctrl

	VERA_SET_ADDR TEMP_4BPP_BMP_ADDR, 1

	stz Vera::Reg::Ctrl

	ldy #>32000
	ldx #<32000
bmp4to8loop:
	lda Vera::Reg::Data1
	pha
	lsr
	lsr
	lsr
	lsr
	sta Vera::Reg::Data0
	pla
	and #$0f
	sta Vera::Reg::Data0
	dex
	bne bmp4to8loop
	dey
	bne bmp4to8loop

	; copy our palette to the first 16 colors again
	VERA_SET_ADDR Vera::VRAM_palette, 1
	ldy #0
:	lda titlepal,y
	sta Vera::Reg::Data0
	iny
	cpy #32
	bcc :-

	WAITVSYNC

	; let's repoint layers to the 8bpp bitmap

	lda #%00000111 ; 8bpp
	sta Vera::Reg::L0Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L0TileBase
	lda #0
	sta Vera::Reg::L0HScrollH ; palette offset

	; now we can load the shockwave FX tiles (uncooked)
	LOADFILE "INTRO-SHOCK.VTS", SCRATCH_BANK, $A000

	; now cook the tiles
	lda #SCRATCH_BANK
	sta X16::Reg::RAMBank

	ldy #4

	VERA_SET_ADDR SHOCKWAVE_FX_TILEBASE, 1
outerloop:
	lda #<$a000
	sta tmpptr

	lda #>$a000
	sta tmpptr+1
cookloop:
	lda (tmpptr)
	ldx #8
bitloop:
	asl
	pha
	bcc zero

	jsr galois16o
	and #$03
	inc
	sta scratch
	asl
	asl
	asl
	asl
	ora scratch
	sta Vera::Reg::Data0
	bra bitloop_end
zero:
	stz Vera::Reg::Data0
bitloop_end:
	pla
	dex
	bne bitloop

	inc tmpptr
	bne cookloop
	inc tmpptr+1
	lda tmpptr+1
	cmp #$a4
	bcc cookloop
	dey
	bne outerloop

	; create the 32x4 tile map (fill out the rest of the 32x32 map with zeroes)
	VERA_SET_ADDR SHOCKWAVE_FX_TILEMAP, 1

	ldx #0
shockmap_loop:
	stx Vera::Reg::Data0
	inx
	cpx #128
	bne shockmap_loop

	ldx #0
shockmap_zeroes:
.repeat 3
	stz Vera::Reg::Data0
.endrepeat
	inx
	bne shockmap_zeroes

	; now we can load the planet FX tiles (uncooked)
	LOADFILE "INTRO-PRAXIS.VTS", SCRATCH_BANK, $A000

	; now cook the tiles
	lda #SCRATCH_BANK
	sta X16::Reg::RAMBank

	ldy #4

	VERA_SET_ADDR PRAXIS_FX_TILEBASE, 1
outerloop2:
	lda #<$a000
	sta tmpptr

	lda #>$a000
	sta tmpptr+1
cookloop2:
	lda (tmpptr)
	ldx #8
bitloop2:
	asl
	pha
	bcc zero2

	jsr galois16o
	and #$01
	clc
	adc #$0e ; planet color
	sta scratch
	asl
	asl
	asl
	asl
	ora scratch
	sta Vera::Reg::Data0
	bra bitloop2_end
zero2:
	stz Vera::Reg::Data0 ; shows through, sneaky sprite underneath!
bitloop2_end:
	pla
	dex
	bne bitloop2

	inc tmpptr
	bne cookloop2
	inc tmpptr+1
	lda tmpptr+1
	cmp #$a2
	bcc cookloop2
	dey
	bne outerloop2

	; create the 8x8 tile map
	VERA_SET_ADDR PRAXIS_FX_TILEMAP, 1

	ldx #0
praxismap_loop:
	stx Vera::Reg::Data0
	inx
	cpx #64
	bne praxismap_loop

	; now create the sprite that shows behind the planet area
	lda #1
	sta Vera::Reg::Ctrl
	VERA_SET_ADDR PLANET_BACKDROP_SPRITE, 1

	stz Vera::Reg::Ctrl
	VERA_SET_ADDR PLANET_AREA, 1

	; 1024 bytes
	ldy #32
outer_backdrop_loop:
	ldx #32
backdrop_loop:
	lda Vera::Reg::Data0
	sta Vera::Reg::Data1
	dex
	bne backdrop_loop
	lda Vera::Reg::AddrL
	clc
	adc #<(320-32)
	sta Vera::Reg::AddrL
	lda Vera::Reg::AddrM
	adc #>(320-32)
	sta Vera::Reg::AddrM
	dey
	bne outer_backdrop_loop

	; now place the sprite
	VERA_SET_ADDR Vera::VRAM_sprattr, 1
	lda #<(PLANET_BACKDROP_SPRITE >> 5)
	sta Vera::Reg::Data0
	lda #>(PLANET_BACKDROP_SPRITE >> 5) | $80 ; 8bpp
	sta Vera::Reg::Data0
	lda #<PLANET_AREA_X
	sta Vera::Reg::Data0
	lda #>PLANET_AREA_X
	sta Vera::Reg::Data0
	lda #<PLANET_AREA_Y
	sta Vera::Reg::Data0
	lda #>PLANET_AREA_Y
	sta Vera::Reg::Data0
	lda #%00000100 ; z-depth 1
	sta Vera::Reg::Data0
	lda #%10100000 ; 32x32
	sta Vera::Reg::Data0

	rts
.endproc

.proc praxis_explosion
	stz fadingout
	WAITVSYNC

	; set palette to $ddd
	VERA_SET_ADDR (Vera::VRAM_palette), 1
	ldx #64
	ldy #$0d
	lda #$dd
:	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	dex
	bne :-

	WAITVSYNC

	; set palette to $fff
	VERA_SET_ADDR (Vera::VRAM_palette), 1
	ldx #64
	ldy #$0f
	lda #$ff
:	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	sta Vera::Reg::Data0
	sty Vera::Reg::Data0
	dex
	bne :-

	; let's copy the palette into the target
	ldx #0
pal1:
	lda praxispal,x
	sta target_palette,x
	inx
	bne pal1
pal2:
	lda praxispal+256,x
	sta target_palette3,x
	inx
	bne pal2

	; for fading back in

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	stz frameno
temploop:
	lda fadingout
	beq fade
	lda frameno
	and #$03
	bne nofade
fade:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	jsr apply_palette_fade_step3
	jsr apply_palette_fade_step4

nofade:
	; set up FX affine stuff for next frame
	; but leave FX itself disabled
	lda #(2 << 1) ; DCSEL = 2
	sta Vera::Reg::Ctrl

	lda frameno
	asl
	asl
	asl
	and #$30
	ora #((SHOCKWAVE_FX_TILEBASE >> 11) << 2) | $02 ; affine clip enable
	sta Vera::Reg::FXTileBase

	lda #((SHOCKWAVE_FX_TILEMAP >> 11) << 2) | $02 ; 32x32
	sta Vera::Reg::FXMapBase


	lda #(3 << 1) ; DCSEL = 3
	sta Vera::Reg::Ctrl
	ldy frameno
	lda shockzoom_l,y
	sta $9f29
	lda shockzoom_h,y
	sta $9f2a
	stz $9f2b
	stz $9f2c

	lda ypos_s,y
	sta fx_y_val
	lda ypos_l,y
	sta fx_y_val+1
	lda ypos_h,y
	sta fx_y_val+2

	lda planet_pos_s,y
	sta planet_fx_y_val
	lda planet_pos_l,y
	sta planet_fx_y_val+1
	lda planet_pos_h,y
	sta planet_fx_y_val+2

	stz Vera::Reg::Ctrl


	WAITVSYNC

	jsr flush_palette
	jsr flush_palette2
	jsr flush_palette3
	jsr flush_palette4


	; enable affine helper
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	; reset cache index
	stz Vera::Reg::FXMult

	lda #%01100011 ; cache fill/write, affine helper mode
	sta Vera::Reg::FXCtrl


	ldx #80
	POS_ADDR_ROW_8BIT
	lda #$30
	sta Vera::Reg::AddrH

	ldy frameno
	cpy #20 ; if frame is less than 20, don't draw shock
	bcc planet

outerloop:

	; set DCSEL=4 to return to beginning of row source
	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	lda xpos_l,y
	sta $9f29

	lda xpos_h,y
	sta $9f2a
	lda fx_y_val+1
	sta $9f2b
	lda fx_y_val+2
	sta $9f2c

	; set DCSEL=5 to return to beginning of row source (subpixels)
	lda #(5 << 1)
	sta Vera::Reg::Ctrl
	lda xpos_s,y
	sta $9f29
	lda fx_y_val
	sta $9f2a
	; set DCSEL=2 to reset cache index
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXMult


	ldy #80
	lda #$55
innerloop:
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	sta Vera::Reg::Data0
	dey
	bne innerloop

	ldy frameno
	lda ypos_incr_l,y
	clc
	adc fx_y_val
	sta fx_y_val
	lda ypos_incr_h,y
	adc fx_y_val+1
	sta fx_y_val+1
	bcc :+
	inc fx_y_val+2
:
	inx
	cpx #120
	bne outerloop

planet:
	; set DCSEL=2
	lda #(2 << 1)
	sta Vera::Reg::Ctrl

	lda frameno
	asl
	asl
	asl
	and #$18
	ora #((PRAXIS_FX_TILEBASE >> 11) << 2) | $02 ; affine clip enable
	sta Vera::Reg::FXTileBase

	lda #((PRAXIS_FX_TILEMAP >> 11) << 2) | $01 ; 8x8
	sta Vera::Reg::FXMapBase

	lda #(3 << 1) ; DCSEL = 3
	sta Vera::Reg::Ctrl

	lda planetzoom_l,y
	sta $9f29
	lda planetzoom_h,y
	sta $9f2a

	ldx #32
	lda #<PLANET_AREA
	sta Vera::Reg::AddrL
	lda #>PLANET_AREA
	sta Vera::Reg::AddrM
planet_outerloop:
	; set DCSEL=4 to return to beginning of row source
	lda #(4 << 1)
	sta Vera::Reg::Ctrl

	lda planet_pos_l,y
	sta $9f29

	lda planet_pos_h,y
	sta $9f2a
	lda planet_fx_y_val+1
	sta $9f2b
	lda planet_fx_y_val+2
	sta $9f2c

	; set DCSEL=5 to return to beginning of row source (subpixels)
	lda #(5 << 1)
	sta Vera::Reg::Ctrl
	lda planet_pos_s,y
	sta $9f29
	lda planet_fx_y_val
	sta $9f2a

	; set DCSEL=2 to reset cache index
;	lda #(2 << 1)
;	sta Vera::Reg::Ctrl
;	stz Vera::Reg::FXMult

	ldy #8
	lda #$aa
planet_innerloop:
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	bit Vera::Reg::Data1
	sta Vera::Reg::Data0
	dey
	bne planet_innerloop

	; move down to next line
	clc
	lda #<(320-(4*8))
	adc Vera::Reg::AddrL
	sta Vera::Reg::AddrL
	lda #>(320-(4*8))
	adc Vera::Reg::AddrM
	sta Vera::Reg::AddrM
	; no bit 16 boundary crossing expected

	ldy frameno
	lda planet_ypos_incr_l,y
	clc
	adc planet_fx_y_val
	sta planet_fx_y_val
	lda planet_ypos_incr_h,y
	adc planet_fx_y_val+1
	sta planet_fx_y_val+1
	bcc :+
	inc planet_fx_y_val+2
:
	dex
	bne planet_outerloop


	; disable FX
	lda #(2 << 1)
	sta Vera::Reg::Ctrl
	stz Vera::Reg::FXCtrl
	stz Vera::Reg::FXMult
	stz Vera::Reg::Ctrl

	inc frameno
	lda frameno
	cmp #20
	bne :+
	lda #$42
	sta target_palette+28
	lda #$08
	sta target_palette+29
	lda #$41
	sta target_palette+30
	lda #$06
	sta target_palette+31
	lda #0
	jsr setup_palette_fade
:

	lda syncval
	cmp #$0f
	beq exit

	lda fadingout
	jne temploop

	lda syncval
	cmp #$0e
	jne temploop
	inc fadingout

	ldx #0
whitepal:
	lda #$ff
	sta target_palette,x
	sta target_palette3,x
	inx
	lda #$0f
	sta target_palette,x
	sta target_palette3,x
	inx
	bne whitepal

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	jmp temploop

exit:
	; set VSTOP for 200px
	lda #%00000010  ; DCSEL=1
	sta Vera::Reg::Ctrl

	lda #20
	sta Vera::Reg::DCVStart
	lda #220
	sta Vera::Reg::DCVStop

	stz Vera::Reg::Ctrl

	DISABLE_SPRITES

	rts
.endproc

.proc titlecard
syncf:
	; set bitmap mode for layer 1
	lda #%00000110 ; 4bpp
	sta Vera::Reg::L1Config
	lda #(($00000 >> 11) << 2) | 0 ; 320
	sta Vera::Reg::L1TileBase
	stz Vera::Reg::L1HScrollH ; palette offset

	; load static image
	LOADFILE "TITLECARD.VBM", 0, $0000, 0
	LOADFILE "TITLECARD.PAL", 0, target_palette

	; show bitmap layer
	stz Vera::Reg::Ctrl
	lda Vera::Reg::DCVideo
	and #$0f
	ora #$20
	sta Vera::Reg::DCVideo

	lda #0 ; set up first 64 palette entries to fade
	jsr setup_palette_fade

	PALETTE_FADE 5

	rts
.endproc

titlepal:
	.word $0000,$0001,$0102,$0202,$0112,$0122,$0223,$0224,$0234,$0333,$0335,$0346,$0456,$0457,$0842,$0641
praxispal:
	.word $0000,$0001,$0102,$0202,$0112,$0122,$0223,$0224,$0234,$0333,$0335,$0346,$0456,$0457,$0eee,$0fff
	.word $0112,$0112,$0213,$0313,$0223,$0233,$0334,$0335,$0345,$0444,$0446,$0457,$0557,$0557,$0853,$0652
	.word $0113,$0113,$0213,$0313,$0223,$0233,$0334,$0335,$0345,$0444,$0446,$0457,$0567,$0568,$0953,$0753
	.word $0223,$0223,$0324,$0424,$0334,$0344,$0445,$0446,$0456,$0555,$0557,$0568,$0668,$0668,$0964,$0763
	.word $0334,$0334,$0435,$0435,$0445,$0445,$0446,$0446,$0456,$0556,$0557,$0568,$0678,$0679,$0965,$0864
	.word $0445,$0445,$0446,$0546,$0446,$0456,$0556,$0557,$0567,$0666,$0668,$0679,$0779,$0779,$0976,$0875
	.word $0446,$0446,$0546,$0646,$0556,$0566,$0667,$0668,$0668,$0667,$0668,$0679,$0789,$078a,$0a76,$0876
	.word $0556,$0556,$0657,$0657,$0667,$0667,$0668,$0668,$0678,$0778,$0779,$078a,$088a,$088a,$0a87,$0986
	.word $0667,$0667,$0668,$0768,$0668,$0678,$0778,$0779,$0779,$0778,$0779,$078a,$089a,$089b,$0a88,$0987
	.word $0778,$0778,$0779,$0879,$0779,$0789,$0889,$088a,$088a,$0889,$088a,$089b,$099b,$099b,$0b99,$0a98
	.word $0779,$0779,$0879,$0879,$0889,$0889,$088a,$088a,$089a,$099a,$099b,$099b,$099b,$099b,$0b99,$0a99
	.word $088a,$088a,$088a,$098a,$088a,$089a,$099a,$099b,$099b,$099a,$099b,$09ac,$0aac,$0aac,$0baa,$0aaa
	.word $099a,$099a,$099b,$099b,$099b,$099b,$099b,$099b,$09ab,$0aab,$0aac,$0aac,$0aac,$0aac,$0bab,$0baa
	.word $099b,$099b,$0a9b,$0a9b,$0aab,$0aab,$0aac,$0aac,$0aac,$0aac,$0aac,$0abd,$0bbd,$0bbd,$0cbb,$0bbb
	.word $0aac,$0aac,$0aac,$0bac,$0aac,$0abc,$0bbc,$0bbd,$0bbd,$0bbc,$0bbd,$0bbd,$0bbd,$0bbd,$0cbc,$0bbc
	.word $0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bbd,$0bce,$0cce,$0cce,$0ccd,$0ccd

shockzoom_l:
	.byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	.byte $ff,$ff,$ff,$ff,$ff,$a0,$64,$b8,$6a,$60,$85,$d0,$36,$b2,$40,$dc
	.byte $83,$35,$ef,$b0,$76,$42,$13,$e8,$c0,$9b,$78,$59,$3b,$20,$06,$ee
	.byte $d7,$c1,$ad,$9a,$88,$77,$67,$58,$49,$3b,$2e,$21,$15,$09,$fe,$f4
	.byte $e9,$e0,$d6,$cd,$c4,$bc,$b4,$ac,$a5,$9d,$96,$90,$89,$83,$7c,$77
	.byte $71,$6b,$66,$60,$5b,$56,$52,$4d,$48,$44,$40,$3b,$37,$33,$2f,$2c
	.byte $28,$24,$21,$1d,$1a,$17,$13,$10,$0d,$0a,$07,$04,$02,$ff,$fc,$fa
	.byte $f7,$f4,$f2,$f0,$ed,$eb,$e9,$e6,$e4,$e2,$e0,$de,$dc,$da,$d8,$d6
	.byte $d4,$d2,$d0,$ce,$cd,$cb,$c9,$c8,$c6,$c4,$c3,$c1,$c0,$be,$bc,$bb
	.byte $ba,$b8,$b7,$b5,$b4,$b3,$b1,$b0,$af,$ad,$ac,$ab,$aa,$a9,$a7,$a6
	.byte $a5,$a4,$a3,$a2,$a1,$a0,$9e,$9d,$9c,$9b,$9a,$99,$98,$97,$96,$96
	.byte $95,$94,$93,$92,$91,$90,$8f,$8e,$8e,$8d,$8c,$8b,$8a,$89,$89,$88
	.byte $87,$86,$86,$85,$84,$83,$83,$82,$81,$81,$80,$7f,$7e,$7e,$7d,$7d
	.byte $7c,$7b,$7b,$7a,$79,$79,$78,$78,$77,$76,$76,$75,$75,$74,$73,$73
	.byte $72,$72,$71,$71,$70,$70,$6f,$6f,$6e,$6e,$6d,$6d,$6c,$6c,$6b,$6b
	.byte $6a,$6a,$69,$69,$68,$68,$67,$67,$67,$66,$66,$65,$65,$64,$64,$64
shockzoom_h:
	.byte $17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17
	.byte $17,$17,$17,$17,$17,$0f,$0d,$0b,$0a,$09,$08,$07,$07,$06,$06,$05
	.byte $05,$05,$04,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$03,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ypos_incr_l:
	.byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
	.byte $fe,$fe,$fe,$fe,$fe,$70,$16,$94,$a0,$10,$c8,$b8,$d1,$0b,$60,$ca
	.byte $45,$d0,$66,$08,$b2,$64,$1d,$dc,$a0,$68,$35,$05,$d9,$b0,$89,$65
	.byte $42,$22,$04,$e8,$cc,$b3,$9b,$84,$6e,$59,$45,$32,$20,$0e,$fd,$ee
	.byte $de,$d0,$c1,$b4,$a7,$9a,$8e,$82,$77,$6c,$62,$58,$4e,$44,$3b,$32
	.byte $29,$21,$19,$11,$09,$02,$fb,$f4,$ed,$e6,$e0,$d9,$d3,$cd,$c7,$c2
	.byte $bc,$b7,$b1,$ac,$a7,$a2,$9d,$99,$94,$90,$8b,$87,$83,$7e,$7a,$77
	.byte $73,$6f,$6b,$68,$64,$60,$5d,$5a,$56,$53,$50,$4d,$4a,$47,$44,$41
	.byte $3e,$3b,$39,$36,$33,$31,$2e,$2c,$29,$27,$24,$22,$20,$1d,$1b,$19
	.byte $17,$14,$12,$10,$0e,$0c,$0a,$08,$06,$04,$02,$01,$ff,$fd,$fb,$fa
	.byte $f8,$f6,$f4,$f3,$f1,$f0,$ee,$ec,$eb,$e9,$e8,$e6,$e5,$e3,$e2,$e1
	.byte $df,$de,$dc,$db,$da,$d8,$d7,$d6,$d5,$d3,$d2,$d1,$d0,$ce,$cd,$cc
	.byte $cb,$ca,$c9,$c8,$c6,$c5,$c4,$c3,$c2,$c1,$c0,$bf,$be,$bd,$bc,$bb
	.byte $ba,$b9,$b8,$b7,$b6,$b5,$b4,$b4,$b3,$b2,$b1,$b0,$af,$ae,$ad,$ad
	.byte $ac,$ab,$aa,$a9,$a9,$a8,$a7,$a6,$a5,$a5,$a4,$a3,$a2,$a2,$a1,$a0
	.byte $a0,$9f,$9e,$9d,$9d,$9c,$9b,$9b,$9a,$99,$99,$98,$97,$97,$96,$96
ypos_incr_h:
	.byte $23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23
	.byte $23,$23,$23,$23,$23,$17,$14,$11,$0f,$0e,$0c,$0b,$0a,$0a,$09,$08
	.byte $08,$07,$07,$07,$06,$06,$06,$05,$05,$05,$05,$05,$04,$04,$04,$04
	.byte $04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
xpos_s:
	.byte $50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50,$50
	.byte $50,$50,$50,$50,$50,$00,$92,$80,$aa,$00,$2e,$00,$13,$49,$00,$40
	.byte $d2,$55,$43,$00,$db,$17,$e9,$80,$00,$89,$38,$24,$61,$00,$10,$a0
	.byte $ba,$69,$b6,$aa,$4c,$a1,$b1,$80,$12,$6d,$94,$8b,$55,$f4,$6c,$c0
	.byte $f0,$00,$f0,$c4,$7d,$1c,$a2,$12,$6b,$b0,$e1,$00,$0c,$08,$f3,$d0
	.byte $9d,$5d,$0f,$b4,$4d,$db,$5d,$d5,$42,$a6,$00,$50,$98,$d8,$10,$40
	.byte $68,$89,$a3,$b6,$c3,$ca,$cb,$c5,$ba,$aa,$95,$7a,$5a,$36,$0d,$e0
	.byte $ae,$78,$3e,$00,$be,$78,$2f,$e2,$92,$3e,$e8,$8e,$31,$d1,$6e,$09
	.byte $a0,$35,$c8,$58,$e5,$70,$f9,$80,$04,$86,$06,$84,$00,$79,$f1,$68
	.byte $dc,$4e,$bf,$2e,$9b,$07,$71,$da,$41,$a6,$0b,$6d,$ce,$2e,$8d,$ea
	.byte $46,$a1,$fa,$53,$aa,$00,$54,$a8,$fa,$4c,$9c,$ec,$3a,$88,$d4,$20
	.byte $6a,$b4,$fc,$44,$8b,$d1,$16,$5b,$9f,$e1,$23,$65,$a5,$e5,$24,$62
	.byte $a0,$dd,$19,$55,$90,$ca,$04,$3d,$75,$ad,$e4,$1b,$51,$86,$bb,$f0
	.byte $23,$57,$89,$bc,$ed,$1f,$4f,$80,$af,$df,$0d,$3c,$6a,$97,$c4,$f1
	.byte $1d,$49,$74,$9f,$c9,$f4,$1d,$47,$70,$98,$c0,$e8,$10,$37,$5e,$84
	.byte $aa,$d0,$f5,$1a,$3f,$64,$88,$ac,$cf,$f2,$15,$38,$5a,$7c,$9e,$c0
xpos_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$9e,$50,$d6,$3e,$92,$d6,$0f,$3f,$68,$8c,$ab
	.byte $c6,$df,$f5,$09,$1a,$2b,$39,$47,$54,$5f,$6a,$74,$7d,$86,$8e,$95
	.byte $9c,$a3,$a9,$af,$b5,$ba,$bf,$c4,$c9,$cd,$d1,$d5,$d9,$dc,$e0,$e3
	.byte $e6,$ea,$ec,$ef,$f2,$f5,$f7,$fa,$fc,$fe,$00,$03,$05,$07,$08,$0a
	.byte $0c,$0e,$10,$11,$13,$14,$16,$17,$19,$1a,$1c,$1d,$1e,$1f,$21,$22
	.byte $23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f,$30,$31,$31
	.byte $32,$33,$34,$35,$35,$36,$37,$37,$38,$39,$39,$3a,$3b,$3b,$3c,$3d
	.byte $3d,$3e,$3e,$3f,$3f,$40,$40,$41,$42,$42,$43,$43,$44,$44,$44,$45
	.byte $45,$46,$46,$47,$47,$48,$48,$48,$49,$49,$4a,$4a,$4a,$4b,$4b,$4b
	.byte $4c,$4c,$4c,$4d,$4d,$4e,$4e,$4e,$4e,$4f,$4f,$4f,$50,$50,$50,$51
	.byte $51,$51,$51,$52,$52,$52,$53,$53,$53,$53,$54,$54,$54,$54,$55,$55
	.byte $55,$55,$56,$56,$56,$56,$57,$57,$57,$57,$57,$58,$58,$58,$58,$58
	.byte $59,$59,$59,$59,$59,$5a,$5a,$5a,$5a,$5a,$5b,$5b,$5b,$5b,$5b,$5b
	.byte $5c,$5c,$5c,$5c,$5c,$5c,$5d,$5d,$5d,$5d,$5d,$5d,$5e,$5e,$5e,$5e
	.byte $5e,$5e,$5e,$5f,$5f,$5f,$5f,$5f,$5f,$5f,$60,$60,$60,$60,$60,$60
xpos_h:
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $01,$01,$01,$01,$01,$03,$04,$04,$05,$05,$05,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ypos_s:
	.byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18
	.byte $18,$18,$18,$18,$18,$00,$92,$c0,$00,$00,$74,$80,$ec,$49,$00,$60
	.byte $a5,$00,$94,$80,$db,$ba,$2c,$40,$00,$76,$aa,$a4,$69,$00,$6b,$b0
	.byte $d1,$d2,$b6,$80,$30,$ca,$4e,$c0,$1f,$6d,$ac,$dd,$00,$16,$20,$20
	.byte $14,$00,$e1,$bb,$8c,$55,$17,$d2,$86,$34,$dd,$80,$1d,$b5,$49,$d8
	.byte $62,$e8,$6a,$e9,$64,$db,$4f,$c0,$2d,$98,$00,$65,$c7,$27,$84,$e0
	.byte $38,$8f,$e4,$36,$87,$d6,$23,$6e,$b8,$00,$46,$8b,$ce,$10,$50,$90
	.byte $cd,$0a,$45,$80,$b9,$f0,$27,$5d,$92,$c6,$f8,$2a,$5b,$8b,$ba,$e9
	.byte $16,$43,$6f,$9a,$c4,$ee,$17,$40,$67,$8e,$b5,$da,$00,$24,$48,$6c
	.byte $8e,$b1,$d3,$f4,$15,$35,$55,$74,$93,$b2,$d0,$ed,$0a,$27,$44,$60
	.byte $7b,$96,$b1,$cc,$e6,$00,$19,$32,$4b,$63,$7b,$93,$ab,$c2,$d9,$f0
	.byte $06,$1c,$32,$47,$5d,$72,$86,$9b,$af,$c3,$d7,$eb,$fe,$11,$24,$37
	.byte $49,$5c,$6e,$80,$91,$a3,$b4,$c5,$d6,$e7,$f7,$08,$18,$28,$38,$48
	.byte $57,$66,$76,$85,$94,$a2,$b1,$c0,$ce,$dc,$ea,$f8,$06,$13,$21,$2e
	.byte $3c,$49,$56,$63,$6f,$7c,$88,$95,$a1,$ad,$b9,$c5,$d1,$dd,$e9,$f4
	.byte $00,$0b,$16,$21,$2c,$37,$42,$4d,$57,$62,$6c,$77,$81,$8b,$95,$a0
ypos_l:
	.byte $d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0,$d0
	.byte $d0,$d0,$d0,$d0,$d0,$99,$ce,$f6,$16,$2f,$43,$54,$62,$6f,$7a,$83
	.byte $8b,$93,$99,$9f,$a4,$a9,$ae,$b2,$b6,$b9,$bc,$bf,$c2,$c5,$c7,$c9
	.byte $cb,$cd,$cf,$d1,$d3,$d4,$d6,$d7,$d9,$da,$db,$dc,$de,$df,$e0,$e1
	.byte $e2,$e3,$e3,$e4,$e5,$e6,$e7,$e7,$e8,$e9,$e9,$ea,$eb,$eb,$ec,$ec
	.byte $ed,$ed,$ee,$ee,$ef,$ef,$f0,$f0,$f1,$f1,$f2,$f2,$f2,$f3,$f3,$f3
	.byte $f4,$f4,$f4,$f5,$f5,$f5,$f6,$f6,$f6,$f7,$f7,$f7,$f7,$f8,$f8,$f8
	.byte $f8,$f9,$f9,$f9,$f9,$f9,$fa,$fa,$fa,$fa,$fa,$fb,$fb,$fb,$fb,$fb
	.byte $fc,$fc,$fc,$fc,$fc,$fc,$fd,$fd,$fd,$fd,$fd,$fd,$fe,$fe,$fe,$fe
	.byte $fe,$fe,$fe,$fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05
	.byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
ypos_h:
	.byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
	.byte $05,$05,$05,$05,$05,$06,$06,$06,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

planetzoom_l:
	.byte $d7,$fd,$6c,$1c,$06,$25,$74,$ed,$8d,$50,$32,$30,$48,$76,$ba,$10
	.byte $76,$ec,$70,$ff,$02,$04,$06,$08,$0a,$0c,$0e,$10,$12,$14,$16,$18
	.byte $1a,$1d,$1f,$21,$23,$25,$27,$29,$2b,$2e,$30,$32,$34,$36,$38,$3a
	.byte $3d,$3f,$41,$43,$45,$47,$4a,$4c,$4e,$50,$52,$55,$57,$59,$5b,$5e
	.byte $61,$64,$68,$6b,$6e,$72,$75,$79,$7c,$80,$83,$87,$8a,$8d,$91,$94
	.byte $98,$9c,$9f,$a3,$a6,$aa,$ad,$b1,$b5,$b8,$bc,$bf,$c3,$c7,$ca,$ce
	.byte $d2,$d5,$d9,$dd,$e1,$e4,$e8,$ec,$f0,$f3,$f7,$fb,$ff,$03,$07,$0a
	.byte $0e,$12,$16,$1a,$1e,$22,$26,$2a,$2e,$32,$36,$3a,$3e,$42,$46,$4a
	.byte $5e,$73,$88,$9d,$b3,$c8,$df,$f5,$0c,$23,$3b,$53,$6b,$84,$9d,$b6
	.byte $d0,$ea,$05,$20,$3b,$57,$73,$90,$ad,$ca,$e8,$06,$25,$44,$64,$84
	.byte $a5,$c6,$e8,$0a,$2d,$50,$74,$98,$bd,$e3,$09,$2f,$56,$7e,$a6,$cf
	.byte $f9,$23,$4e,$79,$a5,$d2,$ff,$2d,$5c,$8b,$bc,$ed,$1e,$51,$84,$b8
	.byte $ec,$22,$58,$8f,$c7,$00,$39,$74,$af,$eb,$29,$67,$a6,$e6,$26,$68
	.byte $ab,$ef,$34,$7a,$c1,$09,$52,$9c,$e7,$34,$81,$d0,$20,$71,$c4,$17
	.byte $6c,$c2,$19,$72,$cc,$28,$84,$e3,$42,$a3,$06,$69,$cf,$36,$9e,$08
	.byte $74,$e1,$50,$c1,$33,$a7,$1d,$94,$0d,$89,$06,$84,$05,$88,$0c,$93
planetzoom_h:
	.byte $1c,$19,$17,$15,$13,$11,$0f,$0d,$0c,$0b,$0a,$09,$08,$07,$06,$06
	.byte $05,$04,$04,$03,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05
	.byte $05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05
	.byte $05,$05,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$07,$07,$07,$07,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08
	.byte $08,$08,$08,$09,$09,$09,$09,$09,$09,$09,$0a,$0a,$0a,$0a,$0a,$0a
	.byte $0a,$0b,$0b,$0b,$0b,$0b,$0b,$0c,$0c,$0c,$0c,$0c,$0d,$0d,$0d,$0d
	.byte $0d,$0e,$0e,$0e,$0e,$0f,$0f,$0f,$0f,$0f,$10,$10,$10,$10,$11,$11
	.byte $11,$11,$12,$12,$12,$13,$13,$13,$13,$14,$14,$14,$15,$15,$15,$16
	.byte $16,$16,$17,$17,$17,$18,$18,$18,$19,$19,$1a,$1a,$1a,$1b,$1b,$1c
	.byte $1c,$1c,$1d,$1d,$1e,$1e,$1f,$1f,$20,$20,$21,$21,$22,$22,$23,$23
planet_ypos_incr_l:
	.byte $6b,$fe,$b6,$8e,$83,$92,$ba,$f6,$46,$a8,$19,$98,$24,$bb,$5d,$08
	.byte $bb,$76,$38,$ff,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c
	.byte $0d,$0e,$0f,$10,$11,$12,$13,$14,$15,$17,$18,$19,$1a,$1b,$1c,$1d
	.byte $1e,$1f,$20,$21,$22,$23,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2f
	.byte $30,$32,$34,$35,$37,$39,$3a,$3c,$3e,$40,$41,$43,$45,$46,$48,$4a
	.byte $4c,$4e,$4f,$51,$53,$55,$56,$58,$5a,$5c,$5e,$5f,$61,$63,$65,$67
	.byte $69,$6a,$6c,$6e,$70,$72,$74,$76,$78,$79,$7b,$7d,$7f,$81,$83,$85
	.byte $87,$89,$8b,$8d,$8f,$91,$93,$95,$97,$99,$9b,$9d,$9f,$a1,$a3,$a5
	.byte $af,$b9,$c4,$ce,$d9,$e4,$ef,$fa,$06,$11,$1d,$29,$35,$42,$4e,$5b
	.byte $68,$75,$82,$90,$9d,$ab,$b9,$c8,$d6,$e5,$f4,$03,$12,$22,$32,$42
	.byte $52,$63,$74,$85,$96,$a8,$ba,$cc,$de,$f1,$04,$17,$2b,$3f,$53,$67
	.byte $7c,$91,$a7,$bc,$d2,$e9,$ff,$16,$2e,$45,$5e,$76,$8f,$a8,$c2,$dc
	.byte $f6,$11,$2c,$47,$63,$80,$9c,$ba,$d7,$f5,$14,$33,$53,$73,$93,$b4
	.byte $d5,$f7,$1a,$3d,$60,$84,$a9,$ce,$f3,$1a,$40,$68,$90,$b8,$e2,$0b
	.byte $36,$61,$8c,$b9,$e6,$14,$42,$71,$a1,$d1,$03,$34,$67,$9b,$cf,$04
	.byte $3a,$70,$a8,$e0,$19,$53,$8e,$ca,$06,$44,$83,$c2,$02,$44,$86,$c9
planet_ypos_incr_h:
	.byte $0e,$0c,$0b,$0a,$09,$08,$07,$06,$06,$05,$05,$04,$04,$03,$03,$03
	.byte $02,$02,$02,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05
	.byte $05,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$07,$07,$07,$07,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08,$08
	.byte $08,$08,$09,$09,$09,$09,$09,$09,$09,$0a,$0a,$0a,$0a,$0a,$0a,$0b
	.byte $0b,$0b,$0b,$0b,$0b,$0c,$0c,$0c,$0c,$0c,$0d,$0d,$0d,$0d,$0d,$0e
	.byte $0e,$0e,$0e,$0e,$0f,$0f,$0f,$0f,$10,$10,$10,$10,$11,$11,$11,$11
planet_pos_s:
	.byte $47,$10,$98,$1a,$c8,$d0,$5c,$91,$92,$7d,$6d,$7b,$be,$49,$2e,$7f
	.byte $49,$9a,$7e,$00,$ef,$df,$ce,$be,$ad,$9d,$8c,$7c,$6b,$5a,$49,$39
	.byte $28,$17,$06,$f5,$e4,$d4,$c3,$b2,$a0,$8f,$7e,$6d,$5c,$4b,$39,$28
	.byte $17,$05,$f4,$e3,$d1,$c0,$ae,$9d,$8b,$79,$68,$56,$44,$32,$21,$0f
	.byte $f4,$d9,$be,$a3,$88,$6d,$51,$36,$1a,$ff,$e3,$c7,$ac,$90,$74,$58
	.byte $3b,$1f,$03,$e6,$ca,$ad,$91,$74,$57,$3a,$1d,$00,$e3,$c6,$a8,$8b
	.byte $6d,$50,$32,$14,$f6,$d8,$ba,$9c,$7e,$60,$41,$23,$04,$e5,$c6,$a8
	.byte $89,$69,$4a,$2b,$0c,$ec,$cd,$ad,$8d,$6d,$4e,$2e,$0d,$ed,$cd,$ac
	.byte $0a,$65,$be,$14,$67,$b8,$06,$52,$9b,$e1,$24,$65,$a3,$dd,$15,$4a
	.byte $7c,$aa,$d6,$fe,$23,$45,$64,$7f,$96,$ab,$bb,$c8,$d2,$d8,$d9,$d8
	.byte $d2,$c8,$bb,$a9,$93,$79,$5b,$39,$12,$e7,$b7,$82,$4a,$0c,$ca,$82
	.byte $36,$e5,$8f,$34,$d3,$6d,$02,$92,$1c,$a0,$1e,$97,$0a,$77,$de,$3f
	.byte $99,$ee,$3b,$83,$c3,$fd,$30,$5d,$82,$a0,$b7,$c7,$cf,$cf,$c8,$b9
	.byte $a2,$83,$5c,$2d,$f6,$b5,$6d,$1b,$c1,$5d,$f0,$7a,$fb,$72,$df,$43
	.byte $9c,$eb,$30,$6a,$9a,$bf,$d9,$e7,$eb,$e3,$cf,$b0,$84,$4d,$09,$b8
	.byte $5b,$f1,$7a,$f5,$63,$c3,$16,$5a,$90,$b7,$cf,$d9,$d3,$be,$99,$65
planet_pos_l:
	.byte $39,$50,$64,$77,$87,$96,$a4,$b0,$bb,$c5,$ce,$d6,$dd,$e4,$ea,$ef
	.byte $f4,$f8,$fc,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	.byte $ff,$ff,$ff,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
	.byte $fe,$fe,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd,$fd
	.byte $fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fb,$fb,$fb,$fb,$fb,$fb,$fb
	.byte $fb,$fb,$fb,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$fa,$f9,$f9,$f9,$f9
	.byte $f9,$f9,$f9,$f9,$f8,$f8,$f8,$f8,$f8,$f8,$f8,$f8,$f8,$f7,$f7,$f7
	.byte $f7,$f7,$f7,$f7,$f7,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f6,$f5,$f5,$f5
	.byte $f5,$f4,$f3,$f3,$f2,$f1,$f1,$f0,$ef,$ee,$ee,$ed,$ec,$eb,$eb,$ea
	.byte $e9,$e8,$e7,$e6,$e6,$e5,$e4,$e3,$e2,$e1,$e0,$df,$de,$dd,$dc,$db
	.byte $da,$d9,$d8,$d7,$d6,$d5,$d4,$d3,$d2,$d0,$cf,$ce,$cd,$cc,$ca,$c9
	.byte $c8,$c6,$c5,$c4,$c2,$c1,$c0,$be,$bd,$bb,$ba,$b8,$b7,$b5,$b3,$b2
	.byte $b0,$ae,$ad,$ab,$a9,$a7,$a6,$a4,$a2,$a0,$9e,$9c,$9a,$98,$96,$94
	.byte $92,$90,$8e,$8c,$89,$87,$85,$83,$80,$7e,$7b,$79,$76,$74,$71,$6f
	.byte $6c,$69,$67,$64,$61,$5e,$5b,$58,$55,$52,$4f,$4c,$49,$46,$43,$3f
	.byte $3c,$38,$35,$31,$2e,$2a,$27,$23,$1f,$1b,$17,$13,$0f,$0b,$07,$03
planet_pos_h:
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$00,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
	.byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07

battle_palette_data:
	.byte $00, $00
	.byte $00, $00
	.byte $11, $01
	.byte $11, $01
	.byte $22, $02
	.byte $22, $02
	.byte $33, $03
	.byte $33, $03
	.byte $44, $04
	.byte $44, $04
	.byte $55, $05
	.byte $55, $05
	.byte $66, $06
	.byte $66, $06
	.byte $77, $07
	.byte $77, $07
	.byte $88, $08
	.byte $88, $08
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
	.byte $ee, $0e
	.byte $ff, $0f
	.byte $ff, $0f
	.byte $25, $01
	.byte $25, $01
	.byte $36, $01
	.byte $37, $02
	.byte $37, $02
	.byte $48, $02
	.byte $49, $02
	.byte $4a, $03
	.byte $5a, $03
	.byte $5b, $03
	.byte $5b, $03
	.byte $6c, $03
	.byte $6d, $04
	.byte $6e, $04
	.byte $7e, $04
	.byte $7f, $04
	.byte $8f, $05
	.byte $8f, $05
	.byte $8f, $05
	.byte $9f, $05
	.byte $9f, $06
	.byte $9f, $06
	.byte $af, $06
	.byte $af, $07
	.byte $af, $07
	.byte $bf, $07
	.byte $bf, $08
	.byte $bf, $08
	.byte $cf, $08
	.byte $cf, $09
	.byte $cf, $09
	.byte $cf, $09
	.byte $24, $05
	.byte $24, $06
	.byte $24, $06
	.byte $34, $06
	.byte $34, $07
	.byte $34, $07
	.byte $35, $07
	.byte $35, $08
	.byte $35, $08
	.byte $45, $08
	.byte $45, $09
	.byte $45, $09
	.byte $46, $09
	.byte $46, $09
	.byte $56, $0a
	.byte $56, $0a
	.byte $56, $0a
	.byte $56, $0b
	.byte $57, $0b
	.byte $67, $0b
	.byte $67, $0b
	.byte $67, $0c
	.byte $67, $0c
	.byte $67, $0c
	.byte $78, $0d
	.byte $78, $0d
	.byte $78, $0d
	.byte $78, $0e
	.byte $88, $0e
	.byte $89, $0e
	.byte $89, $0f
	.byte $99, $0f
	.byte $00, $00
	.byte $01, $00
	.byte $11, $01
	.byte $12, $01
	.byte $12, $01
	.byte $23, $02
	.byte $23, $02
	.byte $34, $03
	.byte $34, $03
	.byte $35, $03
	.byte $45, $04
	.byte $45, $04
	.byte $56, $05
	.byte $56, $05
	.byte $57, $05
	.byte $67, $06
	.byte $68, $06
	.byte $78, $07
	.byte $79, $07
	.byte $89, $08
	.byte $8a, $08
	.byte $9a, $09
	.byte $9b, $09
	.byte $ab, $0a
	.byte $ac, $0a
	.byte $bc, $0a
	.byte $bd, $0b
	.byte $cd, $0c
	.byte $ce, $0c
	.byte $de, $0d
	.byte $df, $0d
	.byte $ef, $0e
	.byte $46, $03
	.byte $46, $03
	.byte $56, $03
	.byte $56, $04
	.byte $57, $04
	.byte $57, $04
	.byte $67, $04
	.byte $68, $05
	.byte $68, $05
	.byte $78, $05
	.byte $79, $05
	.byte $79, $05
	.byte $89, $06
	.byte $8a, $06
	.byte $8a, $06
	.byte $9a, $06
	.byte $9a, $07
	.byte $9b, $07
	.byte $ab, $07
	.byte $ab, $08
	.byte $ac, $08
	.byte $ac, $08
	.byte $bc, $08
	.byte $bd, $09
	.byte $bd, $09
	.byte $cd, $09
	.byte $cd, $0a
	.byte $de, $0a
	.byte $de, $0a
	.byte $de, $0a
	.byte $ef, $0b
	.byte $ef, $0b
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
	.byte $00, $0d
end_of_battle_palette_data:
