# Iris-Codec-JavaScript
[![Iris Codec Emscripten Webassembly Build](https://github.com/IrisDigitalPathology/Iris-Codec-JavaScript/actions/workflows/emcmake.yml/badge.svg)](https://github.com/IrisDigitalPathology/Iris-Codec-JavaScript/actions/workflows/emcmake.yml)

This repository contains the WebAssembly (WASM) build of the Iris Codec library, allowing it to be used in web browsers and Node.js applications.

## Overview

Iris Codec JavaScript provides a WebAssembly module that enables web applications to read and process Iris digital pathology slide files directly in the browser. This allows for viewing and analyzing whole slide images without requiring server-side processing.

## Features

- Load and validate Iris slide files (.iris)
- Read slide metadata and layer information
- Extract and render individual tiles from slides
- Compatible with modern web browsers and Node.js

## Building from Source

### Prerequisites

- CMake 3.14 or higher
- Emscripten SDK (emsdk)
- Git
- C++ compiler with C++20 support

### Local Build

1. Clone the repository:
   ```bash
   git clone https://github.com/IrisDigitalPathology/Iris-Codec-JavaScript.git
   cd Iris-Codec-JavaScript
   ```

2. Set up Emscripten environment:
   ```bash
   # On Linux/macOS
   source /path/to/emsdk/emsdk_env.sh
   
   # On Windows
   call C:\path\to\emsdk\emsdk_env.bat
   ```

3. Run the build script:
   ```bash
   # On Linux/macOS
   ./build.sh
   
   # On Windows
   build.bat
   ```

4. The WebAssembly module will be available in the `build` directory.

### Build Options

The build script supports several options:

```bash
# Build without examples
./build.sh --no-examples

# Create packages
./build.sh --package

# Install to a specific directory
./build.sh --install=/path/to/install
```

## Docker Build

We provide Docker configurations for building the WebAssembly module on both Linux and Windows environments.

### Prerequisites

- Docker
- Docker Compose

### Building with Docker

Run the following command from the repository root:

```bash
docker-compose -f docker/docker-compose.yml run linux-build
```

The build output will be available in the `output` directory, including:
- `iris_codec.js` and `iris_codec.wasm` - The WebAssembly module files
- `html_examples/` - HTML example files (if examples are enabled)
- Platform-specific package (if packaging is enabled)

### Docker Build Options

You can pass build options to the Docker containers:

```bash
# Build without examples
docker-compose -f docker/docker-compose.yml run linux-build --no-examples

# Create packages
docker-compose -f docker/docker-compose.yml run linux-build --package
```

Note: All build artifacts are automatically copied to the `output` directory. The `--install` option is not needed when using Docker.

#### Interactive Development with Docker

For development and debugging, you can use the `linux-dev` service to get an interactive shell:

```bash
# Build the development container
docker-compose -f docker/docker-compose.yml build linux-dev

# Start an interactive shell
docker-compose -f docker/docker-compose.yml run linux-dev
```

Inside the container, you can manually run the build script:

```bash
./build.sh --package
```

## Usage

### Basic Integration

1. Include the WebAssembly module in your HTML:
   ```html
   <script src="path/to/iris_codec.js"></script>
   ```

2. Initialize the module:
   ```javascript
   IrisCodec().then(module => {
     // Module is ready to use
     const version = module.getCodecVersion();
     console.log(`Iris Codec version: ${version.major}.${version.minor}.${version.build}`);
   });
   ```

### Example: Loading a Slide

```javascript
IrisCodec().then(module => {
  // Load a slide file
  const fileInput = document.getElementById('fileInput');
  fileInput.addEventListener('change', event => {
    const file = event.target.files[0];
    const reader = new FileReader();
    
    reader.onload = e => {
      const data = new Uint8Array(e.target.result);
      
      // Write the file to the Emscripten filesystem
      module.FS.writeFile(file.name, data);
      
      // Validate the slide
      const result = module.validateSlide(file.name);
      if (result.success) {
        // Get slide information
        const slideInfo = module.getSlideInfo(file.name);
        console.log('Slide dimensions:', slideInfo.extent.width, 'x', slideInfo.extent.height);
        
        // Read a tile
        const tileData = module.readSlideTile(file.name, 0, 0);
        // Process the tile data...
      }
    };
    
    reader.readAsArrayBuffer(file);
  });
});
```

## Examples

The repository includes several HTML examples demonstrating how to use the Iris Codec WebAssembly module:

- `html_examples/tile-viewer.html`: A simple viewer for exploring slide tiles
- `html_examples/slide-viewer.html`: Displays slide metadata and layer information

1. Build the project with examples enabled
2. Navigate to the project root directory in your terminal
3. Start an HTTP server (using Python's built-in server for example):

   ```bash
   python3 -m http.server 8080
   ```

4. Open your web browser and navigate to `http://localhost:8080/`

## License

This project is licensed under the terms of the Iris Digital Pathology license. See the LICENSE file for details.
