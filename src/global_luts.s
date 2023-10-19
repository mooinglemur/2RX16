.export addrl_per_row_4bit
.export addrm_per_row_4bit
.export addrl_per_row_8bit
.export addrm_per_row_8bit
.export addrl_per_row_spr_4bit
.export addrm_per_row_spr_4bit

.segment "RODATA"

addrl_per_row_4bit:
.repeat 30
    .byte $00,$a0,$40,$e0,$80,$20,$c0,$60
.endrepeat

addrm_per_row_4bit:
    .byte $00,$00,$01,$01,$02,$03,$03,$04
    .byte $05,$05,$06,$06,$07,$08,$08,$09
    .byte $0a,$0a,$0b,$0b,$0c,$0d,$0d,$0e
    .byte $0f,$0f,$10,$10,$11,$12,$12,$13
    .byte $14,$14,$15,$15,$16,$17,$17,$18
    .byte $19,$19,$1a,$1a,$1b,$1c,$1c,$1d
    .byte $1e,$1e,$1f,$1f,$20,$21,$21,$22
    .byte $23,$23,$24,$24,$25,$26,$26,$27
    .byte $28,$28,$29,$29,$2a,$2b,$2b,$2c
    .byte $2d,$2d,$2e,$2e,$2f,$30,$30,$31
    .byte $32,$32,$33,$33,$34,$35,$35,$36
    .byte $37,$37,$38,$38,$39,$3a,$3a,$3b
    .byte $3c,$3c,$3d,$3d,$3e,$3f,$3f,$40
    .byte $41,$41,$42,$42,$43,$44,$44,$45
    .byte $46,$46,$47,$47,$48,$49,$49,$4a
    .byte $4b,$4b,$4c,$4c,$4d,$4e,$4e,$4f
    .byte $50,$50,$51,$51,$52,$53,$53,$54
    .byte $55,$55,$56,$56,$57,$58,$58,$59
    .byte $5a,$5a,$5b,$5b,$5c,$5d,$5d,$5e
    .byte $5f,$5f,$60,$60,$61,$62,$62,$63
    .byte $64,$64,$65,$65,$66,$67,$67,$68
    .byte $69,$69,$6a,$6a,$6b,$6c,$6c,$6d
    .byte $6e,$6e,$6f,$6f,$70,$71,$71,$72
    .byte $73,$73,$74,$74,$75,$76,$76,$77
    .byte $78,$78,$79,$79,$7a,$7b,$7b,$7c
    .byte $7d,$7d,$7e,$7e,$7f,$80,$80,$81
    .byte $82,$82,$83,$83,$84,$85,$85,$86
    .byte $87,$87,$88,$88,$89,$8a,$8a,$8b
    .byte $8c,$8c,$8d,$8d,$8e,$8f,$8f,$90
    .byte $91,$91,$92,$92,$93,$94,$94,$95

addrl_per_row_8bit:
.repeat 51
    .byte $00,$40,$80,$c0
.endrepeat

addrm_per_row_8bit:
    .byte $00,$01,$02,$03,$05,$06,$07,$08
    .byte $0a,$0b,$0c,$0d,$0f,$10,$11,$12
    .byte $14,$15,$16,$17,$19,$1a,$1b,$1c
    .byte $1e,$1f,$20,$21,$23,$24,$25,$26
    .byte $28,$29,$2a,$2b,$2d,$2e,$2f,$30
    .byte $32,$33,$34,$35,$37,$38,$39,$3a
    .byte $3c,$3d,$3e,$3f,$41,$42,$43,$44
    .byte $46,$47,$48,$49,$4b,$4c,$4d,$4e
    .byte $50,$51,$52,$53,$55,$56,$57,$58
    .byte $5a,$5b,$5c,$5d,$5f,$60,$61,$62
    .byte $64,$65,$66,$67,$69,$6a,$6b,$6c
    .byte $6e,$6f,$70,$71,$73,$74,$75,$76
    .byte $78,$79,$7a,$7b,$7d,$7e,$7f,$80
    .byte $82,$83,$84,$85,$87,$88,$89,$8a
    .byte $8c,$8d,$8e,$8f,$91,$92,$93,$94
    .byte $96,$97,$98,$99,$9b,$9c,$9d,$9e
    .byte $a0,$a1,$a2,$a3,$a5,$a6,$a7,$a8
    .byte $aa,$ab,$ac,$ad,$af,$b0,$b1,$b2
    .byte $b4,$b5,$b6,$b7,$b9,$ba,$bb,$bc
    .byte $be,$bf,$c0,$c1,$c3,$c4,$c5,$c6
    .byte $c8,$c9,$ca,$cb,$cd,$ce,$cf,$d0
    .byte $d2,$d3,$d4,$d5,$d7,$d8,$d9,$da
    .byte $dc,$dd,$de,$df,$e1,$e2,$e3,$e4
    .byte $e6,$e7,$e8,$e9,$eb,$ec,$ed,$ee
    .byte $f0,$f1,$f2,$f3,$f5,$f6,$f7,$f8
    .byte $fa,$fb,$fc,$fd

addrl_per_row_spr_4bit:
.repeat 8
    .byte $00,$20,$40,$60,$80,$a0,$c0,$e0
.endrepeat

addrm_per_row_spr_4bit:
.repeat 8, i
    .byte i, i, i, i, i, i, i, i
.endrepeat
