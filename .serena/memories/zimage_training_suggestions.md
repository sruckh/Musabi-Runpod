# Z-Image + Musubi Training Improvement Suggestions

## Core Observations
- Z-Image + musubi is more sensitive than Flux/AI-Toolkit for identity fidelity.
- At 86 epochs, this run likely passed its best point (epoch-loss minimum found around epoch 79).
- Later checkpoints can be worse even if training continues.

## Suggested Next-Run Setup
- Use a curated subset of ~25-40 identity-consistent images.
- Keep captions descriptive for scene/clothing/pose/lighting, but avoid immutable identity traits.
- In `dataset.toml` use:
  - `batch_size = 1`
  - `num_repeats = 2`
- Prefer AdamW path for stability if Prodigy identity quality is weak:
  - `train_lora_adamw8bit.sh`
  - start with `LEARNING_RATE=5e-5`
- Start with `MAX_TRAIN_EPOCHS=60` and evaluate; extend only if needed.

## Checkpoint Strategy
- Save fewer checkpoints by default to avoid storage issues.
- Recommended default now: `SAVE_EVERY_N_EPOCHS=20`.
- For quality comparison runs, temporarily use `SAVE_EVERY_N_EPOCHS=5`.

## Convergence Interpretation (TensorBoard)
- Primary: `loss/average` (flattening trend).
- Secondary: `loss/epoch` (best epoch selection anchor).
- `loss/current` is noisy and should not drive decisions alone.
- Always select final checkpoint by visual identity quality and prompt responsiveness, not loss alone.

## Disk-Space Management
- Remove optimizer state folders when space is tight:
  - `rm -rf /workspace/output/*-state`
- Keep only selected checkpoints after evaluation.

## Practical Rule of Thumb
- If likeness is still weak near best-loss epoch, problem is usually data/caption signal quality, not simply "more epochs".
