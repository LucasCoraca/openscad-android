# glib-shim: GLib's UTF-8 functions OpenSCAD uses, installed with a glib-2.0.pc so OpenSCAD's CMake finds it as GLib.
cmake_minimum_required(VERSION 3.16)
project(glib-shim C)
find_package(utf8proc QUIET)
find_path(UTF8PROC_INCLUDE_DIR utf8proc.h REQUIRED)
find_library(UTF8PROC_LIBRARY NAMES utf8proc utf8proc_static REQUIRED)
add_library(glib-2.0 STATIC gutf8.c)
target_include_directories(glib-2.0 PRIVATE ${UTF8PROC_INCLUDE_DIR})
target_compile_definitions(glib-2.0 PRIVATE UTF8PROC_STATIC)
install(TARGETS glib-2.0 ARCHIVE DESTINATION lib)
install(FILES glib.h DESTINATION include/glib-2.0)
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/glib-2.0.pc
"prefix=${CMAKE_INSTALL_PREFIX}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: GLib
Description: GLib UTF-8 subset for OpenSCAD on Android (glib-shim)
Version: 2.80.0
Libs: -L\${libdir} -lglib-2.0 -lutf8proc
Cflags: -I\${includedir}/glib-2.0
")
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/glib-2.0.pc DESTINATION lib/pkgconfig)
