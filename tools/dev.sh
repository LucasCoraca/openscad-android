#!/bin/bash
# Drive the app on our emulator for UI testing. usage: tools/dev.sh <command> [args]
#   up | down            start (memory-capped, waits for boot, root) / stop our emulator
#   install [abi]        install dist/OpenSCAD-android-<abi>-preview.apk (default x86_64)
#   start | stop         (re)start the app fresh / force-stop it
#   tap X Y | swipe X1 Y1 X2 Y2 [ms] | longpress X Y | key KEYCODE | text 'string'
#   shot NAME            screenshot to $SHOTS/NAME.png (+ .jpg)
#   log [N]              the app's last N log lines (default 40), crash backtraces included
#   env 'K=V;K2=V2'      set environment variables for the next start (dev hook in main.cc); env '' clears
#   pid                  the app's pid, or nothing
#   mem                  the emulator's memory use and the machine's available memory
SERIAL=${ANDROID_SERIAL:-emulator-5590}
A="$HOME/Android/sdk/platform-tools/adb -s $SERIAL"
PKG=io.github.lucascoraca.openscad
R="$(cd "$(dirname "$0")/.." && pwd)"
SHOTS=${SHOTS:-$R/build/shots}
mkdir -p "$SHOTS"
case "$1" in
  up) # start our emulator (memory-capped, watchdog) detached unless it runs, wait for boot, get root
    pgrep -f "qemu-system.*-port ${SERIAL#emulator-}" >/dev/null || \
      (cd "$R" && setsid nohup ./start-emulator.sh > "$R/build/emulator.log" 2>&1 &)
    for i in $(seq 1 150); do
      [ "$($A shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
      pgrep -f "start-emulator.sh" >/dev/null || pgrep -f "qemu-system.*-port ${SERIAL#emulator-}" >/dev/null \
        || { echo "emulator not running:"; grep -i watchdog "$R/build/emulator.log"; tail -2 "$R/build/emulator.log"; exit 1; }
      sleep 4
    done
    sleep 10; $A root >/dev/null; sleep 3; $A wait-for-device
    $A shell settings put global hide_error_dialogs 1  # no "isn't responding" dialogs over the screen under test
    echo "emulator up" ;;
  down) $A emu kill >/dev/null 2>&1; echo "emulator stopping" ;;
  install) $A install -r "$R/dist/OpenSCAD-android-${2:-x86_64}-preview.apk" | tail -1 ;;
  start) # recycle the emulator when its GPU emulation has grown (it keeps ~400 MB per app session), then start fresh
    q=$(pgrep -f "qemu-system.*-port ${SERIAL#emulator-}" | head -1)
    if [ -z "$q" ] || [ $(( $(awk '/VmRSS/{print $2}' /proc/$q/status 2>/dev/null || echo 0) / 1024 )) -gt 6000 ]; then
      [ -n "$q" ] && { "$0" down; while pgrep -f "qemu-system.*-port ${SERIAL#emulator-}" >/dev/null; do sleep 2; done; }
      "$0" up || exit 1; "$0" install >/dev/null
    fi
    $A shell am force-stop $PKG; $A logcat -c; $A shell am start -n $PKG/org.qtproject.qt.android.bindings.QtActivity >/dev/null ;;
  stop) $A shell am force-stop $PKG ;;
  tap) $A shell input tap "$2" "$3" ;;
  swipe) $A shell input swipe "$2" "$3" "$4" "$5" "${6:-300}" ;;
  longpress) $A shell input swipe "$2" "$3" "$2" "$3" 1000 ;;
  key) $A shell input keyevent "$2" ;;
  text) $A shell "input text '$2'" ;;
  shot) $A exec-out screencap -p > "$SHOTS/$2.png" && /usr/bin/python3 -c "
from PIL import Image; Image.open('$SHOTS/$2.png').convert('RGB').save('$SHOTS/$2.jpg', quality=80)" && echo "$SHOTS/$2.jpg" ;;
  log) p=$($A shell pidof $PKG | tr -d '\r'); { [ -n "$p" ] && $A logcat -d --pid=$p; $A logcat -d | grep -E 'F DEBUG|F libc'; } | grep -vE 'ziparchive|nativeloader|GraphicsEnv|CPU variant|variants|Compat' | tail -${2:-40} ;;
  env) printf '%s\n' "$2" | tr ';' '\n' > /tmp/openscad-env.$$ && $A push /tmp/openscad-env.$$ /sdcard/Android/data/$PKG/files/openscad-env >/dev/null; rm -f /tmp/openscad-env.$$ ;;
  pid) $A shell pidof $PKG | tr -d '\r' ;;
  mem) q=$(pgrep -f "qemu-system.*-port ${SERIAL#emulator-}" | head -1); echo "emulator RSS $(( $(awk '/VmRSS/{print $2}' /proc/$q/status) / 1024 )) MB, machine $(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo) GB available" ;;
  *) sed -n 2,11p "$0"; exit 1 ;;
esac
