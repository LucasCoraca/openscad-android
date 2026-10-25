#!/bin/bash
# Drive the app on our emulator for UI testing. usage: tools/dev.sh <command> [args]
#   install [abi]        install dist/OpenSCAD-android-<abi>-preview.apk (default x86_64)
#   start | stop         (re)start the app fresh / force-stop it
#   tap X Y | swipe X1 Y1 X2 Y2 [ms] | longpress X Y | key KEYCODE | text 'string'
#   shot NAME            screenshot to $SHOTS/NAME.png (+ .jpg)
#   log [N]              the app's last N log lines (default 40), crash backtraces included
#   env 'K=V;K2=V2'      set environment variables for the next start (dev hook in main.cc); env '' clears
#   pid                  the app's pid, or nothing
SERIAL=${ANDROID_SERIAL:-emulator-5590}
A="$HOME/Android/sdk/platform-tools/adb -s $SERIAL"
PKG=io.github.lucascoraca.openscad
R="$(cd "$(dirname "$0")/.." && pwd)"
SHOTS=${SHOTS:-$R/build/shots}
mkdir -p "$SHOTS"
case "$1" in
  install) $A install -r "$R/dist/OpenSCAD-android-${2:-x86_64}-preview.apk" | tail -1 ;;
  start) $A shell am force-stop $PKG; $A logcat -c; $A shell am start -n $PKG/org.qtproject.qt.android.bindings.QtActivity >/dev/null ;;
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
  *) sed -n 2,11p "$0"; exit 1 ;;
esac
