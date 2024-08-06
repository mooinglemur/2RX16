


generate_single_fill_line_code:

    ; This routines expects this:
    ;    FILL_LENGTH_LOW (8-bit)   : FILL_LENGTH >= 16, X1[1:0],        FILL_LENGTH[3:0], 0
    
    ; == We first extract this info (8-bit) ==
    ;
    ;   GEN_START_X[1:0]
    ;   GEN_FILL_LENGTH_LOW = [3:0]
    ;   GEN_FILL_LENGTH_IS_16_OR_MORE
    
    lda FILL_LENGTH_LOW
    asl                   ; We remove the bit for FILL_LENGTH >= 16
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr                   ; We keep the X1[1:0] part
    sta GEN_START_X
    
    lda FILL_LENGTH_LOW
    lsr
    and #%00001111
    sta GEN_FILL_LENGTH_LOW
    
    lda FILL_LENGTH_LOW
    and #%10000000
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    sta GEN_FILL_LENGTH_IS_16_OR_MORE
    
    stz GEN_LOANED_16_PIXELS
    
    ; ================================  

    
    ; -- NR_OF_STARTING_PIXELS = 4 - GEN_START_X --
    sec
    lda #4
    sbc GEN_START_X
    sta NR_OF_STARTING_PIXELS

    ; -- NR_OF_ENDING_PIXELS = (GEN_START_X + GEN_FILL_LENGTH_LOW) % 4 --
    clc
    lda GEN_START_X
    adc GEN_FILL_LENGTH_LOW
    and #%00000011
    sta NR_OF_ENDING_PIXELS               ; the lower 2 bits contain the nr of ending pixels
    
    ; -- we start with LEFT_OVER_PIXELS = GEN_FILL_LENGTH_LOW --
    stz LEFT_OVER_PIXELS+1
    lda GEN_FILL_LENGTH_LOW
    sta LEFT_OVER_PIXELS
    
    ; -- check if more than or equal to 16 extra pixels have to be drawn
    lda GEN_FILL_LENGTH_IS_16_OR_MORE
    bne gen_more_or_equal_to_16_pixels
    
gen_less_than_16_pixels:

    ; If we have less than 16 pixels AND fill length low == 0, we have nothing to do, so we go to the end
    lda GEN_FILL_LENGTH_LOW
    beq gen_ending_pixels_are_generated

    ; ===== We need to check if the starting and ending pixels are in the same 4-pixel colum ====
    ; check if GEN_START_X + GEN_FILL_LENGTH_LOW >= 4
    clc
    lda GEN_START_X
    adc GEN_FILL_LENGTH_LOW
    cmp #4
    bcc gen_start_and_end_in_same_column  ; we end in the same 4-pixel column as where we start
    beq gen_start_and_end_in_same_column
    
    ; ============= generate starting pixels code (>=16 pixels) ===============

    ; if NR_OF_STARTING_PIXELS == 4 (meaning GEN_START_X == 0) we add 4 to the total left-over pixel count and NOT generate starting pixels!
    lda NR_OF_STARTING_PIXELS
    cmp #4
    beq gen_generate_middle_pixels
    
gen_generate_starting_pixels:
    
    ; -- we subtract the starting pixels from LEFT_OVER_PIXELS --
    sec
    lda LEFT_OVER_PIXELS
    sbc NR_OF_STARTING_PIXELS
    sta LEFT_OVER_PIXELS
    lda LEFT_OVER_PIXELS+1
    sbc #0
    sta LEFT_OVER_PIXELS+1
    
    jsr generate_draw_starting_pixels_code
    
gen_generate_middle_pixels:

    ; We divide LEFT_OVER_PIXELS by 4 by shifting it 2 bit positions to the right
    lsr LEFT_OVER_PIXELS+1
    ror LEFT_OVER_PIXELS
    lsr LEFT_OVER_PIXELS+1
    ror LEFT_OVER_PIXELS
    
    lda LEFT_OVER_PIXELS            ; Note: the result should always fit into one byte
    sta NR_OF_FULL_CACHE_WRITES
    beq middle_pixels_generated     ; We should not draw any middle pixels
    jsr generate_draw_middle_pixels_code
middle_pixels_generated:
    
    
gen_generate_ending_pixels:
    lda NR_OF_ENDING_PIXELS
    beq gen_ending_pixels_are_generated    ; If there should be no ending pixels generated, we skip generating them

    jsr generate_draw_ending_pixels_code
    
gen_ending_pixels_are_generated:
    .if(TEST_JUMP_TABLE)
        jsr generate_rts_code
    .else
        jsr generate_fill_line_iterate_code
    .endif
    
    rts

    
gen_start_and_end_in_same_column:

    jsr generate_draw_starting_and_ending_pixels_code

    .if(TEST_JUMP_TABLE)
        jsr generate_rts_code
    .else
        jsr generate_fill_line_iterate_code
    .endif
    
    rts
    

gen_more_or_equal_to_16_pixels:

    ; ============= generate starting pixels code (>=16 pixels) ===============

    ; if NR_OF_STARTING_PIXELS == 4 (meaning GEN_START_X == 0) we add 4 to the total left-over pixel count and NOT generate starting pixels!
    lda NR_OF_STARTING_PIXELS
    cmp #4
    beq gen_generate_middle_pixels_16
    
gen_generate_starting_pixels_16:

    ; -- we subtract the starting pixels from LEFT_OVER_PIXELS --
    sec
    lda LEFT_OVER_PIXELS
    sbc NR_OF_STARTING_PIXELS
    sta LEFT_OVER_PIXELS
    lda LEFT_OVER_PIXELS+1
    sbc #0
    sta LEFT_OVER_PIXELS+1
    
    ; if NR_OF_STARTING_PIXELS > LEFT_OVER_PIXELS (which is possible since LEFT_OVER_PIXELS == GEN_FILL_LENGTH_LOW and >16 fill length)
    ; we should *LOAN* 16 pixels. So we add 16 pixels here, and subtract it by jumping 4*stz later in the code fill code.
    
    ; FIXME: use bpl instead? 
    ; bpl do_not_loan_pixels
    
    clc
    lda LEFT_OVER_PIXELS
    adc #16
    sta LEFT_OVER_PIXELS
    lda LEFT_OVER_PIXELS+1
    adc #0
    sta LEFT_OVER_PIXELS+1
    
    lda #1
    sta GEN_LOANED_16_PIXELS

    jsr generate_draw_starting_pixels_code

gen_generate_middle_pixels_16:

    ; We divide LEFT_OVER_PIXELS by 4 by shifting it 2 bit positions to the right
    lsr LEFT_OVER_PIXELS+1
    ror LEFT_OVER_PIXELS
    lsr LEFT_OVER_PIXELS+1
    ror LEFT_OVER_PIXELS
    
    lda LEFT_OVER_PIXELS               ; Note: the result should always fit into one byte
    sta NR_OF_FULL_CACHE_WRITES
    beq middle_pixels_generated_16     ; We should not draw any middle pixels
    jsr generate_draw_middle_pixels_code
middle_pixels_generated_16:
    
gen_generate_jump_to_second_table:

    ;   Note: the table is reversed: since the higher y-number will the less pixels. (so the *beginning* of the table will point to the *end* of the code), when no stz-calls are made)

    lda #<FILL_LINE_END_JUMP_0
    sta END_JUMP_ADDRESS
    lda #>FILL_LINE_END_JUMP_0
    ora NR_OF_ENDING_PIXELS     ; We set the *two* lower bits of the HIGH byte of the JUMP TABLE address to indicate which jump table we want to jump to
    sta END_JUMP_ADDRESS+1

    lda GEN_LOANED_16_PIXELS
    beq jump_address_is_valid
    
    ; if GEN_LOANED_16_PIXELS == 1 we should jump as-if 16 pixels less have to be drawn -> so we subtract 4 bytes (2 jump addresses)
    
    sec
    lda END_JUMP_ADDRESS
    sbc #4
    sta END_JUMP_ADDRESS
    lda END_JUMP_ADDRESS+1
    sbc #0
    sta END_JUMP_ADDRESS+1
    
; FIXME: CHECK: if exactly 16-pixels have to be drawn due to the HIGH fill length, we should not draw any pixels!
    
jump_address_is_valid:

    jsr generate_table_jump
    
    rts
    
    
generate_fill_line_end_code:

    ; -------------- FILL_LINE_END_CODE_0 ---------------
    
    lda #<FILL_LINE_END_CODE_0
    sta CODE_ADDRESS
    lda #>FILL_LINE_END_CODE_0
    sta CODE_ADDRESS+1
    
    jsr generate_80_fill_line_end_codes
    
    ; Note: for FILL_LINE_END_CODE_0 there is no additional (sub 4 byte) pixel draw
    
    .if(TEST_JUMP_TABLE)
        jsr generate_rts_code
    .else
        jsr generate_fill_line_iterate_code
    .endif

    ; -------------- FILL_LINE_END_CODE_1 ---------------

    lda #<FILL_LINE_END_CODE_1
    sta CODE_ADDRESS
    lda #>FILL_LINE_END_CODE_1
    sta CODE_ADDRESS+1
    
    jsr generate_80_fill_line_end_codes
    
    ; -- lda #{NIBBLE_PATTERN}
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda #%11111100         ; NIBBLE_PATTERN = 1 pixel at the end
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    .if(TEST_JUMP_TABLE)
        jsr generate_rts_code
    .else
        jsr generate_fill_line_iterate_code
    .endif
    
    ; -------------- FILL_LINE_END_CODE_2 ---------------

    lda #<FILL_LINE_END_CODE_2
    sta CODE_ADDRESS
    lda #>FILL_LINE_END_CODE_2
    sta CODE_ADDRESS+1
    
    jsr generate_80_fill_line_end_codes
    
    ; -- lda #{NIBBLE_PATTERN}
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda #%11110000         ; NIBBLE_PATTERN = 2 pixels at the end
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    .if(TEST_JUMP_TABLE)
        jsr generate_rts_code
    .else
        jsr generate_fill_line_iterate_code
    .endif
    
    ; -------------- FILL_LINE_END_CODE_3 ---------------

    lda #<FILL_LINE_END_CODE_3
    sta CODE_ADDRESS
    lda #>FILL_LINE_END_CODE_3
    sta CODE_ADDRESS+1
    
    jsr generate_80_fill_line_end_codes
    
    ; -- lda #{NIBBLE_PATTERN}
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda #%11000000         ; NIBBLE_PATTERN = 3 pixels at the end
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    .if(TEST_JUMP_TABLE)
        jsr generate_rts_code
    .else
        jsr generate_fill_line_iterate_code
    .endif
    
    rts

    
generate_fill_line_end_jump:

    lda #<FILL_LINE_END_JUMP_0
    sta STORE_ADDRESS
    lda #>FILL_LINE_END_JUMP_0
    sta STORE_ADDRESS+1
    
    ; We start at the end of the series of 80 'stz'-calls in the FILL_LINE_CODE  (80 * 4 pixels = 320 pixels)
    lda #<(FILL_LINE_END_CODE_0+80*3)
    sta LOAD_ADDRESS
    lda #>(FILL_LINE_END_CODE_0+80*3)
    sta LOAD_ADDRESS+1
    
    jsr generate_jump_table_16

    
    lda #<FILL_LINE_END_JUMP_1
    sta STORE_ADDRESS
    lda #>FILL_LINE_END_JUMP_1
    sta STORE_ADDRESS+1
    
    ; We start at the end of the series of 80 'stz'-calls in the FILL_LINE_CODE  (80 * 4 pixels = 320 pixels)
    lda #<(FILL_LINE_END_CODE_1+80*3)
    sta LOAD_ADDRESS
    lda #>(FILL_LINE_END_CODE_1+80*3)
    sta LOAD_ADDRESS+1
    
    jsr generate_jump_table_16
    
    
    lda #<FILL_LINE_END_JUMP_2
    sta STORE_ADDRESS
    lda #>FILL_LINE_END_JUMP_2
    sta STORE_ADDRESS+1
    
    ; We start at the end of the series of 80 'stz'-calls in the FILL_LINE_CODE  (80 * 4 pixels = 320 pixels)
    lda #<(FILL_LINE_END_CODE_2+80*3)
    sta LOAD_ADDRESS
    lda #>(FILL_LINE_END_CODE_2+80*3)
    sta LOAD_ADDRESS+1
    
    jsr generate_jump_table_16
    
    
    lda #<FILL_LINE_END_JUMP_3
    sta STORE_ADDRESS
    lda #>FILL_LINE_END_JUMP_3
    sta STORE_ADDRESS+1
    
    ; We start at the end of the series of 80 'stz'-calls in the FILL_LINE_CODE  (80 * 4 pixels = 320 pixels)
    lda #<(FILL_LINE_END_CODE_3+80*3)
    sta LOAD_ADDRESS
    lda #>(FILL_LINE_END_CODE_3+80*3)
    sta LOAD_ADDRESS+1
    
    jsr generate_jump_table_16
    
    rts

    
generate_jump_table_16:

    ; We backup the address of the *end* of the the series of 80 'stz'-calls
    lda LOAD_ADDRESS
    sta TMP1
    lda LOAD_ADDRESS+1
    sta TMP2

    ldy #0
generate_next_jump_table_16_entry:

    lda LOAD_ADDRESS
    sta (STORE_ADDRESS), y
    iny
    lda LOAD_ADDRESS+1
    sta (STORE_ADDRESS), y
    iny

    ; We do *two* addresses since the 9F2C (FILL_LENGTH_HIGH) value also contains bit 3, but we essentially *ignore* it. Therefore creating the same entry *twice*.
    lda LOAD_ADDRESS
    sta (STORE_ADDRESS), y
    iny
    lda LOAD_ADDRESS+1
    sta (STORE_ADDRESS), y
    iny
    
    sec
    lda LOAD_ADDRESS
    sbc #4*3               ; we need to skip 16 pixels, so four times a stz, this is 4 * 3 bytes of code
    sta LOAD_ADDRESS
    lda LOAD_ADDRESS+1
    sbc #0
    sta LOAD_ADDRESS+1
    
    cpy #80+4                ; We need 20 entries of 16 pixels (=320 pixels) *plus* an entry for 0 pixels. Each entry is 4 bytes (two addresses, so we stop at 4*21=84 bytes.
    bne generate_next_jump_table_16_entry


    ; --- fill length > 768 (or in our case >320) ---

    ; If the length of the fill line >768 (or in our case even >320) we should not draw the fill line
    ; TODO: For now we keep on iterating, but we *might* want to do an rts here instead 

    ; We restore the address of the *end* of the the series of 80 'stz'-calls
    lda TMP1
    sta LOAD_ADDRESS
    lda TMP2
    sta LOAD_ADDRESS+1
    
generate_next_jump_table_16_entry_overflow:

    lda LOAD_ADDRESS
    sta (STORE_ADDRESS), y
    iny
    lda LOAD_ADDRESS+1
    sta (STORE_ADDRESS), y
    iny
    
    cpy #0                ; We fill in the whole table
    bne generate_next_jump_table_16_entry_overflow
    
    rts


    
generate_80_fill_line_end_codes:
    ldy #0                 ; generated code byte counter
    
    ldx #0                 ; counts nr of fill instructions
next_fill_instruction:

    ; -- stz VERA_DATA1 ($9F24)
    lda #$9C               ; stz ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    inx
    cpx #80
    bne next_fill_instruction  ; 80 times a "fill 4-bytes" written to VERA
    
    rts

nr_of_starting_pixels_to_nibble_pattern:
    .byte %00000000     ; 4 pixels         ; only used in combination with ending pixels
    .byte %00111111     ; 1 pixel
    .byte %00001111     ; 2 pixels
    .byte %00000011     ; 3 pixels
    
nr_of_ending_pixels_to_nibble_pattern:
    .byte %00000000     ; 4 pixels         ; only used in combination with starting pixels
    .byte %11111100     ; 1 pixel
    .byte %11110000     ; 2 pixels
    .byte %11000000     ; 3 pixels
    
    
  
