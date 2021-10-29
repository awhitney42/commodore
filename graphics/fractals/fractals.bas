   10 rem *** fractals
  100 rem set vic address
  110 v = 53248
  120 rem set graphic ram address
  130 ga = 8192
  140 rem set video ram address
  150 vr = 1024
  160 rem set border to black
  170 poke v+32,0
  500 gosub 20000 : rem turn on hires
  510 gosub 21000 : rem graphic ram area
  520 gosub 22000 : rem set color ram
  530 gosub 23000 : rem clr graphic ram
 1000 rem plot fractal pixels
 1005 rem xc=10:yc=10:rem debug pixel
 1006 rem gosub 30000:rem debug plot point
 1009 rem end:rem debug
 1010 cr = - .25:ci = .65
 1020 for xc = 0 to 279
 1030 r = (xc - 139) / 90
 1040 for yc = 0 to 191
 1050 zi = (95 - yc) / 90
 1060 zr = r : k = 0
 1070 t = zr * zr - zi * zi + cr
 1080 zi = 2 * zr * zi + ci
 1090 zr = t : k = k+1
 1100 if k = 50 then gosub 30000 : goto 1120 : rem plot (xc, yc)
 1110 if abs(zr) < 2 then 1070
 1120 next yc
 1130 next xc
 1140 poke 198,0 : wait 198,0
 1150 gosub 24000
 1160 end
 20000 rem code from "graphics book for the commodore 64" by axel plenge
 20005 rem turn on hi res graphics
 20010 rem   1. set bits 5/6 of v+17
 20020 rem   2. clr bits 4 of v+22
 20030 poke v+17,peek(v+17) or (11*16):rem graphics on
 20040 poke v+22,peek(v+22) and (255-16):rem multi-color off
 20050 poke v+24,peek(v+24) or 8:rem graphics at $2000 (8192)
 20060 return
 21000 rem set graphic ram area
 21010 rem   1. set bit 3 of v+24
 21020 poke v+24, peek(v+24) or 8
 21030 return
 22000 rem set color ram
 22010 rem   1. color ram is 1024-2023
 22020 rem   2. set background 0 - black
 22030 rem   3. set foreground 4 - purple
 22040 co = 4*16 + 0
 22050 for i = vr to vr+1000
 22060 poke i,co
 22070 next i
 22080 return
 23000 rem clear graphic ram
 23010 rem   1. graphic ram is ga to
 23020 rem        ga + 8000
 23030 for i = ga to ga + 8000
 23040 poke i,0
 23050 next i
 23060 return
 23922 poke v+22,peek(v+22) and (255-16):rem multi-color off
 24000 rem turn graphics off
 24010 rem   1. clr bits 5/6 of v+17
 24020 rem   2. clr bit 4 of v+22
 24030 rem   3. clr bit 3 of v+24
 24040 poke v+17,peek(v+17) and (255-96):rem graphics off
 23922 poke v+22,peek(v+22) and (255-16)
 24060 poke v+24,peek(v+24) and (255-8):rem character set back to $1000 (4096)
 24070 return
 30000 rem set pixel
 30010 ra = 320*int(yc/8)+(yc and 7)
 30020 ba = 8*int(xc/8)
 30030 ma = 2^(7-(xc and 7))
 30040 ad = ga + ra + ba
 30050 poke ad,peek(ad) or ma
 30060 return
 31000 rem clr pixel
 31010 ra = 320*int(yc/8)+(yc and 7)
 31020 ba = 8,int(xc/8)
 31030 ma = 255-2^(7-(xc and 7))
 31040 ad = ga + ra + ba
 31050 poke ad,peek(ad) or ma
 31060 return

