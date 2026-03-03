#!/bin/bash
set -euo pipefail

# Config (env with defaults)
MODEL_DIR="/models"
PORT="${PORT:-8080}"
OLLAMA_PORT="11434"
PLATFORM="${PLATFORM:-hf}"           # hf | modelscope
MODEL_NAME="${MODEL_NAME:-}"
MODEL_FILENAME="${MODEL_FILENAME:-}"
MODEL_PATH="$MODEL_DIR/$MODEL_FILENAME"
CONTEXT_SIZE="${CONTEXT_SIZE:-10240}"
BATCH_SIZE="${BATCH_SIZE:-512}"
API_KEY="${API_KEY:-}"

# 1. Check required environment variables
for v in MODEL_NAME MODEL_FILENAME API_KEY; do
  if [ -z "$(eval echo \"\${$v}\")" ]; then
    echo "❌ Error: $v is required but not set. Please set it via Dockerfile or Railway env vars."
    exit 1
  fi
done

# 2. Create model directory
if [ ! -d "$MODEL_DIR" ]; then
  echo "Creating directory $MODEL_DIR..."
  mkdir -p "$MODEL_DIR"
fi

# 3. Start Ollama in background
echo "🚀 Starting Ollama service (internal port $OLLAMA_PORT)..."
export OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT"
export OLLAMA_ORIGINS="*"
# Redirect stdout to /dev/null to reduce logs (access logs), keep stderr for errors
/bin/ollama serve > /dev/null &
OLLAMA_PID=$!

# 4. Wait for Ollama to be ready
echo "⏳ Waiting for Ollama service to be ready..."
until curl -s http://127.0.0.1:$OLLAMA_PORT >/dev/null; do
  sleep 1
done
echo "✅ Ollama service is up."

# 5. Download model if missing (Logic reused)
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
        kill "$OLLAMA_PID"
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
    kill "$OLLAMA_PID"
    exit 1
  fi
fi

# 6. Create Modelfile and Import Model into Ollama
echo "📝 Creating Modelfile for $MODEL_FILENAME..."
cat <<EOF > Modelfile
FROM $MODEL_PATH
PARAMETER num_ctx $CONTEXT_SIZE
PARAMETER num_batch $BATCH_SIZE
EOF

# Use MODEL_NAME (or slug) as the Ollama model name
OLLAMA_MODEL_NAME=$(basename "$MODEL_FILENAME" .gguf)
echo "📦 Importing model as '$OLLAMA_MODEL_NAME'..."

# Create model (this will load GGUF and register it in Ollama)
/bin/ollama create "$OLLAMA_MODEL_NAME" -f Modelfile

# Verify model loaded
if /bin/ollama list | grep -q "$OLLAMA_MODEL_NAME"; then
  echo "✅ Model '$OLLAMA_MODEL_NAME' created successfully!"
else
  echo "❌ Failed to create model."
  kill "$OLLAMA_PID"
  exit 1
fi

# 7. Configure Caddy for API Key Authentication
echo "🔒 Configuring Caddy Proxy on port $PORT..."
cat <<EOF > /app/Caddyfile
{
    admin off
    log {
        level ERROR
    }
}
:$PORT {
    @unauthorized {
        not header Authorization "Bearer $API_KEY"
    }
    respond @unauthorized 401
    reverse_proxy 127.0.0.1:$OLLAMA_PORT {
        header_up Host localhost
        header_up -Authorization
    }
}
EOF

# 8. Start Caddy in foreground (keeping container alive)
# Note: Ollama runs in background, Caddy runs in foreground.
# If Ollama crashes, we might want to exit too, but Caddy will just 502.
# For simplicity, we just run Caddy.
echo "🚀 Starting Caddy Proxy..."
caddy run --config /app/Caddyfile --adapter caddyfile

# Cleanup if Caddy exits
kill "$OLLAMA_PID"