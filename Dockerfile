FROM ollama/ollama:latest

USER root

# Install dependencies
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install Caddy from official image
COPY --from=caddy:latest /usr/bin/caddy /usr/bin/caddy

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Default envs
ENV OLLAMA_HOST=127.0.0.1:11434 \
    PORT=8080 \
    PLATFORM=hf \
    MODEL_NAME=Qwen/Qwen3-Embedding-4B-GGUF \
    MODEL_FILENAME=Qwen3-Embedding-4B-Q4_K_M.gguf \
    CONTEXT_SIZE=10240 \
    BATCH_SIZE=512

EXPOSE 8080

# Healthcheck checking Caddy endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://localhost:${PORT}/ || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
