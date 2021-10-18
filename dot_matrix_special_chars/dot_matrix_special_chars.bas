   10 rem dot matrix special characters demo
   20 rem can you decode the secret message?   
   30 x=25: rem number of special chars
   35 gosub 1000
   40 open 1,4:rem open printer
   50 print#1,chr$(27);"p" :rem normal density okidata 120
   55 print#1,chr$(8); :rem start graphics okidata 120
  100 rem print message
  110 print#1,ch$(1);ch$(2);ch$(3);ch$(4);chr$(13)
  115 print#1,ch$(1);ch$(5);ch$(6);ch$(7);
  120 print#1,ch$(8);ch$(2);ch$(9);ch$(8);chr$(13)
  125 print#1,ch$(25);ch$(4);ch$(7);
  130 print#1,ch$(11);ch$(15);ch$(12);ch$(7);
  135 print#1,ch$(14);ch$(16);chr$(13)
  140 print#1,ch$(11);ch$(7);
  145 print#1,ch$(25);ch$(12);ch$(5);ch$(7);
  150 print#1,ch$(13);ch$(14);ch$(18);chr$(13)
  155 print#1,ch$(17);ch$(15);ch$(19);ch$(20);ch$(7);
  160 print#1,ch$(14);ch$(21);ch$(12);ch$(4);chr$(13)
  165 print#1,ch$(14);ch$(22);ch$(6);ch$(23);chr$(13)
  170 print#1,ch$(24);ch$(25);ch$(24);ch$(25);ch$(24)
  180 print#1,chr$(13)
  880 print#1,chr$(15);: rem exit graphics okidata 120
  890 close 1:rem close printer
  900 end
 1000 rem special characters
 1005 rem
 1010 data 0,127,18,9,4,3,0
 1015 rem
 1020 data 0,0,0,127,0,0,0
 1025 rem
 1030 data 0,127,1,2,4,120,0
 1035 rem
 1040 data 0,127,2,4,2,127,0
 1045 rem
 1050 data 64,68,42,17,42,68,64
 1055 rem
 1060 data 0,4,2,127,2,4,0
 1065 rem
 1070 data 0,0,0,8,0,0,0
 1075 rem
 1080 data 0,127,10,20,40,127,0
 1085 rem
 1090 data 65,34,20,8,20,34,65
 1095 rem
 1100 data 0,127,34,20,20,8,0
 1105 rem
 1110 data 127,34,20,8,20,34,127
 1115 rem
 1120 data 0,127,17,42,68,0,0
 1125 rem
 1130 data 127,17,10,4,10,17,127
 1135 rem
 1140 data 0,127,9,18,36,0,0
 1145 rem
 1150 data 0,127,9,18,36,18,0
 1155 rem
 1160 data 0,2,4,127,8,16,0
 1165 rem
 1170 data 0,127,17,10,4,0,0
 1175 rem
 1180 data 0,127,9,114,20,124,0
 1185 rem
 1190 data 0,127,2,4,8,0,0
 1195 rem
 1200 data 0,127,8,8,16,96,0
 1205 rem
 1210 data 0,127,73,42,20,0,0
 1215 rem
 1220 data 0,31,8,4,126,0,0
 1225 rem
 1230 data 0,0,0,42,0,0,0
 1235 rem
 1240 data 0,0,0,64,0,0,0
 1245 rem
 1250 data 0,127,20,20,8,0,0
 1890 dim ch$(x)
 1900 for i=1 to x : rem load characters
 1910 ch$(i)=""
 1920 for j=1 to 7
 1930 read c
 1940 ch$(i)=ch$(i)+chr$(c+128)
 1950 next j
 1960 next i
 1970 return

