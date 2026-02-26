FROM ghcr.io/ggml-org/llama.cpp:server

USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Default envs (can be overridden by Railway)
ENV HOST=0.0.0.0 \
    PORT=8080 \
    PLATFORM=hf \
    MODEL_NAME=Qwen/Qwen3-Embedding-4B-GGUF \
    MODEL_FILENAME=Qwen3-Embedding-4B-Q4_K_M.gguf \
    CONTEXT_SIZE=40960

# Persist models via Railway volume
VOLUME ["/models"]

EXPOSE 8080

# Basic healthcheck for OpenAI-compatible endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://localhost:${PORT}/v1/models >/dev/null || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]