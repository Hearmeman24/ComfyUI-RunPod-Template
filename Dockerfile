# Use multi-stage build with caching optimizations
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
   PIP_PREFER_BINARY=1 \
   PYTHONUNBUFFERED=1 \
   CMAKE_BUILD_PARALLEL_LEVEL=8

# Consolidated installation to reduce layers
RUN apt-get update && apt-get install -y --no-install-recommends \
   python3.10 python3-pip git git-lfs libportaudio2 wget vim libgl1 libglib2.0-0 \
   python3-dev build-essential gcc \
   && ln -sf /usr/bin/python3.10 /usr/bin/python \
   && ln -sf /usr/bin/pip3 /usr/bin/pip \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/*

# Use build cache for pip installations
RUN pip install --no-cache-dir gdown comfy-cli jupyterlab jupyterlab-lsp \
    jupyter-server jupyter-server-terminals \
    ipykernel jupyterlab_code_formatter
EXPOSE 8888

RUN /usr/bin/yes | comfy --workspace /ComfyUI install \
   --cuda-version 11.8 --nvidia

FROM base AS final
RUN python -m pip install opencv-python

RUN for repo in \
    https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/rgthree/rgthree-comfy.git \
    https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    https://github.com/Jordach/comfy-plasma.git \
    https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    https://github.com/yolain/ComfyUI-Easy-Use.git \
    https://github.com/ShmuelRonen/ComfyUI-Gemini_Flash_2.0_Exp.git \
    https://github.com/kijai/ComfyUI-Florence2.git \
    https://github.com/WASasquatch/was-node-suite-comfyui.git \
    https://github.com/theUpsider/ComfyUI-Logic.git \
    https://github.com/cubiq/ComfyUI_essentials.git \
    https://github.com/chrisgoringe/cg-image-picker.git \
    https://github.com/Gourieff/ComfyUI-ReActor.git \
    https://github.com/chrisgoringe/cg-use-everywhere.git \
    https://github.com/welltop-cn/ComfyUI-TeaCache.git \
    https://github.com/Jonseed/ComfyUI-Detail-Daemon.git \
    https://github.com/M1kep/ComfyLiterals.git; \
    do \
        cd /ComfyUI/custom_nodes; \
        repo_dir=$(basename "$repo" .git); \
        if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
            git clone --recursive "$repo"; \
        else \
            git clone "$repo"; \
        fi; \
        if [ -f "/ComfyUI/custom_nodes/$repo_dir/requirements.txt" ]; then \
            pip install -r "/ComfyUI/custom_nodes/$repo_dir/requirements.txt"; \
        fi; \
        if [ -f "/ComfyUI/custom_nodes/$repo_dir/install.py" ]; then \
            python "/ComfyUI/custom_nodes/$repo_dir/install.py"; \
        fi; \
    done

COPY src/start_script.sh /start_script.sh
COPY 4xLSDIR.pth /4xLSDIR.pth
COPY 4xFaceUpDAT.pth /4xFaceUpDAT.pth
COPY Basic_PuLID.json /Basic_PuLID.json
COPY Basic_Flux.json /Basic_Flux.json


CMD ["/start_script.sh"]