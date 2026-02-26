#!/bin/bash
set -euo pipefail

API_KEY="${API_KEY:-}"
if [ -z "$API_KEY" ]; then
  echo "API_KEY is required. Export API_KEY before running: export API_KEY=..."
  exit 1
fi

curl -sS http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "input": "The food was delicious and the waiter...",
    "model": "qwen3-embedding"
  }' | jq .