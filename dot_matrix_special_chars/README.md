# Dot Matrix Special Characters - Secret Message Demo 

This program demos the creation of a small alphabet of special characters to be printed on a dot matrix printer.

It includes a secret message printed on lines 100 - 180. *Do you have what it takes to decode the message?*

The special character format in this program is specific to an Okidata 120 printer. However, CBM and other dot matrix printers supported this feature with a very similar bitmapping scheme for the dot matrix character values. For example, early CBM printers supported a 7 x 6 dot matrix as can been seen in the book PET/CBM Personal Computer Guide - Second Edition by Adam Osborne and Carroll S. Donahue in Chapter 6: Peripheral Devices on page 330. (See: https://archive.org/details/PET-CBM_Personal_Computer_Guide_2/page/n338/mode/2up)

I attached the manual for the Okidata 120 printer. If you attempt to decode this message or modify it for your own Okidata printer, please note that the dot matrix bit map for special characters shown on page 36 is inverted for the rows. The manual shows row 1 as bit 64, row 2 as bit 32, row 3 as bit 16, etc. This was incorrect, and resulted in the characters printing upside down. In reality row 1 is bit 1, row 2 is bit 2, row 3 is bit 4, etc.
