# libintl-lite: the gettext API OpenSCAD uses (bionic has no libintl), installed as libintl.a + libintl.h.
cmake_minimum_required(VERSION 3.16)
project(libintl-lite CXX)
set(CMAKE_CXX_STANDARD 17)
add_library(intl STATIC intl.cc)
install(TARGETS intl ARCHIVE DESTINATION lib)
install(FILES libintl.h DESTINATION include)
