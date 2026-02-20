FROM runpod/base:1.0.3-cuda1290-ubuntu2404

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PATH=/root/.local/bin:${PATH} \
    HF_HOME=/workspace/.cache/huggingface \
    HF_HUB_CACHE=/workspace/.cache/huggingface/hub \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    HF_XET_HIGH_PERFORMANCE=1 \
    HF_HUB_DOWNLOAD_TIMEOUT=30 \
    HF_HUB_ETAG_TIMEOUT=10 \
    HF_MAX_WORKERS=16 \
    JUPYTER_PORT=8888 \
    JUPYTER_TOKEN=runpod \
    RUN_BOOTSTRAP_ON_START=1 \
    SKIP_MODEL_DOWNLOAD=0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    git-lfs \
    jq \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python3-pip \
    python3-venv \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN git lfs install

# uv is used by musubi-tuner's dependency workflow.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Use a dedicated venv to avoid Debian/PEP668 system-packages conflicts.
RUN python3.12 -m venv /opt/venv
ENV PATH=/opt/venv/bin:/root/.local/bin:${PATH}

# Core runtime tooling, including hf CLI (replacement for huggingface-cli).
RUN pip install --no-cache-dir -U pip setuptools wheel && \
    pip install --no-cache-dir \
      huggingface_hub \
      accelerate \
      jupyterlab \
      tensorboard

# Optional acceleration library for hf downloads.
RUN pip install --no-cache-dir hf_transfer || \
    echo "hf_transfer install failed; hf download will still work without transfer acceleration."

# bitsandbytes can fail to install on some Python/CUDA/base image combinations.
# Keep image build green and use Prodigy path when unavailable.
RUN pip install --no-cache-dir bitsandbytes || \
    echo "bitsandbytes install failed; AdamW8bit optimizer may be unavailable in this image."

# Required by the user request: exact flash_attn build (best-effort at image build).
RUN pip install --no-cache-dir \
    "https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu12torch2.9cxx11abiTRUE-cp312-cp312-linux_x86_64.whl" || \
    echo "flash_attn wheel install at image build failed; bootstrap will install it in musubi-tuner env."

WORKDIR /opt/runpod

COPY entrypoint.sh /opt/runpod/entrypoint.sh
COPY bootstrap.sh /opt/runpod/bootstrap.sh
COPY download_models.sh /opt/runpod/download_models.sh
COPY prepare_dataset.sh /opt/runpod/prepare_dataset.sh
COPY train_lora_prodigy.sh /opt/runpod/train_lora_prodigy.sh
COPY train_lora_adamw8bit.sh /opt/runpod/train_lora_adamw8bit.sh
COPY convert_lora.sh /opt/runpod/convert_lora.sh
COPY dataset.toml.example /opt/runpod/dataset.toml.example
COPY sample_prompts.txt /opt/runpod/sample_prompts.txt
COPY notebooks /opt/runpod/notebooks

RUN chmod +x /opt/runpod/*.sh

EXPOSE 8888

ENTRYPOINT ["/opt/runpod/entrypoint.sh"]
