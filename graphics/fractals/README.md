# Fractals Demo

This program demos calculating and drawing a fractal on screen. It utilizes the high resolution graphics (aka bitmap) mode of the Commodore 64.

Note: This program takes a very long time to run, and take several minutes before anything appears on the screen. Be patient.


## 6502 Assembly Version

`fractals.asm` is a port of `fractals.bas` to 6502 machine language. It assembles to $1000 and is started from BASIC with `SYS 4096`. It draws the same Julia set (c = -0.25 + 0.65i) using 16-bit fixed-point math instead of BASIC floating point, and finishes in about 25 minutes. Press any key when it is done to return to BASIC.

## Zooming Version

`fractals2.asm` draws the same Julia set in multicolor bitmap mode (160x200), coloring each pixel by how many iterations it took to escape, and lets you zoom in.

- `SYS 4096` renders a frame and saves it to disk as `FRAME00`, `FRAME01`, and so on. A box then appears: move it with the cursor keys or W/A/S/D, press + to make it smaller or - to make it larger (for a 2x, 4x or 8x zoom), RETURN to zoom into it, or Q to quit. RUN/STOP quits while drawing. It stops once the total zoom reaches 512x, which takes from 3 to 9 zooms depending on the box sizes used. If saving fails, the border turns red.
- `SYS 4099` plays back the saved frames in a loop. Press any key to quit.

Run it from direct mode, not from a BASIC program, because its multiply tables use the BASIC program area at $0800-$0FFF.

It uses 32-bit fixed-point math with a table-based (quarter-square) multiply. The first frame takes about 15 minutes; deeper frames take over an hour each because more of the screen is close to the set and the iteration limit rises by 20 for each 2x of zoom (50 at the start, 230 at 512x). Zooming 2x at a time to 512x takes roughly 11 hours; bigger steps skip frames and take less time. Playback speed is limited by the disk drive, about 20 seconds per frame on a stock 1541.
