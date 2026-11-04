// Case for the CoCo 3 RS-232 to 3.3 V TTL Cable (LTC1327) board.
// Origin = board's bottom-left corner, letters A-T at the top, regulator bottom right.
// All sizes in mm. Change a number, then re-export: base and lid_print are the files to print.
// Cables are finished at both ends, so they drop into open slots in the base's rim;
// the lid closes the slots. Lid screws are outside the board: the board's own holes
// aren't used because the cables run over them.

part = "preview";            // base | lid_print | preview | check_base | check_lid
$fn = 48;

// Board, as measured
L = 60.2;
W = 40.1;
bt = 1.7;

// Fit
cl = 0.4;                    // board-to-wall clearance per side
wall = 3.2;                  // 8 x 0.4 mm lines: 4 slicer shells make it solid
floor_t = 2.8;
roof = 2.8;
under = 4;                   // space under the board for joints and wires
over = 14.5;                 // space above the board; the board + parts measured 17 total
slot_extra = 0.6;            // slot width over cable diameter
slot_top = 0.3;              // slot depth over cable diameter

// Cables: side, y from the board's bottom edge, diameter
pico_y = 35.9;  pico_d = 2.9;
coco_y = 7.0;   coco_d = 3.8;
power_y = 3.2;  power_d = 4.1;

// Regulator LED window on the bottom-edge wall
led_x = 45.6;  led_w = 3;  led_z0 = 16.3;  led_z1 = 21.3;

// M3 lid screws
boss_x = [6, 54];             // clear of the LED window
boss_r = 5.5;                // leaves 2.4 mm of plastic around the screw head
pilot_d = 2.6;               // M3 thread cut directly in the plastic
clear_d = 3.4;
head_d = 6.2;
ear_t = 3;                   // plastic under the screw head

zb = floor_t + under + bt;   // top of the board
rim = zb + 0.3 + power_d + slot_top;
top_in = zb + over;
top_out = top_in + roof;
x0 = -cl - wall;  x1 = L + cl + wall;
y0 = -cl - wall;  y1 = W + cl + wall;

function boss_y(front) = front ? y0 - 1.5 : y1 + 1.5;

module box(a, b) { translate(a) cube(b - a); }

module outer(z0, z1) {
    r = 2;
    translate([0, 0, z0]) linear_extrude(z1 - z0) hull() {
        for (x = [x0 + r, x1 - r], y = [y0 + r, y1 - r]) translate([x, y]) circle(r);
    }
}

module inner(z0, z1) { box([-cl, -cl, z0], [L + cl, W + cl, z1]); }

module boss_shape(z0, z1) {
    for (bx = boss_x, front = [true, false]) {
        by = boss_y(front);
        wy = front ? y0 + 0.5 : y1 - 0.5;
        difference() {
            translate([0, 0, z0]) linear_extrude(z1 - z0) hull() {
                translate([bx, by]) circle(boss_r);
                translate([bx - boss_r, min(wy, wy + 0.01)]) square([2 * boss_r, 0.01]);
            }
            inner(z0 - 1, z1 + 1);   // the bigger bosses would otherwise poke into the board's space
        }
    }
}

module slot(from_left, y, d) {
    w = d + slot_extra;
    zc = rim - d - slot_top + w / 2;
    xa = from_left ? x0 - 1 : L + cl - 1;
    xb = from_left ? -cl + 1 : x1 + 1;
    translate([xa, y, 0]) rotate([0, 90, 0]) mirror([1, 0, 0]) {}
    hull() {
        translate([xa, y, zc]) rotate([0, 90, 0]) cylinder(d = w, h = xb - xa);
        translate([xa, y - w / 2, rim + 1]) cube([xb - xa, w, 0.01]);
    }
}

module base() {
    difference() {
        union() {
            difference() {
                outer(0, rim);
                inner(floor_t, rim + 1);
            }
            boss_shape(0, rim);
            // Corner supports under the board
            for (x = [-cl, L - 4], y = [-cl, W - 4])
                box([x, y, floor_t - 0.01], [x + 4 + cl, y + 4 + cl, floor_t + under]);
            // End supports under the hold-down ribs
            box([-cl, 17, floor_t - 0.01], [2.5, 23, floor_t + under]);
            box([L - 2.5, 17, floor_t - 0.01], [L + cl, 23, floor_t + under]);
        }
        slot(true, pico_y, pico_d);
        slot(true, coco_y, coco_d);
        slot(false, power_y, power_d);
        for (bx = boss_x, front = [true, false])
            translate([bx, boss_y(front), 1]) cylinder(d = pilot_d, h = rim);
    }
}

module lid() {
    difference() {
        union() {
            difference() {
                outer(rim, top_out);
                inner(rim - 1, top_in);
            }
            boss_shape(rim, top_out);
            // Hold-down ribs press on the empty pad strips at each end of the board
            box([-cl - 0.01, 17, zb + 0.15], [2, 23, top_in + 0.01]);
            box([L - 2, 17, zb + 0.15], [L + cl + 0.01, 23, top_in + 0.01]);
            // Locating lips drop inside the long base walls
            box([10, -cl + 0.2, rim - 2], [38, 1.0, rim + 0.01]);
            box([10, W - 1.0, rim - 2], [38, W + cl - 0.2, rim + 0.01]);
            // ...and tie those lips to the lid's walls
            box([10, -cl - 0.01, rim], [38, 1.0, rim + 2]);
            box([10, W - 1.0, rim], [38, W + cl + 0.01, rim + 2]);
        }
        // LED window
        hull() {
            translate([led_x, y0 - 1, led_z0 + led_w / 2]) rotate([-90, 0, 0]) cylinder(d = led_w, h = wall + 2);
            translate([led_x, y0 - 1, led_z1 - led_w / 2]) rotate([-90, 0, 0]) cylinder(d = led_w, h = wall + 2);
        }
        for (bx = boss_x, front = [true, false]) {
            by = boss_y(front);
            translate([bx, by, rim - 1]) cylinder(d = clear_d, h = top_out);
            translate([bx, by, rim + ear_t]) cylinder(d = head_d, h = top_out);
        }
    }
}

// Space the circuit needs, used only by the check parts: each must export empty
module circuit() {
    box([0, 0, zb - bt + 0.01], [L, W, zb]);              // board
    box([4.5, 0.5, floor_t + 0.01], [L - 4.5, W - 0.5, zb - bt]); // joints and wires under it
    box([6, 3, zb], [54, 37, zb + 8.8]);                  // chip, socket, caps, wires
    box([40, 2.5, zb], [48, 6, zb + over - 0.1]);         // regulator
}

if (part == "base") base();
if (part == "lid_print") translate([0, 0, top_out]) rotate([180, 0, 0]) lid(); // rotated, not mirrored, so it isn't a mirror image
if (part == "preview") { base(); translate([0, 0, 18]) lid(); %circuit(); }
if (part == "check_base") intersection() { base(); circuit(); }
if (part == "check_lid") intersection() { lid(); circuit(); }
