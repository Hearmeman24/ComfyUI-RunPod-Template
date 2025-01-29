# Use multi-stage build with caching optimizations
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
   PIP_PREFER_BINARY=1 \
   PYTHONUNBUFFERED=1 \
   CMAKE_BUILD_PARALLEL_LEVEL=8

# Consolidated installation to reduce layers
RUN apt-get update && apt-get install -y --no-install-recommends \
   python3.10 python3-pip git git-lfs wget vim libgl1 libglib2.0-0 \
   python3-dev build-essential gcc \
   && ln -sf /usr/bin/python3.10 /usr/bin/python \
   && ln -sf /usr/bin/pip3 /usr/bin/pip \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/*

# Use build cache for pip installations
RUN pip install --no-cache-dir gdown comfy-cli jupyterlab

FROM base AS final
RUN python -m pip install opencv-python
RUN wget https://github.com/comfyanonymous/ComfyUI/raw/refs/heads/master/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
# Copy the repos.txt file into the container

COPY src/start.sh /start.sh
COPY repos.txt /repos.txt

# Configure Jupyterlab
RUN mkdir -p /root/.jupyter && \
    echo "c.NotebookApp.token = ''" > /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.password = ''" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.port = 8888" >> /root/.jupyter/jupyter_notebook_config.py

RUN chmod +x /start.sh


CMD ["/start.sh"]