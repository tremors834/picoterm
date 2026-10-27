# Setting a Pocket Pico to 1200 baud

PicoTerm talks at 1200 baud. A Pocket Pico that was set up before at another
speed keeps that speed, even after a power cycle, because the Pico saves its
settings to flash. Its `*` auto-baud only runs on a fresh Pico.

Do this over the Pico's USB port with any terminal program (PuTTY, picocom).
USB works at any speed setting.

## Check the speed

At `cmd:` type:

    RESTART

The Pico restarts with its saved settings (nothing is erased) and prints a
line like:

    TTL Serial= 115200, 8, 1, None

That is the speed of the 3.5 mm jack. `ABAUD` shows it too (75 means 115200).

## Set it to 1200 and make it stick

The firmware saves to flash only when a new PBBS message arrives or TXDELAY
changes, so ABAUD alone is lost at the next power-up. Changing TXDELAY and
putting it back forces the save.

1. `TXDELAY` - note the number it shows (call it n).
2. `ABAUD 1200`
3. `TXDELAY` n+1 - you should see `TNCEMU:Saving Ram Data to Flash slot ...`
4. `TXDELAY` n - saves again, with TXDELAY back where it was.
5. `RESTART` - should show `TTL Serial= 1200, 8, 1, None`.

Power-cycle the Pico and check `ABAUD` again: it should still say 1200.

## Putting it back to 115200

Same steps with `ABAUD 75` (the firmware turns 75 into 115200; ABAUD itself
only goes up to 19200).

Do not use `RESET` for this: it brings back the `*` auto-baud but erases all
of the Pico's settings.
