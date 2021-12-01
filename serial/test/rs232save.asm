         *= $7000

; memory pointers

; commodore 64 addresses
sob      = $0801 ; start of basic
rs232cmd = $0293 ; serial control reg
rs232ctr = $0294 ; serial command reg
rxbufbeg = $029b ; rx buffer start
rxbufend = $029c ; rx buffer end
txbufbeg = $029d ; tx buffer start
txbufend = $029e ; tx buffer end

; memory data
ptrlo    = $fc ; basic step ptr
ptrhi    = $fd ; basic step ptr
endlo    = $fe ; basic end ptr
endhi    = $ff ; basic end ptr
blenlo   = $22 ; store basic len
blenhi   = $23 ; store basic len

tmp1     = $24
tmp2     = $25

; begin serial connection

serstart
         lda #$00  ; no filename
         ldx #$00
         ldy #$00
         jsr $ffbd ; setnam

         lda #$05 ; logical file #
         ldx #$02 ; 2 = rs-232 device
         ldy #$00 ; no cmd
         jsr $ffba ; setlfs

         ; rs-232 registers

         lda #$08 ; 1200 baud,8 bits
         sta rs232cmd ; ser control reg

         lda #$00 ; fullduplex,no parity
         sta rs232ctr ; ser command reg

         ; open file

         jsr $ffc0 ; open file

         ldx #$05  ; logical file #
         jsr $ffc9 ; chkout
         bcs error

         jsr blen  ; calc basic len
         jsr bsave ; send basic program

         lda #$00
         jsr $ffd2 ; send final kludge
         jsr wait
         jmp exit

error    clc
         adc #48
         sta tmp1
         lda #$05
         jsr $ffcc ; clrchn
         lda tmp1
         jsr $ffd2
         lda #13
         jsr $ffd2

wait     clc
         lda txbufbeg ; tx buffer start
         cmp txbufend ; tx buffer end
         bcc wait
         clc
         lda rxbufbeg ; rx buffer start
         cmp rxbufend ; rx buffer end
         bcc wait
done     rts

exit     jsr $ffcc ; clrchn
         lda #$05; logical file #
         jsr $ffc3 ; close
         rts

; inc16
; Add 1 to a 16-bit pointer in zero page

inc16
         inc ptrlo
         bne inc16end
         inc ptrlo
inc16end rts

bsave
         ldx #<sob
         stx ptrlo
         ldy #>sob
         sty ptrhi

; save loop
         ldx #0
         stx tmp1
sloop
         ldx tmp1
         ldy #0
         lda (ptrlo),y
         cpx #$00
         bne read1
; save start
bsstart
         sta endlo  ; store end lo byte

         ;send header
         lda #0
         jsr $ffd2
         lda #0
         jsr $ffd2
         lda #0
         jsr $ffd2
         lda #$53 ; S
         jsr $ffd2
         lda #$41 ; A
         jsr $ffd2
         lda #$56 ; V
         jsr $ffd2
         lda #$45 ; E
         jsr $ffd2

         ; send length
         lda blenlo ; basic len lo byte
         jsr $ffd2  ; send len lo
         lda blenhi ; basic len hi byte
         jsr $ffd2  ; send len hi

         lda endlo

         ldx tmp1
read1    cpx #$01
         bne read2
         sta endhi  ; store end hi byte
read2               ; read basic program
         inx
         stx tmp1
         jsr $ffd2  ; send basic bytes
         ;jsr hexout
         ;lda #$20
         ;jsr $ffd2
         jsr inc16  ; inc basic step ptr

         ldx ptrhi
         cpx endhi  ; cmp step ptr hi
         bne sloop  ; keep reading
         ldx ptrlo
         cpx endlo  ; cmp step ptr lo
         bne sloop  ; keep reading
         rts        ; done reading

blen
         ldx #<sob  ; lo byte of basic
         stx tmp1
         ldx #>sob  ; hi byte of basic
         stx tmp2
         sec        ; set carry flag
         lda sob    ; first lo byte
         sbc tmp1   ; sub other lo byte
         sta blenlo ; resulting lo byte
         lda sob+1  ; first hi byte
         sbc tmp2   ; carry flg complmnt
         sta blenhi ; resulting hi byte
         rts

hexdig   cmp #$0a  ; alpha digit?
         bcc skip  ; if no, then skip
         adc #$06  ; add seven
skip     adc #$30  ; convert to ascii
         jmp $ffd2 ; print it
         ; no rts, process to hexout

hexout   pha   ; save the byte
         lsr a
         lsr a ; extract 4...
         lsr a ; ...high bits
         lsr a
         jsr hexdig
         pla      ; bring byte back
         and #$0f ; extract low four
         jmp hexdig ; print ascii
