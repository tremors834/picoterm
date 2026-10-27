#!/usr/bin/env python3
"""Stand-in for the Pocket Pico's HK-21 console, for emulator tests.

MAME's null-modem port connects here as a TCP client.  Behaves like the
HK-21 ROM: starts in auto-baud (junk out, ignores input until a '*'
gets through - here the 3rd one), then echoes and answers commands.

  TEST   sends 60 numbered lines back to back (no-loss check)
  LONG   sends one 130-character line (wrap check)
  --synced  start already at 1200 (no auto-baud)
  --dead    never answer
  ^C     back to cmd:
"""
import socket, sys, time, json

PORT = 2323
synced = "--synced" in sys.argv
dead = "--dead" in sys.argv
log = {"received": [], "sent_bytes": 0, "test_lines": 0}

def line(n):
    return f"{n:03d} The quick brown fox jumps over the lazy dog 0123456789 abcdefghij\r\n"

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", PORT))
srv.listen(1)
srv.settimeout(60)
c, _ = srv.accept()
c.settimeout(0.2)

def send(s):
    b = s.encode() if isinstance(s, str) else s
    c.sendall(b)
    log["sent_bytes"] += len(b)

stars = 0
if not synced:
    send(b"\x80\xf8\x00\xfe\x1c\x80")  # what a 115200-baud greeting looks like at 1200
buf = ""
end = time.time() + float(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1][0].isdigit() else time.time() + 120
while time.time() < end:
    try:
        d = c.recv(64)
    except socket.timeout:
        continue
    if not d:
        break
    for ch in d.decode("latin-1"):
        log["received"].append(ord(ch))
        if dead:
            continue
        if not synced:
            if ch == "*":
                stars += 1
                if stars >= 3:
                    synced = True
                    send("\r\nPocket Pico (FM)\r\nHeathkit HK-21 Pocket Packet\r\ncmd:")
                else:
                    send(b"\xe0\x00")       # wrong-speed junk
            continue
        if ch == "\x03":
            buf = ""
            send("\r\ncmd:")
        elif ch == "\r":
            send("\r\n")
            cmd = buf.strip().upper()
            buf = ""
            if cmd == "TEST":
                out = "".join(line(n) for n in range(1, 61))
                send(out)
                log["test_lines"] = 60
            elif cmd == "LONG":
                send("".join(chr(65 + i % 26) for i in range(130)) + "\r\n")
            elif cmd:
                send("?EH\r\n")
            send("cmd:")
        elif ch == "\x08":
            buf = buf[:-1]
            send("\x08 \x08")
        else:
            buf += ch
            send(ch)
json.dump(log, open("fakepico.json", "w"))
