# Gemma 4 OpenAI API on Tailscale

This project serves your local cached `google/gemma-4-31B-it` model through a vLLM OpenAI-compatible API and binds it only on your Tailscale IPv4.

Scope note: this setup has only been tested on a single-node DGX system.

Current local assumptions:

- Tailscale IPv4: `100.xxx.xxx.xxx` in examples only
- Local smoke-test port: `127.0.0.1:8001`
- HF cache: `/home/anthonywu/.cache/huggingface`
- Cached model snapshot found locally for `google/gemma-4-31B-it`
- Docker present locally
- Host identified as NVIDIA DGX Spark with one GB10 GPU on CUDA `13.0`
- Local memory report: about `119 GiB` total unified memory available to the system

## Tested container versions

The currently working container versions on this single-node DGX system are:

- `vllm/vllm-openai:gemma4-cu130`
  - image ID: `sha256:9afe08ebfa30ea7889d8792ad1f9815ce92e1ba742b3900703f5b12b36f982f8`
- `redis@sha256:7b6fb55d8b0adcd77269dc52b3cfffe5f59ca5d43dec3c90dbe18aacce7942e1` for the local `redis-queue` container

## Why this shape

- vLLM exposes an OpenAI-compatible `/v1` API.
- This is aligned to NVIDIA's DGX Spark playbook for Gemma 4, which says to use the custom `vllm/vllm-openai:gemma4-cu130` container for the Gemma 4 family.
- Binding the published port to `${TAILSCALE_IP}` means the API is reachable on your tailnet without opening it on every host interface.
- A second localhost-only port is published for playbook-style `curl localhost` verification on the Spark itself.
- The default config forces offline Hugging Face resolution so the server uses your local cache instead of trying to redownload the model.
- The DGX Spark defaults are tuned above the conservative baseline: full multimodal enabled, `32768` context, FP8 KV cache, and async scheduling.
- Telemetry and usage reporting are disabled by default with `HF_HUB_OFFLINE=1`, `TRANSFORMERS_OFFLINE=1`, `VLLM_NO_USAGE_STATS=1`, and `DO_NOT_TRACK=1`.

The NVIDIA playbook's Gemma 4 test command is effectively:

```bash
docker run -it --gpus all -p 8000:8000 vllm/vllm-openai:gemma4-cu130 google/gemma-4-31B-it
```

This project keeps that same container/entrypoint model, then layers on:

- offline HF cache mounting
- tailnet-specific host bind
- API key enforcement
- Spark-specific tuning flags

## Onboarding

Use NVIDIA's DGX Spark vLLM overview as the upstream reference for the supported Spark/Gemma 4 path:

- https://build.nvidia.com/spark/vllm/overview

Before starting this project, make sure the model is already downloaded locally:

```bash
hf download google/gemma-4-31B-it
```

This setup assumes the Hugging Face cache already contains the Gemma 4 snapshot and that the server will run in offline mode against that local cache.

## Prerequisites

- DGX Spark with Docker and NVIDIA container runtime working
- Hugging Face CLI installed and authenticated if the model download requires it
- Local Gemma 4 weights already downloaded with `hf download google/gemma-4-31B-it`
- Tailscale running on the Spark if you want tailnet access

## 1. Create the env file

```bash
cp .env.example .env
```

Edit `.env` and set:

- `OPENAI_API_KEY` to a real secret
- `TAILSCALE_IP` to your own Tailscale IPv4
- `VLLM_LANGUAGE_ONLY_FLAG=` to empty if you want image or audio inputs
- `VLLM_EXTRA_ARGS` for extra tuning flags

The `100.xxx.xxx.xxx` value used in this README is a placeholder only. Each Tailscale device gets its own tailnet IP, so you must replace it with the actual IP for the machine serving vLLM.

Default sizing is tuned for this DGX Spark:

- `TENSOR_PARALLEL_SIZE=1`
- `MAX_MODEL_LEN=32768`
- `GPU_MEMORY_UTILIZATION=0.93`
- `VLLM_EXTRA_ARGS=--async-scheduling --kv-cache-dtype fp8 --limit-mm-per-prompt '{"image":4,"audio":1}' --max-num-seqs 64`

If startup fails on memory pressure, reduce `MAX_MODEL_LEN` first.

## 2. Start the API

```bash
docker compose --env-file .env -f compose.yaml up -d
```

Check logs:

```bash
docker compose --env-file .env -f compose.yaml logs -f
```

Stop it:

```bash
docker compose --env-file .env -f compose.yaml down
```

## 3. Verify the endpoint

List models:

```bash
./scripts/healthcheck.sh
```

Run a chat completion:

```bash
./scripts/chat-test.sh
```

The API base URL on your tailnet will be:

```text
http://100.xxx.xxx.xxx:8000/v1
```

The local smoke-test base URL on the Spark itself will be:

```text
http://127.0.0.1:8001/v1
```

## 4. Use it from an OpenAI client

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://100.xxx.xxx.xxx:8000/v1",
    api_key="your-api-key-here",
)

resp = client.chat.completions.create(
    model="gemma-4-31b-it",
    messages=[{"role": "user", "content": "Say hello from my tailnet server."}],
)

print(resp.choices[0].message.content)
```

## 5. Optional systemd service

Install the unit:

```bash
sudo cp systemd/gemma4-tailnet.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now gemma4-tailnet.service
```

Inspect service state:

```bash
sudo systemctl status gemma4-tailnet.service
journalctl -u gemma4-tailnet.service -f
```

## Notes

- By default this only binds on your current Tailscale IPv4, not `0.0.0.0`.
- Local verification uses `127.0.0.1:8001`, which matches the playbook's `curl localhost` style more closely.
- If your Tailscale IP changes, update `.env` and restart the service.
- Multimodal stays enabled by default on this DGX Spark profile.
- If you want a lower-memory text-only server, set `VLLM_LANGUAGE_ONLY_FLAG=--language-model-only`.
- If you want reasoning and tool calling support, that is already enabled through the Gemma 4 parser flags.

## Sources

- vLLM OpenAI-compatible server: https://docs.vllm.ai/en/latest/serving/openai_compatible_server/
- vLLM CLI `serve`: https://docs.vllm.ai/en/latest/cli/serve/
- vLLM Gemma 4 recipe: https://docs.vllm.ai/projects/recipes/en/latest/Google/Gemma4.html
