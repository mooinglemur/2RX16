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


.macpack longbranch


.include "x16.inc"
.include "macros.inc"

RAM_BANK = X16::Reg::RAMBank
ROM_BANK = X16::Reg::ROMBank


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

SETNAM            = $FFBD  ; set filename
SETLFS            = $FFBA  ; Set LA, FA, and SA
LOAD              = $FFD5  ; Load a file into main memory or VRAM

VERA_PALETTE      = $1FA00
VERA_SPRITES      = $1FC00

BITMAP_VRAM_ADDRESS   = $00000

BITMAP_WIDTH = 320
BITMAP_HEIGHT = 200

SCROLLTEXT_RAM_BANK        = $21  ; This is 640x32 bytes
SCROLL_COPY_CODE_RAM_BANK  = $24  ; This is 13 RAM Banks of scroll copy code (actually 12.06 RAM banks)
NR_OF_SCROLL_COPY_CODE_BANKS = 13
; FIXME: we should change this!
INITIAL_SCROLL = 100
NR_OF_SCROLL_ITERATIONS = 640-INITIAL_SCROLL


.segment "SCROLLER_ZP": zeropage
LOAD_ADDRESS: .res 2
CODE_ADDRESS: .res 2
STORE_ADDRESS: .res 2
VRAM_ADDRESS: .res 3

SCROLL_ITERATION: .res 2
CURRENT_SCROLLTEXT_BANK: .res 1

.segment "SCROLLER_BSS"
SCROLLER_BUFFER_ADDRESS: .res 7378
SHIFT_PIXEL_CODE_ADDRESS: .res 1423

SCROLLTEXT_RAM_ADDRESS    = $A000
SCROLL_COPY_CODE_RAM_ADDRESS = $A000

.segment "SCROLLER"
entry:
	; zero the entire palette
	VERA_SET_ADDR (Vera::VRAM_palette), 1
	ldx #128
:   stz target_palette-128,x
	stz target_palette2-128,x
	stz target_palette3-128,x
	stz target_palette4-128,x
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	stz Vera::Reg::Data0
	inx
	bne :-

	; begin "forest" subroutines

    jsr generate_shift_by_one_pixel_code
    
    jsr setup_vera_for_layer0_bitmap

    jsr copy_palette_from_index_0
    jsr load_bitmap_into_vram
    
    jsr load_scrolltext_into_banked_ram
    jsr load_scroll_copy_code_into_banked_ram

    jsr clear_initial_scroll_text_slow
    jsr load_initial_scroll_text_slow
    jsr do_scrolling

	MUSIC_SYNC $60 ; needs to move to do_scrolling

	ldx #128
:   stz target_palette-128,x
	stz target_palette2-128,x
	stz target_palette3-128,x
	stz target_palette4-128,x
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


.proc clear_initial_scroll_text_slow
    lda #<SCROLLER_BUFFER_ADDRESS
    sta STORE_ADDRESS
    lda #>SCROLLER_BUFFER_ADDRESS
    sta STORE_ADDRESS+1

    ldx #0
clear_scroll_text_next_column:

    lda #$80  ; We set bit7 to 1
    ldy #0
clear_scroll_text_next_pixel:    

    sta (STORE_ADDRESS), y
    iny
    cpy #31
    bne clear_scroll_text_next_pixel
    
    clc
    lda STORE_ADDRESS
    adc #31
    sta STORE_ADDRESS
    lda STORE_ADDRESS+1
    adc #0
    sta STORE_ADDRESS+1
    
    inx
    cpx #237
    bne clear_scroll_text_next_column

    rts
.endproc


.proc load_initial_scroll_text_slow

    lda #SCROLLTEXT_RAM_BANK
    sta RAM_BANK

    lda #<SCROLLTEXT_RAM_ADDRESS
    sta LOAD_ADDRESS
    lda #>SCROLLTEXT_RAM_ADDRESS
    sta LOAD_ADDRESS+1
    
    lda #<(SCROLLER_BUFFER_ADDRESS+(237-INITIAL_SCROLL)*31)
    sta STORE_ADDRESS
    lda #>(SCROLLER_BUFFER_ADDRESS+(237-INITIAL_SCROLL)*31)
    sta STORE_ADDRESS+1
    
    ldx #0
initial_copy_scroll_text_next_column:

    ldy #0
initial_copy_scroll_text_next_pixel:    

    lda (LOAD_ADDRESS), y
    sta (STORE_ADDRESS), y
    iny
    cpy #31
    bne initial_copy_scroll_text_next_pixel
    
    ; Increment LOAD and STORE ADDRESS (with 32 and 31 respectively)
    
    clc
    lda LOAD_ADDRESS
    adc #32
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    clc
    lda STORE_ADDRESS
    adc #31
    sta STORE_ADDRESS
    lda STORE_ADDRESS+1
    adc #0
    sta STORE_ADDRESS+1
    
    inx
    cpx #INITIAL_SCROLL
    bne initial_copy_scroll_text_next_column
    

    stz RAM_BANK
    
    rts
.endproc


.proc do_scrolling
    ; Setup ADDR0 HIGH and nibble-bit and increment (+1 byte) and set to 4-bit mode
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to +1 byte, nibble-address bit to 1
    sta VERA_ADDR_BANK

    lda #%00000100
    sta VERA_FX_CTRL         ; 4-bit mode


    lda #<NR_OF_SCROLL_ITERATIONS
    sta SCROLL_ITERATION
    lda #>NR_OF_SCROLL_ITERATIONS
    sta SCROLL_ITERATION+1
    
    lda #<(SCROLLTEXT_RAM_ADDRESS+INITIAL_SCROLL*32)
    sta LOAD_ADDRESS
    lda #>(SCROLLTEXT_RAM_ADDRESS+INITIAL_SCROLL*32)
    sta LOAD_ADDRESS+1
    
    lda #SCROLLTEXT_RAM_BANK
    sta CURRENT_SCROLLTEXT_BANK

next_scroll_iteration:

    ; Copying all scroll text to VRAM
    
    ldy #SCROLL_COPY_CODE_RAM_BANK
next_scroll_copy_code_bank:

    sty RAM_BANK
    
    jsr SCROLL_COPY_CODE_RAM_ADDRESS
    
    iny
    cpy #SCROLL_COPY_CODE_RAM_BANK+NR_OF_SCROLL_COPY_CODE_BANKS
    bne next_scroll_copy_code_bank
    

    
    ; FIXME: WARNING: if no more scroll text is left, we need to fill with zeros!
        
    ; We load the 238th column into the buffer
    
    lda CURRENT_SCROLLTEXT_BANK
    sta RAM_BANK
    
    ldy #0
scroll_text_single_column_copy_next_y:
    lda (LOAD_ADDRESS), y
    sta SCROLLER_BUFFER_ADDRESS+237*31, y  ; 237 is the 238th pixel from the left
    iny
    cpy #31
    bne scroll_text_single_column_copy_next_y

    ; We increment our load address into the scroll text data
    clc
    lda LOAD_ADDRESS
    adc #32
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    ; Check if you reached the end of our RAM bank (>= $C000)
    cmp #$C0
    bne scroll_bank_is_ok
    
    ; We have reached the end of a RAM bank so we switch to the next one and reset our address
    
    inc CURRENT_SCROLLTEXT_BANK
    
    lda #<SCROLLTEXT_RAM_ADDRESS
    sta LOAD_ADDRESS
    lda #>SCROLLTEXT_RAM_ADDRESS
    sta LOAD_ADDRESS+1
    
scroll_bank_is_ok:
    

    ; We 'shift' all pixels to the left in the buffer (31 rows)
    ldy #0
shift_nex_row:
    jsr SHIFT_PIXEL_CODE_ADDRESS
    iny
    cpy #31
    bne shift_nex_row

    sec
    lda SCROLL_ITERATION
    sbc #1
    sta SCROLL_ITERATION
    lda SCROLL_ITERATION+1
    sbc #0
    sta SCROLL_ITERATION+1
    
    lda SCROLL_ITERATION
    bne next_scroll_iteration
    lda SCROLL_ITERATION+1
    bne next_scroll_iteration
    
    ; We are done, exiting

    lda #%00000000
    sta VERA_FX_CTRL         ; back to 8-bit mode

    lda #%00000000           ; DCSEL=0, ADDRSEL=0
    sta VERA_CTRL

    ; Resetting to RAM_BANK zero (not sure if this is needed)
    stz RAM_BANK

    rts
.endproc

.proc setup_vera_for_layer0_bitmap

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
.endproc

.proc copy_palette_from_index_0

    ; Starting at palette VRAM address
    
    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    ; We start at color index 16 of the palette (we preserve the first 16 default VERA colors)
    lda #<(VERA_PALETTE)
    sta VERA_ADDR_LOW
    lda #>(VERA_PALETTE)
    sta VERA_ADDR_HIGH


    ; Copy 2 times 128 colors

    ldy #0
next_packed_color_0:
    lda palette_data, y
    sta VERA_DATA0
    iny
    bne next_packed_color_0

    ldy #0
next_packed_color_256:
    lda palette_data+256, y
    sta VERA_DATA0
    iny
    bne next_packed_color_256
    
    rts
.endproc

.proc load_bitmap_into_vram

	LOADFILE "FOREST.DAT", 0, .loword(BITMAP_VRAM_ADDRESS), <(.hiword(BITMAP_VRAM_ADDRESS))

    rts
.endproc


.proc load_scrolltext_into_banked_ram

	LOADFILE "SCROLLTEXT.DAT", SCROLLTEXT_RAM_BANK, SCROLLTEXT_RAM_ADDRESS

    rts
.endproc


.proc load_scroll_copy_code_into_banked_ram

	LOADFILE "SCROLLCOPY.DAT", SCROLL_COPY_CODE_RAM_BANK, SCROLL_COPY_CODE_RAM_ADDRESS

    rts
.endproc

.proc generate_shift_by_one_pixel_code

    lda #<SHIFT_PIXEL_CODE_ADDRESS
    sta CODE_ADDRESS
    lda #>SHIFT_PIXEL_CODE_ADDRESS
    sta CODE_ADDRESS+1
    
    lda #<SCROLLER_BUFFER_ADDRESS
    sta LOAD_ADDRESS
    lda #>SCROLLER_BUFFER_ADDRESS
    sta LOAD_ADDRESS+1
    
    ldy #0                 ; generated code byte counter
    
    ldx #0                 ; counts nr of copy instructions (we need to do 237 copies)
next_copy_instruction:

    ; Use the previous LOAD_ADDRESS as the new STORE_ADDRESS
    lda LOAD_ADDRESS
    sta STORE_ADDRESS
    lda LOAD_ADDRESS+1
    sta STORE_ADDRESS+1

    ; Increment the LOAD_ADDRESS with 31
    clc
    lda LOAD_ADDRESS
    adc #31
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    adc #0
    sta LOAD_ADDRESS+1

    ; -- lda $LOAD_ADDRESS, y
    lda #$B9               ; lda ...., y
    jsr add_code_byte
    
    lda LOAD_ADDRESS       ; LOAD_ADDRESS
    jsr add_code_byte
    
    lda LOAD_ADDRESS+1     ; LOAD_ADDRESS+1
    jsr add_code_byte

    ; -- sta $STORE_ADDRESS, y
    lda #$99               ; sta ...., y
    jsr add_code_byte

    lda STORE_ADDRESS      ; STORE_ADDRESS
    jsr add_code_byte
    
    lda STORE_ADDRESS+1    ; STORE_ADDRESS+1
    jsr add_code_byte

    inx
    cpx #237
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
.endproc


; ==== DATA ====

palette_data:
  .byte $00, $00
  .byte $02, $00
  .byte $13, $01
  .byte $24, $01
  .byte $25, $02
  .byte $36, $02
  .byte $47, $02
  .byte $48, $03
  .byte $58, $03
  .byte $69, $04
  .byte $7a, $04
  .byte $7c, $05
  .byte $8d, $05
  .byte $9f, $06
  .byte $9f, $07
  .byte $af, $07
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $bf, $08
  .byte $ff, $0f
  .byte $ff, $0f
  .byte $11, $02
  .byte $12, $02
  .byte $21, $02
  .byte $21, $01
  .byte $21, $01
  .byte $31, $01
  .byte $31, $01
  .byte $31, $01
  .byte $41, $01
  .byte $41, $01
  .byte $41, $01
  .byte $32, $01
  .byte $32, $01
  .byte $42, $01
  .byte $22, $01
  .byte $21, $01
  .byte $20, $01
  .byte $20, $00
  .byte $30, $00
  .byte $30, $01
  .byte $30, $01
  .byte $40, $00
  .byte $30, $00
  .byte $20, $00
  .byte $21, $00
  .byte $20, $00
  .byte $10, $00
  .byte $10, $00
  .byte $00, $00
  .byte $00, $01
  .byte $10, $01
  .byte $11, $01
  .byte $11, $01
  .byte $11, $01
  .byte $11, $01
  .byte $11, $01
  .byte $12, $00
  .byte $12, $00
  .byte $02, $00
  .byte $43, $04
  .byte $43, $04
  .byte $43, $04
  .byte $43, $04
  .byte $33, $04
  .byte $32, $04
  .byte $32, $03
  .byte $33, $03
  .byte $32, $03
  .byte $32, $03
  .byte $32, $03
  .byte $22, $03
  .byte $22, $02
  .byte $32, $02
  .byte $32, $02
  .byte $42, $02
  .byte $42, $02
  .byte $41, $02
  .byte $13, $00
  .byte $02, $00
  .byte $12, $00
  .byte $10, $00
  .byte $14, $00
  .byte $13, $00
  .byte $14, $01
  .byte $23, $01
  .byte $23, $01
  .byte $22, $00
  .byte $11, $00
  .byte $11, $00
  .byte $10, $00
  .byte $00, $00
  .byte $00, $00
  .byte $01, $00
  .byte $01, $00
  .byte $01, $00
  .byte $02, $00
  .byte $10, $01
  .byte $20, $01
  .byte $21, $01
  .byte $10, $00
  .byte $10, $00
  .byte $10, $00
  .byte $00, $00
  .byte $00, $00
  .byte $10, $00
  .byte $00, $00
  .byte $00, $00
  .byte $20, $00
  .byte $41, $00
  .byte $41, $00
  .byte $51, $01
  .byte $51, $01
  .byte $62, $02
  .byte $52, $03
  .byte $33, $03
  .byte $ff, $0f
  .byte $02, $00
  .byte $13, $01
  .byte $24, $01
  .byte $25, $02
  .byte $36, $02
  .byte $47, $02
  .byte $48, $03
  .byte $58, $03
  .byte $69, $04
  .byte $7a, $04
  .byte $7c, $05
  .byte $8d, $05
  .byte $9f, $06
  .byte $9f, $07
  .byte $af, $07
  .byte $bf, $08
  .byte $01, $00
  .byte $11, $01
  .byte $23, $02
  .byte $23, $03
  .byte $34, $03
  .byte $35, $04
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $11, $01
  .byte $23, $02
  .byte $23, $03
  .byte $34, $03
  .byte $35, $04
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $ad, $0b
  .byte $23, $02
  .byte $23, $03
  .byte $34, $03
  .byte $35, $04
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $ad, $0b
  .byte $bd, $0c
  .byte $23, $03
  .byte $34, $03
  .byte $35, $04
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $ad, $0b
  .byte $bd, $0c
  .byte $be, $0c
  .byte $34, $03
  .byte $35, $04
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $ad, $0b
  .byte $bd, $0c
  .byte $be, $0c
  .byte $cf, $0d
  .byte $35, $04
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $ad, $0b
  .byte $bd, $0c
  .byte $be, $0c
  .byte $cf, $0d
  .byte $df, $0e
  .byte $45, $04
  .byte $46, $05
  .byte $47, $06
  .byte $57, $06
  .byte $58, $07
  .byte $69, $07
  .byte $79, $08
  .byte $8b, $09
  .byte $8b, $0a
  .byte $9c, $0a
  .byte $ad, $0b
  .byte $bd, $0c
  .byte $be, $0c
  .byte $cf, $0d
  .byte $df, $0e
  .byte $df, $0e
end_of_palette_data:
