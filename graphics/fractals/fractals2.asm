; fractals2.asm
;
; zooming julia set, c = -0.25+0.65i,
; in multicolor bitmap mode (160x200).
; pixels are colored by how many
; iterations they took to escape.
;
; sys 4096 - render and zoom:
;   draws a frame and saves it to disk
;   as frame00, frame01, ... then shows
;   a box. move it with the cursor keys
;   or w/a/s/d. + makes it smaller and
;   - larger, for a 2x, 4x or 8x zoom.
;   return zooms into it, q quits.
;   run/stop quits while drawing. it
;   stops after 512x total zoom.
;
; sys 4099 - play back saved frames.
;   any key quits.
;
; run from direct mode, not from a
; basic program: the multiply tables
; overwrite basic memory $0800-$0fff.
;
; math is 32-bit signed fixed point,
; 8.24 format: 1.0 = $01000000.
;
; memory:
;   $0800-$0fff multiply tables
;   $1000-$1bff code
;   $1c00-$1fff variables, tables
;   $2000-$3f3f bitmap
;   $0400-$07e7 screen ram (colors)

         *= $1000

; vic-ii registers
scrctl1  = $d011
scrctl2  = $d016
memctl   = $d018
border   = $d020
bgcol    = $d021

; commodore 64 addresses
ga       = $2000 ; bitmap
gaend    = $3f40 ; end of bitmap + 1
vr       = $0400 ; screen ram
colram   = $d800 ; color ram
ndx      = $c6   ; keys in buffer
stkey    = $91   ; $7f = run/stop down
jiffy    = $a2   ; 1/60 sec clock
lastdev  = $ba   ; last disk device

; kernal routines
setmsg   = $ff90
setlfs   = $ffba
setnam   = $ffbd
chrout   = $ffd2
load     = $ffd5
save     = $ffd8
getin    = $ffe4

; quarter-square tables, f(n)=n*n/4
sq1lo    = $0800 ; f(n), n = 0-511
sq1hi    = $0a00
sq2lo    = $0c00 ; f(abs(n-255))
sq2hi    = $0e00

; variables and tables
xacc     = $1c00 ; pixel x, 8.24 (4)
yacc     = $1c04 ; pixel y, 8.24 (4)
x0       = $1c08 ; view left (4)
y0       = $1c0c ; view top (4)
step     = $1c10 ; y step (4)
xstep    = $1c14 ; x step = 2*step (4)
px       = $1c18 ; pixel x, 0-159
py       = $1c19 ; pixel y, 0-199
pxpos    = $1c1a ; px and 3
colofs   = $1c1b ; 8*int(px/4) (2)
frame    = $1c1d ; frame number
bcol     = $1c1e ; box column, 0-20
brow     = $1c1f ; box row, 0-100
row      = $1c20 ; box row counter
cnt      = $1c21 ; counter
dev      = $1c22 ; disk device
tmp      = $1c23
psign    = $1c24 ; sign of product
tr       = $1c25 ; t (4)
step8    = $1c29 ; 8*step (4)
bsize    = $1c2d ; box size 0-2
zlevel   = $1c2e ; zoom so far, 2^n
bw       = $1c2f ; box width, bytes
bh       = $1c30 ; box height, rows
bw8      = $1c31 ; 8*bw
redge    = $1c32 ; 8*(bw-1)
fname    = $1c40 ; "@0:frame00" (10)
fname2   = $1c43 ; "frame00", no "@0:"
ylo      = $1d00 ; row addr lo (200)
yhi      = $1e00 ; row addr hi (200)
cmask    = $1f00 ; color masks (16)

; zero page
sqp1l    = $22 ; -> sq1lo + a (2)
sqp1h    = $24 ; -> sq1hi + a (2)
sqp2l    = $26 ; -> sq2lo + 255-a (2)
sqp2h    = $28 ; -> sq2hi + 255-a (2)
pb       = $55 ; product byte 0
               ; pb+2 - pb+7 = bytes
               ; 2-7 of the product
res      = $58 ; pb+3, result (4)
mcnd     = $5d ; multiplicand (4)
mplr     = $61 ; multiplier (4)
ml       = $65 ; 8x8 product lo
mh       = $66 ; 8x8 product hi
zr       = $67 ; real part (4)
zi       = $6b ; imaginary part (4)
k        = $6f ; iteration count
maxk     = $70 ; iterations to plot
ptr      = $fb ; pointer (2)
ptr2     = $fd ; pointer (2)

; constants
lastz    = 9     ; stop at 2^9 = 512x
k0       = 50    ; maxk at 1x
kstep    = 20    ; maxk added per 2x
cr0      = $00   ; cr = -0.25
cr1      = $00   ;    = $ffc00000
cr2      = $c0
cr3      = $ff
ci0      = $66   ; ci = 0.65
ci1      = $66   ;    = $00a66666
ci2      = $a6
ci3      = $00
scrcol   = $6e   ; 01=blue 10=lt blue
colcol   = $04   ; 11=purple

         jmp render
         jmp playback

; start view, 8.24: step = 1/90,
; x0 = -160*step, y0 = 100*step
view0    .byte $2e,$d8,$02,$00
         .byte $40,$e3,$38,$fe
         .byte $f8,$71,$1c,$01

; "@0:frame00"
fname0   .byte $40,$30,$3a,$46,$52
         .byte $41,$4d,$45,$30,$30

; box width (bytes) and height (rows)
; for 2x, 4x and 8x zoom
bwtab    .byte 20,10,5
bhtab    .byte 100,50,25

; "no frames" + return
nofrm    .byte $4e,$4f,$20,$46,$52
         .byte $41,$4d,$45,$53,$0d

; ------------------------------------
; render and zoom

render   jsr setup
         ldx #$03
rn1      lda view0,x  ; step
         sta step,x
         lda view0+4,x ; x0
         sta x0,x
         lda view0+8,x ; y0
         sta y0,x
         dex
         bpl rn1
         lda #$00
         sta frame
         sta zlevel
         sta bsize
         lda #k0
         sta maxk

rnframe  jsr gfxon
         jsr draw
         bcs rnquit   ; run/stop
         jsr savefr
         lda zlevel
         cmp #lastz
         beq rnlast
         jsr select
         bcs rnquit   ; q
         jsr zoom
         inc frame
         jmp rnframe

rnlast   jsr waitkey
rnquit   jmp gfxoff

; ------------------------------------
; play back frames saved by render

playback jsr setup
         jsr gfxon
pbstart  lda #$00
         sta frame
pbnext   jsr loadfr
         bcs pbend
         lda #120     ; show 2 seconds
         jsr delay
         bcs pbquit   ; key pressed
         inc frame
         jmp pbnext
pbend    lda frame    ; nothing loaded?
         beq pbnone
         lda #180     ; pause, then
         jsr delay    ; play again
         bcc pbstart
pbquit   jmp gfxoff
pbnone   jsr gfxoff
         ldx #$00
pb1      lda nofrm,x
         jsr chrout
         inx
         cpx #10
         bne pb1
         rts

; ------------------------------------
; draw one frame
; returns carry set if run/stop

draw     ldx #$03     ; xstep = 2*step
         clc
         lda step
         adc step
         sta xstep
         lda step+1
         adc step+1
         sta xstep+1
         lda step+2
         adc step+2
         sta xstep+2
         lda step+3
         adc step+3
         sta xstep+3
dw1      lda x0,x     ; xacc = x0
         sta xacc,x
         dex
         bpl dw1
         lda #$00
         sta px

dwcol    lda stkey    ; run/stop?
         cmp #$7f
         bne dw2
         sec
         rts
dw2      lda px       ; pxpos, colofs
         and #$03
         sta pxpos
         lda px
         and #$fc
         asl a
         sta colofs
         lda #$00
         rol a
         sta colofs+1
         ldx #$03     ; yacc = y0
dw3      lda y0,x
         sta yacc,x
         dex
         bpl dw3
         lda #$00
         sta py

dwpix    ldx #$03     ; zr = x, zi = y
dw4      lda xacc,x
         sta zr,x
         lda yacc,x
         sta zi,x
         dex
         bpl dw4
         lda #$00     ; k = 0
         sta k

iter
         ; if abs(zi) >= 3, zr*zr-zi*zi
         ; < -2.5, so zr escapes. this
         ; keeps the math in range too.
         lda zi+3
         bmi zineg
         cmp #$03
         bcc zisok
         jmp bigzi
zineg    cmp #$fd
         bcs zisok
         jmp bigzi
zisok
         ; t = (zr+zi)*(zr-zi) + cr
         clc
         lda zr
         adc zi
         sta mcnd
         lda zr+1
         adc zi+1
         sta mcnd+1
         lda zr+2
         adc zi+2
         sta mcnd+2
         lda zr+3
         adc zi+3
         sta mcnd+3
         sec
         lda zr
         sbc zi
         sta mplr
         lda zr+1
         sbc zi+1
         sta mplr+1
         lda zr+2
         sbc zi+2
         sta mplr+2
         lda zr+3
         sbc zi+3
         sta mplr+3
         jsr smul
         clc
         lda res
         adc #cr0
         sta tr
         lda res+1
         adc #cr1
         sta tr+1
         lda res+2
         adc #cr2
         sta tr+2
         lda res+3
         adc #cr3
         sta tr+3

         ; zi = 2*zr*zi + ci
         ldx #$03
it1      lda zr,x
         sta mcnd,x
         lda zi,x
         sta mplr,x
         dex
         bpl it1
         jsr smul
         asl res
         rol res+1
         rol res+2
         rol res+3
         clc
         lda res
         adc #ci0
         sta zi
         lda res+1
         adc #ci1
         sta zi+1
         lda res+2
         adc #ci2
         sta zi+2
         lda res+3
         adc #ci3
         sta zi+3

         ldx #$03     ; zr = t
it2      lda tr,x
         sta zr,x
         dex
         bpl it2
         inc k        ; k = k+1
         lda k
         cmp maxk     ; inside the set?
         beq inside

         ; if abs(zr) < 2 then iter
         lda zr+3
         bmi zrneg
         cmp #$02
         bcs escaped
         jmp iter
zrneg    cmp #$fe
         bcc escaped  ; zr < -2
         bne zrok     ; zr > -2
         lda zr+2     ; zr = -2 if the
         ora zr+1     ; low bytes are 0
         ora zr
         beq escaped
zrok     jmp iter

bigzi    inc k        ; k = k+1, then
         lda k        ; inside if maxk,
         cmp maxk     ; else zr escapes
         bne escaped

inside   lda #$03     ; color 3, purple
         bne dwplot

escaped  lda k        ; fast escape:
         cmp #$04     ; leave black
         bcc dwnext
         lsr a        ; else stripes of
         and #$01     ; colors 1 and 2,
         clc          ; 2 iterations
         adc #$01     ; wide
dwplot   jsr plot

dwnext   sec          ; next py
         ldx #$00
         ldy #$04
dw5      lda yacc,x
         sbc step,x
         sta yacc,x
         inx
         dey
         bne dw5
         inc py
         lda py
         cmp #200
         beq dw6
         jmp dwpix

dw6      clc          ; next px
         ldx #$00
         ldy #$04
dw7      lda xacc,x
         adc xstep,x
         sta xacc,x
         inx
         dey
         bne dw7
         inc px
         lda px
         cmp #160
         beq dw8
         jmp dwcol
dw8      clc
         rts

; ------------------------------------
; plot
; set pixel (px,py) to color a (0-3)

plot     asl a        ; x = 4*color
         asl a        ;   + pxpos
         ora pxpos
         tax
         ldy py
         lda ylo,y
         clc
         adc colofs
         sta ptr
         lda yhi,y
         adc colofs+1
         sta ptr+1
         ldy #$00
         lda (ptr),y
         ora cmask,x
         sta (ptr),y
         rts

; ------------------------------------
; smul
; signed 8.24 multiply:
; res = mcnd * mplr

smul     lda mcnd+3
         eor mplr+3
         sta psign    ; bit 7 = sign
         lda mcnd+3   ; mcnd=abs(mcnd)
         bpl sm1
         ldx #mcnd
         jsr neg32
sm1      lda mplr+3   ; mplr=abs(mplr)
         bpl sm2
         ldx #mplr
         jsr neg32
sm2      jsr umul
         lda psign    ; apply sign
         bpl sm3
         ldx #res
         jsr neg32
sm3      rts

; neg32
; negate the 32-bit number at zero
; page address x

neg32    sec
         lda #$00
         sbc $00,x
         sta $00,x
         lda #$00
         sbc $01,x
         sta $01,x
         lda #$00
         sbc $02,x
         sta $02,x
         lda #$00
         sbc $03,x
         sta $03,x
         rts

; ------------------------------------
; umul
; unsigned 32x32 multiply, keeping
; bytes 3-6 of the product (>> 24).
; it adds up the 8x8 products ai*bj
; with i+j >= 2. the rest only reach
; byte 3 by a carry, so they are
; skipped (at most 2 lsb low).

umul     lda #$00
         ldx #$05
um1      sta pb+2,x
         dex
         bpl um1

         lda mcnd     ; a0 * b2, b3
         beq um2
         jsr mset
         ldx #$02
         ldy mplr+2
         jsr mqadd
         ldx #$03
         ldy mplr+3
         jsr mqadd

um2      lda mcnd+1   ; a1 * b1, b2, b3
         beq um3
         jsr mset
         ldx #$02
         ldy mplr+1
         jsr mqadd
         ldx #$03
         ldy mplr+2
         jsr mqadd
         ldx #$04
         ldy mplr+3
         jsr mqadd

um3      lda mcnd+2   ; a2 * b0 - b3
         beq um4
         jsr mset
         ldx #$02
         ldy mplr
         jsr mqadd
         ldx #$03
         ldy mplr+1
         jsr mqadd
         ldx #$04
         ldy mplr+2
         jsr mqadd
         ldx #$05
         ldy mplr+3
         jsr mqadd

um4      lda mcnd+3   ; a3 * b0 - b3
         beq um5
         jsr mset
         ldx #$03
         ldy mplr
         jsr mqadd
         ldx #$04
         ldy mplr+1
         jsr mqadd
         ldx #$05
         ldy mplr+2
         jsr mqadd
         ldx #$06
         ldy mplr+3
         jsr mqadd
um5      rts

; mset
; point the table pointers at a
; for a multiplicand byte a

mset     sta sqp1l
         sta sqp1h
         eor #$ff
         sta sqp2l
         sta sqp2h
         rts

; mqadd
; a*y by quarter squares:
;   a*y = f(a+y) - f(abs(y-a))
; then add it to product byte x.
; y is loaded just before the jsr,
; so z set means y = 0: skip it.

mqadd    beq mq2
         sec
         lda (sqp1l),y
         sbc (sqp2l),y
         sta ml
         lda (sqp1h),y
         sbc (sqp2h),y
         sta mh
         clc
         lda ml
         adc pb,x
         sta pb,x
         lda mh
         adc pb+1,x
         sta pb+1,x
         bcc mq2
         inc pb+2,x   ; carry
         bne mq2
         inc pb+3,x
mq2      rts

; ------------------------------------
; select
; move and size the zoom box.
; returns carry clear to zoom, set
; to quit.

select   lda #$00
         sta ndx      ; flush keys
         jsr maxsize  ; keep the size
         cmp bsize    ; within 512x
         bcs se0
         sta bsize
se0      jsr setbox
         lda #40      ; center the box
         sec
         sbc bw
         lsr a
         sta bcol
         lda #200
         sec
         sbc bh
         lsr a
         sta brow
         jsr xorbox
se1      jsr getin
         cmp #$00
         beq se1
         cmp #$0d     ; return
         beq sezoom
         cmp #$51     ; q
         beq sequit
         cmp #$2b     ; +
         beq sesmall
         cmp #$2d     ; -
         beq sebig
         cmp #$91     ; crsr up
         beq seup
         cmp #$57     ; w
         beq seup
         cmp #$11     ; crsr down
         beq sedown
         cmp #$53     ; s
         beq sedown
         cmp #$9d     ; crsr left
         beq seleft
         cmp #$41     ; a
         beq seleft
         cmp #$1d     ; crsr right
         beq seright
         cmp #$44     ; d
         beq seright
         jmp se1

sezoom   clc
         rts
sequit   sec
         rts

sesmall  jsr maxsize  ; already the
         cmp bsize    ; smallest box?
         beq se1
         bcc se1
         ldx bsize
         inx
         jmp resize
sebig    ldx bsize    ; already the
         beq se1      ; largest box?
         dex
         jmp resize

seup     jsr xorbox   ; erase
         lda brow
         sec
         sbc #$04
         bcs se2
         lda #$00
se2      sta brow
         jmp sedraw
sedown   jsr xorbox
         lda #200     ; tmp = last row
         sec
         sbc bh
         sta tmp
         lda brow
         clc
         adc #$04
         cmp tmp
         bcc se3
         lda tmp
se3      sta brow
         jmp sedraw
seleft   jsr xorbox
         lda bcol
         beq sedraw
         dec bcol
         jmp sedraw
seright  jsr xorbox
         lda #40      ; last column
         sec
         sbc bw
         cmp bcol
         beq sedraw
         inc bcol
sedraw   jsr xorbox   ; draw
         jmp se1

; resize
; change the box to size x, keeping
; its center where it was

resize   txa
         pha
         jsr xorbox   ; erase
         lda bw       ; cnt = mid col
         lsr a
         clc
         adc bcol
         sta cnt
         lda bh       ; row = mid row
         lsr a
         clc
         adc brow
         sta row
         pla
         sta bsize
         jsr setbox
         lda bw       ; bcol = cnt-bw/2
         lsr a
         sta tmp
         lda cnt
         sec
         sbc tmp
         bcs rs1
         lda #$00     ; off the left
rs1      sta bcol
         lda #40      ; off the right?
         sec
         sbc bw
         cmp bcol
         bcs rs2
         sta bcol
rs2      lda bh       ; brow = row-bh/2
         lsr a
         sta tmp
         lda row
         sec
         sbc tmp
         bcs rs3
         lda #$00     ; off the top
rs3      sta brow
         lda #200     ; off the bottom?
         sec
         sbc bh
         cmp brow
         bcs rs4
         sta brow
rs4      jmp sedraw

; maxsize
; a = largest box size that keeps the
; total zoom within 2^lastz

maxsize  lda #lastz-1
         sec
         sbc zlevel
         cmp #$03
         bcc ms1
         lda #$02
ms1      rts

; setbox
; set bw, bh, bw8 and redge for the
; box size in bsize

setbox   ldx bsize
         lda bwtab,x
         sta bw
         lda bhtab,x
         sta bh
         lda bw
         asl a
         asl a
         asl a
         sta bw8
         sec
         sbc #$08
         sta redge
         rts

; xorbox
; draw or erase the zoom box, bw
; bytes by bh rows, at byte column
; bcol and row brow, by xor-ing the
; bitmap.

xorbox   ldy brow     ; top edge
         jsr xbline
         lda brow     ; bottom edge
         clc
         adc bh
         sec
         sbc #$01
         tay
         jsr xbline
         lda brow     ; sides
         sta row
         lda bh
         sec
         sbc #$02
         sta cnt
xb1      inc row
         ldy row
         jsr xbaddr
         ldy #$00     ; left pixel
         lda (ptr),y
         eor #$c0
         sta (ptr),y
         ldy redge    ; right pixel
         lda (ptr),y
         eor #$03
         sta (ptr),y
         dec cnt
         bne xb1
         rts

xbline   jsr xbaddr   ; bw bytes, row y
         ldy #$00
xbl1     lda (ptr),y
         eor #$ff
         sta (ptr),y
         tya
         clc
         adc #$08
         tay
         cpy bw8
         bne xbl1
         rts

xbaddr   lda #$00     ; ptr = row y
         sta ptr+1    ;   + 8*bcol
         lda bcol
         asl a
         asl a
         asl a        ; can carry out
         rol ptr+1
         clc
         adc ylo,y
         sta ptr
         lda yhi,y
         adc ptr+1
         sta ptr+1
         rts

; ------------------------------------
; zoom
; the box becomes the new view:
;   x0 = x0 + 8*bcol*step
;   y0 = y0 - brow*step
; then step is halved 1-3 times, by
; box size, adding kstep to maxk each
; time.

zoom     ldx #$03     ; step8 = 8*step
zm0      lda step,x
         sta step8,x
         dex
         bpl zm0
         ldx #$03
zm0a     asl step8
         rol step8+1
         rol step8+2
         rol step8+3
         dex
         bne zm0a
         lda bcol
         sta cnt
         beq zm2
zm1      clc
         ldx #$00
         ldy #$04
zm1a     lda x0,x
         adc step8,x
         sta x0,x
         inx
         dey
         bne zm1a
         dec cnt
         bne zm1
zm2      lda brow
         sta cnt
         beq zm4
zm3      sec
         ldx #$00
         ldy #$04
zm3a     lda y0,x
         sbc step,x
         sta y0,x
         inx
         dey
         bne zm3a
         dec cnt
         bne zm3
zm4      ldx bsize    ; halve bsize+1
         inx          ; times
zm5      lsr step+3
         ror step+2
         ror step+1
         ror step
         inc zlevel
         clc
         lda maxk
         adc #kstep
         sta maxk
         dex
         bne zm5
         rts

; ------------------------------------
; disk

; mkname
; put the frame number in fname

mkname   ldx #$09
mn1      lda fname0,x
         sta fname,x
         dex
         bpl mn1
         lda frame
mn2      cmp #10      ; tens digit
         bcc mn3
         sbc #10
         inc fname+8
         jmp mn2
mn3      clc          ; ones digit
         adc #$30
         sta fname+9
         rts

; savefr
; save the bitmap as "@0:frameNN".
; if it fails the border turns red.

savefr   jsr mkname
         lda #10
         ldx #<fname
         ldy #>fname
         jsr setnam
         lda #$00
         ldx dev
         ldy #$00
         jsr setlfs
         lda #<ga
         sta ptr
         lda #>ga
         sta ptr+1
         ldx #<gaend
         ldy #>gaend
         lda #ptr
         jsr save
         bcc sv1
         lda #$02     ; red
         sta border
sv1      rts

; loadfr
; load "frameNN" into the bitmap.
; returns carry set if it fails.

loadfr   jsr mkname
         lda #7
         ldx #<fname2
         ldy #>fname2
         jsr setnam
         lda #$01
         ldx dev
         ldy #$01     ; load to $2000
         jsr setlfs
         lda #$00
         jsr load
         rts

; ------------------------------------
; waiting

; waitkey
; wait for a key

waitkey  lda #$00
         sta ndx
wk1      lda ndx
         beq wk1
         lda #$00
         sta ndx
         rts

; delay
; wait a jiffies (1/60 sec).
; returns carry set if a key was hit.

delay    clc
         adc jiffy
         sta tmp
dl1      jsr getin
         cmp #$00
         bne dl2
         lda jiffy
         cmp tmp
         bne dl1
         clc
         rts
dl2      sec
         rts

; ------------------------------------
; graphics on and off

; gfxon
; clear the bitmap, set the colors
; and turn on multicolor bitmap mode

gfxon    lda #$00
         sta border
         sta bgcol    ; 00 = black

         lda #<ga     ; clear bitmap
         sta ptr
         lda #>ga
         sta ptr+1
         lda #$00
         ldx #31      ; 31 full pages
         ldy #$00
gn1      sta (ptr),y
         iny
         bne gn1
         inc ptr+1
         dex
         bne gn1
         ldy #$3f     ; plus 64 bytes
gn2      sta (ptr),y
         dey
         bpl gn2

         ldx #$00     ; colors
gn3      lda #scrcol
         sta vr,x
         sta vr+$100,x
         sta vr+$200,x
         sta vr+$2e8,x
         lda #colcol
         sta colram,x
         sta colram+$100,x
         sta colram+$200,x
         sta colram+$2e8,x
         inx
         bne gn3

         lda scrctl1
         ora #$20     ; bitmap mode on
         sta scrctl1
         lda scrctl2
         ora #$10     ; multicolor on
         sta scrctl2
         lda memctl
         ora #$08     ; bitmap at $2000
         sta memctl
         rts

; gfxoff
; back to text mode and basic

gfxoff   lda scrctl1
         and #$9f     ; bitmap mode off
         sta scrctl1
         lda scrctl2
         and #$ef     ; multicolor off
         sta scrctl2
         lda memctl
         and #$f7     ; chars at $1000
         sta memctl
         lda #14      ; default colors
         sta border
         lda #6
         sta bgcol
         lda #$00     ; empty basic
         sta $0800    ; program, since
         sta $0801    ; the tables used
         sta $0802    ; that memory
         lda #$00
         sta ndx
         lda #147     ; clear screen
         jmp chrout

; ------------------------------------
; setup
; build tables, set the disk device
; and turn off kernal messages

setup    lda #$00
         jsr setmsg
         lda lastdev  ; last device,
         bne su1      ; or 8
         lda #$08
su1      sta dev

         lda #>sq1lo  ; table pointers
         sta sqp1l+1
         lda #>sq1hi
         sta sqp1h+1
         lda #>sq2lo
         sta sqp2l+1
         lda #>sq2hi
         sta sqp2h+1

         ; f(n) = n*n/4 for n = 0-511,
         ; with f(n+1) = f(n) + (n+1)/2
         lda #<sq1lo
         sta ptr
         lda #>sq1lo
         sta ptr+1
         lda #<sq1hi
         sta ptr2
         lda #>sq1hi
         sta ptr2+1
         lda #$00
         sta ml       ; f lo
         sta mh       ; f hi
         sta cnt      ; n hi
         tay          ; n lo
su2      lda ml
         sta (ptr),y
         lda mh
         sta (ptr2),y
         iny          ; n = n+1
         bne su3
         inc cnt
         inc ptr+1
         inc ptr2+1
su3      lda cnt      ; a = n/2
         lsr a
         tya
         ror a
         clc          ; f = f + n/2
         adc ml
         sta ml
         bcc su4
         inc mh
su4      lda cnt
         cmp #$02
         bne su2

         ; f(abs(n-255)) for n = 0-511
         ldy #$00
su5      tya          ; n < 256: 255-n
         eor #$ff
         tax
         lda sq1lo,x
         sta sq2lo,y
         lda sq1hi,x
         sta sq2hi,y
         lda sq1lo+1,y ; n>=256: n-255
         sta sq2lo+$100,y
         lda sq1hi+1,y
         sta sq2hi+$100,y
         iny
         bne su5

         ; bitmap row addresses
         lda #<ga
         sta ptr
         lda #>ga
         sta ptr+1
         ldy #$00
su6      tya
         and #$07
         ora ptr      ; base lo is n*64
         sta ylo,y
         lda ptr+1
         sta yhi,y
         tya
         and #$07
         cmp #$07
         bne su7
         clc          ; next char row
         lda ptr
         adc #<320
         sta ptr
         lda ptr+1
         adc #>320
         sta ptr+1
su7      iny
         cpy #200
         bne su6

         ; cmask(4*c+p) = c shifted to
         ; pixel p of a byte (0 = left)
         ldx #$00
su8      txa          ; c = x/4
         lsr a
         lsr a
         sta tmp
         txa          ; shift 6-2*p
         and #$03
         eor #$03
         asl a
         tay
         lda tmp
su9      dey
         bmi su10
         asl a
         jmp su9
su10     sta cmask,x
         inx
         cpx #16
         bne su8
         rts
