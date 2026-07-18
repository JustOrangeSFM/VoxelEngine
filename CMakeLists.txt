cmake_minimum_required(VERSION 3.20)
project(App VERSION 1.0.0 LANGUAGES CXX C)

option(ENABLE_WARNINGS "Enable warnings" ON)
option(ENABLE_COMPILE_COMMANDS "Generate compile_commands.json" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Определяем архитектуру
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(ARCH "x64")
else()
    set(ARCH "x86")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/debug)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/debug)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/debug)
else()
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/release)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/release)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/release)
endif()

set(GLFW_INCLUDE_DIR ${CMAKE_SOURCE_DIR}/external/glfw/include)
set(GLFW_LIBRARY ${CMAKE_SOURCE_DIR}/external/glfw/lib-vc2022/glfw3.lib)
set(GLFW_DLL ${CMAKE_SOURCE_DIR}/external/glfw/lib-vc2022/glfw3.dll)

# GLAD
add_library(glad STATIC external/glad/src/glad.c)
target_include_directories(glad PRIVATE 
    ${CMAKE_SOURCE_DIR}/external/glad/include
    ${CMAKE_SOURCE_DIR}/external
)
target_compile_definitions(glad PUBLIC GLAD_GL_IMPLEMENTATION)

# GLM - добавляем как поддиректорию
add_subdirectory(external/glm)

# IMGUI
file(GLOB IMGUI_SOURCES 
    external/imgui/*.cpp 
    external/imgui/backends/*.cpp
)
add_library(imgui STATIC ${IMGUI_SOURCES})
target_include_directories(imgui PUBLIC 
    ${CMAKE_SOURCE_DIR}/external/imgui
    ${CMAKE_SOURCE_DIR}/external/imgui/backends
)
target_include_directories(imgui SYSTEM PRIVATE 
    ${GLFW_INCLUDE_DIR}
)

# Project options
add_library(project_options INTERFACE)
target_compile_features(project_options INTERFACE cxx_std_20)

if(ENABLE_WARNINGS)
    if(MSVC)
        target_compile_options(project_options INTERFACE
            /W4
            /WX-
            /permissive-
        )
    else()
        target_compile_options(project_options INTERFACE
            -Wall -Wextra -Wpedantic
            -Wshadow -Wformat=2 -Wconversion
            -Wnull-dereference -Wdouble-promotion
        )
    endif()
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(MSVC)
        target_compile_options(project_options INTERFACE 
            /MDd
            /Zi
            /Od
        )
        target_compile_definitions(project_options INTERFACE 
            DEBUG=1
            _DEBUG
            _WIN32_WINNT=0x0A00
        )
    else()
        target_compile_options(project_options INTERFACE 
            -g
            -O0
            -fno-omit-frame-pointer
        )
        target_compile_definitions(project_options INTERFACE 
            DEBUG=1
            _DEBUG
        )
    endif()
    message(STATUS "Debug build enabled")
    message(STATUS "Output: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
else()
    if(MSVC)
        target_compile_options(project_options INTERFACE 
            /MD
            /O2
        )
        target_compile_definitions(project_options INTERFACE 
            NDEBUG
            _WIN32_WINNT=0x0A00
        )
    else()
        target_compile_options(project_options INTERFACE 
            -O2
            -DNDEBUG
        )
    endif()
    message(STATUS "Release build enabled")
    message(STATUS "Output: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
endif()

find_package(OpenGL REQUIRED)

if(NOT EXISTS ${GLFW_INCLUDE_DIR}/GLFW/glfw3.h)
    message(FATAL_ERROR "GLFW headers not found at ${GLFW_INCLUDE_DIR}")
endif()

if(NOT EXISTS ${GLFW_LIBRARY})
    message(FATAL_ERROR "GLFW library not found at ${GLFW_LIBRARY}")
endif()

add_library(glfw SHARED IMPORTED)
set_target_properties(glfw PROPERTIES
    IMPORTED_LOCATION ${GLFW_DLL}
    IMPORTED_IMPLIB ${GLFW_LIBRARY}
    INTERFACE_INCLUDE_DIRECTORIES ${GLFW_INCLUDE_DIR}
)

find_package(Threads REQUIRED)

file(GLOB_RECURSE APP_SOURCES src/*.cpp)
add_executable(${PROJECT_NAME} ${APP_SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_SOURCE_DIR}/inc
    ${CMAKE_SOURCE_DIR}/external
    ${CMAKE_SOURCE_DIR}/external/stb
    ${CMAKE_SOURCE_DIR}/external/robin_hood
    ${CMAKE_SOURCE_DIR}/external/KHR
    ${CMAKE_SOURCE_DIR}/external/glad/include
    ${GLFW_INCLUDE_DIR}
)

# Линкуем с GLM
target_link_libraries(${PROJECT_NAME}
    PRIVATE
    project_options
    glad
    imgui
    glfw
    OpenGL::GL
    Threads::Threads
    glm
    ${CMAKE_DL_LIBS}
)

if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        opengl32
        gdi32
        user32
        shell32
        psapi
    )
endif()

# Исправленные POST_BUILD команды с кавычками для путей с пробелами
if(EXISTS ${CMAKE_SOURCE_DIR}/res)
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_SOURCE_DIR}/res"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
        COMMENT "Copying resources"
    )
endif()

if(EXISTS ${GLFW_DLL})
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${GLFW_DLL}"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
        COMMENT "Copying glfw3.dll"
    )
endif()

# Only attempt to copy compile_commands.json if it exists and generator supports it
if(ENABLE_COMPILE_COMMANDS AND CMAKE_EXPORT_COMPILE_COMMANDS)
    # Only for non-VS generators
    if(NOT CMAKE_GENERATOR MATCHES "Visual Studio")
        set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_BINARY_DIR}/compile_commands.json"
                "${CMAKE_SOURCE_DIR}/compile_commands.json"
            COMMENT "Generating compile_commands.json"
        )
    else()
        message(STATUS "compile_commands.json not supported with Visual Studio generator")
        message(STATUS "Use Ninja or Makefile generator for compile_commands.json support")
    endif()
endif()

add_custom_target(clean_bin
    COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_SOURCE_DIR}/bin"
    COMMAND echo "Cleaned bin/"
)

add_custom_target(clean_all
    COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_SOURCE_DIR}/bin"
    COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}"
    COMMAND echo "Cleaned bin/ and build/"
)

message(STATUS "Project configured successfully")
message(STATUS "Build directory: ${CMAKE_BINARY_DIR}")
message(STATUS "Output directory: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")