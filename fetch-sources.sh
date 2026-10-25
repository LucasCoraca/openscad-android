#!/bin/bash
# Download every source this port builds: OpenSCAD (pinned, with submodules, patched), its dependencies and the host tools.
# Tarballs land in dl-cache/ and are unpacked into build/src/ by build-deps.sh; OpenSCAD is checked out to openscad-src/.
set -e
R="$(cd "$(dirname "$0")" && pwd)"
OPENSCAD_COMMIT=${OPENSCAD_COMMIT:-a3bf46a}
mkdir -p "$R/dl-cache"

# name|url
SOURCES="
m4-1.4.19.tar.xz|https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz
bison-3.8.2.tar.xz|https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz
flex-2.6.4.tar.gz|https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz
gperf-3.1.tar.gz|https://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz
gmp-6.3.0.tar.xz|https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
mpfr-4.2.1.tar.xz|https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz
boost-1.86.0-cmake.tar.xz|https://github.com/boostorg/boost/releases/download/boost-1.86.0/boost-1.86.0-cmake.tar.xz
eigen-3.4.0.tar.gz|https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz
CGAL-6.0.1.tar.xz|https://github.com/CGAL/cgal/releases/download/v6.0.1/CGAL-6.0.1.tar.xz
oneTBB-2021.13.0.tar.gz|https://github.com/uxlfoundation/oneTBB/archive/refs/tags/v2021.13.0.tar.gz
freetype-2.13.3.tar.xz|https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz
harfbuzz-10.1.0.tar.xz|https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz
expat-2.6.4.tar.xz|https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.xz
fontconfig-2.15.0.tar.xz|https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz
libxml2-2.13.5.tar.xz|https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz
libzip-1.11.2.tar.xz|https://libzip.org/download/libzip-1.11.2.tar.xz
double-conversion-3.3.0.tar.gz|https://github.com/google/double-conversion/archive/refs/tags/v3.3.0.tar.gz
utf8proc-2.9.0.tar.gz|https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.9.0.tar.gz
QScintilla_src-2.14.1.tar.gz|https://www.riverbankcomputing.com/static/Downloads/QScintilla/2.14.1/QScintilla_src-2.14.1.tar.gz
qtsvg-everywhere-src-6.8.3.tar.xz|https://download.qt.io/archive/qt/6.8/6.8.3/submodules/qtsvg-everywhere-src-6.8.3.tar.xz
qtbase-everywhere-src-6.8.3.tar.xz|https://download.qt.io/archive/qt/6.8/6.8.3/submodules/qtbase-everywhere-src-6.8.3.tar.xz
gl4es-1.1.6.tar.gz|https://github.com/ptitSeb/gl4es/archive/refs/tags/v1.1.6.tar.gz
glu-9.0.3.tar.xz|https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz
openssl-3.5.4.tar.gz|https://github.com/openssl/openssl/releases/download/openssl-3.5.4/openssl-3.5.4.tar.gz
lib3mf-2.3.2.tar.gz|https://github.com/3MFConsortium/lib3mf/archive/refs/tags/v2.3.2.tar.gz
pixman-0.43.4.tar.gz|https://cairographics.org/releases/pixman-0.43.4.tar.gz
cairo-1.18.2.tar.xz|https://cairographics.org/releases/cairo-1.18.2.tar.xz
"
for line in $SOURCES; do
  name=${line%%|*} url=${line#*|}
  [ -s "$R/dl-cache/$name" ] && continue
  echo "fetch $name"
  curl -fL --retry 3 -o "$R/dl-cache/$name.part" "$url" && mv "$R/dl-cache/$name.part" "$R/dl-cache/$name"
done

if [ ! -d "$R/openscad-src/.git" ]; then
  git clone https://github.com/openscad/openscad.git "$R/openscad-src"
fi
cd "$R/openscad-src"
if ! git cat-file -e "$OPENSCAD_COMMIT^{commit}" 2>/dev/null; then git fetch --unshallow 2>/dev/null || git fetch; fi
if [ "$(git rev-parse --short HEAD)" != "$OPENSCAD_COMMIT" ] || [ -z "$(git status --porcelain)" ]; then
  git checkout -q "$OPENSCAD_COMMIT"
  git submodule update --init --recursive
  [ -s "$R/patches/openscad-android.patch" ] && git apply "$R/patches/openscad-android.patch"
  [ -s "$R/patches/opencsg-android.patch" ] && git -C submodules/OpenCSG apply "$R/patches/opencsg-android.patch"
fi
echo "sources ready"
