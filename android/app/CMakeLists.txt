# OpenSCAD for Android: OpenSCAD's own GUI and engine (OpenSCADLibInternal) with an Android entry point, packaged by Qt.
# Added by OpenSCAD's CMakeLists.txt when ANDROID and OPENSCAD_ANDROID_DIR are set (needs the Qt for Android toolchain).
find_package(Qt6 REQUIRED COMPONENTS Core Widgets OpenGLWidgets Svg)

set(OSA_PACKAGE_DIR "${CMAKE_CURRENT_BINARY_DIR}/package")
file(MAKE_DIRECTORY "${OSA_PACKAGE_DIR}/assets")
file(GLOB_RECURSE _pkg_files RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}/package" CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/package/*")
foreach (_f ${_pkg_files})  # manifest, gradle, launcher icon, Java
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/package/${_f}" "${OSA_PACKAGE_DIR}/${_f}" COPYONLY)
endforeach ()

# share/openscad (examples, libraries, fonts, color schemes, shaders, templates) -> one asset, unpacked on first start
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(_res_dirs color-schemes examples fonts libraries shaders templates locale)
set(_res_deps "")
foreach (_d ${_res_dirs})
  file(GLOB_RECURSE _files CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/${_d}/*")
  list(APPEND _res_deps ${_files})
endforeach ()
add_custom_command(
  OUTPUT "${OSA_PACKAGE_DIR}/assets/openscad-share.zip"
  COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/make_share_zip.py" "${CMAKE_SOURCE_DIR}"
          "${CMAKE_CURRENT_SOURCE_DIR}/fonts.conf" "${OSA_PACKAGE_DIR}/assets/openscad-share.zip" ${_res_dirs}
  DEPENDS ${_res_deps} "${CMAKE_CURRENT_SOURCE_DIR}/make_share_zip.py" "${CMAKE_CURRENT_SOURCE_DIR}/fonts.conf"
  COMMENT "Packing share/openscad into openscad-share.zip")
add_custom_target(openscad_share_zip DEPENDS "${OSA_PACKAGE_DIR}/assets/openscad-share.zip")

qt_add_executable(openscad_android main.cc)
add_dependencies(openscad_android openscad_share_zip)
# the static dependencies' own dependencies, which OpenSCAD's finders don't ask pkg-config for (fontconfig: expat; freetype: zlib)
find_library(EXPAT_LIBRARY expat REQUIRED)
target_link_libraries(openscad_android PRIVATE OpenSCADLibInternal svg Qt6::Widgets Qt6::OpenGLWidgets Qt6::Svg
  ${EXPAT_LIBRARY} z android log)

set_target_properties(openscad_android PROPERTIES
  QT_ANDROID_PACKAGE_SOURCE_DIR "${OSA_PACKAGE_DIR}"
  QT_ANDROID_PACKAGE_NAME "io.github.lucascoraca.openscad"
  QT_ANDROID_MIN_SDK_VERSION 28
  QT_ANDROID_TARGET_SDK_VERSION 34
  QT_ANDROID_APP_NAME "OpenSCAD"
  QT_ANDROID_VERSION_NAME "0.1.1-preview"
  QT_ANDROID_VERSION_CODE 2)  # bump for every release, so Android installs it as an update
