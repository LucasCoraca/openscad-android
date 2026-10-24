#!/bin/bash
# Our own emulator ("scadtest", a tablet; port 5590 => serial emulator-5590). Other agents' emulators are never touched.
R="$(cd "$(dirname "$0")" && pwd)"
export ANDROID_SDK_ROOT=$HOME/Android/sdk ANDROID_AVD_HOME=$R/hosttools/avd ANDROID_USER_HOME=$R/hosttools/androiduser
exec nice -n 5 $ANDROID_SDK_ROOT/emulator/emulator -avd ${AVD:-scadtest} -port ${PORT:-5590} -no-window -no-audio -no-boot-anim \
  -no-snapshot -gpu ${GPU:-swiftshader_indirect} -memory 4096 -cores 4
