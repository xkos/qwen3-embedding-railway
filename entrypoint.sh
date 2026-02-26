#!/bin/bash
set -euo pipefail

# Config (env with defaults)
MODEL_DIR="/models"
PORT="${PORT:-}"
PLATFORM="${PLATFORM:-hf}"           # hf | modelscope
MODEL_NAME="${MODEL_NAME:-}"
MODEL_FILENAME="${MODEL_FILENAME:-}"
CONTEXT_SIZE="${CONTEXT_SIZE:-}"
API_KEY="${API_KEY:-}"
MODEL_PATH="$MODEL_DIR/$MODEL_FILENAME"

# Require API_KEY and core envs
if [ -z "$API_KEY" ]; then
  echo "❌ Error: API_KEY is required. Please set the API_KEY environment variable."
  exit 1
fi

for v in PORT MODEL_NAME MODEL_FILENAME CONTEXT_SIZE; do
  if [ -z "$(eval echo \"\${$v}\")" ]; then
    echo "❌ Error: $v is required but not set. Please set it via Dockerfile or Railway env vars."
    exit 1
  fi
done

# Ensure model dir
if [ ! -d "$MODEL_DIR" ]; then
  echo "Creating directory $MODEL_DIR..."
  mkdir -p "$MODEL_DIR"
fi

# Build MODEL_URL if file missing
if [ -f "$MODEL_PATH" ]; then
  echo "✅ Model found at $MODEL_PATH, skipping download."
else
  # Allow explicit MODEL_URL override
  if [ -n "${MODEL_URL:-}" ]; then
    MODEL_URL_RESOLVED="$MODEL_URL"
  else
    case "$PLATFORM" in
      hf)
        # Hugging Face resolve URL (branch 'main' by default)
        MODEL_URL_RESOLVED="https://huggingface.co/${MODEL_NAME}/resolve/main/${MODEL_FILENAME}"
        ;;
      modelscope)
        # ModelScope resolve URL (use 'master' by default)
        MODEL_URL_RESOLVED="https://modelscope.cn/models/${MODEL_NAME}/resolve/master/${MODEL_FILENAME}"
        ;;
      *)
        echo "❌ Unsupported PLATFORM: $PLATFORM (supported: hf, modelscope)"
        exit 1
        ;;
    esac
  fi

  echo "⬇️ Model not found. Downloading from $MODEL_URL_RESOLVED..."
  if [ -n "${HF_TOKEN:-}" ] && [ "$PLATFORM" = "hf" ]; then
    curl -L -C - -H "Authorization: Bearer ${HF_TOKEN}" -o "$MODEL_PATH" "$MODEL_URL_RESOLVED"
  else
    curl -L -C - -o "$MODEL_PATH" "$MODEL_URL_RESOLVED"
  fi
  if [ $? -eq 0 ]; then
    echo "✅ Download complete. Saved to $MODEL_PATH"
  else
    echo "❌ Download failed."
    exit 1
  fi
fi

echo "🚀 Starting llama-server on port $PORT..."
exec /app/llama-server \
  -m "$MODEL_PATH" \
  --host 0.0.0.0 \
  --port "$PORT" \
  --embedding \
  --nobrowser \
  --api-key "$API_KEY" \
  -c "$CONTEXT_SIZE"