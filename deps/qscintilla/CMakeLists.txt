# QScintilla 2.14 (Qt 6) as a static library, built with CMake instead of its qmake project (src/qscintilla.pro).
# Configure with -DQSCI_SRC=<QScintilla_src-2.14.x> and the Qt for Android toolchain.
cmake_minimum_required(VERSION 3.16)
project(qscintilla CXX)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets PrintSupport)
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(S ${QSCI_SRC})

file(GLOB _qsci ${S}/src/*.cpp)
list(FILTER _qsci EXCLUDE REGEX "MacPasteboardMime")  # macOS only
file(GLOB _sci ${S}/scintilla/src/*.cpp ${S}/scintilla/lexlib/*.cpp ${S}/scintilla/lexers/*.cpp)
file(GLOB _hdr ${S}/src/*.h ${S}/src/Qsci/*.h)

add_library(qscintilla2_qt6 STATIC ${_qsci} ${_sci} ${_hdr})
target_include_directories(qscintilla2_qt6 PRIVATE ${S}/src ${S}/scintilla/include ${S}/scintilla/lexlib ${S}/scintilla/src)
target_compile_definitions(qscintilla2_qt6 PRIVATE SCINTILLA_QT SCI_LEXER INCLUDE_DEPRECATED_FEATURES)
target_link_libraries(qscintilla2_qt6 PUBLIC Qt6::Widgets Qt6::PrintSupport)
target_compile_options(qscintilla2_qt6 PRIVATE -w)

install(TARGETS qscintilla2_qt6 ARCHIVE DESTINATION lib)
file(GLOB _pub ${S}/src/Qsci/*.h)
install(FILES ${_pub} DESTINATION include/Qsci)
