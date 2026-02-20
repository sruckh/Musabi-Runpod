# Musabi Runpod

Runpod-only container template for training **ultrarealistic Z-Image Base LoRAs** with **musubi-tuner**.

This project is designed to run entirely on Runpod and remote CI.  
No local GPU, Docker runtime, or local Python environment is required.

## What This Provides

- Base image: `runpod/base:1.0.3-cuda1290-ubuntu2404`
- Exact FlashAttention wheel:
  - `flash_attn-2.8.3+cu12torch2.9cxx11abiTRUE-cp312-cp312-linux_x86_64.whl`
- `hf` CLI usage (not deprecated `huggingface-cli`)
- Optimized Hugging Face downloads (`hf_transfer`, xet high-performance, workers)
- Automatic first-boot bootstrap:
  - clone `musubi-tuner`
  - install dependencies with `uv`
  - configure `accelerate`
  - download Z-Image Base/Turbo components
- JupyterLab auto-launch for dataset upload + training workflow
- Notebook 7 installed so both `/lab` and `/tree` routes are available

## Repository Layout

- `Dockerfile`: Runpod image build definition
- `entrypoint.sh`: container start entrypoint + Jupyter launch
- `bootstrap.sh`: one-time workspace initialization on first boot
- `download_models.sh`: optimized model download script using `hf`
- `prepare_dataset.sh`: latent/text-encoder cache prep
- `train_lora_prodigy.sh`: recommended training command
- `train_lora_adamw8bit.sh`: alternate optimizer training command
- `convert_lora.sh`: convert LoRA for ComfyUI
- `dataset.toml.example`: starter dataset config
- `sample_prompts.txt`: starter validation prompts
- `notebooks/00_musubi_tuner_runpod.ipynb`: starter notebook
- `.github/workflows/docker-publish.yml`: remote Docker image build/push

## GitHub Actions (Remote Build and Push)

The workflow builds and pushes to Docker Hub:
- Image: `gemneye/musabi-runpod`
- Workflow: `.github/workflows/docker-publish.yml`
- Triggers:
  - push to `main`
  - tag push `v*`
  - manual dispatch

Required GitHub repository secrets:
- `DOCKER_USERNAME` = `gemneye`
- `DOCKER_PASSWORD` = Docker Hub personal access token

Generated image tags include:
- `latest` (default branch)
- `main`
- `sha-<commit>`
- `vX.Y.Z` (when tag pushed)

## Runpod Deployment

In Runpod template settings:
- Container image: `gemneye/musabi-runpod:latest` (or another generated tag)
- Exposed port: `8888`
- Environment variables:
  - `JUPYTER_TOKEN` (required, set a strong token)
  - `HF_TOKEN` (optional; required for gated/private HF repos)
  - `HF_MAX_WORKERS=16` (optional tuning)
  - `SKIP_MODEL_DOWNLOAD=0` (set `1` only if models already present)

## First-Boot Behavior

On first boot, the container:
1. Creates `/workspace` folder structure
2. Clones `musubi-tuner`
3. Runs dependency sync with `uv` using Python 3.12
4. Installs the requested flash-attn wheel in musubi-tuner environment
5. Writes a non-interactive `accelerate` config
6. Downloads model files to `/workspace/models`
7. Copies helper scripts to `/workspace/scripts`
8. Launches JupyterLab

Bootstrap is marked complete by:
- `/workspace/.musubi_bootstrap_done`

## Training Workflow

1. Upload training images and matching `.txt` captions:
   - `/workspace/dataset/images`
2. Review/edit dataset config:
   - `/workspace/dataset/dataset.toml`
3. Prepare caches:
   - `/workspace/scripts/prepare_dataset.sh`
4. Train (recommended):
   - `/workspace/scripts/train_lora_prodigy.sh`
5. Convert trained LoRA for ComfyUI:
   - `/workspace/scripts/convert_lora.sh /workspace/output/<checkpoint>.safetensors`

The starter notebook covers the same flow:
- `/workspace/notebooks/00_musubi_tuner_runpod.ipynb`

## Hugging Face Download Optimization

Configured defaults:
- `HF_HUB_ENABLE_HF_TRANSFER=1`
- `HF_XET_HIGH_PERFORMANCE=1`
- `HF_HUB_DOWNLOAD_TIMEOUT=30`
- `HF_HUB_ETAG_TIMEOUT=10`
- `hf download ... --max-workers ${HF_MAX_WORKERS}`

`hf download` usage supports:
- `--include` / `--exclude`
- `--local-dir`
- `--repo-type`
- `--revision`
- `--cache-dir`
- `--max-workers`

## Notes

- This repo intentionally excludes `musubi-tuner-zimage-runpod-guide.md` from git tracking via `.gitignore`.
- The setup is intended for Runpod execution, not local runtime.
- `hf_transfer` and `bitsandbytes` are best-effort installs. If unavailable, workflow still runs.
- If `bitsandbytes` is unavailable, use `train_lora_prodigy.sh` (recommended path).
