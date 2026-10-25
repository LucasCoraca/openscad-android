#!/bin/bash
# Cross-compile OpenSCAD's dependencies for Android into deps-android/<abi> (static libraries), and set up our Qt prefix
# deps-android/qt/<abi> (qtbase copied from QT_ANDROID_ROOT, plus qtsvg).
# usage: build-deps.sh <arm64-v8a|x86_64> [step...]     (default: every step not yet done; a named step is rebuilt)
# Sources come from dl-cache/ (fetch-sources.sh); logs and stamps are in build/deps-<abi>/.
set -e
ABI=${1:?usage: build-deps.sh <arm64-v8a|x86_64> [step...]}; shift
source "$(dirname "$0")/env.sh"
case $ABI in
  arm64-v8a) TRIPLE=aarch64-linux-android ;;
  x86_64) TRIPLE=x86_64-linux-android ;;
  *) echo "unknown ABI $ABI"; exit 1 ;;
esac
P=$(prefix_for $ABI)
QT=$(qt_for $ABI)
B=$R/build/deps-$ABI
SRC=$R/build/src
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64
mkdir -p $P $B $SRC

export PKG_CONFIG_LIBDIR=$P/lib/pkgconfig:$P/share/pkgconfig PKG_CONFIG_PATH= PKG_CONFIG_SYSROOT_DIR=
CMAKE_NDK=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake
  -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API -DANDROID_STL=c++_shared
  -DCMAKE_INSTALL_PREFIX=$P -DCMAKE_PREFIX_PATH=$P -DCMAKE_FIND_ROOT_PATH=$P -DBUILD_SHARED_LIBS=OFF
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5)
CMAKE_QT=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=$QT/lib/cmake/Qt6/qt.toolchain.cmake
  -DQT_HOST_PATH=$QT_HOST_PATH -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API
  -DCMAKE_PREFIX_PATH="$P;$QT" -DCMAKE_FIND_ROOT_PATH="$P;$QT" -DBUILD_SHARED_LIBS=OFF)
autotools_env() {
  export CC=$TC/bin/$TRIPLE$API-clang CXX=$TC/bin/$TRIPLE$API-clang++ AR=$TC/bin/llvm-ar RANLIB=$TC/bin/llvm-ranlib
  export STRIP=$TC/bin/llvm-strip NM=$TC/bin/llvm-nm CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC"
}
meson_cross() {
  cat > $B/cross.ini <<EOF
[binaries]
c = '$TC/bin/$TRIPLE$API-clang'
cpp = '$TC/bin/$TRIPLE$API-clang++'
ar = '$TC/bin/llvm-ar'
strip = '$TC/bin/llvm-strip'
pkg-config = 'pkg-config'
[built-in options]
c_args = ['-fPIC']
cpp_args = ['-fPIC']
[properties]
pkg_config_libdir = '$P/lib/pkgconfig'
[host_machine]
system = 'android'
cpu_family = '${TRIPLE%%-*}'
cpu = '${TRIPLE%%-*}'
endian = 'little'
EOF
}
# unpack <tarball-prefix> -> sets S to the fresh source dir
unpack() {
  local tb=$(ls $R/dl-cache/$1* | head -1)
  local top=$(tar tf $tb | head -1 | cut -d/ -f1)
  rm -rf $SRC/$top; tar xf $tb -C $SRC; S=$SRC/$top
}
cm() { # cm <src> <build-name> [cmake args...]: configure, build, install with the NDK toolchain
  local s=$1 n=$2; shift 2
  rm -rf $B/$n; cmake -S $s -B $B/$n "${CMAKE_NDK[@]}" "$@" && cmake --build $B/$n -j$JOBS && cmake --install $B/$n
}

step_qt() { # our Qt prefix: the Qt files of qtbase for Android, host Qt linked next to it (target_qt.conf: HostPrefix=../../qt-host)
  local from=$QT_ANDROID_ROOT/$ABI
  mkdir -p $QT/lib $QT/bin $QT/src
  ln -sfn $QT_ANDROID_ROOT/qt-host $QT_DIR/qt-host
  (cd $from/bin && cp -a qmake qmake6 qt-cmake qt-cmake-create qt-configure-module qtpaths qtpaths6 target_qt.conf $QT/bin/)
  (cd $from/lib && cp -a libQt6* Qt6*-android-dependencies.xml objects-Release $QT/lib/ && mkdir -p $QT/lib/cmake $QT/lib/pkgconfig \
     && cp -a cmake/Qt6* $QT/lib/cmake/ && cp -a pkgconfig/Qt6* $QT/lib/pkgconfig/ 2>/dev/null || true)
  mkdir -p $QT/include && cp -a $from/include/Qt* $QT/include/
  cp -a $from/plugins $from/mkspecs $from/modules $from/jar $from/metatypes $from/libexec $QT/
  cp -a $from/src/android $from/src/3rdparty $QT/src/
}
step_qtsvg() {
  unpack qtsvg-everywhere-src-6.8.3
  rm -rf $B/qtsvg && mkdir -p $B/qtsvg && cd $B/qtsvg
  $QT/bin/qt-configure-module $S -- -DCMAKE_INSTALL_PREFIX=$QT -DQT_GENERATE_SBOM=OFF && cmake --build . -j$JOBS && cmake --install .
}
step_qtplugin() { # Qt's Android platform plugin with our input fix, over the one copied from QT_ANDROID_ROOT
  rm -rf $SRC/qtbase-everywhere-src-6.8.3
  tar xf $R/dl-cache/qtbase-everywhere-src-6.8.3.tar.xz -C $SRC qtbase-everywhere-src-6.8.3/src/plugins/platforms/android \
    qtbase-everywhere-src-6.8.3/src/3rdparty/android
  S=$SRC/qtbase-everywhere-src-6.8.3
  patch -d $S -p1 < $R/patches/qtbase-android.patch
  rm -rf $B/qtplugin
  cmake -S $R/deps/qt-android-plugin -B $B/qtplugin "${CMAKE_QT[@]}" -DQTBASE_SRC=$S && cmake --build $B/qtplugin -j$JOBS
  cp $B/qtplugin/libplugins_platforms_qtforandroid_$ABI.so $QT/plugins/platforms/
}
step_gmp() {
  unpack gmp-6.3.0; autotools_env; cd $S
  ./configure --host=$TRIPLE --prefix=$P --enable-cxx --disable-shared --with-pic && make -j$JOBS && make install
}
step_mpfr() {
  unpack mpfr-4.2.1; autotools_env; cd $S
  ./configure --host=$TRIPLE --prefix=$P --with-gmp=$P --disable-shared --with-pic && make -j$JOBS && make install
}
step_boost() {
  unpack boost-1.86.0-cmake
  cm $S boost -DBOOST_INCLUDE_LIBRARIES="program_options;regex;assign;asio;beast;algorithm;format;lexical_cast;logic;range;unordered;multiprecision;graph;heap;iterator;property_map;container;optional;variant;any;math;random;bimap;multi_index;ptr_container;pool;intrusive;tuple;type_traits;utility;spirit;functional;dynamic_bitset;interval;numeric_conversion;circular_buffer;accumulators;property_tree;foreach;bind;crc;array;smart_ptr;core;config;integer;mpl;preprocessor;static_assert;throw_exception;assert;describe;mp11;move;dll;geometry;polygon;qvm;rational;tokenizer;uuid;exception;function;variant2;endian;predef;io;concept_check;type_index;container_hash;callable_traits;hof;atomic;filesystem;system;thread;chrono;date_time;serialization;iostreams" \
    -DBOOST_IOSTREAMS_ENABLE_BZIP2=OFF -DBOOST_IOSTREAMS_ENABLE_LZMA=OFF -DBOOST_IOSTREAMS_ENABLE_ZSTD=OFF
}
step_eigen() { unpack eigen-3.4.0; cm $S eigen -DBUILD_TESTING=OFF -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_PKGCONFIG=ON; }
step_cgal() { unpack CGAL-6.0.1; cm $S cgal -DWITH_CGAL_Qt6=OFF -DCGAL_DISABLE_GMP=OFF; }
step_tbb() {
  unpack oneTBB-2021.13.0
  cm $S tbb -DTBB_TEST=OFF -DTBB_EXAMPLES=OFF -DTBB_STRICT=OFF -DTBBMALLOC_PROXY_BUILD=OFF
}
step_zlibpc() { # the NDK's zlib, described for pkg-config users (freetype2.pc requires zlib)
  mkdir -p $P/lib/pkgconfig
  printf 'Name: zlib\nDescription: zlib from the Android NDK\nVersion: 1.3\nLibs: -lz\nCflags:\n' > $P/lib/pkgconfig/zlib.pc
}
step_openssl() { # HTTPClient (import from URLs)
  unpack openssl-3.5.4; cd $S
  export ANDROID_NDK_ROOT=$NDK PATH=$TC/bin:$PATH
  local target=android-${TRIPLE%%-*}; target=${target/aarch64/arm64}
  ./Configure $target -D__ANDROID_API__=$API --prefix=$P --libdir=lib no-shared no-tests no-docs no-apps \
    && make -j$JOBS build_libs && make install_dev
}
step_freetype() {
  unpack freetype-2.13.3
  cm $S freetype -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_PNG=ON -DFT_REQUIRE_ZLIB=ON
}
step_harfbuzz() {
  unpack harfbuzz-10.1.0; meson_cross; rm -rf $B/harfbuzz
  meson setup $B/harfbuzz $S --cross-file $B/cross.ini --prefix=$P --libdir=lib --buildtype=release --default-library=static \
    -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dchafa=disabled \
    -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dintrospection=disabled
  ninja -C $B/harfbuzz -j$JOBS install
}
step_expat() {
  unpack expat-2.6.4
  cm $S expat -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_DOCS=OFF -DEXPAT_SHARED_LIBS=OFF
}
step_fontconfig() {
  unpack fontconfig-2.15.0; meson_cross; rm -rf $B/fontconfig
  meson setup $B/fontconfig $S --cross-file $B/cross.ini --prefix=$P --libdir=lib --buildtype=release --default-library=static \
    -Ddoc=disabled -Dtests=disabled -Dtools=disabled -Dcache-build=disabled -Dnls=disabled -Diconv=disabled
  ninja -C $B/fontconfig -j$JOBS install
}
step_libxml2() {
  unpack libxml2-2.13.5
  cm $S libxml2 -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_ZLIB=OFF \
    -DLIBXML2_WITH_ICU=OFF -DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_PROGRAMS=OFF -DLIBXML2_WITH_HTTP=OFF
}
step_libzip() {
  unpack libzip-1.11.2
  cm $S libzip -DENABLE_COMMONCRYPTO=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DENABLE_OPENSSL=OFF -DENABLE_WINDOWS_CRYPTO=OFF \
    -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF \
    -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
}
step_doubleconversion() { unpack double-conversion-3.3.0; cm $S double-conversion -DBUILD_TESTING=OFF; }
step_utf8proc() { unpack utf8proc-2.9.0; cm $S utf8proc -DUTF8PROC_INSTALL=ON -DUTF8PROC_ENABLE_TESTING=OFF; }
step_glibshim() { cm $R/deps/glib-shim glib-shim; }
step_libintl() { cm $R/deps/libintl-lite libintl; }
step_qscintilla() {
  unpack QScintilla_src-2.14.1
  rm -rf $B/qscintilla
  cmake -S $R/deps/qscintilla -B $B/qscintilla "${CMAKE_QT[@]}" -DQSCI_SRC=$S -DCMAKE_INSTALL_PREFIX=$P \
    && cmake --build $B/qscintilla -j$JOBS && cmake --install $B/qscintilla
}
step_gl4es() {
  unpack gl4es-1.1.6
  patch -d $S -p1 < $R/patches/gl4es-android.patch
  cm $S gl4es -DANDROID=ON -DNOEGL=ON -DSTATICLIB=ON -DNO_LOADER=ON -DNO_INIT_CONSTRUCTOR=ON -DUSE_ANDROID_LOG=ON -DNO_GBM=ON
  # gl4es has no install rules for the static lib
  cp $(find $B/gl4es $S/lib -name 'libGL*.a' 2>/dev/null | head -1) $P/lib/libgl4es.a
  mkdir -p $P/include/gl4es $P/include/GL && cp $S/include/gl4esinit.h $S/include/gl4eshint.h $P/include/gl4es/
  cp $S/include/GL/gl.h $S/include/GL/glext.h $S/include/GL/gl_mangle.h $P/include/GL/  # desktop GL headers, for GLU
  printf 'prefix=%s\nName: gl\nDescription: desktop OpenGL from gl4es (on GLES)\nVersion: 2.1\nLibs: -L${prefix}/lib -lgl4es -lGLESv2 -lEGL -ldl\nCflags: -I${prefix}/include\n' $P \
    > $P/lib/pkgconfig/gl.pc
}
step_glu() { # GLU (tessellator, gluUnProject) for the CGAL renderer and the view
  unpack glu-9.0.3; meson_cross; rm -rf $B/glu
  meson setup $B/glu $S --cross-file $B/cross.ini --prefix=$P --libdir=lib --buildtype=release --default-library=static \
    -Dgl_provider=gl
  ninja -C $B/glu -j$JOBS install
}

ALL="qt qtplugin qtsvg gmp mpfr boost eigen cgal tbb zlibpc freetype harfbuzz expat fontconfig libxml2 libzip doubleconversion utf8proc glibshim libintl qscintilla gl4es glu openssl"
STEPS=${*:-$ALL}
for s in $STEPS; do
  if [ $# -eq 0 ] && [ -f $B/$s.done ]; then continue; fi
  echo "[$ABI] $s"
  if ( step_$s ) > $B/$s.log 2>&1; then touch $B/$s.done; else echo "[$ABI] $s FAILED, see build/deps-$ABI/$s.log"; tail -20 $B/$s.log; exit 1; fi
done
echo "[$ABI] dependencies ready in $P"
