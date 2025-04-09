#!/bin/bash

# Create output directory
mkdir -p output

# Check if we want to connect to the container
if [ "$1" = "--connect" ]; then
    # Build the image if it doesn't exist
    IMAGE=$(docker build -q -f docker/Dockerfile.linux ..)
    
    # Run an interactive shell in the container
    docker run --rm -it \
        -v "$(pwd)/../output:/output" \
        -v "$(pwd)/..:/app" \
        --entrypoint /bin/bash \
        $IMAGE
    
    echo "Exited from container. Output files are in the 'output' directory."
else
    # Run the Docker container with the build script
    docker run --rm \
        -v "$(pwd)/../output:/output" \
        $(docker build -q -f docker/Dockerfile.linux ..) "$@"
    
    echo "Build complete. Output files are in the 'output' directory."
fi
