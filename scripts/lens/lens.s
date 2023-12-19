; == Very crude PoC of a 256x192px bitmap with a lens effect  ==

; To build: cl65 -t cx16 -o LENS.PRG lens.s
; To run: x16emu.exe -prg LENS.PRG -run

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

VERA_PALETTE      = $1FA00
VERA_SPRITES      = $1FC00
 


; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01


LOAD_ADDRESS              = $30 ; 31
CODE_ADDRESS              = $32 ; 33
STORE_ADDRESS             = $34 ; 35
VRAM_ADDRESS              = $36 ; 37 ; 38
LENS_VRAM_ADDRESS         = $39 ; 3A ; 3B

LENS_POS_ADDRESS          = $3E ; 3F

LENS_X_POS                = $40 ; 41
LENS_Y_POS                = $42 ; 43
Z_DEPTH_BIT               = $44
QUADRANT                  = $45

DWN_RAM_BANK              = $4A
DWN_IDX                   = $4B

UPL_RAM_BANK              = $4C
UPL_IDX                   = $4D
UPL_QUADRANT              = $4E

LENS_VRAM_BANK            = $4F

COSINE_OF_ANGLE           = $51 ; 52
SINE_OF_ANGLE             = $53 ; 53

; === RAM addresses ===


BITMAP_QUADRANT_BUFFER    = $6000  ; HALF_LENS_WIDTH * HALF_LENS_HEIGHT bytes = 3068 bytes (= $BFC, so $C00 is ok)
LENS_POSITIONS_ADDRESS    = $6C00  ; around 350? (30 fps) frames of 4 bytes of positions (X and Y each 2 bytes) =~ 1400 bytes (so $600 is enough?)
Y_TO_ADDRESS_LOW          = $7600
Y_TO_ADDRESS_HIGH         = $7700
Y_TO_ADDRESS_BANK         = $7800  ; when Y is positive, BANK is always 0 (so technically we dont need this) 
NEG_Y_TO_ADDRESS_LOW      = $7900
NEG_Y_TO_ADDRESS_HIGH     = $7A00
NEG_Y_TO_ADDRESS_BANK     = $7B00
DOWNLOAD_RAM_ADDRESS      = $A000
UPLOAD_RAM_ADDRESS        = $A000

; === VRAM addresses ===

BITMAP_VRAM_ADDRESS   = $01000   ; We need 11 pixel rows of room above/below the bitmap, so we start at $01000 (=4096). This is 12.8 pixel rows.
SPRITES_VRAM_ADDRESS  = $12000   ; if you CHANGE this you also have to change quadrant_addr0_high_sprite/quadrant_addr0_low_sprite!!


; === Other constants ===

BITMAP_WIDTH = 256
BITMAP_HEIGHT = 192

HALF_LENS_WIDTH = 59            ; 117 total width, 1 pixel overlapping so 117 // 2 + 1 = 59 (or 118 // 2 if you will)
HALF_LENS_HEIGHT = 52           ; 103 total height, 1 pixel overlapping so 103 // 2 + 1 = 52 (or 104 // 2 if you will)

DOWNLOAD_RAM_BANK         = $01 ; 02
UPLOAD_RAM_BANK           = $03 ; 04; 05;   06 ; 07; 08;   09 ; 0A; 0B;   0C ; 0D; 0E

start:

    sei
    
    jsr setup_vera_for_layer0_bitmap

    jsr copy_palette_from_index_0
    jsr clear_bitmap_memory   ; SLOW!
    jsr load_bitmap_into_vram
    jsr generate_y_to_address_table
    
    jsr load_lens_positions_into_ram
    
    lda #DOWNLOAD_RAM_BANK
    sta DWN_RAM_BANK
    stz DWN_IDX
    jsr load_download_code_into_banked_ram
    inc DWN_RAM_BANK
    inc DWN_IDX
    jsr load_download_code_into_banked_ram


    lda #UPLOAD_RAM_BANK
    sta UPL_RAM_BANK
    stz UPL_QUADRANT
    
load_next_upload_quadrant:    
    stz UPL_IDX
    jsr load_upload_code_into_banked_ram
    inc UPL_RAM_BANK
    inc UPL_IDX
    jsr load_upload_code_into_banked_ram
    inc UPL_RAM_BANK
    inc UPL_IDX
    jsr load_upload_code_into_banked_ram
    inc UPL_RAM_BANK
    lda UPL_RAM_BANK
    
    inc UPL_QUADRANT
    cmp #UPLOAD_RAM_BANK+12
    bne load_next_upload_quadrant
    
    ; If set the first 4 sprites will be enabled, the others not
    lda #%00001000  ; Z-depth = 2
    sta Z_DEPTH_BIT
    
    lda #<LENS_POSITIONS_ADDRESS
    sta LENS_POS_ADDRESS
    lda #>LENS_POSITIONS_ADDRESS
    sta LENS_POS_ADDRESS+1
    
    ; We set the start position of the lens
    ldy #0
    lda (LENS_POS_ADDRESS), y
    sta LENS_X_POS
    iny
    lda (LENS_POS_ADDRESS), y
    sta LENS_X_POS+1
    iny
    lda (LENS_POS_ADDRESS), y
    sta LENS_Y_POS
    iny
    lda (LENS_POS_ADDRESS), y
    sta LENS_Y_POS+1
    
    
    clc
    lda LENS_POS_ADDRESS
    adc #4
    sta LENS_POS_ADDRESS
    lda LENS_POS_ADDRESS+1
    adc #0
    sta LENS_POS_ADDRESS+1
 
    jsr clear_sprite_memory
    jsr clear_download_buffer ; TODO: this is not really needed, but makes debugging easier
    

    ; FIXME: disable all sprites beforehand!
    ; FIXME: we have to set X1-increment and X1-position to 0! (NOW we rely on the DEFAULT settings of VERA!)

    
    ; We start filling the first 4 sprites (QUADRANT = 0 instead of 4)
    lda #0
    sta QUADRANT
    
move_lens:
    ; This will fill the buffer for 4 sprites
    jsr download_and_upload_quadrants


    ; FIXME: replace this with something proper!
    jsr dumb_wait_for_vsync
    
    ; IMPORTANT: this has to run during/just after VSYNC so the other sprites (which have just been drawn) become visible (aka double buffer)
    ; It will also flip the Z_DEPTH_BIT so *next* time the other 4 sprites become visible
    jsr setup_sprites

    ; We set the start position of the lens
    ldy #0
    lda (LENS_POS_ADDRESS), y
    sta LENS_X_POS
    iny
    lda (LENS_POS_ADDRESS), y
    sta LENS_X_POS+1
    iny
    lda (LENS_POS_ADDRESS), y
    sta LENS_Y_POS
    iny
    lda (LENS_POS_ADDRESS), y
    sta LENS_Y_POS+1
    
    clc
    lda LENS_POS_ADDRESS
    adc #4
    sta LENS_POS_ADDRESS
    lda LENS_POS_ADDRESS+1
    adc #0
    sta LENS_POS_ADDRESS+1

    ; X never gets negative, so it is negative, we know we are done (this is a marker)
    lda LENS_X_POS+1
    bpl move_lens
    

    ; We are not returning to BASIC here...
infinite_loop:
    jmp infinite_loop
    
    rts

; This is just a dumb verison of a proper vsync    
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
    
    
quadrant_addr1_bank:  ; %00010000 ($10) = +1 and %00011000 ($18) = -1   (bit16 = 0)
    .byte $10, $18, $18, $10,    $10, $18, $18, $10
    
quadrant_addr0_bank:  ; %11100000 ($E0) = +320 and %11101000 ($E8) = -320  (bit16 = 0)
    .byte $E0, $E0, $E8, $E8,    $E0, $E0, $E8, $E8
    
quadrant_vram_offset_low: ;  +0, -1, -321, -320 -> 0, 1, 65, 64 (negated and low)
    ; Note: these are SUBTRACTED!
; FIXME: CLEAN UP!
; FIXME: CLEAN UP!
; FIXME: CLEAN UP!
;    .byte   0,   1,  65,  64,      0,   1,  65,  64 
    .byte   0,   0,  64,  64,      0,   0,  64,  64 
    
quadrant_vram_offset_high: ;  +0, -1, -321, -320 -> 0, 0, 1, 1 (negated and high)
    ; Note: these are SUBTRACTED!
    .byte   0,   0,   1,   1,      0,   0,   1,    1 
    
quadrant_addr0_high_sprite:  ; SPRITES_VRAM_ADDRESS + 4096 * sprite_index ($12000, $13000, $14000, ..., $19000)
    .byte $20, $30, $40, $50,    $60, $70, $80, $90
    
    
download_and_upload_quadrants:


    ; For each quadrant download we need to have set this:
    ;
    ;  - Normal addr1-mode
    ;  - DCSEL=2
    ;  - ADDR0-increment should be set 1-pixel vertically (+320/-320 according to quadrant)
    ;  - ADDR1-increment should be set 1-pixel horizontally (+1/-1 according to quadrant)
    ;  - ADDR0 set to address of first pixel in quadrant
    ;  - X1-increment is 0
    ;  - X1-position is 0
    ;  - Free memory at address BITMAP_QUADRANT_BUFFER (half_lens_width*half_lens_height in size)

    
    ; - We calculate the BASE vram address for the LENS -
    
    lda LENS_Y_POS+1
    bpl positive_y_position
    
    ; We have a negative Y position
    
    ldy LENS_Y_POS
    
    clc
    lda NEG_Y_TO_ADDRESS_LOW, y
    adc LENS_X_POS
    sta LENS_VRAM_ADDRESS

    lda NEG_Y_TO_ADDRESS_HIGH, y
    adc LENS_X_POS+1
    sta LENS_VRAM_ADDRESS+1
    
    lda NEG_Y_TO_ADDRESS_BANK, y
    adc #0
    sta LENS_VRAM_ADDRESS+2
    
    bra lens_vram_address_determined
    
positive_y_position:
    ; We have a positive Y position
    
    ldy LENS_Y_POS
    
    clc
    lda Y_TO_ADDRESS_LOW, y
    adc LENS_X_POS
    sta LENS_VRAM_ADDRESS

    lda Y_TO_ADDRESS_HIGH, y
    adc LENS_X_POS+1
    sta LENS_VRAM_ADDRESS+1
    
    lda Y_TO_ADDRESS_BANK, y
    adc #0
    sta LENS_VRAM_ADDRESS+2

lens_vram_address_determined:
    
    ; We iterate through 4 quadrants (either 0-3 OR 4-7)

    ldx QUADRANT
    
    lda #UPLOAD_RAM_BANK
    sta UPL_RAM_BANK

next_quadrant_to_download_and_upload:
    
    ; -- download --
    
    ; -- Setup for downloading in quadrant 0 --
    
    lda #%00000101           ; DCSEL=2, ADDRSEL=1
    sta VERA_CTRL
    
    lda quadrant_addr1_bank, x   ; Setting bit 16 of ADDR1 to 0, auto-increment to +1 or -1 (depending on quadrant)
    sta VERA_ADDR_BANK
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    ; Each quadrant has a slight VRAM-offset as its starting point (+0, -1, -321, -320). We subtract those here.
    sec
    lda LENS_VRAM_ADDRESS
    sbc quadrant_vram_offset_low, x
    sta VERA_ADDR_LOW

    lda LENS_VRAM_ADDRESS+1
    sbc quadrant_vram_offset_high, x
    sta VERA_ADDR_HIGH
    
    lda LENS_VRAM_ADDRESS+2
    sbc #0
; FIXME: WHAT IF WE JUST GO FROM ONE VRAM-BANK to ANOTHER VRAM-BANK HERE?
; OK?: does and-ing with 01 work here? -> looks like it!
    and #$01
    sta LENS_VRAM_BANK

    lda quadrant_addr0_bank, x   ; Setting bit 16 of ADDR1 to 0 (or 1), auto-increment to +320 or -320 (depending on quadrant)
    ora LENS_VRAM_BANK
    sta VERA_ADDR_BANK
    

    lda #%00000010
    sta VERA_FX_CTRL         ; polygon addr1-mode
    
    lda VERA_DATA1           ; sets ADDR1 to ADDR0
    
    lda #%00000000
    sta VERA_FX_CTRL         ; normal addr1-mode
    
    lda #DOWNLOAD_RAM_BANK
    sta RAM_BANK
    jsr DOWNLOAD_RAM_ADDRESS
    
    lda #DOWNLOAD_RAM_BANK+1
    sta RAM_BANK
    jsr DOWNLOAD_RAM_ADDRESS

    ; -- upload --
    
    ; This sets ADDR1 increment to +1
    
    lda #%00000101           ; DCSEL=2, ADDRSEL=1
    sta VERA_CTRL
    
    lda #%00010001           ; Setting bit 16 of ADDR1 to 1, auto-increment to +1  (note: setting bit16 is not needed here, because it will be overwritten later)
    sta VERA_ADDR_BANK
    
    lda #%00000100           ; DCSEL=2, ADDRSEL=0
    sta VERA_CTRL
    
    ; This sets ADDR0 to the base vram address of the sprite involved (and sets it autoincrement correctly)
    
    lda #%01110001           ; Setting bit 16 of ADDR0 to 1, auto-increment to +64 
    sta VERA_ADDR_BANK
    
    lda quadrant_addr0_high_sprite, x
    sta VERA_ADDR_HIGH
    
    stz VERA_ADDR_LOW
    
    lda #%00000010
    sta VERA_FX_CTRL          ; polygon addr1-mode

    lda VERA_DATA1            ; sets ADDR1 to ADDR0
    
    ; Note: when doing the upload, we stay in polygon mode

    clc                       ; we are adding during upload, so we need the carry to be 0
    lda UPL_RAM_BANK
    sta RAM_BANK
    jsr UPLOAD_RAM_ADDRESS
    
    clc                       ; the carry might have been set again, since the UPLOAD (run before) might have gotton garbage data and overflown)
    lda UPL_RAM_BANK
    adc #1
    sta RAM_BANK
    jsr UPLOAD_RAM_ADDRESS

    clc                       ; the carry might have been set again, since the UPLOAD (run before) might have gotton garbage data and overflown)
    lda UPL_RAM_BANK
    adc #2
    sta RAM_BANK
    jsr UPLOAD_RAM_ADDRESS
    
    inx 
    inc QUADRANT  ; TODO: this is not efficient
    
    clc
    lda UPL_RAM_BANK
    adc #3
    sta UPL_RAM_BANK
    
    ; We loop through quadrant indexes be 0-3 OR 4-7.
    cpx #4
    beq done_downloading_and_uploading_quadrants
    cpx #8
    beq done_downloading_and_uploading_quadrants
    
; FIXME!    
;    jsr wait_a_few_ms
    
    jmp next_quadrant_to_download_and_upload

done_downloading_and_uploading_quadrants:
    
    ; We reset QUADRANT to 0 if we reach 8
    lda QUADRANT
    cmp #8
    bne quadrant_is_ok
    stz QUADRANT
    
quadrant_is_ok:

    rts



; For debugging    
wait_a_few_ms:
    phx
    phy
    ldx #64
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
    ply
    plx
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

    ; Set layer0 tilebase to $01000 and tile width to 320 px
    lda #%00001000   ; first first 6 bits of $01000 is 000010b
    sta VERA_L0_TILEBASE

    ; Setting VSTART/VSTOP so that we have 200 rows on screen (320x200 pixels on screen)

    lda #%00000010  ; DCSEL=1
    sta VERA_CTRL
   
    lda #20
    sta VERA_DC_VSTART
    lda #400/2+20-1
    sta VERA_DC_VSTOP
    
    rts
    

clear_download_buffer:

    lda #<BITMAP_QUADRANT_BUFFER
    sta STORE_ADDRESS
    lda #>BITMAP_QUADRANT_BUFFER
    sta STORE_ADDRESS+1
    
    ; Number of bytes to clear is: HALF_LENS_WIDTH*HALF_LENS_HEIGHT
    
    ; FIXME: We *ASSUME* this is 59*52=3068 bytes. So clearing 12*256 would be enough
    
    lda #0
    
    ldx #12
clear_next_download_buffer_256:

    ldy #0
clear_next_download_buffer_1:

    sta (STORE_ADDRESS),y

    iny
    bne clear_next_download_buffer_1

    inc STORE_ADDRESS+1
    
    dex
    bne clear_next_download_buffer_256

    rts
    

clear_bitmap_memory:

    lda #%00010000      ; setting bit 16 of vram address to 0, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    lda #0
    sta VERA_ADDR_LOW
    lda #0
    sta VERA_ADDR_HIGH

    ; FIXME: PERFORMANCE we can do this MUCH faster using CACHE writes and UNROLLING!
    
    ; We need 320*200 + 4096 (top border) + 4096 (bottom border) = 72192 bytes to be cleared
    ; This means we need 282*256 bytes to be cleared (282 = 256 + 26)

    ; First 256*256 bytes
    ldy #0
clear_bitmap_next_256:
    ldx #0
clear_bitmap_next_1:
    stz VERA_DATA0
    inx
    bne clear_bitmap_next_1
    dey
    bne clear_bitmap_next_256

    ; FIXME: we take a little extra margin (which is NEEDED!)
    ldy #26+10
clear_bitmap_next_256a:
    ldx #0
clear_bitmap_next_1a:
    stz VERA_DATA0
    inx
    bne clear_bitmap_next_1a
    dey
    bne clear_bitmap_next_256a
    
    rts

    
clear_sprite_memory:

    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
    sta VERA_ADDR_BANK

    lda #<(SPRITES_VRAM_ADDRESS)
    sta VERA_ADDR_LOW
    lda #>(SPRITES_VRAM_ADDRESS)
    sta VERA_ADDR_HIGH

    ; FIXME: PERFORMANCE we can do this MUCH faster using CACHE writes and UNROLLING!
    
    ldy #128
clear_next_256:
    ldx #0
clear_next_1:

; FIXME: we should CLEAR! (for now filling with red)
    stz VERA_DATA0
;    lda #2
;    sta VERA_DATA0

    inx
    bne clear_next_1
    
    dey
    bne clear_next_256
    
    rts
    
sprite_address_l:  ; Addres bits: 12:5  -> starts at $12000, then $13000: so first is %00000000, second is %10000000 = $00 and $80
    .byte $00, $80, $00, $80, $00, $80, $00, $80
sprite_address_h:  ; Addres bits: 16:13  -> starts at $12000, so first is %10001001 (mode = 8bpp, $12000) = $09
    .byte $09, $09, $0A, $0A, $0B, $0B, $0C, $0C
sprite_x_offset:
; Note: these are SUBTRACTED!
    .byte 0,  64, 64, 0, 0,  64, 64, 0
sprite_y_offset:
; Note: these are SUBTRACTED!
    .byte 0, 0, 64,  64, 0, 0, 64,  64
sprite_flips:
    .byte 0, 1, 3,  2, 0, 1, 3,  2
    
setup_sprites:

    lda #%00010001      ; setting bit 16 of vram address to 1, setting auto-increment value to 1
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
    ora #%10000000 ; 8bpp
    sta VERA_DATA0
    
    ; X (7:0)
    sec
    lda LENS_X_POS
    sbc sprite_x_offset, x
    sta VERA_DATA0
    
    ; X (9:8)
    lda LENS_X_POS+1
    sbc #0
    sta VERA_DATA0

    ; Y (7:0)
    sec
    lda LENS_Y_POS
    sbc sprite_y_offset, x
    sta VERA_DATA0

    ; Y (9:8)
    lda LENS_Y_POS+1
    sbc #0
    sta VERA_DATA0
    
    ; Collision mask	Z-depth	V-flip	H-flip
    lda Z_DEPTH_BIT
    ora sprite_flips, x
    sta VERA_DATA0

    ; Sprite height,	Sprite width,	Palette offset
    ; Note: we want to use a different palette (blue-ish color) for the pixels inside the lens, so we add 32 to the color index!
;    lda #%11110100 ; 64x64, 4*16 = 64 palette offset
;    lda #%11110010 ; 64x64, 2*16 = 32 palette offset
    lda #%11110000 ; 64x64, 0*16 = 0 palette offset
    sta VERA_DATA0
    
    inx
    
    ; if x == 4 we flip the Z_DEPTH_BIT
    cpx #4
    bne z_depth_bit_is_correct
    
    lda Z_DEPTH_BIT
    eor #%00001000
    sta Z_DEPTH_BIT

z_depth_bit_is_correct:

    cpx #8
    bne setup_next_sprite
    
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


bitmap_filename:      .byte    "background.dat" 
end_bitmap_filename:

load_bitmap_into_vram:

    lda #(end_bitmap_filename-bitmap_filename) ; Length of filename
    ldx #<bitmap_filename      ; Low byte of Fname address
    ldy #>bitmap_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    jsr SETLFS
 
    lda #2            ; load into Bank 0 of VRAM (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<BITMAP_VRAM_ADDRESS
    ldy #>BITMAP_VRAM_ADDRESS
    jsr LOAD
    bcc bitmap_loaded
    ; FIXME: do proper error handling!
    stp

bitmap_loaded:
    rts







lens_pos_filename:      .byte    "lens-pos.dat" 
end_lens_pos_filename:

load_lens_positions_into_ram:

    lda #(end_lens_pos_filename-lens_pos_filename) ; Length of filename
    ldx #<lens_pos_filename      ; Low byte of Fname address
    ldy #>lens_pos_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    
    jsr SETLFS
    
    lda #0            ; load into Fixed RAM (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<LENS_POSITIONS_ADDRESS
    ldy #>LENS_POSITIONS_ADDRESS
    jsr LOAD
    bcc lens_pos_loaded
    ; FIXME: do proper error handling!
    stp
lens_pos_loaded:

    rts


download_filename:      .byte    "download0.dat" 
end_download_filename:

load_download_code_into_banked_ram:

    clc
    lda #'0'                  ; '0' = $30
    adc DWN_IDX
    sta end_download_filename-5 ; 5 characters from the end is the '0'

    lda #(end_download_filename-download_filename) ; Length of filename
    ldx #<download_filename      ; Low byte of Fname address
    ldy #>download_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    
    jsr SETLFS
    
    lda DWN_RAM_BANK
    sta RAM_BANK
    
    lda #0            ; load into Fixed RAM (current RAM Bank) (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<DOWNLOAD_RAM_ADDRESS
    ldy #>DOWNLOAD_RAM_ADDRESS
    jsr LOAD
    bcc download_loaded
    ; FIXME: do proper error handling!
    stp
download_loaded:

    rts
    
    
upload_filename:      .byte    "upload0-0.dat" 
end_upload_filename:

load_upload_code_into_banked_ram:

    clc
    lda #'0'                  ; '0' = $30
    adc UPL_QUADRANT
    sta end_upload_filename-7 ; 7 characters from the end is the first '0'
    
    clc
    lda #'0'                  ; '0' = $30
    adc UPL_IDX
    sta end_upload_filename-5 ; 5 characters from the end is the second '0'

    lda #(end_upload_filename-upload_filename) ; Length of filename
    ldx #<upload_filename      ; Low byte of Fname address
    ldy #>upload_filename      ; High byte of Fname address
    jsr SETNAM
 
    lda #1            ; Logical file number
    ldx #8            ; Device 8 = sd card
    ldy #2            ; 0=ignore address in bin file (2 first bytes)
                      ; 1=use address in bin file
                      ; 2=?use address in bin file? (and dont add first 2 bytes?)
    
    jsr SETLFS
    
    lda UPL_RAM_BANK
    sta RAM_BANK
    
    lda #0            ; load into Fixed RAM (current RAM Bank) (see https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-load )
    ldx #<UPLOAD_RAM_ADDRESS
    ldy #>UPLOAD_RAM_ADDRESS
    jsr LOAD
    bcc upload_loaded
    ; FIXME: do proper error handling!
    stp
upload_loaded:

    rts
    
    
    
generate_y_to_address_table:

    ; Positive Y
    
    lda #<BITMAP_VRAM_ADDRESS
    sta VRAM_ADDRESS
    lda #>BITMAP_VRAM_ADDRESS
    sta VRAM_ADDRESS+1
    lda #(BITMAP_VRAM_ADDRESS>>16)
    sta VRAM_ADDRESS+2

    ; Our first entry (same for positive and negative y)
    ldy #0
    lda VRAM_ADDRESS
    sta Y_TO_ADDRESS_LOW, y
    lda VRAM_ADDRESS+1
    sta Y_TO_ADDRESS_HIGH, y
    lda VRAM_ADDRESS+2
    sta Y_TO_ADDRESS_BANK, y

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
    sta Y_TO_ADDRESS_BANK, y
    
    iny
    bne generate_next_y_to_address_entry
    
    ; Negative Y

    lda #<BITMAP_VRAM_ADDRESS
    sta VRAM_ADDRESS
    lda #>BITMAP_VRAM_ADDRESS
    sta VRAM_ADDRESS+1
    lda #(BITMAP_VRAM_ADDRESS>>16)
    sta VRAM_ADDRESS+2
    
    ; Note: the negative-y table does not use its first entry, so we start with -1
    lda #$FF  ; = -1
generate_next_neg_y_to_address_entry:
    sec
    lda VRAM_ADDRESS
    sbc #<320
    sta VRAM_ADDRESS
    sta NEG_Y_TO_ADDRESS_LOW, y
    
    lda VRAM_ADDRESS+1
    sbc #>320
    sta VRAM_ADDRESS+1
    sta NEG_Y_TO_ADDRESS_HIGH, y
    
    lda VRAM_ADDRESS+2
    sbc #0
    sta VRAM_ADDRESS+2
    and #$01
    sta NEG_Y_TO_ADDRESS_BANK, y
    
    dey
    bne generate_next_neg_y_to_address_entry

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
  .byte $64, $09
  .byte $23, $01
  .byte $75, $0a
  .byte $75, $0b
  .byte $86, $0b
  .byte $97, $0c
  .byte $64, $0a
  .byte $86, $0b
  .byte $98, $0c
  .byte $a8, $0d
  .byte $a9, $0d
  .byte $b9, $0e
  .byte $ca, $0e
  .byte $23, $01
  .byte $cb, $0f
  .byte $00, $02
  .byte $00, $04
  .byte $10, $05
  .byte $00, $04
  .byte $10, $06
  .byte $20, $07
  .byte $30, $08
  .byte $50, $0a
  .byte $70, $0b
  .byte $80, $0b
  .byte $40, $09
  .byte $30, $08
  .byte $90, $0c
  .byte $c0, $0e
  .byte $b0, $0d
  .byte $e0, $0f
  .byte $f0, $0f
  .byte $02, $00
  .byte $16, $01
  .byte $27, $02
  .byte $39, $02
  .byte $3a, $03
  .byte $3a, $03
  .byte $39, $03
  .byte $28, $02
  .byte $27, $01
  .byte $16, $01
  .byte $4b, $04
  .byte $28, $02
  .byte $16, $01
  .byte $02, $01
  .byte $02, $01
  .byte $26, $01
  .byte $4b, $04
  .byte $02, $01
  .byte $02, $02
  .byte $12, $02
  .byte $13, $03
  .byte $13, $03
  .byte $13, $03
  .byte $14, $03
  .byte $02, $02
  .byte $02, $02
  .byte $02, $02
  .byte $24, $03
  .byte $24, $04
  .byte $25, $04
  .byte $25, $04
  .byte $25, $04
  .byte $36, $04
  .byte $15, $00
  .byte $36, $05
  .byte $36, $05
  .byte $47, $05
  .byte $48, $06
  .byte $36, $05
  .byte $47, $05
  .byte $49, $06
  .byte $59, $06
  .byte $5a, $06
  .byte $5a, $07
  .byte $6b, $07
  .byte $15, $00
  .byte $6b, $07
  .byte $02, $01
  .byte $02, $02
  .byte $02, $02
  .byte $02, $02
  .byte $02, $03
  .byte $12, $03
  .byte $12, $04
  .byte $22, $05
  .byte $32, $05
  .byte $42, $05
  .byte $22, $04
  .byte $12, $04
  .byte $42, $06
  .byte $62, $07
  .byte $52, $06
  .byte $72, $07
  .byte $72, $07
  .byte $05, $00
  .byte $18, $01
  .byte $29, $02
  .byte $3a, $02
  .byte $3b, $03
  .byte $3b, $03
  .byte $3a, $03
  .byte $2a, $02
  .byte $29, $01
  .byte $18, $01
  .byte $4c, $04
  .byte $2a, $02
  .byte $18, $01
  .byte $05, $01
  .byte $05, $01
  .byte $28, $01
  .byte $4c, $04
  .byte $05, $01
  .byte $05, $02
  .byte $15, $02
  .byte $16, $03
  .byte $16, $03
  .byte $16, $03
  .byte $16, $03
  .byte $05, $02
  .byte $05, $02
  .byte $05, $02
  .byte $26, $03
  .byte $26, $04
  .byte $27, $04
  .byte $27, $04
  .byte $27, $04
  .byte $38, $04
  .byte $17, $00
  .byte $38, $05
  .byte $38, $05
  .byte $49, $05
  .byte $4a, $06
  .byte $38, $05
  .byte $49, $05
  .byte $4a, $06
  .byte $5a, $06
  .byte $5b, $06
  .byte $5b, $07
  .byte $6c, $07
  .byte $17, $00
  .byte $6c, $07
  .byte $05, $01
  .byte $05, $02
  .byte $05, $02
  .byte $05, $02
  .byte $05, $03
  .byte $15, $03
  .byte $15, $04
  .byte $25, $05
  .byte $35, $05
  .byte $45, $05
  .byte $25, $04
  .byte $15, $04
  .byte $45, $06
  .byte $65, $07
  .byte $55, $06
  .byte $75, $07
  .byte $75, $07
  .byte $08, $00
  .byte $1a, $01
  .byte $2b, $02
  .byte $3c, $02
  .byte $3c, $03
  .byte $3c, $03
  .byte $3c, $03
  .byte $2b, $02
  .byte $2b, $01
  .byte $1a, $01
  .byte $4d, $04
  .byte $2b, $02
  .byte $1a, $01
  .byte $08, $01
  .byte $08, $01
  .byte $2a, $01
  .byte $4d, $04
  .byte $08, $01
  .byte $08, $02
  .byte $18, $02
  .byte $18, $03
  .byte $18, $03
  .byte $18, $03
  .byte $19, $03
  .byte $08, $02
  .byte $08, $02
  .byte $08, $02
  .byte $29, $03
  .byte $29, $04
  .byte $29, $04
  .byte $29, $04
  .byte $29, $04
  .byte $3a, $04
  .byte $19, $00
  .byte $3a, $05
  .byte $3a, $05
  .byte $4b, $05
  .byte $4b, $06
  .byte $3a, $05
  .byte $4b, $05
  .byte $4c, $06
  .byte $5c, $06
  .byte $5c, $06
  .byte $5c, $07
  .byte $6d, $07
  .byte $19, $00
  .byte $6d, $07
  .byte $08, $01
  .byte $08, $02
  .byte $08, $02
  .byte $08, $02
  .byte $08, $03
  .byte $18, $03
  .byte $18, $04
  .byte $28, $05
  .byte $38, $05
  .byte $48, $05
  .byte $28, $04
  .byte $18, $04
  .byte $48, $06
  .byte $68, $07
  .byte $58, $06
  .byte $78, $07
  .byte $78, $07
end_of_palette_data:


