# Qt's Android platform plugin (qtbase src/plugins/platforms/android), rebuilt alone against the installed Qt so it can
# carry our fix (patches/qtbase-android.patch). Configure with -DQTBASE_SRC=<qtbase-everywhere-src-6.8.3> and the
# Qt for Android toolchain; it installs over plugins/platforms/libplugins_platforms_qtforandroid_<abi>.so.
cmake_minimum_required(VERSION 3.16)
project(qtforandroid CXX)
find_package(Qt6 REQUIRED COMPONENTS Core Gui)
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(D ${QTBASE_SRC}/src/plugins/platforms/android)

file(GLOB _src ${D}/*.cpp)
list(FILTER _src EXCLUDE REGEX "extract-dummy\\.cpp|qandroidplatformvulkan.*\\.cpp")  # android_style_assets on, vulkan off
qt_add_plugin(qtforandroid SHARED PLUGIN_TYPE platforms CLASS_NAME QAndroidIntegrationPlugin OUTPUT_NAME qtforandroid)
target_sources(qtforandroid PRIVATE ${_src})
# some private headers include QPA headers by bare name, which Qt's own build finds next to them in its source tree
set(_qtinc ${Qt6Gui_DIR}/../../../include/QtGui/${Qt6_VERSION}/QtGui/qpa)
target_include_directories(qtforandroid PRIVATE ${D} ${QTBASE_SRC}/src/3rdparty/android ${_qtinc})
target_compile_definitions(qtforandroid PRIVATE QT_NO_FOREACH QT_USE_QSTRINGBUILDER QT_BUILD_PLUGIN QT_PLUGIN)
target_link_libraries(qtforandroid PRIVATE Qt6::Core Qt6::CorePrivate Qt6::Gui Qt6::GuiPrivate EGL android jnigraphics log)
