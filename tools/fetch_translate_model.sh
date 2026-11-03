#!/usr/bin/env bash
# 本地翻译模型获取脚本（在能访问网络的机器上运行；沙箱内已验证可达）
# 用途：下载 transformers.js 运行时 + opus-mt-en-zh INT8 模型到 vendor/translate/，
#       部署到 NAS / 本地服务器后，即可启用「英文释义自动翻译」第二级兜底（覆盖手机 / WebView）。
#
# 说明：
#   - 引擎：@huggingface/transformers（含 onnxruntime-web，浏览器端 WASM/WebGPU 推理）
#   - 模型：Xenova/opus-mt-en-zh（Helsinki-NLP OPUS-MT 的 ONNX 版，英→中，INT8 量化）
#   - 这些大文件不进 GitHub（vendor/ 已在 .gitignore）
set +e
ROOT="/d/dictation-assistant"
DEST="$ROOT/vendor/translate"
mkdir -p "$DEST/opus-mt-en-zh"
cd "$DEST"

echo "[1/2] 下载 transformers.js v3 (ESM) -> transformers.min.js …"
if [ ! -f transformers.min.js ]; then
  curl -L --max-time 600 -o transformers.min.js \
    "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.5.0/dist/transformers.min.js"
fi

echo "[2/2] 下载 Xenova/opus-mt-en-zh ONNX 模型（INT8）-> opus-mt-en-zh/ …"
if [ ! -f opus-mt-en-zh/config.json ]; then
  python3 - <<'PY'
from huggingface_hub import snapshot_download
import os, shutil
src = snapshot_download("Xenova/opus-mt-en-zh",
                        allow_patterns=["onnx/*", "*.json", "*.spm", "tokenizer*", "vocab*", "*.txt"])
for name in os.listdir(src):
    s = os.path.join(src, name)
    if os.path.isfile(s):
        shutil.copy(s, os.path.join("opus-mt-en-zh", name))
onnx_dir = os.path.join(src, "onnx")
if os.path.isdir(onnx_dir):
    os.makedirs("opus-mt-en-zh/onnx", exist_ok=True)
    for f in os.listdir(onnx_dir):
        shutil.copy(os.path.join(onnx_dir, f), os.path.join("opus-mt-en-zh/onnx", f))
print("model files copied")
PY
fi

echo "FETCH_DONE"
ls -R "$DEST" 2>/dev/null | head -50
