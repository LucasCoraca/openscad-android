#!/bin/bash
# Build the APK for one ABI and sign it into dist/. usage: build-app.sh [x86_64|arm64-v8a]
set -e
ABI=${1:-x86_64}
source "$(dirname "$0")/env.sh"
wait_for_resources
$NICE cmake --build $R/build/app-$ABI --target openscad_android_make_apk -j$JOBS
mkdir -p $R/dist
short=${ABI/-v8a/}
apk=$(ls -t $R/build/app-$ABI/android-app/android-build/build/outputs/apk/*/*.apk $R/build/app-$ABI/android-app/android-build/*.apk 2>/dev/null | head -1)
$BT/apksigner sign --ks $OPENSCAD_KEYSTORE --ks-pass pass:android --key-pass pass:android \
  --out $R/dist/OpenSCAD-android-$short-preview.apk "$apk"
echo "dist/OpenSCAD-android-$short-preview.apk"
