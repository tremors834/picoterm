# Emulator test kit

Runs PicoTerm in MAME's CoCo 3 with a fake Pocket Pico on the serial port.
Tested with MAME 0.276 on Debian 13.

- `stub.asm` - a stand-in ROM (not Tandy code) that sets up the machine
  roughly like Super Extended BASIC. Assemble it and put it where MAME looks
  for the CoCo 3 ROM:

      lwasm --raw -o coco3.rom stub.asm      # comes out exactly 32K
      mkdir -p roms/coco3 && mv coco3.rom roms/coco3/

  MAME will warn that the ROM checksum is wrong; that is expected.
  Because of the stand-in ROM, the BASIC launcher and disk loading are not
  tested here; the program itself is.
- `fakepico.py` - acts like the HK-21 console on TCP port 2323
  (`TEST` floods 60 lines, `LONG` sends a 130-character line).
- `harness.lua` - MAME script: loads `../PICOTERM.BIN`, types keys, dumps the screen.
- `scen_*.lua` - test scenarios.
- `run.sh` - runs one scenario. Set `MAME` to your MAME command, including
  `-rompath` for the stand-in ROM:

      MAME="mame -rompath $PWD/roms" ./run.sh scen_full.lua            # Pico starts in auto-baud
      MAME="mame -rompath $PWD/roms" ./run.sh scen_keys.lua --synced   # already at 1200; keys, buffer wrap
      MAME="mame -rompath $PWD/roms" ./run.sh scen_dead.lua --dead     # Pico never answers

Results go to `result-<scenario>.txt`.
