#!/bin/bash
# Configure OpenSCAD (GUI on) for Android with the Qt toolchain; the APK target comes from android/app.
# usage: configure-app.sh [x86_64|arm64-v8a] [extra cmake args...]      build tree: build/app-<abi>
ABI=${1:-x86_64}
source "$(dirname "$0")/env.sh"
QT=$(qt_for $ABI)
P=$(prefix_for $ABI)
export PKG_CONFIG_LIBDIR=$P/lib/pkgconfig:$P/share/pkgconfig PKG_CONFIG_PATH= PKG_CONFIG_SYSROOT_DIR=
cmake -S $R/openscad-src -B $R/build/app-$ABI -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=$QT/lib/cmake/Qt6/qt.toolchain.cmake -DQT_HOST_PATH=$QT_HOST_PATH \
  -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API -DANDROID_SDK_ROOT=$ANDROID_SDK_ROOT -DANDROID_NDK_ROOT=$NDK \
  -DCMAKE_PREFIX_PATH="$P;$QT" -DCMAKE_FIND_ROOT_PATH="$P;$QT" \
  -DFLEX_EXECUTABLE=$R/hosttools/bin/flex -DBISON_EXECUTABLE=$R/hosttools/bin/bison \
  -DCMAKE_REQUIRE_FIND_PACKAGE_Lib3MF=OFF -DCMAKE_DISABLE_FIND_PACKAGE_Lib3MF=ON \
  -DEXPERIMENTAL=ON -DSNAPSHOT=OFF -DOFFLINE_DOCS=OFF \
  -DOPENSCAD_ANDROID_DIR=$R \
  "${@:2}"
