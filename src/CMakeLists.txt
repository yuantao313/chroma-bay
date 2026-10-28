cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(chroma_bay C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(chroma_bay)

pico_generate_pio_header(chroma_bay
    ${CMAKE_CURRENT_LIST_DIR}/Lighting/neopixel.pio)

target_sources(chroma_bay PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/main.c
    ${CMAKE_CURRENT_LIST_DIR}/usb_descriptors.c
    ${CMAKE_CURRENT_LIST_DIR}/Lighting/Neopixel.c
    ${CMAKE_CURRENT_LIST_DIR}/Lighting/LampArray.c
    )

target_include_directories(chroma_bay PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}
    )

target_link_libraries(chroma_bay PUBLIC
    pico_stdlib
    hardware_pio
    hardware_watchdog
    hardware_exception
    tinyusb_device
    tinyusb_board
    )

pico_add_extra_outputs(chroma_bay)
pico_enable_stdio_usb(chroma_bay 1)
