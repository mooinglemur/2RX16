
; === Parameters that have to be set ===

; TEST_JUMP_TABLE = 0 or 1     ; This turns off the iteration in-between the jump-table calls
; USE_SOFT_FILL_LEN = 0 or 1;  ; This turns off reading from 9F2B and 9F2C (for fill length data) and instead reads from USE_SOFT_FILL_LEN-variables

; FIXME: are we going to use this? NR_OF_BYTES_PER_LINE = 320 / 160 / 80
; DO_4BIT = 1 or 0
; DO_2BIT = 1 or 0 (DO_4BIT has to be 1 for this to take effect)

; === Required ZP addresses: (one byte each, unless mentioned otherwise) ===

; TMP1
; TMP2

; END_JUMP_ADDRESS (2 bytes)
; START_JUMP_ADDRESS (2 bytes)

; CODE_ADDRESS (2 bytes)
; LOAD_ADDRESS (2 bytes)
; STORE_ADDRESS (2 bytes)

; FILL_LENGTH_LOW   ; FIXME: maybe we should use a differenly named variable using GEN?
; FILL_LENGTH_HIGH  ; FIXME: not actually used!


; FIXME: PREFIX these too with GEN_ ?
; LEFT_OVER_PIXELS (2 bytes)
; NIBBLE_PATTERN
; NR_OF_FULL_CACHE_WRITES
; NR_OF_STARTING_PIXELS
; NR_OF_ENDING_PIXELS

; -- Used to generate jump tables --
; GEN_START_X
; GEN_START_X_ORG ; only for 2-bit mode
; GEN_START_X_SET_TO_ZERO ; only for 2-bit mode
; GEN_FILL_LENGTH_LOW
; GEN_FILL_LENGTH_IS_16_OR_MORE (8-bit) / GEN_FILL_LENGTH_IS_8_OR_MORE (4-bit)
; GEN_LOANED_16_PIXELS (8-bit) / GEN_LOANED_8_PIXELS (4-bit) / GEN_START_X_SUB (2-bit)
; GEN_FILL_LINE_CODE_INDEX

; == Required RAM Addresses ==

; -- Only used when USE_SOFT_FILL_LEN is 1 --
; FILL_LENGTH_HIGH_SOFT (1 byte)

; FILL_LINE_START_JUMP (256 bytes)
; FILL_LINE_START_CODE ; 128 different (start of) fill line code patterns -> takes roughly $0C28 (3112) bytes -> so $0D00 is safe

; 8-bit:
; -- IMPORTANT: we set the *two* lower bits of (the HIGH byte of) this address in the code, using FILL_LINE_END_JUMP_0 as base. So the distance between the 4 tables should be $100! AND bits 8 and 9 should be 00b! (for FILL_LINE_END_JUMP_0) --
; FILL_LINE_END_JUMP_0 ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_0
; FILL_LINE_END_JUMP_1 ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_1
; FILL_LINE_END_JUMP_2 ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_2
; FILL_LINE_END_JUMP_3 ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_3

; 4-bit:
; -- IMPORTANT: we set the *three* lower bits of (the HIGH byte of) this address in the code, using FILL_LINE_END_JUMP_0 as base. So the distance between the 8 tables should be $100! AND bits 8, 9 and 10 should be 000b! (for FILL_LINE_END_JUMP_0) --
; FILL_LINE_END_JUMP_0 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_0
; FILL_LINE_END_JUMP_1 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_1
; FILL_LINE_END_JUMP_2 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_2
; FILL_LINE_END_JUMP_3 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_3
; FILL_LINE_END_JUMP_4 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_4
; FILL_LINE_END_JUMP_5 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_5
; FILL_LINE_END_JUMP_6 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_6
; FILL_LINE_END_JUMP_7 ; 40 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_7

; 8-bit:
; FIXME: can we put these code blocks closer to each other? Are they <= 256 bytes? -> NO, MORE than 256 bytes!!
; FILL_LINE_END_CODE_0 ; 3 (stz) * 80 (=320/4) = 240                      + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_1 ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_2 ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_3 ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?

; 4-bit:
; FIXME: can we put these code blocks closer to each other? Are they <= 256 bytes? -> YES??!
; FILL_LINE_END_CODE_0 ; 3 (stz) * 40 (=320/8) = 120                      + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_1 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_2 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_3 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_4 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_5 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_6 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
; FILL_LINE_END_CODE_7 ; 3 (stz) * 40 (=320/8) = 120 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
    
generate_fill_line_start_code_and_jump:

    lda #<FILL_LINE_START_CODE
    sta CODE_ADDRESS
    lda #>FILL_LINE_START_CODE
    sta CODE_ADDRESS+1
    
    ldy #0                 ; generated code byte counter
    
    stz GEN_FILL_LINE_CODE_INDEX
gen_next_fill_line_code:
    ; We remember where this partical code starts (where we have to jump to from the jump table)
    clc
    tya
    adc CODE_ADDRESS           ; TODO: CODE_ADDRESS will always stay 0, so this doesnt do anything really
    sta START_JUMP_ADDRESS       
    lda CODE_ADDRESS+1
    sta START_JUMP_ADDRESS+1

    lda GEN_FILL_LINE_CODE_INDEX
    sta FILL_LENGTH_LOW
    jsr generate_single_fill_line_code
    
    ; Storing jump address in jump table
    ldx GEN_FILL_LINE_CODE_INDEX
    lda START_JUMP_ADDRESS
    sta FILL_LINE_START_JUMP, x
    inx
    lda START_JUMP_ADDRESS+1
    sta FILL_LINE_START_JUMP, x
    
    inc GEN_FILL_LINE_CODE_INDEX
    inc GEN_FILL_LINE_CODE_INDEX
    bne gen_next_fill_line_code

    rts

    
; Note: the following routines are implemented in 2/4/8-bit specific files:
; 
;   generate_single_fill_line_code
;   generate_fill_line_end_code
;   generate_fill_line_end_jump
;

    
;
; Below are more generic routines that are used by the 2/4/8-bit specific routines:
;    
generate_draw_starting_and_ending_pixels_code:

    ; Note: in 2-bit mode we still count 4-bit pixels
    ldx NR_OF_STARTING_PIXELS
    lda nr_of_starting_pixels_to_nibble_pattern, x
    sta TMP2

    ; Note: in 2-bit mode we still count 4-bit pixels
    ldx NR_OF_ENDING_PIXELS
    lda nr_of_ending_pixels_to_nibble_pattern, x
    ora TMP2
    sta NIBBLE_PATTERN
    beq generate_nibble_pattern_is_0
    
    ; -- lda #{NIBBLE_PATTERN}
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda NIBBLE_PATTERN      ; NIBBLE_PATTERN
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    rts

generate_nibble_pattern_is_0:

    ; -- stz VERA_DATA1 ($9F24)
    lda #$9C               ; stz ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte

    rts
    
    
generate_draw_starting_pixels_code:

    ; Note: in 2-bit mode we still count 4-bit pixels
    ldx NR_OF_STARTING_PIXELS
    lda nr_of_starting_pixels_to_nibble_pattern, x
    sta NIBBLE_PATTERN
    
    ; -- lda #{NIBBLE_PATTERN}
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda NIBBLE_PATTERN      ; NIBBLE_PATTERN
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    rts


generate_draw_ending_pixels_code:

    ; Note: in 2-bit mode we still count 4-bit pixels
    ldx NR_OF_ENDING_PIXELS
    lda nr_of_ending_pixels_to_nibble_pattern, x
    sta NIBBLE_PATTERN
    
    ; -- lda #{NIBBLE_PATTERN}
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda NIBBLE_PATTERN      ; NIBBLE_PATTERN
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    rts
    
generate_load_fill_len_high:

    ; -- ldx $9F2C (= VERA_FX_POLY_FILL_H)
    lda #$AE               ; ldx ....
    jsr add_code_byte

    .if(USE_SOFT_FILL_LEN)
        lda #<FILL_LENGTH_HIGH_SOFT
        jsr add_code_byte
        
        lda #>FILL_LENGTH_HIGH_SOFT
        jsr add_code_byte
    .else
        lda #$2C               ; $2C
        jsr add_code_byte
        
        lda #$9F               ; $9F
        jsr add_code_byte
    .endif
    
    rts
    
generate_beq:

    ; -- beq ..
    lda #$F0               ; beq ....
    jsr add_code_byte

    rts
    
generate_dummy_offset:

    lda #$00               ; $00 -> this is PATCHED later on!
    jsr add_code_byte
    
    rts
    
generate_table_jump_without_ldx:

    ; -- jmp ($....,x)
    lda #$7C               ; jmp (....,x)
    jsr add_code_byte

    lda END_JUMP_ADDRESS        ; low byte of jump base address
    jsr add_code_byte
    
    lda END_JUMP_ADDRESS+1      ; high byte of jump base address
    jsr add_code_byte
    
    rts
    
    
generate_empty_cache_write:

    ; -- lda #$FF
    lda #$A9               ; lda #....
    jsr add_code_byte

    lda #$FF               ; $FF
    jsr add_code_byte
    
    ; -- sta VERA_DATA1 ($9F24)
    lda #$8D               ; sta ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte

    rts
    
; FIXME: maybe split this function into ldx ... and jmp(...,x) -> see generate_table_jump_without_ldx above!
generate_table_jump:

    ; -- ldx $9F2C (= VERA_FX_POLY_FILL_H)
    lda #$AE               ; ldx ....
    jsr add_code_byte

    .if(USE_SOFT_FILL_LEN)
        lda #<FILL_LENGTH_HIGH_SOFT
        jsr add_code_byte
        
        lda #>FILL_LENGTH_HIGH_SOFT
        jsr add_code_byte
    .else
        lda #$2C               ; $2C
        jsr add_code_byte
        
        lda #$9F               ; $9F
        jsr add_code_byte
    .endif

    ; -- jmp ($....,x)
    lda #$7C               ; jmp (....,x)
    jsr add_code_byte

    lda END_JUMP_ADDRESS        ; low byte of jump base address
    jsr add_code_byte
    
    lda END_JUMP_ADDRESS+1      ; high byte of jump base address
    jsr add_code_byte
    
    rts
    
    
generate_draw_middle_pixels_code:

    ldx #0                 ; counts nr of draw middle pixels instructions (four 8-bit pixels, eight 4-bit pixels)

next_draw_middle_pixels_instruction:

    ; -- stz VERA_DATA1 ($9F24)
    lda #$9C               ; stz ....
    jsr add_code_byte
    
    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
    
    inx
    cpx NR_OF_FULL_CACHE_WRITES
    bne next_draw_middle_pixels_instruction

    rts

 
generate_fill_line_iterate_code:

    ; -- lda VERA_DATA0 ($9F23)
    lda #$AD               ; lda ....
    jsr add_code_byte

    lda #$23               ; $23
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
        
    ; -- dey
    lda #$88               ; dey
    jsr add_code_byte
        
    ; -- beq fill_done
    lda #$F0               ; beq ...
    jsr add_code_byte
        
    ; IMPORTANT: if you change any of the below code byte make sure you change this number accordingly!
    .if(DO_4BIT && DO_2BIT)
        lda #$0B               ; ... fill_done -> branches to the rts opcode below!
    .else
        lda #$09               ; ... fill_done -> branches to the rts opcode below!
    .endif
    jsr add_code_byte
        
    ; -- lda VERA_DATA1 ($9F24)
    lda #$AD               ; lda ....
    jsr add_code_byte

    lda #$24               ; $24
    jsr add_code_byte
    
    lda #$9F               ; $9F
    jsr add_code_byte
        
    .if(DO_4BIT && DO_2BIT)
    
        ; In 2-bit mode we have to shift the FILL_LENGTH_LOW-value one bit to the left (and keep the top bit in the CARRY)
    
        ; -- lda $9F2B (FILL_LENGTH_LOW)
        lda #$AD               ; lda ....
        jsr add_code_byte

        lda #$2B               ; $2B
        jsr add_code_byte
        
        lda #$9F               ; $9F
        jsr add_code_byte
    
        ; -- asl
        lda #$0A               ; asl
        jsr add_code_byte
    
        ; -- tax
        lda #$AA               ; tax
        jsr add_code_byte
    .else
        ; In 4-bit and 8-bit mode we can use the FILL_LENGTH_LOW-value directly for the jump table
    
        ; -- ldx $9F2B (FILL_LENGTH_LOW)
        lda #$AE               ; ldx ....
        jsr add_code_byte

        lda #$2B               ; $2B
        jsr add_code_byte
        
        lda #$9F               ; $9F
        jsr add_code_byte
    .endif
        
    ; -- jmp (FILL_LINE_START_JUMP,x)
    lda #$7C               ; jmp (....,x)
    jsr add_code_byte

    lda #<FILL_LINE_START_JUMP  ; low byte of jump table
    jsr add_code_byte
    
    lda #>FILL_LINE_START_JUMP  ; high byte of jump table
    jsr add_code_byte
    
    ; -- rts
    lda #$60               ; rts
    jsr add_code_byte

    rts
    
    
    .if(DEBUG)
; Note: DEBUG_VALUE should contain the value of y to be compared with
generate_loop_at_y_equals:

    ; Since we are about to do a debug-compare, we have to store the carry bit (in the stack)
    ; -- php --
    lda #$08
    jsr add_code_byte

    ; -- cpy --
    lda #$C0
    jsr add_code_byte
    
    lda DEBUG_VALUE
    jsr add_code_byte
    
    ; -- beq loop (itself)
    lda #$F0               ; beq ...
    jsr add_code_byte

    lda #$FE               ; jump 2 steps back (so to itself)
    jsr add_code_byte
    
    ; Since we are about to do a debug-compare, we have to restore the carry bit (in the stack)
    ; -- plp --
    lda #$28
    jsr add_code_byte
    
    rts
    .endif


    .if(DEBUG)
; Note: DEBUG_VALUE should contain the value of y to be compared with
generate_stp_at_y_equals:

    ; Since we are about to do a debug-compare, we have to store the carry bit (in the stack)
    ; -- php --
    lda #$08
    jsr add_code_byte

    ; -- cpy --
    lda #$C0
    jsr add_code_byte
    
    lda DEBUG_VALUE
    jsr add_code_byte
    
    ; -- bne skip_stp
    lda #$D0               ; bne ...
    jsr add_code_byte

    .if(1)
        lda #$04               ; jump 4 step ahead (skipping the stp and the lda)
    .else
        lda #$01               ; jump 1 step ahead (skipping the stp)
    .endif
    jsr add_code_byte
    
    ; -- stp --
    lda #$DB
    jsr add_code_byte
    
    .if(1)
        ; -- lda $9F2B (FILL_LENGTH_LOW)
        lda #$AD               ; lda ....
        jsr add_code_byte

        lda #$2B               ; $2B
        jsr add_code_byte
        
        lda #$9F               ; $9F
        jsr add_code_byte
    .endif
    
    ; Since we are about to do a debug-compare, we have to restore the carry bit (in the stack)
    ; -- plp --
    lda #$28
    jsr add_code_byte
    
    rts
    .endif


    .if(DEBUG)
generate_infinite_loop_code:

    ; -- bra --
    lda #$80
    jsr add_code_byte
    
    lda #$FE           ; jump 2 steps back (so to itself)
    jsr add_code_byte
    
    rts
    .endif
    
    .if(DEBUG)
generate_stp_code:

    ; -- stp --
    lda #$DB
    jsr add_code_byte
    
    rts
    .endif
 
generate_rts_code:

    ; -- rts --
    lda #$60
    jsr add_code_byte
    
    rts
  
