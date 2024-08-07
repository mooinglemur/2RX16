; == Polygon Filler table gen 8-bit  ==

; To build: cl65 -t cx16 -o POLYGON-FILLER-TABLE-GEN-8BIT.PRG polygon_filler_table_gen_8bit.s
; To run: x16emu.exe -prg POLYGON-FILLER-TABLE-GEN-8BIT.PRG -run
; To create memory dump: CTRL-S

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

   jmp start


; === Zero page addresses ===

; Bank switching
RAM_BANK                  = $00
ROM_BANK                  = $01

; Temp vars
TMP1                      = $02
TMP2                      = $03
TMP3                      = $04
TMP4                      = $05

; For generating jump-table code
END_JUMP_ADDRESS          = $2B ; 2C
START_JUMP_ADDRESS        = $2D ; 2E
CODE_ADDRESS              = $2F ; 30
LOAD_ADDRESS              = $31 ; 32
STORE_ADDRESS             = $33 ; 34

FILL_LENGTH_LOW           = $40
FILL_LENGTH_HIGH          = $41
NUMBER_OF_ROWS            = $42


; Used to generate jump-tables
LEFT_OVER_PIXELS         = $B6 ; B7
NIBBLE_PATTERN           = $B8
NR_OF_FULL_CACHE_WRITES  = $B9
NR_OF_STARTING_PIXELS    = $BA
NR_OF_ENDING_PIXELS      = $BB

GEN_START_X              = $BC
GEN_START_X_ORG          = $BD ; only for 2-bit mode
GEN_START_X_SET_TO_ZERO  = $BE ; only for 2-bit mode
GEN_FILL_LENGTH_LOW      = $BF
GEN_FILL_LENGTH_IS_16_OR_MORE = $C0
GEN_FILL_LENGTH_IS_8_OR_MORE = GEN_FILL_LENGTH_IS_16_OR_MORE
GEN_LOANED_16_PIXELS     = $C1
GEN_LOANED_8_PIXELS = GEN_LOANED_16_PIXELS
GEN_START_X_SUB          = $C2 ; only for 2-bit mode
GEN_FILL_LINE_CODE_INDEX = $C3


; === RAM addresses ===

; -- IMPORTANT: we set the *two* lower bits of (the HIGH byte of) this address in the code, using FILL_LINE_END_JUMP_0 as base. So the distance between the 4 tables should be $100! AND bits 8 and 9 should be 00b! (for FILL_LINE_END_JUMP_0) --
FILL_LINE_END_JUMP_0     = $8400   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_0
FILL_LINE_END_JUMP_1     = $8500   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_1
FILL_LINE_END_JUMP_2     = $8600   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_2
FILL_LINE_END_JUMP_3     = $8700   ; 20 entries (* 4 bytes) of jumps into FILL_LINE_END_CODE_3

; FIXME: can we put these code blocks closer to each other? Are they <= 256 bytes? -> NO, MORE than 256 bytes!!
FILL_LINE_END_CODE_0     = $8800   ; 3 (stz) * 80 (=320/4) = 240                      + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
FILL_LINE_END_CODE_1     = $8A00   ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
FILL_LINE_END_CODE_2     = $8C00   ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?
FILL_LINE_END_CODE_3     = $8E00   ; 3 (stz) * 80 (=320/4) = 240 + lda .. + sta DATA1 + lda DATA0 + lda DATA1 + dey + beq + ldx $9F2B + jmp (..,x) + rts/jmp?

FILL_LINE_START_JUMP     = $9000   ; 256 bytes
FILL_LINE_START_CODE     = $9100   ; 128 different (start of) fill line code patterns -> safe: takes $0D00 bytes  (so this ends before: $9E00)

; === Other constants ===


DEBUG = 0

; Jump table specific constants
TEST_JUMP_TABLE = 0   ; This turns off the iteration in-between the jump-table calls
USE_SOFT_FILL_LEN = 0 ; This turns off reading from 9F2B and 9F2C (for fill length data) and instead reads from USE_SOFT_FILL_LEN-variables
DO_4BIT = 0
DO_2BIT = 0



message: .byte "press ctrl-s to create a memory dump. then rename to polyfill-8bit-dump.bin"
end_msg:

NEWLINE = $0D
UPPERCASE = $8E
CHROUT = $FFD2

start:

    sei
    
    jsr clear_memory
    
    jsr generate_fill_line_end_code
    jsr generate_fill_line_end_jump
    jsr generate_fill_line_start_code_and_jump
    
    jsr print_message
    
    
    ; We are not returning to BASIC here...
infinite_loop:
    jmp infinite_loop
    
    rts
    
    
    
clear_memory:
    
    ; We clear from $2F00 to $9F00 (so $7000 = 7*16*256 bytes)
    
    lda #$00
    sta STORE_ADDRESS
    lda #$2F
    sta STORE_ADDRESS+1
    
    lda #0
    ldx #0
clear_next_block:
    ldy #0
    
clear_next_byte:
    sta (STORE_ADDRESS),y
    iny
    bne clear_next_byte
    
    inc STORE_ADDRESS+1
    
    inx
    cpx #7*16
    bne clear_next_block
    
    rts


    
    
print_message:
    ; print newline
    lda #NEWLINE
    jsr CHROUT
    ; force uppercase
    lda #UPPERCASE
    jsr CHROUT
    ; print message
    lda #<message
    sta TMP1
    lda #>message
    sta TMP1+1
    ldy #0
next_char:
    cpy #(end_msg-message)
    beq chars_done
    lda (TMP1),y
    jsr CHROUT
    iny
    bra next_char
chars_done:
    ; print newline
    lda #NEWLINE
    jsr CHROUT
    rts
    

; this is used by the gen-code    
add_code_byte:
    sta (CODE_ADDRESS),y   ; store code byte at address (located at CODE_ADDRESS) + y
    iny                    ; increase y
    cpy #0                 ; if y == 0
    bne done_adding_code_byte
    inc CODE_ADDRESS+1     ; increment high-byte of CODE_ADDRESS
done_adding_code_byte:
    rts
    
    .include "fx_polygon_fill_jump_tables.s"
    .include "fx_polygon_fill_jump_tables_8bit.s"

