#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# This is in case there's any special installs or overrides that needs to occur when starting the machine before starting ComfyUI
if [ -f "/workspace/additional_params.sh" ]; then
    chmod +x /workspace/additional_params.sh
    echo "Executing additional_params.sh..."
    /workspace/additional_params.sh
else
    echo "additional_params.sh not found in /workspace. Skipping..."
fi

# Set the network volume path
NETWORK_VOLUME="/workspace"

# Check if NETWORK_VOLUME exists; if not, use root directory instead
if [ ! -d "$NETWORK_VOLUME" ]; then
    echo "NETWORK_VOLUME directory '$NETWORK_VOLUME' does not exist. You are NOT using a network volume. Setting NETWORK_VOLUME to '/' (root directory)."
    NETWORK_VOLUME="/"
    echo "NETWORK_VOLUME directory doesn't exist. Starting JupyterLab on root directory..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/ &
else
    echo "NETWORK_VOLUME directory exists. Starting JupyterLab..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/workspace &
fi

COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"
WORKFLOW_DIR="$NETWORK_VOLUME/ComfyUI/user/default/workflows"

# Set the target directory
CUSTOM_NODES_DIR="$NETWORK_VOLUME/ComfyUI/custom_nodes"

if [ ! -d "$COMFYUI_DIR" ]; then
    mv /ComfyUI "$COMFYUI_DIR"
else
    echo "Directory already exists, skipping move."
fi

echo "Downloading CivitAI download script to /usr/local/bin"
git clone "https://github.com/Hearmeman24/CivitAI_Downloader.git" || { echo "Git clone failed"; exit 1; }
mv CivitAI_Downloader/download.py "/usr/local/bin/" || { echo "Move failed"; exit 1; }
chmod +x "/usr/local/bin/download.py" || { echo "Chmod failed"; exit 1; }
rm -rf CivitAI_Downloader  # Clean up the cloned repo

download_model() {
  local destination_dir="$1"
  local destination_file="$2"
  local repo_id="$3"
  local file_path="$4"

  mkdir -p "$destination_dir"

  if [ ! -f "$destination_dir/$destination_file" ]; then
    echo "Downloading $destination_file..."

    # First, download to a temporary directory
    local temp_dir=$(mktemp -d)
    huggingface-cli download "$repo_id" "$file_path" --local-dir "$temp_dir" --resume-download

    # Find the downloaded file in the temp directory (may be in subdirectories)
    local downloaded_file=$(find "$temp_dir" -type f -name "$(basename "$file_path")")

    # Move it to the destination directory with the correct name
    if [ -n "$downloaded_file" ]; then
      mv "$downloaded_file" "$destination_dir/$destination_file"
      echo "Successfully downloaded to $destination_dir/$destination_file"
    else
      echo "Error: File not found after download"
    fi

    # Clean up temporary directory
    rm -rf "$temp_dir"
  else
    echo "$destination_file already exists, skipping download."
  fi
}

DIFFUSION_MODELS_DIR="$NETWORK_VOLUME/ComfyUI/models/diffusion_models"
TEXT_ENCODERS_DIR="$NETWORK_VOLUME/ComfyUI/models/text_encoders"
VAE_DIR="$NETWORK_VOLUME/ComfyUI/models/vae"

# Change to the directory
cd "$CUSTOM_NODES_DIR" || exit 1

if [ "$install_pulid" == "true" ]; then
    echo "Installing PuLID and Starting ComfyUI"
    # Clone the InsightFace repository into /comfyui/models
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models"
    if [ ! -d "$NETWORK_VOLUME/ComfyUI/models/insightface" ]; then
        echo "Cloning InsightFace repository..."
        git clone https://huggingface.co/Aitrepreneur/insightface "$NETWORK_VOLUME/ComfyUI/models/insightface"
        echo "Installing InsightFace python dependencies"
        pip install --no-cache-dir numpy insightface==0.7.3
    fi

    # Clone Pulid Flux Custom Node
    cd "$NETWORK_VOLUME/ComfyUI/custom_nodes"
    if [ ! -d "ComfyUI_PuLID_Flux_ll" ]; then
        echo "Cloning Pulid Flux Custom Node..."
        git clone https://github.com/lldacing/ComfyUI_PuLID_Flux_ll.git
    fi

    # Install dependencies for Pulid Flux
    if [ -f "$NETWORK_VOLUME/ComfyUI/custom_nodes/ComfyUI_PuLID_Flux_ll/requirements.txt" ]; then
        pip install -r "$NETWORK_VOLUME/ComfyUI/custom_nodes/ComfyUI_PuLID_Flux_ll/requirements.txt"
    fi

    # Create the directory for Pulid model
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/pulid"

    # Download the Pulid Flux model
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/pulid/pulid_flux_v0.9.0.safetensors" ]; then
        echo "Downloading Pulid Flux model..."
        wget -O "$NETWORK_VOLUME/ComfyUI/models/pulid/pulid_flux_v0.9.0.safetensors" https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.0.safetensors?download=true
    fi

    # Install Python dependencies
    echo "Installing Python dependencies..."
    /usr/bin/python3 -m pip install facexlib
    /usr/bin/python3 -m pip install onnxruntime-gpu
    /usr/bin/python3 -m pip install timm
    /usr/bin/python3 -m pip install onnxruntime

    echo "Setup complete!"
fi

if [ "$download_flux" == "true" ]; then
  # Download flux1-dev model
# Download flux1-dev model from the new repository
download_model "$DIFFUSION_MODELS_DIR" "flux1-dev.safetensors" \
  "realung/flux1-dev.safetensors" "flux1-dev.safetensors"

# Download text encoders
download_model "$TEXT_ENCODERS_DIR" "clip_l.safetensors" \
  "comfyanonymous/flux_text_encoders" "clip_l.safetensors"

download_model "$TEXT_ENCODERS_DIR" "t5xxl_fp8_e4m3fn.safetensors" \
  "comfyanonymous/flux_text_encoders" "t5xxl_fp8_e4m3fn.safetensors"

# Download VAE
download_model "$VAE_DIR" "ae.safetensors" \
  "realung/flux1-dev.safetensors" "ae.safetensors"
fi

echo "Checking and copying workflow..."
mkdir -p "$WORKFLOW_DIR"

# Ensure the file exists in the current directory before moving it
cd /

declare -A MODEL_CATEGORIES=(
    ["$NETWORK_VOLUME/ComfyUI/models/diffusion_models"]="$MODEL_IDS_TO_DOWNLOAD"
    ["$NETWORK_VOLUME/ComfyUI/models/loras"]="$LORAS_IDS_TO_DOWNLOAD"
)

# Ensure directories exist and download models
for TARGET_DIR in "${!MODEL_CATEGORIES[@]}"; do
    mkdir -p "$TARGET_DIR"
    IFS=',' read -ra MODEL_IDS <<< "${MODEL_CATEGORIES[$TARGET_DIR]}"

    for MODEL_ID in "${MODEL_IDS[@]}"; do
        echo "Downloading model: $MODEL_ID to $TARGET_DIR"
        (cd "$TARGET_DIR" && download.py --model "$MODEL_ID")
    done
done

echo "All models downloaded successfully!"

if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4xLSDIR.pth" ]; then
    if [ -f "/4xLSDIR.pth" ]; then
        mv "/4xLSDIR.pth" "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4xLSDIR.pth"
        echo "Moved 4xLSDIR.pth to the correct location."
    else
        echo "4xLSDIR.pth not found in the root directory."
    fi
else
    echo "4xLSDIR.pth already exists. Skipping."
fi
if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4xFaceUpDAT.pth" ]; then
    if [ -f "/4xFaceUpDAT.pth" ]; then
        mv "/4xFaceUpDAT.pth" "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4xFaceUpDAT.pth"
        echo "Moved 4xFaceUpDAT.pth to the correct location."
    else
        echo "4xFaceUpDAT.pth not found in the root directory."
    fi
else
    echo "4xFaceUpDAT.pth already exists. Skipping."
fi

WORKFLOWS=("Basic_PuLID.json" "Basic_Flux.json")

for WORKFLOW in "${WORKFLOWS[@]}"; do
    if [ -f "./$WORKFLOW" ]; then
        if [ ! -f "$WORKFLOW_DIR/$WORKFLOW" ]; then
            mv "./$WORKFLOW" "$WORKFLOW_DIR"
            echo "$WORKFLOW copied."
        else
            echo "$WORKFLOW already exists in the target directory, skipping move."
        fi
    else
        echo "$WORKFLOW not found in the current directory."
    fi
done

# Workspace as main working directory
echo "cd $NETWORK_VOLUME" >> ~/.bashrc

# Start ComfyUI
echo "Starting ComfyUI"
python3 "$NETWORK_VOLUME/ComfyUI/main.py" --listen

