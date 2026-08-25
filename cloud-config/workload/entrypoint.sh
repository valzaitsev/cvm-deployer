#!/bin/bash
set -e

RAM_MOUNT="/mnt/secure_tmp"
MODEL_PATH="/mnt/secure_tmp/model"

echo "[Init] Waiting for loader to extract the model..."
while [ ! -f "$RAM_MOUNT/model.ready" ]; do
  sleep 2
done

echo "Files list at MODEL_PATH=$MODEL_PATH:"
ls -la $MODEL_PATH

rm -f "$RAM_MOUNT/model.ready"

echo "[Init] Model is ready! Launching vLLM..."

python3 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --served-model-name "$MODEL_NAME" \
    --port "$PORT" \
    --host 0.0.0.0 \
    --enforce-eager \
    --gpu-memory-utilization 0.9 \
    &VLLM_PID=$!

echo "[Init] Waiting for vLLM to finish loading model..."
until curl -s http://localhost:"$PORT"/health >/dev/null 2>&1; do
    if ! kill -0 $VLLM_PID 2>/dev/null; then
        echo "[Error] vLLM failed to start."
        exit 1
    fi
    sleep 2
done

echo "[Init] vLLM health check OK. Model has been loaded successfully."
#echo "[Init] Wiping RAM staging path..."
#rm -rf "$MODEL_PATH"/*

# Keep container attached to vLLM
wait $VLLM_PID