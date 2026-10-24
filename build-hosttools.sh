#!/bin/bash
# Build the host tools the dependency and OpenSCAD builds need (m4, bison, flex, gperf) into hosttools/,
# and the Python venv with cmake, ninja and meson.
set -e
source "$(dirname "$0")/env.sh"
[ -x $R/hosttools/pyenv/bin/meson ] || { python3 -m venv $R/hosttools/pyenv && $R/hosttools/pyenv/bin/pip install cmake ninja meson; }
mkdir -p $R/build/host
for p in m4-1.4.19 bison-3.8.2 flex-2.6.4 gperf-3.1; do
  [ -f $R/build/host/$p.done ] && continue
  rm -rf $R/build/host/$p && tar xf $R/dl-cache/$p.tar.* -C $R/build/host
  (cd $R/build/host/$p && CFLAGS="-O2 -std=gnu17" CXXFLAGS="-O2 -std=gnu++14" ./configure --prefix=$R/hosttools -q && make -j$JOBS -s && make install -s) > $R/build/host/$p.log 2>&1 \
    || { echo "$p FAILED, see build/host/$p.log"; exit 1; }
  touch $R/build/host/$p.done; echo "built $p"
done
[ -f $OPENSCAD_KEYSTORE ] || keytool -genkeypair -keystore $OPENSCAD_KEYSTORE -storepass android -keypass android \
  -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -validity 10000 >/dev/null
echo "host tools ready"
