#!/bin/bash
# Our own emulator ("scadtest", a tablet; port 5590 => serial emulator-5590). Other agents' emulators are never touched.
# Shared machine: waits for room before starting, and a watchdog kills the emulator if it grows past EMU_MAX_GB of
# memory (its host-side GPU emulation can leak) or the machine runs low on memory.
R="$(cd "$(dirname "$0")" && pwd)"
source "$R/env.sh"
wait_for_resources
export ANDROID_SDK_ROOT=$HOME/Android/sdk ANDROID_AVD_HOME=$R/hosttools/avd ANDROID_USER_HOME=$R/hosttools/androiduser
EMU_MAX_GB=${EMU_MAX_GB:-7}
# the kernel enforces the limit too: the emulator runs in its own memory-capped scope (OOM kills only it)
systemd-run --user --scope -q -p MemoryMax=${EMU_MAX_GB}G -p MemorySwapMax=0 \
nice -n 5 $ANDROID_SDK_ROOT/emulator/emulator -avd ${AVD:-scadtest} -port ${PORT:-5590} -no-window -no-audio -no-boot-anim \
  -no-snapshot -gpu ${GPU:-swiftshader_indirect} -memory 3072 -cores 2 &
EMU=$!
sleep 10
while kill -0 $EMU 2>/dev/null; do
  qemu=$(pgrep -f "qemu-system.*-avd ${AVD:-scadtest} " | head -1)
  rss_gb=$(( $(awk '/VmRSS/{print $2}' /proc/${qemu:-0}/status 2>/dev/null || echo 0) / 1048576 ))
  avail_gb=$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)
  if [ "$rss_gb" -ge "$EMU_MAX_GB" ] || [ "$avail_gb" -lt 4 ]; then
    echo "watchdog: emulator at ${rss_gb} GB, machine has ${avail_gb} GB available: killing it" >&2
    $ANDROID_SDK_ROOT/platform-tools/adb -s emulator-${PORT:-5590} emu kill >/dev/null 2>&1
    sleep 5; kill $EMU 2>/dev/null; [ -n "$qemu" ] && kill -9 $qemu 2>/dev/null
    exit 1
  fi
  sleep 5
done
wait $EMU
