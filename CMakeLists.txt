cmake_minimum_required(VERSION 3.21)

project(PaletteSniper VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Quick
    QuickControls2
    Gui
)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(PaletteSniper WIN32
    main.cpp
    palettebackend.h
    palettebackend.cpp
    icon.rc
)

qt_add_resources(PaletteSniper "qml_resources"
    PREFIX "/"
    FILES
        qml/Main.qml
        qml/CopyButton.qml
        qml/SegButton.qml
        qml/DarkCheckBox.qml
)

target_link_libraries(PaletteSniper PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Gui
)
