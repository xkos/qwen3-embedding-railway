#!/bin/bash
set -e


API_KEY="${API_KEY:-}"
if [ -z "$API_KEY" ]; then
  echo "API_KEY is required. Export API_KEY before running: export API_KEY=..."
  exit 1
fi

# curl -vvv  https://qwen3-embedding-railway-production.up.railway.app/v1/models -H "Content-Type: application/json"  -H "Authorization: Bearer ${API_KEY}" 

curl -vvv -sS https://qwen3-embedding-railway-production.up.railway.app/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "input": "The food was delicious and the waiter...",
    "model": "Qwen3-Embedding-4B-Q4_K_M"
  }' | jq .