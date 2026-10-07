; fractals.asm
;
; 6502 port of fractals.bas. draws the
; julia set for c = -0.25 + 0.65i in
; hi-res (bitmap) mode, then waits for
; a key and returns to basic.
;
; run with: sys 49152
;
; math is 16-bit signed fixed point in
; 4.12 format (sign + 3 integer bits +
; 12 fraction bits): 1.0 = $1000,
; 2.0 = $2000, -2.0 = $e000.

         *= $c000

; vic-ii registers
scrctl1  = $d011 ; v+17
scrctl2  = $d016 ; v+22
memctl   = $d018 ; v+24
border   = $d020 ; v+32

; commodore 64 addresses
ga       = $2000 ; graphic ram (8192)
vr       = $0400 ; video ram (1024)
ndx      = $c6   ; keys in buffer (198)
chrout   = $ffd2

; tables built at run time
ylo      = $c800 ; row addr lo, y 0-191
yhi      = $c900 ; row addr hi, y 0-191
bits     = $ca00 ; pixel masks 128..1

; zero page (basic fac/temp area,
; free while this program runs)
mcnd     = $57 ; multiplicand (2)
mplr     = $59 ; multiplier (2)
prod     = $5b ; product (4)
res      = $5c ; product >> 12 (2)
sign     = $5f ; sign of product
zr       = $60 ; real part (2)
zi       = $62 ; imaginary part (2)
tr       = $64 ; t (2)
k        = $66 ; iteration count
yc       = $67 ; pixel y, 0-191
xc       = $68 ; pixel x, 0-279 (2)
xacc     = $6a ; zr start, 24-bit (3)
yacc     = $6d ; zi start, 24-bit (3)
ptr      = $fb ; pointer (2)

; constants, 4.12 fixed point
crlo     = $00 ; cr = -0.25 = $fc00
crhi     = $fc
cilo     = $66 ; ci = 0.65 = $0a66
cihi     = $0a
maxk     = 50  ; iterations to plot

; start values are 24-bit, 1.0 = $100000
; so the top two bytes are 4.12 values.
; step = 1/90, x0 = -139/90, y0 = 95/90
steplo   = $83 ; 11651 = $002d83
stephi   = $2d
x0lo     = $f5 ; -1619467 = $e749f5
x0md     = $49
x0hi     = $e7
y0lo     = $8e ; 1106830 = $10e38e
y0md     = $e3
y0hi     = $10

start
         lda #$00
         sta border ; border black

         jsr hireson  ; turn on hires
         jsr setcolor ; set color ram
         jsr clrgfx   ; clr graphic ram
         jsr mktabs   ; build tables

; plot fractal pixels

         lda #$00     ; for xc = 0
         sta xc
         sta xc+1
         lda #x0lo    ; r = -139/90
         sta xacc
         lda #x0md
         sta xacc+1
         lda #x0hi
         sta xacc+2

xloop
         lda #$00     ; for yc = 0
         sta yc
         lda #y0lo    ; zi = 95/90
         sta yacc
         lda #y0md
         sta yacc+1
         lda #y0hi
         sta yacc+2

yloop
         lda xacc+1   ; zr = r
         sta zr
         lda xacc+2
         sta zr+1
         lda yacc+1   ; zi = (95-yc)/90
         sta zi
         lda yacc+2
         sta zi+1
         lda #$00     ; k = 0
         sta k

iter
         ; if abs(zi) >= 2.5 then
         ; zr*zr-zi*zi < -2.5, so zr
         ; will escape. this also keeps
         ; the math from overflowing.
         lda zi+1
         bmi zineg
         cmp #$28
         bcc zisok
         jmp bigzi
zineg    cmp #$d8
         bcs zisok
         jmp bigzi
zisok
         ; t = zr*zr - zi*zi + cr
         ;   = (zr+zi)*(zr-zi) + cr
         clc
         lda zr
         adc zi
         sta mcnd
         lda zr+1
         adc zi+1
         sta mcnd+1
         sec
         lda zr
         sbc zi
         sta mplr
         lda zr+1
         sbc zi+1
         sta mplr+1
         jsr smul
         clc
         lda res
         adc #crlo
         sta tr
         lda res+1
         adc #crhi
         sta tr+1

         ; zi = 2*zr*zi + ci
         lda zr
         sta mcnd
         lda zr+1
         sta mcnd+1
         lda zi
         sta mplr
         lda zi+1
         sta mplr+1
         jsr smul
         ; if abs(zr*zi) >= 2 then
         ; 2*zr*zi would overflow, but
         ; zi is big so zr escapes on
         ; the next pass anyway
         lda res+1
         bmi pneg
         cmp #$20
         bcs pbig
         bcc pok
pneg     cmp #$e0
         bcs pok
pbig     lda #$00     ; zi = 3.0
         sta zi
         lda #$30
         sta zi+1
         jmp setzr
pok      asl res
         rol res+1
         clc
         lda res
         adc #cilo
         sta zi
         lda res+1
         adc #cihi
         sta zi+1

setzr    lda tr       ; zr = t
         sta zr
         lda tr+1
         sta zr+1
         inc k        ; k = k+1
         lda k
         cmp #maxk    ; if k=50 plot
         beq plotit

         ; if abs(zr) < 2 then iter
         lda zr+1
         bmi zrneg
         cmp #$20
         bcs nexty
         jmp iter
zrneg    cmp #$e0
         bcc nexty    ; zr < -2
         bne zrok     ; zr > -2
         lda zr       ; zr=-2 if lo=0
         beq nexty
zrok     jmp iter

bigzi    inc k        ; k = k+1, then
         lda k        ; plot if k = 50,
         cmp #maxk    ; else zr escapes
         bne nexty

plotit   jsr plot     ; plot (xc,yc)

nexty    sec          ; next yc
         lda yacc
         sbc #steplo
         sta yacc
         lda yacc+1
         sbc #stephi
         sta yacc+1
         lda yacc+2
         sbc #$00
         sta yacc+2
         inc yc
         lda yc
         cmp #192
         beq nextx
         jmp yloop

nextx    clc          ; next xc
         lda xacc
         adc #steplo
         sta xacc
         lda xacc+1
         adc #stephi
         sta xacc+1
         lda xacc+2
         adc #$00
         sta xacc+2
         inc xc
         bne nx1
         inc xc+1
nx1      lda xc+1
         cmp #>280
         bne nx2
         lda xc
         cmp #<280
         beq done
nx2      jmp xloop

done     lda #$00     ; poke 198,0
         sta ndx
wkey     lda ndx      ; wait 198,0
         beq wkey
         lda #$00     ; discard the key
         sta ndx
         jsr hiresoff ; graphics off
         lda #147     ; clear screen
         jsr chrout
         rts

; smul
; signed 4.12 multiply:
; res = mcnd * mplr
; destroys mcnd, mplr, x

smul     lda mcnd+1
         eor mplr+1
         sta sign     ; bit 7 = sign
         lda mcnd+1   ; mcnd = abs(mcnd)
         bpl sm1
         sec
         lda #$00
         sbc mcnd
         sta mcnd
         lda #$00
         sbc mcnd+1
         sta mcnd+1
sm1      lda mplr+1   ; mplr = abs(mplr)
         bpl sm2
         sec
         lda #$00
         sbc mplr
         sta mplr
         lda #$00
         sbc mplr+1
         sta mplr+1

         ; unsigned 16x16 = 32-bit
sm2      lda #$00
         sta prod+2
         sta prod+3
         ldx #16
sm3      lsr mplr+1
         ror mplr
         bcc sm4
         lda prod+2   ; add mcnd to hi
         clc
         adc mcnd
         sta prod+2
         lda prod+3
         adc mcnd+1
sm4      ror a        ; shift product
         sta prod+3
         ror prod+2
         ror prod+1
         ror prod
         dex
         bne sm3

         ldx #4       ; res = prod >> 12
sm5      lsr prod+3
         ror prod+2
         ror prod+1
         dex
         bne sm5

         lda sign     ; apply sign
         bpl sm6
         sec
         lda #$00
         sbc res
         sta res
         lda #$00
         sbc res+1
         sta res+1
sm6      rts

; plot
; set pixel (xc,yc)
; ad = ga + 320*int(yc/8) + (yc and 7)
;         + 8*int(xc/8)

plot     ldy yc
         lda ylo,y
         sta ptr
         lda yhi,y
         sta ptr+1
         lda xc
         and #$f8
         clc
         adc ptr
         sta ptr
         lda xc+1
         adc ptr+1
         sta ptr+1
         lda xc
         and #$07
         tax
         ldy #$00
         lda (ptr),y
         ora bits,x
         sta (ptr),y
         rts

; hireson
; code from "graphics book for the
; commodore 64" by axel plenge

hireson  lda scrctl1
         ora #$20     ; bitmap mode on
         sta scrctl1
         lda scrctl2
         and #$ef     ; multi-color off
         sta scrctl2
         lda memctl
         ora #$08     ; bitmap at $2000
         sta memctl
         rts

; hiresoff

hiresoff lda scrctl1
         and #$9f     ; bitmap mode off
         sta scrctl1
         lda scrctl2
         and #$ef     ; multi-color off
         sta scrctl2
         lda memctl
         and #$f7     ; chars at $1000
         sta memctl
         rts

; setcolor
; video ram 1024-2023 holds the
; colors: fg 4 (purple), bg 0 (black)

setcolor lda #$40
         ldx #$00
sc1      sta vr,x
         sta vr+$100,x
         sta vr+$200,x
         sta vr+$2e8,x
         inx
         bne sc1
         rts

; clrgfx
; clear graphic ram ga to ga+7999

clrgfx   lda #<ga
         sta ptr
         lda #>ga
         sta ptr+1
         lda #$00
         ldx #31      ; 31 full pages
         ldy #$00
cg1      sta (ptr),y
         iny
         bne cg1
         inc ptr+1
         dex
         bne cg1
         ldy #$3f     ; plus 64 bytes
cg2      sta (ptr),y
         dey
         bpl cg2
         rts

; mktabs
; build the row address and pixel
; mask tables used by plot

mktabs   lda #<ga     ; ptr = row base
         sta ptr
         lda #>ga
         sta ptr+1
         ldy #$00
mt1      tya
         and #$07
         ora ptr      ; base lo is n*64,
         sta ylo,y    ; so or = add
         lda ptr+1
         sta yhi,y
         tya
         and #$07
         cmp #$07
         bne mt2
         clc          ; next char row
         lda ptr
         adc #<320
         sta ptr
         lda ptr+1
         adc #>320
         sta ptr+1
mt2      iny
         cpy #192
         bne mt1

         lda #$80     ; 2^(7-(xc and 7))
         ldx #$00
mt3      sta bits,x
         inx
         lsr a
         bne mt3
         rts
