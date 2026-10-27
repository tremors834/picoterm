#!/bin/sh
# run.sh <scenario.lua> <fakepico options...>
cd "$(dirname "$0")"
scen=$1; shift
rm -f fakepico.json
python3 fakepico.py 200 "$@" > fake.log 2>&1 &
sleep 1
BIN=../PICOTERM.BIN SCEN=$scen OUT=result-${scen%.lua}.txt timeout 300 ${MAME:-mame} coco3 -ext "" \
  -rs232 null_modem -bitb socket.127.0.0.1:2323 -video none -sound none -skip_gameinfo \
  -snapshot_directory snap -snapsize 1280x480 -autoboot_script harness.lua 2>&1 \
  | grep -vE "^$|WRONG|EXPECTED|FOUND|might not|doesn.t make|Average speed"
kill %1 2>/dev/null; wait
python3 -c "
import json;d=json.load(open('fakepico.json'));print('fake sent',d['sent_bytes'],'received',bytes(d['received']))"
