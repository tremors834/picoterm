# PicoTerm for the Tandy CoCo 3

A terminal program for the **Tandy Color Computer 3** that talks to a
[Pocket Pico](https://github.com/pfiliberti) (the Pico TNC by KF7PSM, which
emulates the Heathkit HK-21 packet TNC) through the CoCo's 4-pin serial
(bit-banger) port.

No setup screens: 1200 baud, 8 data bits, no parity, 1 stop bit, 80 columns.
It wakes up the Pocket Pico by itself and shows the `cmd:` prompt.

Written in 6809 assembly. Needs a CoCo 3 with Disk BASIC (tested on a real
CoCo 3 with a CoCo SDC) and an RS-232 level converter cable (see
[docs/cable.md](docs/cable.md)).

## Using it

1. Copy `PICOTERM.DSK` to the CoCo SDC's SD card (or write it to a floppy).
2. On the CoCo, mount it and run it:

       DRIVE 0,"PICOTERM.DSK"
       RUN"PICOTERM"

3. PicoTerm wakes up the Pocket Pico and you get `cmd:`.

Text from the Pico is white; PicoTerm's own messages are yellow.

| CoCo key | What it does |
|---|---|
| BREAK | Ctrl-C (back to the `cmd:` prompt) |
| CLEAR | clear the screen |
| CTRL + letter | control key (CTRL+Z = Ctrl-Z) |
| LEFT arrow | backspace |
| SHIFT+0 | caps lock on/off (starts on) |
| F1 | help on screen |
| SHIFT+F1 | wake up the Pocket Pico again |
| F2 | quit to BASIC (press Y to confirm) |

Characters the CoCo keyboard doesn't have, typed with CTRL plus a key:

| CTRL + | 1 | 3 | 7 | 8 | 9 | , | - | . | / |
|---|---|---|---|---|---|---|---|---|---|
| types | `\|` | `~` | `^` | `[` | `]` | `{` | `_` | `}` | `\` |

The CoCo's font shows `^` as an up arrow and `_` as a left arrow; the
correct characters are sent.

A printable key card: [docs/PicoTerm-Quick-Reference.pdf](docs/PicoTerm-Quick-Reference.pdf).

## How the wake-up works

PicoTerm sends Ctrl-C and ENTER. If `cmd:` comes back, the Pico is already at
1200. If not, it sends `*` every 0.7 s (up to 12 times), because the HK-21 ROM
auto-bauds on a `*`. After about 9 seconds with no answer it says to check the
cable and power.

**Important:** the Pocket Pico saves its settings to flash, so the `*`
auto-baud only runs on a fresh (never set up) Pico. A Pico that has been used
at another speed (115200 is common) keeps that speed and will not answer.
See [docs/pocket-pico-1200-baud.md](docs/pocket-pico-1200-baud.md) to set it
to 1200 and make it stick.

## Files

- `pico.asm` - the program (6809, assembled with [lwtools](http://www.lwtools.ca/) `lwasm`)
- `PICOTERM.BAS` - BASIC launcher: CLEAR 200,&H4DFF / WIDTH 80 / LOADM / EXEC / WIDTH 32
- `PICOTERM.BIN` - the assembled program
- `PICOTERM.DSK` - ready-to-use Disk BASIC disk image with both of the above
- `mkdsk.py` - builds the `.DSK`
- `test/` - emulator test kit (MAME, a stand-in ROM and a fake Pico)
- `docs/` - cable wiring, Pocket Pico 1200 baud setup, printable quick reference

## Building

    lwasm --format=decb -o PICOTERM.BIN pico.asm
    python3 mkdsk.py PICOTERM.DSK PICOTERM.BAS:0:A:PICOTERM.BAS PICOTERM.BIN:2:B:PICOTERM.BIN

Tested with lwtools 4.24.

## How it works inside

- Serial: the GIME timer FIRQ runs at 4800 Hz (4 samples per bit). It
  receives and sends at the same time, so nothing is lost while the screen
  scrolls. 256-byte receive buffer.
- Screen: 80x24 text with attributes, in a 16K buffer at physical
  $60000-$63FFF (mapped at $A000-$DFFF). Scrolling moves the GIME video start
  address. Every 78 lines the last 23 rows are copied back to the start.
- Memory: code $5000, variables $4F00, receive buffer $4E00.
- On exit it puts back the FIRQ vector, MMU, PIA interrupts, palette and CPU
  speed, and the launcher's WIDTH 32 resets the screen.

## License

MIT - see [LICENSE](LICENSE). Gene N7WDZ, 2026.
