# TightNCM —— 目标 Qt 5.15（最后一个支持 Windows 7 的 Qt 系列）
#
# 为什么是 5.15：Qt 6 官方最低要求 Windows 10 1809（QTBUG-85851）。
# 5.15.2 是最后一个 LGPL 开源发布版（5.15.3+ 长期仅商业版）。
cmake_minimum_required(VERSION 3.16)

project(TightNCM VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# AUTORCC 负责编译 resources.qrc（不要再调 qt5_add_resources，会重复编译）
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "构建类型" FORCE)
endif()

# ── 找 Qt5 ──────────────────────────────────────────────
find_package(Qt5 5.15 REQUIRED COMPONENTS Core Gui Qml Quick Svg Network Multimedia)

if(NOT Qt5_FOUND)
    message(FATAL_ERROR
        "找不到 Qt 5.15.x。\n"
        "本项目**必须**用 Qt 5 —— Qt 6 不支持 Windows 7，而且本项目的 QML 依赖\n"
        "QtGraphicalEffects（Qt 6 里改名为 Qt5Compat.GraphicalEffects，需要改所有 import）。\n"
        "请运行 setup-env.bat 自动安装，或手动安装 Qt 5.15.2 后指定 -DCMAKE_PREFIX_PATH=<Qt路径>")
endif()

message(STATUS "Qt 版本: ${Qt5_VERSION}")
message(STATUS "Qt 路径: ${Qt5_DIR}")

# QtGraphicalEffects 在 5.15 是随包模块，这里确认一下 QML 模块存在
set(_qml_dir "${Qt5_DIR}/../../../qml")
if(EXISTS "${_qml_dir}/QtGraphicalEffects")
    message(STATUS "QtGraphicalEffects: 已就位")
else()
    message(WARNING "没找到 ${_qml_dir}/QtGraphicalEffects，运行时会缺模糊/阴影效果")
endif()

# ── 目标 ────────────────────────────────────────────────
# TIGHTNCM_CONSOLE=ON 会生成带控制台窗口的版本，方便看 qDebug / QML 报错
option(TIGHTNCM_CONSOLE "构建带控制台的调试版本" OFF)

set(_exe_type WIN32)
if(TIGHTNCM_CONSOLE)
    set(_exe_type "")
endif()

add_executable(TightNCM ${_exe_type}
    src/main.cpp
    src/net/NcmApi.h
    src/net/NcmApi.cpp
    src/audio/AudioPlayer.h
    src/audio/AudioPlayer.cpp
    src/core/AppStore.h
    src/core/AppStore.cpp
    src/core/ColorProbe.h
    src/core/ColorProbe.cpp
    src/core/TrayNotifier.h
    src/core/TrayNotifier.cpp
    src/core/SvgIcon.h
    src/core/SvgIcon.cpp
    resources.qrc
)

target_include_directories(TightNCM PRIVATE src)
target_link_libraries(TightNCM PRIVATE
    Qt5::Core Qt5::Gui Qt5::Qml Qt5::Quick Qt5::Svg Qt5::Network Qt5::Multimedia
)

# Windows 上要拿进程常驻内存（--memtest 打点用），MinGW 需要显式链 psapi
if(WIN32)
    # psapi: 取常驻内存（--memtest 打点）
    # shell32: 系统通知（TrayNotifier，见那个文件里为什么不直接用 QSystemTrayIcon）
    target_link_libraries(TightNCM PRIVATE psapi shell32)
endif()

# MinGW/MSVC 都按 UTF-8 源码处理（源码里有中文注释）
if(MSVC)
    target_compile_options(TightNCM PRIVATE /utf-8 /W3)
else()
    target_compile_options(TightNCM PRIVATE -Wall -finput-charset=UTF-8 -fexec-charset=UTF-8)
endif()

# ── 部署（独立目标，不挂在构建里，避免部署失败拖累编译） ──
if(WIN32)
    get_filename_component(_qt_bin "${Qt5_DIR}/../../../bin" ABSOLUTE)
    get_filename_component(_qt_qml "${Qt5_DIR}/../../../qml" ABSOLUTE)
    get_filename_component(_qt_plugins "${Qt5_DIR}/../../../plugins" ABSOLUTE)

    find_program(WINDEPLOYQT_EXECUTABLE
        NAMES windeployqt
        HINTS "${_qt_bin}"
        NO_DEFAULT_PATH)
    if(NOT WINDEPLOYQT_EXECUTABLE)
        find_program(WINDEPLOYQT_EXECUTABLE NAMES windeployqt)
    endif()

    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_target(deploy
            COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                    --release --no-translations --no-system-d3d-compiler
                    --no-compiler-runtime
                    --plugindir "${_qt_plugins}"
                    --qmlimport "${_qt_qml}"
                    "$<TARGET_FILE:TightNCM>"
            DEPENDS TightNCM
            COMMENT "windeployqt: 收集 Qt 运行库到输出目录"
            VERBATIM)
    else()
        message(WARNING "没找到 windeployqt，可用 `cmake --build build --target deploy` 的前提是能自动找到它")
    endif()
endif()
