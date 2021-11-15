         *= $033c

         lda #$00  ; no filename
         ldx #$00
         ldy #$00
         jsr $ffbd ; setnam

         lda #$05 ; file #
         ldx #$02 ; 2 = rs-232 device
         ldy #$00 ; no cmd
         jsr $ffba ; setlfs

         lda #$08 ; 1200 baud, 8 bits
         sta $0293 ; serial control reg

         lda #$00; fullduplex, no parity
         sta $0294 ; serial command reg

         jsr $ffc0 ; open

         ldx #$05
         jsr $ffc9 ; chkout

         lda #$41
         jsr $ffd2
         lda #$42
         jsr $ffd2
         lda #$43
         jsr $ffd2
         lda #$0d
         jsr $ffd2
         jmp exit

error    clc
         adc #48
         sta $fc
         lda #$05
         jsr $ffcc ; clrchn
         lda $fc
         jsr $ffd2
         lda #13
         jsr $ffd2

exit     jsr $ffcc ; clrchn
         jsr $ffc3 ; close
         rts
