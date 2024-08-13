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

VERA_PALETTE      = $1FA00
VERA_SPRITES      = $1FC00

; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

; === RAM addresses ===

SCROLLER_BUFFER_ADDRESS   = $8000  ; (158+1)*34 = 5406 bytes (= $151E, so rougly $1600 is ok) -> Note: the +1 is the extra column used to add a single column just before 'shifting' every pixel to the left
SHIFT_PIXEL_CODE_ADDRESS  = $7C00  ; 158*6 + rts = 949 bytes

SCROLLSWORD_RAM_ADDRESS   = $A000
SCROLL_COPY_CODE_RAM_ADDRESS = $A000


; === VRAM addresses ===

BITMAP_VRAM_ADDRESS   = $00000
SPRITES_VRAM_ADDRESS  = $10000  ; 10 sprites of 64x64 are used (40960 bytes)


; === Other constants ===

BITMAP_WIDTH = 320
BITMAP_HEIGHT = 200

SCROLLSWORD_RAM_BANK       = $20  ; This is 460x64 bytes (3.59 RAM banks -> 4 RAM banks)  - Note: the original image is 400x35, but we added 60 pixels of padding at the end
SCROLL_COPY_CODE_RAM_BANK  = $24  ; This is 17 RAM Banks of scroll copy code (actually 16.268 RAM banks)
NR_OF_SCROLL_COPY_CODE_BANKS = 17

; FIXME: we should change this!
; FIXME: we should change this!
; FIXME: we should change this!
INITIAL_SCROLL = 1
NR_OF_SCROLL_ITERATIONS = 460-INITIAL_SCROLL

.segment "SWORD_ZP": zeropage


LOAD_ADDRESS:
	.res 2
CODE_ADDRESS:
	.res 2
STORE_ADDRESS:
	.res 2
VRAM_ADDRESS:
	.res 3

SPRITE_SRC_VRAM_ADDR:
	.res 2

SCROLL_ITERATION:
	.res 2
CURRENT_SCROLLSWORD_BANK:
	.res 1

.segment "SWORD"
entry:
	DISABLE_SPRITES

	jsr setup_vera_for_layer0_bitmap
	jsr load_bitmap_into_vram

	jsr copy_palette_from_index_0

	PALETTE_FADE_FULL 1

	jsr generate_shift_by_one_pixel_code

	jsr load_scrollsword_into_banked_ram
	jsr load_scroll_copy_code_into_banked_ram


	jsr clear_initial_scroll_sword_slow
	jsr load_initial_scroll_sword_slow

	jsr load_sprite_data

	jsr setup_sprites

	MUSIC_SYNC $A4

	jsr do_scrolling

	MUSIC_SYNC $AC

	ldx #0
:   stz target_palette,x
	stz target_palette3,x
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

	DISABLE_SPRITES

	MUSIC_SYNC $B0

	rts

.proc do_scrolling
	; Setup ADDR0 HIGH and nibble-bit and increment (+1 byte)

	lda #<NR_OF_SCROLL_ITERATIONS
	sta SCROLL_ITERATION
	lda #>NR_OF_SCROLL_ITERATIONS
	sta SCROLL_ITERATION+1

	lda #<(SCROLLSWORD_RAM_ADDRESS+INITIAL_SCROLL*64)
	sta LOAD_ADDRESS
	lda #>(SCROLLSWORD_RAM_ADDRESS+INITIAL_SCROLL*64)
	sta LOAD_ADDRESS+1

	lda #SCROLLSWORD_RAM_BANK
	sta CURRENT_SCROLLSWORD_BANK

	stz jcarry
	stz jiffy_cnt
next_scroll_iteration:
	; pace ourselves to do 23.333... frames per second
	; this is done by a period 7 table of 2-3-2-3-2-3-3
	; frames per render
wait:
	jsr apply_palette_fade_step
	jsr apply_palette_fade_step2
	jsr apply_palette_fade_step3
	jsr apply_palette_fade_step4

	WAITVSYNC
	jsr flush_palette
	jsr flush_palette2
	jsr flush_palette3
	jsr flush_palette4

	jsr X16::Kernal::RDTIM
	sec
	sbc jiffy_cnt
	ldx jcarry
	cmp jtable,x
	bcc wait
	jsr X16::Kernal::RDTIM
	sta jiffy_cnt
	dec jcarry
	bpl :+
	lda #6
	sta jcarry
:

	lda #%00000100           ; DCSEL=2, ADDRSEL=0
	sta VERA_CTRL

	lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to +1 byte
	sta VERA_ADDR_BANK

	; Copying all scroll sword to VRAM

	ldy #SCROLL_COPY_CODE_RAM_BANK
next_scroll_copy_code_bank:

	sty RAM_BANK

	jsr SCROLL_COPY_CODE_RAM_ADDRESS

	iny
	cpy #SCROLL_COPY_CODE_RAM_BANK+NR_OF_SCROLL_COPY_CODE_BANKS
	bne next_scroll_copy_code_bank



	; FIXME: WARNING: if no more scroll sword is left, we need to fill with zeros!

	; We load the 159th column into the buffer

	lda CURRENT_SCROLLSWORD_BANK
	sta RAM_BANK

	ldy #0
scroll_sword_single_column_copy_next_y:
	lda (LOAD_ADDRESS), y
	sta SCROLLER_BUFFER_ADDRESS+158*34, y  ; 158 is the 159th pixel from the left
	iny
	cpy #34
	bne scroll_sword_single_column_copy_next_y

	; We increment our load address into the scroll sword data
	clc
	lda LOAD_ADDRESS
	adc #64
	sta LOAD_ADDRESS
	lda LOAD_ADDRESS+1
	adc #0
	sta LOAD_ADDRESS+1

	; Check if you reached the end of our RAM bank (>= $C000)
	cmp #$C0
	bne scroll_bank_is_ok

	; We have reached the end of a RAM bank so we switch to the next one and reset our address

	inc CURRENT_SCROLLSWORD_BANK

	lda #<SCROLLSWORD_RAM_ADDRESS
	sta LOAD_ADDRESS
	lda #>SCROLLSWORD_RAM_ADDRESS
	sta LOAD_ADDRESS+1

scroll_bank_is_ok:


	; We 'shift' all pixels to the left in the buffer (34 rows)
	ldy #0
shift_nex_row:
	jsr SHIFT_PIXEL_CODE_ADDRESS
	iny
	cpy #34
	bne shift_nex_row

	sec
	lda SCROLL_ITERATION
	sbc #1
	sta SCROLL_ITERATION
	lda SCROLL_ITERATION+1
	sbc #0
	sta SCROLL_ITERATION+1

	; check for music trigger to exit scroller
	; if we hit it, we start our fadeout
	; and exit the scroller after 16 fade steps
	lda syncval
	cmp #$AC
	bcc no_fade_yet
	lda fadeout
	cmp #16
	beq setup_fade

fade_cont:
	dec fadeout
	beq done

no_fade_yet:
	lda SCROLL_ITERATION
	ora SCROLL_ITERATION+1
	jne next_scroll_iteration

done:
	; We are done, exiting

	lda #%00000000
	sta VERA_FX_CTRL         ; back to 8-bit mode

	lda #%00000000           ; DCSEL=0, ADDRSEL=0
	sta VERA_CTRL

	rts

	; set it up to fade the entire palette to black
setup_fade:
	ldx #128
:	stz target_palette-128,x
	stz target_palette2-128,x
	stz target_palette3-128,x
	stz target_palette4-128,x
	inx
	bne :-

	; turn off FX to do palette stuff

	lda #%00000100           ; DCSEL=2, ADDRSEL=0
	sta VERA_CTRL

	stz VERA_FX_CTRL

	stz VERA_CTRL

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

	; set fx back up
	lda #%00000100           ; DCSEL=2, ADDRSEL=0
	sta VERA_CTRL

	lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to +1 byte
	sta VERA_ADDR_BANK

	bra fade_cont
	; some local variables
	; and a small table :)
fadeout:
	.byte 16
jiffy_cnt:
	.byte 0
jcarry:
	.byte 0
jtable:
	.byte 3,3,2,3,2,3,2
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

.proc load_bitmap_into_vram
	LOADFILE "WATER.DAT", 0, .loword(BITMAP_VRAM_ADDRESS), ^BITMAP_VRAM_ADDRESS
	rts
.endproc

.proc copy_palette_from_index_0

	; Copy 2 times 128 colors

	ldy #0
next_packed_color_0:
	lda palette_data, y
	sta target_palette, y
	iny
	bne next_packed_color_0

	ldy #0
next_packed_color_256:
	lda palette_data+256, y
	sta target_palette3, y
	iny
	bne next_packed_color_256

	lda #0
	jsr setup_palette_fade
	lda #64
	jsr setup_palette_fade2
	lda #128
	jsr setup_palette_fade3
	lda #192
	jsr setup_palette_fade4

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

	ldx #0                 ; counts nr of copy instructions (we need to do 158 copies)
next_copy_instruction:

	; Use the previous LOAD_ADDRESS as the new STORE_ADDRESS
	lda LOAD_ADDRESS
	sta STORE_ADDRESS
	lda LOAD_ADDRESS+1
	sta STORE_ADDRESS+1

	; Increment the LOAD_ADDRESS with 34
	clc
	lda LOAD_ADDRESS
	adc #34
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
	cpx #158
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


.proc load_scrollsword_into_banked_ram
	LOADFILE "SCROLLSWORD.DAT", SCROLLSWORD_RAM_BANK, SCROLLSWORD_RAM_ADDRESS
	rts
.endproc

.proc load_scroll_copy_code_into_banked_ram
	LOADFILE "SCROLLCOPYW.DAT", SCROLL_COPY_CODE_RAM_BANK, SCROLL_COPY_CODE_RAM_ADDRESS
	rts
.endproc

.proc clear_initial_scroll_sword_slow

	lda #<SCROLLER_BUFFER_ADDRESS
	sta STORE_ADDRESS
	lda #>SCROLLER_BUFFER_ADDRESS
	sta STORE_ADDRESS+1

	ldx #0
clear_scroll_sword_next_column:

	lda #0  ; We clear the buffer
	ldy #0
clear_scroll_sword_next_pixel:

	sta (STORE_ADDRESS), y
	iny
	cpy #34
	bne clear_scroll_sword_next_pixel

	clc
	lda STORE_ADDRESS
	adc #34
	sta STORE_ADDRESS
	lda STORE_ADDRESS+1
	adc #0
	sta STORE_ADDRESS+1

	inx
	cpx #158
	bne clear_scroll_sword_next_column


	rts
.endproc

.proc load_initial_scroll_sword_slow

	lda #SCROLLSWORD_RAM_BANK
	sta RAM_BANK

	lda #<SCROLLSWORD_RAM_ADDRESS
	sta LOAD_ADDRESS
	lda #>SCROLLSWORD_RAM_ADDRESS
	sta LOAD_ADDRESS+1

	lda #<(SCROLLER_BUFFER_ADDRESS+(158-INITIAL_SCROLL)*34)
	sta STORE_ADDRESS
	lda #>(SCROLLER_BUFFER_ADDRESS+(158-INITIAL_SCROLL)*34)
	sta STORE_ADDRESS+1

	ldx #0
initial_copy_scroll_sword_next_column:

	ldy #0
initial_copy_scroll_sword_next_pixel:

	lda (LOAD_ADDRESS), y
	sta (STORE_ADDRESS), y
	iny
	cpy #34
	bne initial_copy_scroll_sword_next_pixel

	; Increment LOAD and STORE ADDRESS (with 64 and 34 respectively)

	clc
	lda LOAD_ADDRESS
	adc #64
	sta LOAD_ADDRESS
	lda LOAD_ADDRESS+1
	adc #0
	sta LOAD_ADDRESS+1

	clc
	lda STORE_ADDRESS
	adc #34
	sta STORE_ADDRESS
	lda STORE_ADDRESS+1
	adc #0
	sta STORE_ADDRESS+1

	inx
	cpx #INITIAL_SCROLL
	bne initial_copy_scroll_sword_next_column


	stz RAM_BANK

	rts
.endproc

.proc load_sprite_data

	; Setting up ADDR1 first to SPRITES_VRAM_ADDRESS

	lda #%00000001           ; DCSEL=0, ADDRSEL=1
	sta VERA_CTRL

	lda #(%00010000 | ^SPRITES_VRAM_ADDRESS)      ; setting auto-increment value to +1 byte, nibble-address bit to 1
	sta VERA_ADDR_BANK

	lda #>SPRITES_VRAM_ADDRESS
	sta VERA_ADDR_HIGH

	lda #<SPRITES_VRAM_ADDRESS
	sta VERA_ADDR_LOW

	lda #%00000000           ; DCSEL=0, ADDRSEL=0
	sta VERA_CTRL


	; iterating over all 10 sprites

	ldx #0

load_next_sprite:

	lda sprite_src_addr_l, x
	sta SPRITE_SRC_VRAM_ADDR
	lda sprite_src_addr_h, x
	sta SPRITE_SRC_VRAM_ADDR+1

	jsr copy_sprite_data_slow

	inx

	cpx #10
	bne load_next_sprite

	rts

copy_sprite_data_slow:

	phx

	; Starting at palette VRAM address

	lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to 1
	sta VERA_ADDR_BANK

	ldy #0
next_sprite_row:

	lda SPRITE_SRC_VRAM_ADDR
	sta VERA_ADDR_LOW
	lda SPRITE_SRC_VRAM_ADDR+1
	sta VERA_ADDR_HIGH

	ldx #0
next_sprite_pixel:

.repeat 8
	lda VERA_DATA0
	sta VERA_DATA1
.endrepeat

	inx
	cpx #64/8   ; 64 pixels (and we are doing 8 pixel each iteration
	bne next_sprite_pixel

	clc
	lda SPRITE_SRC_VRAM_ADDR
	adc #<320
	sta SPRITE_SRC_VRAM_ADDR
	lda SPRITE_SRC_VRAM_ADDR+1
	adc #>320
	sta SPRITE_SRC_VRAM_ADDR+1

	iny
	cpy #64
	bne next_sprite_row

	plx

	rts
.endproc

.proc setup_sprites

	lda #(%00010000 | ^VERA_SPRITES)      ;  setting auto-increment value to 1
	sta VERA_ADDR_BANK

	lda #<(VERA_SPRITES)
	sta VERA_ADDR_LOW
	lda #>(VERA_SPRITES)
	sta VERA_ADDR_HIGH

	ldx #0

setup_next_sprite:

	; TODO: for performance we could skip writing certain sprite attibutes and just read them 

	; Address (12:5)
	lda sprite_address_l, x
	sta VERA_DATA0

	; Mode,	-	, Address (16:13)
	lda sprite_address_h, x
	sta VERA_DATA0

	; X (7:0)
	lda sprite_x_pos_l, x
	sta VERA_DATA0

	; X (9:8)
	lda sprite_x_pos_h, x
	sta VERA_DATA0

	; Y (7:0)
	lda sprite_y_pos_l, x
	sta VERA_DATA0

	; Y (9:8)
	lda sprite_y_pos_h, x
	sta VERA_DATA0

	; Collision mask	Z-depth	V-flip	H-flip
	lda #%00000100 ; Sprite between background and layer 0
	sta VERA_DATA0

	; Sprite height,	Sprite width,	Palette offset
	lda #%11110000 ; 64x64, 0*16 = 0 palette offset
	sta VERA_DATA0

	inx

	cpx #10
	bne setup_next_sprite

	rts
.endproc


sprite_address_l:  ; Addres bits: 12:5  -> starts at $10000, then $11000: so first is %00000000, second is %10000000 = $00 and $80
	.byte $00, $80, $00, $80, $00, $80, $00, $80, $00, $80
sprite_address_h:  ; Addres bits: 16:13  -> starts at $10000, so first is %10001000 (mode = 8bpp, $10000) = $88
	.byte $88, $88, $89, $89, $8A, $8A, $8B, $8B, $8C, $8C

; This part is *generated*
sprite_x_pos_l:
	.byte $00, $40, $80, $00, $40, $80, $c0, $d6, $c0, $00
sprite_x_pos_h:
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $01
sprite_y_pos_l:
	.byte $00, $00, $00, $40, $40, $40, $10, $48, $88, $88
sprite_y_pos_h:
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
sprite_src_addr_l:
	.byte $00, $40, $80, $00, $40, $80, $c0, $d6, $c0, $00
sprite_src_addr_h:
	.byte $00, $00, $00, $50, $50, $50, $14, $5a, $aa, $ab


palette_data:
	.byte $00, $00
	.byte $6b, $06
	.byte $49, $04
	.byte $7c, $07
	.byte $28, $02
	.byte $28, $02
	.byte $9c, $09
	.byte $39, $03
	.byte $27, $02
	.byte $38, $03
	.byte $be, $0b
	.byte $9c, $09
	.byte $7c, $07
	.byte $18, $01
	.byte $49, $04
	.byte $ae, $0a
	.byte $be, $0b
	.byte $8b, $08
	.byte $7a, $07
	.byte $79, $07
	.byte $ad, $0a
	.byte $18, $01
	.byte $38, $03
	.byte $6b, $06
	.byte $38, $03
	.byte $6c, $06
	.byte $69, $06
	.byte $47, $04
	.byte $5b, $05
	.byte $69, $06
	.byte $ad, $0a
	.byte $68, $06
	.byte $7b, $07
	.byte $49, $04
	.byte $ad, $0a
	.byte $28, $02
	.byte $17, $01
	.byte $cf, $0c
	.byte $46, $04
	.byte $df, $0d
	.byte $af, $0a
	.byte $29, $02
	.byte $58, $05
	.byte $9d, $09
	.byte $09, $00
	.byte $17, $01
	.byte $7c, $07
	.byte $27, $02
	.byte $8d, $08
	.byte $48, $04
	.byte $58, $05
	.byte $57, $05
	.byte $5a, $05
	.byte $9e, $09
	.byte $36, $03
	.byte $07, $00
	.byte $39, $03
	.byte $ae, $0a
	.byte $8c, $08
	.byte $9c, $09
	.byte $6b, $06
	.byte $6a, $06
	.byte $17, $01
	.byte $bf, $0b
	.byte $7b, $07
	.byte $17, $01
	.byte $bf, $0b
	.byte $ae, $0a
	.byte $9d, $09
	.byte $7a, $07
	.byte $35, $03
	.byte $8c, $08
	.byte $37, $03
	.byte $59, $05
	.byte $27, $02
	.byte $59, $05
	.byte $9d, $09
	.byte $06, $00
	.byte $cf, $0c
	.byte $07, $00
	.byte $38, $03
	.byte $47, $04
	.byte $16, $01
	.byte $69, $06
	.byte $23, $02
	.byte $16, $01
	.byte $24, $02
	.byte $58, $05
	.byte $ae, $0a
	.byte $48, $04
	.byte $8c, $08
	.byte $48, $04
	.byte $8c, $08
	.byte $7b, $07
	.byte $7b, $07
	.byte $26, $02
	.byte $37, $03
	.byte $9e, $09
	.byte $8b, $08
	.byte $6a, $06
	.byte $cf, $0c
	.byte $6a, $06
	.byte $27, $02
	.byte $47, $04
	.byte $59, $05
	.byte $25, $02
	.byte $36, $03
	.byte $26, $02
	.byte $37, $03
	.byte $16, $01
	.byte $af, $0a
	.byte $06, $00
	.byte $16, $01
	.byte $bf, $0b
	.byte $47, $04
	.byte $9d, $09
	.byte $36, $03
	.byte $59, $05
	.byte $25, $02
	.byte $48, $04
	.byte $7d, $07
	.byte $26, $02
	.byte $15, $01
	.byte $4a, $04
	.byte $6a, $06
	.byte $bf, $0b
	.byte $08, $00
	.byte $37, $03
	.byte $8e, $08
	.byte $13, $01
	.byte $8b, $08
	.byte $15, $01
	.byte $12, $01
	.byte $26, $02
	.byte $af, $0a
	.byte $58, $05
	.byte $15, $01
	.byte $36, $03
	.byte $14, $01
	.byte $6c, $06
	.byte $05, $00
	.byte $25, $02
	.byte $4a, $04
	.byte $9e, $09
	.byte $08, $00
	.byte $18, $01
	.byte $13, $01
	.byte $15, $01
	.byte $14, $01
	.byte $39, $03
	.byte $25, $02
	.byte $06, $00
	.byte $07, $00
	.byte $8d, $08
	.byte $05, $00
	.byte $05, $00
	.byte $03, $00
	.byte $07, $00
	.byte $04, $00
	.byte $24, $02
	.byte $5b, $05
	.byte $04, $00
	.byte $04, $00
	.byte $02, $00
	.byte $06, $00
	.byte $14, $01
	.byte $11, $01
	.byte $00, $00
	.byte $01, $00
	.byte $02, $00
	.byte $29, $02
	.byte $04, $00
	.byte $01, $00
	.byte $12, $01
	.byte $02, $00
	.byte $05, $00
	.byte $00, $00
	.byte $03, $00
	.byte $14, $01
	.byte $01, $00
	.byte $12, $01
	.byte $00, $00
	.byte $03, $00
	.byte $13, $01
	.byte $03, $00
	.byte $01, $00
	.byte $13, $01
	.byte $02, $00
	.byte $19, $01
	.byte $08, $00
	.byte $09, $00
	.byte $df, $0d
	.byte $fa, $0f
	.byte $f9, $0f
	.byte $f7, $0f
	.byte $e6, $0f
	.byte $e5, $0f
	.byte $d3, $0f
	.byte $c2, $0e
	.byte $b2, $0e
	.byte $a1, $0d
	.byte $90, $0d
	.byte $70, $0c
	.byte $60, $0c
	.byte $50, $0b
	.byte $40, $0a
	.byte $40, $09
	.byte $30, $08
	.byte $20, $08
	.byte $20, $07
	.byte $10, $06
	.byte $00, $05
	.byte $00, $05
	.byte $00, $04
	.byte $00, $03
	.byte $00, $02
	.byte $00, $03
	.byte $22, $04
	.byte $33, $04
	.byte $44, $05
	.byte $44, $05
	.byte $56, $06
	.byte $66, $06
	.byte $77, $07
	.byte $78, $08
	.byte $89, $08
	.byte $9a, $09
	.byte $ab, $09
	.byte $bc, $0a
	.byte $cc, $0b
	.byte $dd, $0b
	.byte $de, $0c
	.byte $fb, $0b
	.byte $ea, $0a
	.byte $d8, $08
	.byte $c7, $07
	.byte $b6, $06
	.byte $a5, $05
	.byte $94, $04
	.byte $83, $03
	.byte $72, $02
	.byte $61, $01
	.byte $51, $01
	.byte $10, $05
	.byte $31, $06
	.byte $31, $07
	.byte $42, $07
	.byte $52, $08
	.byte $53, $08
	.byte $64, $09
	.byte $74, $0a
	.byte $85, $0a
	.byte $86, $0b
	.byte $97, $0b
	.byte $a8, $0c
	.byte $b9, $0d
end_of_palette_data:
