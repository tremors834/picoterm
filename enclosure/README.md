# Case for the LTC1327 converter board

A 3D-printed case for the level converter board in my PicoTerm cable: an
LTC1327CN (in a 28-pin socket) and an AMS1117-3.3 regulator board on a
4 x 6 cm perfboard (measured 60.2 x 40.1 mm, 1.7 mm thick), with three
finished cables: the 3.5 mm plug for the Pocket Pico, the 4-pin DIN plug for
the CoCo 3, and the 5 V wall adapter.

The cables already have their plugs on, so they drop into open slots in the
base's rim and the lid closes the slots. A small window in one long side lets
the regulator board's power LED show through.

## Files

- `ltc1327_case.scad` - the OpenSCAD design. All sizes are numbers at the top
  of the file; set `part` to `base` or `lid_print` and export an STL.
- `ltc1327_base.stl` - the base, ready to print.
- `ltc1327_lid_print.stl` - the lid, already turned upside down for printing.

The sizes fit my board and cables. Measure yours and adjust the numbers (board
size, part heights, cable positions and diameters, LED window) before printing.

## Printing

Printed in PETG on a Flashforge Adventurer 3: 4 shells, 5 top and bottom solid
layers, 30% infill. The walls are 3.2 mm so that 4 shells print them solid.
Four M3 screws thread straight into the plastic of the base.
