#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Set the network volume path
NETWORK_VOLUME="/workspace"
COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"
WORKFLOW_DIR="$NETWORK_VOLUME/ComfyUI/pysssss-workflows"

if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Installing ComfyUI on network volume..."
    git clone https://github.com/comfyanonymous/ComfyUI "$COMFYUI_DIR"
else
    echo "ComfyUI already installed on network volume."
fi

# Set the target directory
CUSTOM_NODES_DIR="$NETWORK_VOLUME/ComfyUI/custom_nodes"

# Change to the directory
cd "$CUSTOM_NODES_DIR" || exit 1

# Read repos.txt line by line and clone if not already cloned
while read -r repo; do
    if [ -n "$repo" ]; then
        repo_name=$(basename "$repo" .git)
        if [ ! -d "$repo_name" ]; then
            echo "Cloning $repo..."
            git clone "$repo"
        else
            echo "$repo_name already exists, skipping..."
        fi
    fi
done < /repos.txt

if [ "$install_pulid" == "true" ]; then
    echo "Installing PuLID and Starting ComfyUI"
    # Clone the InsightFace repository into /comfyui/models
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models"
    if [ ! -d "$NETWORK_VOLUME/ComfyUI/models/insightface" ]; then
        echo "Cloning InsightFace repository..."
        git clone https://huggingface.co/Aitrepreneur/insightface "$NETWORK_VOLUME/ComfyUI/models/insightface"
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
    pip install --no-cache-dir numpy
    pip install --no-cache-dir insightface==0.7.3
    /usr/bin/python3 -m pip install facexlib
    /usr/bin/python3 -m pip install onnxruntime-gpu
    /usr/bin/python3 -m pip install timm
    /usr/bin/python3 -m pip install onnxruntime

    echo "Setup complete!"
fi

if [ "$download_flux" == "true" ]; then
    if [ -z "$hugging_face_token" ]; then
        echo "Error: hugging_face_token is not set. Exiting..."
        exit 1
    fi

    echo "Downloading flux1-dev.safetensors"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/diffusion_models"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/diffusion_models/flux1-dev.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/diffusion_models/flux1-dev.safetensors" --header="Authorization: Bearer $hugging_face_token" https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors
    fi

    echo "Downloading text encoders"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/text_encoders"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/text_encoders/clip_l.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/text_encoders/clip_l.safetensors" https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors
    fi
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors" https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors
    fi

    echo "Downloading VAE"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/vae"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/vae/ae.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/vae/ae.safetensors" --header="Authorization: Bearer $hugging_face_token" https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors
    fi

    echo "Finished downloading Flux models!"
fi

# Requirements installations for Custom Nodes
if [ -f "$NETWORK_VOLUME/ComfyUI/custom_nodes/ComfyUI-Impact-Pack/requirements.txt" ]; then
    pip install -r "$NETWORK_VOLUME/ComfyUI/custom_nodes/ComfyUI-Impact-Pack/requirements.txt"
fi
if [ -f "$NETWORK_VOLUME/ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt" ]; then
    pip install -r "$NETWORK_VOLUME/ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt"
fi

echo "Copying worflow"
mkdir -p "$WORKFLOW_DIR"
mv "Basic PuLID.json" "$WORKFLOW_DIR"

# Start JupyterLab in the background
echo "Starting JupyterLab..."
jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' &

# Start ComfyUI
echo "Starting ComfyUI"
python3 "$NETWORK_VOLUME/ComfyUI/main.py" --listen