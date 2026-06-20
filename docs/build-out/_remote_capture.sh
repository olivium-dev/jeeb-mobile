#!/bin/bash
# Remote capture on the Mac Studio. Usage: _remote_capture.sh <SC-id> <emu-port> <mock-port>
# Reads local /Volumes/Extreme Pro/.../_captures/<id>/flow.yaml, runs it on the remote emulator,
# rsyncs png+mp4 back to the SSD capture dir. Exits 0 always; verdict is decided by the caller.
set -u
ID="$1"; PORT="$2"; MOCK="$3"; DEV="emulator-$PORT"
RH="oudaykhaled@192.168.2.33"
SSD="/Volumes/Extreme Pro/jeeb-scenarios/_captures/$ID"
OPTS=(-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=20)
PW='Ronaldo0$'
[ -f "$SSD/flow.yaml" ] || { echo "NO_FLOW"; exit 0; }
# rewrite screenshot paths to remote /tmp
sed "s#${SSD}#/tmp/captures/${ID}#g" "$SSD/flow.yaml" > "/tmp/${ID}.remote.flow.yaml"
sshpass -p "$PW" ssh "${OPTS[@]}" "$RH" "rm -rf /tmp/captures/$ID && mkdir -p /tmp/captures/$ID" 2>/dev/null
sshpass -p "$PW" scp "${OPTS[@]}" "/tmp/${ID}.remote.flow.yaml" "$RH:/tmp/captures/$ID/flow.yaml" 2>/dev/null
# optional extra seed curls passed via env REMOTE_SEED (run on remote against localhost:MOCK)
sshpass -p "$PW" ssh "${OPTS[@]}" "$RH" "
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
export PATH=/opt/homebrew/bin:\$HOME/Library/Android/sdk/platform-tools:\$PATH
adb -s $DEV reverse tcp:4010 tcp:$MOCK >/dev/null 2>&1
curl -s -X POST http://localhost:$MOCK/__mock/reset >/dev/null
${REMOTE_SEED:-true}
rm -f /tmp/captures/$ID/*.png /tmp/captures/$ID/$ID.mp4
adb -s $DEV shell screenrecord --time-limit 180 /sdcard/$ID.mp4 >/dev/null 2>&1 &
TO=\$(command -v gtimeout || command -v timeout || echo); for att in 1 2 3; do \$TO 180 \$HOME/.maestro/bin/maestro --device $DEV test /tmp/captures/$ID/flow.yaml > /tmp/captures/$ID/maestro.log 2>&1; grep -qi 'Unable to launch app' /tmp/captures/$ID/maestro.log || break; adb -s $DEV shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1; sleep 6; done
adb -s $DEV shell pkill -INT screenrecord >/dev/null 2>&1
sleep 3
adb -s $DEV pull /sdcard/$ID.mp4 /tmp/captures/$ID/$ID.mp4 >/dev/null 2>&1
adb -s $DEV shell rm -f /sdcard/$ID.mp4 >/dev/null 2>&1
" 2>/dev/null
mkdir -p "$SSD"
SSHPASS="$PW" sshpass -e rsync -az -e "ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no" \
  --include='*.png' --include='*.mp4' --include='maestro.log' --include='*/' --exclude='*' \
  "$RH:/tmp/captures/$ID/" "$SSD/" 2>/dev/null
echo "REMOTE_CAPTURE_DONE $ID"; ls "$SSD"/*.png 2>/dev/null | grep -v '/\._' | wc -l | tr -d ' '; echo "png(s); mp4:"; [ -f "$SSD/$ID.mp4" ] && stat -f%z "$SSD/$ID.mp4" || echo 0
