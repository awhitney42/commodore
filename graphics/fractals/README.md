# Fractals Demo

This program demos calculating and drawing a fractal on screen. It utilizes the high resolution graphics (aka bitmap) mode of the Commodore 64.

Note: This program takes a very long time to run, and take several minutes before anything appears on the screen. Be patient.


## 6502 Assembly Version

`fractals.asm` is a port of `fractals.bas` to 6502 machine language. It assembles to $1000 and is started from BASIC with `SYS 4096`. It draws the same Julia set (c = -0.25 + 0.65i) using 16-bit fixed-point math instead of BASIC floating point, and finishes in about 25 minutes. Press any key when it is done to return to BASIC.
