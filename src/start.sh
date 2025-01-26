#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    echo "runpod-worker-comfy: Starting ComfyUI"
# Run pip install in the background
    pip install -r /comfyui/custom_nodes/comfyui-impact-pack/requirements.txt &
    pip install -r /comfyui/custom_nodes/comfyui-impact-subpack/requirements.txt &

# Wait for both background installs to complete
    wait
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata --listen &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    echo "runpod-worker-comfy: Starting ComfyUI"
# Run pip install in the background
    pip install -r /comfyui/custom_nodes/comfyui-impact-pack/requirements.txt &
    pip install -r /comfyui/custom_nodes/comfyui-impact-subpack/requirements.txt &

# Wait for both background installs to complete
    wait
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py
fi