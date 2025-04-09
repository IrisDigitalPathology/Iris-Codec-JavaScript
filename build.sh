#!/bin/bash
# Build script for Iris Codec WebAssembly module

# Parse command line arguments
BUILD_EXAMPLES=true
CREATE_PACKAGE=false
INSTALL_DIR=""

for arg in "$@"
do
    case $arg in
        --no-examples)
        BUILD_EXAMPLES=false
        shift
        ;;
        --package)
        CREATE_PACKAGE=true
        shift
        ;;
        --install=*)
        INSTALL_DIR="${arg#*=}"
        shift
        ;;
    esac
done

# Ensure Emscripten is available
if ! command -v emcmake &> /dev/null; then
    echo "Error: Emscripten toolchain not found. Please source emsdk_env.sh first."
    exit 1
fi

# Create build directory
mkdir -p build
cd build

# Configure with CMake
EXAMPLES_FLAG=""
if [ "$BUILD_EXAMPLES" = false ]; then
    EXAMPLES_FLAG="-DIRIS_BUILD_HTML_EXAMPLES=OFF"
fi

echo "configure: cmake .. -DCMAKE_BUILD_TYPE=Release $EXAMPLES_FLAG"
emcmake cmake .. -DCMAKE_BUILD_TYPE=Release -DIRIS_USE_TURBOJPEG=OFF -DIRIS_USE_AVIF=OFF -DIRIS_BUILD_ENCODER=OFF $EXAMPLES_FLAG

# Fix include paths by copying IrisCore.hpp to the priv directory
if [ -d _deps/irisheaders-src ]; then
    echo "Copying IrisCore.hpp to the priv directory..."
    cp _deps/irisheaders-src/include/IrisCore.hpp _deps/irisheaders-src/priv/
fi

# Apply compatibility changes to IrisFileExtension
if [ -d _deps/irisfileextension-src ]; then
    echo "Applying compatibility changes to IrisFileExtension..."
    
    # Create EmscriptenCompat.hpp if it doesn't exist
    cat > _deps/irisfileextension-src/src/EmscriptenCompat.hpp << 'EOF'
#ifndef EMSCRIPTEN_COMPAT_HPP
#define EMSCRIPTEN_COMPAT_HPP

#include <cstring>
#include <type_traits>

// Provide a bit_cast implementation if std::bit_cast is not available
namespace std {
    template <typename To, typename From>
    typename std::enable_if<
        sizeof(To) == sizeof(From) &&
        std::is_trivially_copyable<From>::value &&
        std::is_trivially_copyable<To>::value,
        To>::type
    bit_cast(const From& src) noexcept {
        To dst;
        std::memcpy(&dst, &src, sizeof(To));
        return dst;
    }
}

#endif // EMSCRIPTEN_COMPAT_HPP
EOF

    # Add include for EmscriptenCompat.hpp at the top of IrisCodecExtension.cpp
    sed -i '1i\#include "EmscriptenCompat.hpp"' _deps/irisfileextension-src/src/IrisCodecExtension.cpp
    
    # Fix IFE_EXPORT issues directly with sed
    sed -i 's/namespace IFE_EXPORT Abstraction/namespace Abstraction/g' _deps/irisfileextension-src/src/IrisCodecExtension.hpp
    sed -i 's/struct IFE_EXPORT Header/struct Header/g' _deps/irisfileextension-src/src/IrisCodecExtension.hpp
    sed -i 's/IFE_EXPORT //g' _deps/irisfileextension-src/src/IrisCodecExtension.hpp
fi

# Apply compatibility changes to IrisCodec if needed
if [ -d _deps/iriscodec-src ]; then
    echo "Applying compatibility changes to IrisCodec..."
    
    # Copy our EmscriptenCompat.hpp to the IrisCodec src directory
    cp ../src/EmscriptenCompat.hpp _deps/iriscodec-src/src/
    
    # Create a stub CMakeLists.txt to prevent building dependencies
    cat > _deps/iriscodec-src/cmake/turbo-jpeg.cmake << 'EOF'
# Stub file to prevent building TurboJPEG
message(STATUS "TurboJPEG disabled for WebAssembly build")
EOF

    cat > _deps/iriscodec-src/cmake/avif.cmake << 'EOF'
# Stub file to prevent building AVIF
message(STATUS "AVIF disabled for WebAssembly build")
EOF

    cat > _deps/iriscodec-src/cmake/openslide.cmake << 'EOF'
# Stub file to prevent building OpenSlide
message(STATUS "OpenSlide disabled for WebAssembly build")
EOF
fi

# Copy our custom files
echo "Copying custom Emscripten-compatible files..."
cp ../src/EmscriptenCompat.hpp .
cp ../src/IrisCodecContext.cpp .
cp ../src/IrisCodecFile.cpp .

# Build
echo "make: make -j$(nproc)"
emmake make -j$(nproc)

# Create packages if requested
if [ "$CREATE_PACKAGE" = true ]; then
    echo "Creating packages..."
    
    # Get version from CMakeLists.txt
    VERSION=$(grep -oP 'VERSION \K[0-9]+\.[0-9]+\.[0-9]+' ../CMakeLists.txt)
    
    # Determine platform architecture
    ARCH=$(uname -m)
    OS=$(uname -s)
    
    if [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            PLATFORM="linux-x86_64"
        elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            PLATFORM="linux-aarch64"
        else
            PLATFORM="linux-$ARCH"
        fi
    elif [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            PLATFORM="macOS-x86_64"
        elif [ "$ARCH" = "arm64" ]; then
            PLATFORM="macOS-arm64"
        else
            PLATFORM="macOS-$ARCH"
        fi
    else
        # Default to win-64 if we can't determine the platform (likely Windows)
        PLATFORM="win-64"
    fi
    
    # Create a temporary directory for packaging
    TEMP_DIR=$(mktemp -d)
    mkdir -p $TEMP_DIR/iris-codec
    
    # Copy WebAssembly files
    cp -f iris_codec.js iris_codec.wasm $TEMP_DIR/iris-codec/
    
    # Copy examples if enabled
    if [ "$BUILD_EXAMPLES" = true ]; then
        # Check all possible example locations
        if [ -d "html_examples" ]; then
            echo "Found examples in build/html_examples"
            mkdir -p $TEMP_DIR/iris-codec/html_examples
            cp -rf html_examples/* $TEMP_DIR/iris-codec/html_examples/
        elif [ -d "../examples" ]; then
            echo "Found examples in project root examples directory"
            mkdir -p $TEMP_DIR/iris-codec/html_examples
            cp -rf ../examples/*.html $TEMP_DIR/iris-codec/html_examples/
        elif [ -d "examples" ]; then
            echo "Found examples in build/examples"
            mkdir -p $TEMP_DIR/iris-codec/html_examples
            cp -rf examples/*.html $TEMP_DIR/iris-codec/html_examples/
        else
            echo "Warning: No examples found to include in the package"
        fi
    fi
    
    # Create the tar.gz package
    PACKAGE_NAME="${PLATFORM}-iris-codec-${VERSION}-a2.tar.gz"

    cd $TEMP_DIR
    tar -czf "$PACKAGE_NAME" iris-codec
    cp -f "$PACKAGE_NAME" /app/build/
    
    # Also copy to /output if it exists (for Docker)
    if [ -d "/output" ]; then
        cp -f "$PACKAGE_NAME" /output/
        echo "Package also copied to /output directory for Docker"
    fi
    
    cd ..
    
    # Clean up
    rm -rf $TEMP_DIR
    
    echo ""
    echo "Package created:"
    echo "- $PACKAGE_NAME: WebAssembly module package"
    echo "Location: $(pwd)/$PACKAGE_NAME"
    
    # Verify the package exists
    if [ -f "$PACKAGE_NAME" ]; then
        echo "Package file exists at $(pwd)/$PACKAGE_NAME"
        ls -la "$PACKAGE_NAME"
    else
        echo "Warning: Package file not found at expected location"
        echo "Searching for package file:"
        find /app -name "$PACKAGE_NAME"
    fi
fi

# Install if an installation directory was provided
if [ -n "$INSTALL_DIR" ]; then
    echo "Installing to $INSTALL_DIR..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy WebAssembly module files
    cp iris_codec.js iris_codec.wasm "$INSTALL_DIR/"
    
    # Copy examples if enabled
    if [ "$BUILD_EXAMPLES" = true ]; then
        mkdir -p "$INSTALL_DIR/html_examples"
        cp examples/*.html "$INSTALL_DIR/html_examples/"
    fi
    
    echo "Installation complete. Files installed to $INSTALL_DIR"
else
    echo "Build complete. WebAssembly module is available in the build directory."
fi

cd ..
