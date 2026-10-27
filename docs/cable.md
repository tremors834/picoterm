# Cable: Pocket Pico to CoCo 3

The Pocket Pico's serial jack is 3.3 V TTL. The CoCo 3's 4-pin serial port
uses RS-232 levels (about +/-12 V). A level converter chip goes in between.
Never connect the Pico straight to the CoCo.

## Connectors

**Pocket Pico, 3.5 mm TRS jack**

| Contact | Signal |
|---|---|
| Tip | Pico receive (RX) |
| Ring | Pico transmit (TX) |
| Sleeve | ground |

**CoCo 3, 4-pin DIN serial port**

| Pin | Signal |
|---|---|
| 1 | carrier detect (not used) |
| 2 | CoCo receive (RXD in) |
| 3 | ground |
| 4 | CoCo transmit (TXD out) |

## Option A: 3.3 V converter (MAX3232 / SP3232), no resistors

A MAX3232 or SP3232 board powered from 3.3 V (for example an AMS1117-3.3
regulator board) has TTL outputs that are safe for the Pico as they are.

```
Pico ring (TX) ──── TTL in  ─[converter]─ RS-232 out ──── DIN 2 (CoCo RXD)
Pico tip  (RX) ──── TTL out ─[converter]─ RS-232 in  ──── DIN 4 (CoCo TXD)
Pico sleeve    ──── GND ──────────────────────────────── DIN 3 (ground)
```

Converter boards label their TTL pins differently (TXD/RXD can mean either
direction), so check the board's chip pins with a meter before wiring.

## Option B: 5 V converter (MAX232 / ICL232) with a divider

A 5 V-only chip puts out up to 5 V on its TTL side, too much for the Pico.
Add a divider on the receive output going to the Pico's tip:

```
R OUT ──[2k]──┬── tip (Pico RX)
              │
            [3.3k]
              │
GND ──────────┴── sleeve (Pico ground)

T IN ──────────── ring (Pico TX)
```

With an ICL232 (receive output high 3.5 V minimum, 4.6 V typical) the tip sees
about 2.9 V typical and never less than about 2.2 V, above the Pico's 2.0 V
"high" threshold, and never more than 3.3 V. 1.8k works too; avoid going much
lower than 1.8k (the tip can go over 3.3 V) or much higher than 2.2k (too
little margin).

This is the cable PicoTerm was first tested with: ICL232 channel 1
(T1 IN 11, R1 OUT 12, R1 IN 13, T1 OUT 14, GND 15, VCC 16), T1 OUT to DIN 2,
R1 IN to DIN 4, GND to DIN 3.

## Meter checks before plugging in the Pico

With the cable powered and nothing plugged in:

1. Converter supply: 3.3 V (option A) or 5 V (option B).
2. Tip to sleeve: about 2.9 V (option B) or about 3.3 V (option A). The
   receive line idles high.
3. DIN 2 to DIN 3: about -5 to -9 V (RS-232 idle).
4. Plug the DIN into the CoCo (CoCo off first), turn it on: the tip should
   still read the same as in step 2.

## Loopback test

If PicoTerm gets no answer, unplug the Pico and connect the plug's tip to its
ring with a clip lead (not the sleeve). Type on the CoCo in PicoTerm: the
letters should show on screen. If they do, the cable and the CoCo are fine and
the problem is on the Pico side (usually its speed, see
[pocket-pico-1200-baud.md](pocket-pico-1200-baud.md)).
