#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

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

if [ "$download_hunyuan" == "true" ]; then
    echo "Downloading Hunyuan diffusion model"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/diffusion_models"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/diffusion_models/hunyuan_video_720_cfgdistill_bf16.safetensors" ]; then
        wget -c -O "$NETWORK_VOLUME/ComfyUI/models/diffusion_models/hunyuan_video_720_cfgdistill_bf16.safetensors" \
        https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_720_cfgdistill_bf16.safetensors
    fi

    echo "Downloading text encoders"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/text_encoders"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/text_encoders/clip_l.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/text_encoders/clip_l.safetensors" \
        https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/clip_l.safetensors
    fi
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/text_encoders/llava_llama3_fp8_scaled.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/text_encoders/llava_llama3_fp8_scaled.safetensors" \
        https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/llava_llama3_fp8_scaled.safetensors
    fi
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/text_encoders/Long-ViT-L-14-GmP-SAE-full-model.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/text_encoders/Long-ViT-L-14-GmP-SAE-full-model.safetensors" \
        https://huggingface.co/zer0int/LongCLIP-SAE-ViT-L-14/resolve/main/Long-ViT-L-14-GmP-SAE-full-model.safetensors
    fi

    echo "Downloading VAE"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/vae"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/vae/hunyuan_video_vae_fp32.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/vae/hunyuan_video_vae_fp32.safetensors" \
        https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_vae_fp32.safetensors
    fi

    # Download upscale model
    echo "Downloading upscale models"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/upscale_models"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4x_foolhardy_Remacri.pt" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4x_foolhardy_Remacri.pt" \
        https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth
    fi
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/upscale_models/OmniSR_X2_DIV2K.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/upscale_models/OmniSR_X2_DIV2K.safetensors" \
        https://huggingface.co/Acly/Omni-SR/resolve/main/OmniSR_X2_DIV2K.safetensors
    fi

    echo "Downloading img2vid lora"
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/loras"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/loras/leapfusion_img2vid544p_comfy.safetensors" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/loras/leapfusion_img2vid544p_comfy.safetensors" \
        https://huggingface.co/Kijai/Leapfusion-image2vid-comfy/resolve/main/leapfusion_img2vid544p_comfy.safetensors
    fi

    # Download film network model
    echo "Downloading film network model"
    if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/upscale_models/film_net_fp32.pt" ]; then
        wget -O "$NETWORK_VOLUME/ComfyUI/models/upscale_models/film_net_fp32.pt" \
        https://huggingface.co/nguu/film-pytorch/resolve/887b2c42bebcb323baf6c3b6d59304135699b575/film_net_fp32.pt
    fi

    echo "Finished downloading models!"
fi

echo "Checking and copying workflow..."
mkdir -p "$WORKFLOW_DIR"

# Ensure the file exists in the current directory before moving it
cd /

WORKFLOWS=("Basic_PuLID.json" "Basic_Hunyuan.json" "Hunyuan_with_Restore_Faces_Upscaling.json" "Hunyuan_img2vid.json" "Basic_Flux.json")

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
echo 'cd /workspace' >> ~/.bashrc

# This is in case there's any special installs or overrides that needs to occur when starting the machine before starting ComfyUI
if [ -f "/workspace/additional_params.sh" ]; then
    chmod +x /workspace/additional_params.sh
    echo "Executing additional_params.sh..."
    /workspace/additional_params.sh
else
    echo "additional_params.sh not found in /workspace. Skipping..."
fi

# Start ComfyUI
echo "Starting ComfyUI"
python3 "$NETWORK_VOLUME/ComfyUI/main.py" --listen
