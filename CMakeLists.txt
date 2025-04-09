cmake_minimum_required(VERSION 3.14)
project(IrisCodecWasm VERSION 2025.1.0)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add necessary definitions
add_compile_definitions(IFE_EXPORT=)
add_compile_definitions(IFE_EXPORT_API=false)
add_compile_definitions(__EMSCRIPTEN__=1)
add_compile_definitions(IRIS_NO_TURBOJPEG=1)
add_compile_definitions(IRIS_NO_AVIF=1)

# Option for building HTML examples
option(IRIS_BUILD_HTML_EXAMPLES "Build HTML examples" ON)

# Include FetchContent for dependencies
include(FetchContent)

# Fetch Iris Headers
FetchContent_Declare(
    IrisHeaders
    GIT_REPOSITORY https://github.com/IrisDigitalPathology/Iris-Headers.git
    GIT_TAG "origin/main"
    GIT_SHALLOW ON
)

# Fetch Iris File Extension
FetchContent_Declare(
    IrisFileExtension
    GIT_REPOSITORY https://github.com/IrisDigitalPathology/Iris-File-Extension.git
    GIT_TAG "origin/main"
    GIT_SHALLOW ON
)

# Fetch Iris Codec
FetchContent_Declare(
    IrisCodec
    GIT_REPOSITORY https://github.com/IrisDigitalPathology/Iris-Codec.git
    GIT_TAG "origin/main"
    GIT_SHALLOW ON
)

# Set options for IrisCodec before making it available
set(IRIS_BUILD_ENCODER OFF CACHE BOOL "Disable encoder functionality for WebAssembly build" FORCE)
set(IRIS_BUILD_TESTS OFF CACHE BOOL "Disable tests for WebAssembly build" FORCE)
set(IRIS_BUILD_EXAMPLES OFF CACHE BOOL "Disable examples for WebAssembly build" FORCE)
set(IRIS_USE_TURBOJPEG OFF CACHE BOOL "Disable TurboJPEG for WebAssembly build" FORCE)
set(IRIS_USE_AVIF OFF CACHE BOOL "Disable AVIF for WebAssembly build" FORCE)

# Make the content available
FetchContent_MakeAvailable(
    IrisHeaders
    IrisFileExtension
)

# We'll handle IrisCodec differently to avoid building its dependencies
FetchContent_GetProperties(IrisCodec)
if(NOT iriscodec_POPULATED)
    FetchContent_Populate(IrisCodec)
endif()

# Print version information
message(STATUS "BUILDING IRIS CODEC WASM MODULE VERSION v${PROJECT_VERSION}")

# Set source files - use our custom Emscripten versions
set(SOURCES
    ${CMAKE_SOURCE_DIR}/src/IrisCodecEmscripten.cpp
    ${CMAKE_SOURCE_DIR}/src/IrisCodecContext.cpp
    ${CMAKE_SOURCE_DIR}/src/IrisCodecFile.cpp
    ${iriscodec_SOURCE_DIR}/src/IrisCodecSlide.cpp
    ${iriscodec_SOURCE_DIR}/src/IrisCodecCache.cpp
    ${irisheaders_SOURCE_DIR}/src/IrisBuffer.cpp
)

# Create the WebAssembly module
add_executable(iris_codec ${SOURCES})

# Add include directories
target_include_directories(iris_codec PRIVATE
    ${iriscodec_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src
    ${irisheaders_SOURCE_DIR}/include
    ${irisheaders_SOURCE_DIR}/priv
    ${irisfileextension_SOURCE_DIR}/src
)

# Link with the Iris File Extension library
target_link_libraries(iris_codec PRIVATE
    IrisFileExtensionStatic
)

# Set Emscripten-specific options
set_target_properties(iris_codec PROPERTIES
    SUFFIX ".js"
    LINK_FLAGS "--bind -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 -s EXPORT_NAME='IrisCodec' -s EXPORTED_RUNTIME_METHODS=['FS'] -s ENVIRONMENT='web' -s ERROR_ON_UNDEFINED_SYMBOLS=0"
)

# Handle HTML examples
if(IRIS_BUILD_HTML_EXAMPLES)
    message(STATUS "Building HTML examples")
    
    # Create a directory for HTML examples
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/html_examples)
    
    # Copy example HTML files to html_examples directory
    file(GLOB EXAMPLE_HTML_FILES "${CMAKE_SOURCE_DIR}/examples/*.html")
    foreach(HTML_FILE ${EXAMPLE_HTML_FILES})
        get_filename_component(FILE_NAME ${HTML_FILE} NAME)
        configure_file(${HTML_FILE} ${CMAKE_BINARY_DIR}/html_examples/${FILE_NAME} COPYONLY)
    endforeach()
endif()
