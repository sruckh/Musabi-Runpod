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
- Exposed port: `6006` (optional, TensorBoard)
- Environment variables:
  - `JUPYTER_TOKEN` (required, set a strong token)
  - `JUPYTER_DEFAULT_URL` (optional, defaults to `/lab`)
  - `AUTO_START_TENSORBOARD` (optional, `1` to start TensorBoard on boot)
  - `TENSORBOARD_PORT` (optional, defaults to `6006`)
  - `TENSORBOARD_LOGDIR` (optional, defaults to `/workspace/logs`)
  - `HF_TOKEN` (optional; required for gated/private HF repos)
  - `HF_MAX_WORKERS=16` (optional tuning)
  - `SKIP_MODEL_DOWNLOAD=0` (set `1` only if models already present)
  - `MUSUBI_PYTHON=3.10` (recommended operational default for musubi env)
  - `MUSUBI_CUDA_EXTRA=cu128` (recommended with CUDA 12.9 base image for driver compatibility)
  - `MUSUBI_TORCH_VERSION=2.9.1` (default pin)
  - `MUSUBI_TORCHVISION_VERSION=0.24.1` (default pin)

Container default shell directory:
- `/workspace` (persistent volume)

## First-Boot Behavior

On first boot, the container:
1. Creates `/workspace` folder structure
2. Clones `musubi-tuner`
3. Runs dependency sync with `uv` (defaults: Python 3.10 + `cu128`, configurable by env vars)
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
6. Start TensorBoard (optional):
   - `/workspace/scripts/start_tensorboard.sh`

The starter notebook covers the same flow:
- `/workspace/notebooks/00_musubi_tuner_runpod.ipynb`

## Training Depth Guidance

The default script uses `MAX_TRAIN_EPOCHS=16`, which is often too short for identity LoRA quality.

Estimate equivalent training depth by:
- `effective_steps_per_epoch ~= (num_images * num_repeats) / batch_size`
- `effective_total_steps ~= effective_steps_per_epoch * epochs`

Example with `54` images, `num_repeats=1`, `batch_size=2`:
- steps/epoch ~= `27`
- `16` epochs ~= `432` effective steps
- `2000` to `3000` effective steps ~= about `74` to `111` epochs

Recommended starting point for this setup:
- `MAX_TRAIN_EPOCHS=80`
- `SAVE_EVERY_N_EPOCHS=1` or `2`

Command example:
```bash
MAX_TRAIN_EPOCHS=80 SAVE_EVERY_N_EPOCHS=2 /workspace/scripts/train_lora_prodigy.sh
```

## TensorBoard Convergence Signals

Useful tags in this workflow:
- `loss/average`: primary convergence signal
- `loss/epoch`: slower trend confirmation
- `loss/current`: noisy per-step value
- `lr/d*lr/unet`: effective LR proxy for Prodigy behavior

Convergence is typically when:
- `loss/average` flattens over many steps
- `loss/epoch` stops improving meaningfully for 2+ epochs
- no instability spikes dominate `loss/current`

Always choose final checkpoint by image quality/identity tests, not loss alone.

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
- Current musubi `convert_lora.py` uses `--target other` for ComfyUI-compatible output; `--target comfy` is not a valid option in this build.
