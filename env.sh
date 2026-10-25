# Shared settings for the build scripts (sourced, not run). Every path can be overridden from the environment.
#   ANDROID_SDK_ROOT  Android SDK (with NDK 29.0.14206865, build-tools 34.0.0, platform android-34)
#   QT_ANDROID_ROOT   folder holding Qt 6.8.3 for Android per ABI: <root>/arm64-v8a, <root>/x86_64 and the host Qt in <root>/qt-host
#                     (only qtbase is needed; build-deps.sh copies its Qt files into deps-android/qt and adds qtsvg there)
#   JAVA_HOME         JDK 17
#   OPENSCAD_KEYSTORE keystore used to sign the APK (password "android")
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-$HOME/Android/sdk}
NDK=${ANDROID_NDK:-$ANDROID_SDK_ROOT/ndk/29.0.14206865}
BT=$ANDROID_SDK_ROOT/build-tools/34.0.0
API=28
QT_ANDROID_ROOT=${QT_ANDROID_ROOT:-$HOME/Android/fcdeps}
export JAVA_HOME=${JAVA_HOME:-$HOME/Android/jdk17}
OPENSCAD_KEYSTORE=${OPENSCAD_KEYSTORE:-$R/hosttools/debug.keystore}
JOBS=${JOBS:-2}  # shared machine: keep builds small (other agents compile here too; it ran out of resources at 4)
NICE="nice -n 19 ionice -c3"
# private host tools: cmake, ninja and meson in a Python venv; m4, bison, flex and gperf built by build-hosttools.sh
export PATH=$R/hosttools/pyenv/bin:$R/hosttools/bin:$JAVA_HOME/bin:$PATH

# our Qt prefix per ABI (qtbase from QT_ANDROID_ROOT + qtsvg), and the host Qt next to it as target_qt.conf expects
QT_DIR=$R/deps-android/qt
QT_HOST_PATH=$QT_DIR/qt-host
qt_for() { echo "$QT_DIR/$1"; }
prefix_for() { echo "$R/deps-android/$1"; }

# wait_for_resources: block until the shared machine has room (1-minute load under half the cores, 8 GB available)
wait_for_resources() {
  local cores=$(nproc) waited=0
  while :; do
    local load=$(cut -d' ' -f1 /proc/loadavg) avail=$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)
    if awk -v l="$load" -v c="$cores" 'BEGIN{exit !(l < c/2)}' && [ "$avail" -ge 8 ]; then return 0; fi
    [ $waited -eq 0 ] && echo "waiting for resources (load $load, ${avail} GB available)..." >&2
    waited=1; sleep 30
  done
}
