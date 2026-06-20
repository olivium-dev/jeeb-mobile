#!/bin/bash
# Bring up capture lanes B-F (A = emulator-5554 already running). Idempotent-ish.
# Each AVD pinned to a fixed console port so adb id maps to a known mock port.
export JAVA_HOME="$(/usr/libexec/java_home)"
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$PATH"
APK=/tmp/jeeb-app-dev-debug-localhost.apk

if [ ! -f "$APK" ]; then echo "FATAL: localhost APK not built yet ($APK). Check /tmp/jeeb-apk-localhost-build.log"; exit 1; fi

# AVD -> console port -> mock host port
LANES="jeeb_test2:5556:4011 jeeb_test3:5558:4012 jeeb_test4:5560:4013 jeeb_test5:5562:4014 jeeb_test6:5564:4015"

echo "== booting emulators =="
for L in $LANES; do
  AVD="${L%%:*}"; rest="${L#*:}"; PORT="${rest%%:*}"
  if adb -s emulator-$PORT get-state 2>/dev/null | grep -q device; then echo "  emulator-$PORT already up"; continue; fi
  nohup emulator -avd "$AVD" -port "$PORT" -no-window -no-audio -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect -no-metrics > /tmp/emu-$AVD.log 2>&1 &
  echo "  launched $AVD on port $PORT"
done

echo "== waiting for boot_completed =="
for L in $LANES; do
  rest="${L#*:}"; PORT="${rest%%:*}"
  adb -s emulator-$PORT wait-for-device 2>/dev/null
  for i in $(seq 1 60); do
    [ "$(adb -s emulator-$PORT shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
    sleep 3
  done
  echo "  emulator-$PORT boot=$(adb -s emulator-$PORT shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
done

echo "== install APK + adb reverse per lane =="
for L in $LANES; do
  AVD="${L%%:*}"; rest="${L#*:}"; PORT="${rest%%:*}"; MOCK="${rest##*:}"
  adb -s emulator-$PORT install -r -d "$APK" >/tmp/install-$PORT.log 2>&1 && echo "  installed on emulator-$PORT" || echo "  INSTALL FAIL emulator-$PORT (see /tmp/install-$PORT.log)"
  adb -s emulator-$PORT reverse tcp:4010 tcp:$MOCK && echo "    reverse 4010->host:$MOCK ok"
done

echo "== ready =="; adb devices
