# Use multi-stage build with caching optimizations
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
   PIP_PREFER_BINARY=1 \
   PYTHONUNBUFFERED=1 \
   CMAKE_BUILD_PARALLEL_LEVEL=8

# Consolidated installation to reduce layers
RUN apt-get update && apt-get install -y --no-install-recommends \
   python3.10 python3-pip git wget libgl1 libglib2.0-0 \
   python3-dev build-essential gcc \
   && ln -sf /usr/bin/python3.10 /usr/bin/python \
   && ln -sf /usr/bin/pip3 /usr/bin/pip \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/*

# Use build cache for pip installations
RUN pip install --no-cache-dir \
   comfy-cli runpod requests

# Install ComfyUI in one step
RUN /usr/bin/yes | comfy --workspace /comfyui install \
   --cuda-version 11.8 --nvidia --version 0.3.12

# Model download stage with wget optimization
FROM base AS downloader
WORKDIR /comfyui

COPY src/extra_model_paths.yaml /comfyui/extra_model_paths.yaml

WORKDIR /comfyui/models
RUN mkdir -p /comfyui/models/ipadapter /comfyui/models/ultralytics/bbox /comfyui/models/ultralytics/segm \
   && wget -O /comfyui/models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin \
   && wget -O /comfyui/models/ipadapter/ip-adapter-faceid-plusv2_sdxl_lora.safetensors https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors \
   && wget -O /comfyui/models/ultralytics/segm/face_yolov8m-seg_60.pt https://huggingface.co/24xx/segm/resolve/main/face_yolov8m-seg_60.pt

COPY src/Eyes.pt /comfyui/models/ultralytics/bbox/Eyes.pt

# Final stage
FROM base AS final
COPY --from=downloader /comfyui/extra_model_paths.yaml /comfyui/extra_model_paths.yaml
COPY --from=downloader /comfyui/models /comfyui/models
COPY src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json *snapshot*.json /
RUN python -m pip install opencv-python
RUN chmod +x /start.sh /restore_snapshot.sh \
   && /restore_snapshot.sh

CMD ["/start.sh"]