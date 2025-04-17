#!/bin/bash

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "Dart is not installed. Please install Dart and try again."
    exit 1
fi

# Set default model type
MODEL_TYPE="standard"

# Parse options
while getopts ":am:vt" opt; do
  case ${opt} in
    a)
      MODEL_TYPE="anime"
      ;;
    m)
      MODEL_TYPE=$OPTARG
      ;;
    v)
      MODEL_TYPE="v2"
      ;;
    t)
      MODEL_TYPE="turbo"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" 1>&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." 1>&2
      exit 1
      ;;
  esac
done

# Shift to get the image path argument
shift $((OPTIND -1))

# Check if input image is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [-a] [-v] [-t] [-m model_type] <path_to_image>"
    echo "Options:"
    echo "  -a                Use the anime model (shorthand for -m anime)"
    echo "  -v                Use Stable Diffusion v2 with img2img (better for face images)"
    echo "  -t                Use SDXL Turbo (faster, newer model)"
    echo "  -m model_type     Use specified model type: standard, anime, v2, or turbo"
    echo "Example: $0 ~/Pictures/test_face.jpg"
    echo "Example: $0 -a ~/Pictures/test_face.jpg"
    echo "Example: $0 -v ~/Pictures/test_face.jpg"
    echo "Example: $0 -t ~/Pictures/test_face.jpg"
    exit 1
fi

# Get the absolute path of the image
IMAGE_PATH="$1"

# Check if image exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: Image file not found at $IMAGE_PATH"
    exit 1
fi

echo "==== Testing Replicate API Image Generation ===="
echo "Image: $IMAGE_PATH"
echo "Model: $MODEL_TYPE"
echo "This will test whether Replicate API can generate an image."
echo "================================================"

# Compile and run the Dart script
cd "$(dirname "$0")"

if [ "$MODEL_TYPE" = "anime" ]; then
    dart test_replicate_api_anime.dart "$IMAGE_PATH"
elif [ "$MODEL_TYPE" = "v2" ]; then
    dart test_replicate_api_v2.dart "$IMAGE_PATH"
elif [ "$MODEL_TYPE" = "turbo" ]; then
    dart test_replicate_api_turbo.dart "$IMAGE_PATH"
else
    dart test_replicate_api.dart "$IMAGE_PATH"
fi 