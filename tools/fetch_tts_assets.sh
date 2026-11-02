#!/usr/bin/env bash
# 离线语音资源获取脚本（在能访问 GitHub 的机器上运行；沙箱内已验证可达）
# 用途：下载 sherpa-onnx 浏览器 WASM 包（含中文模型）与英文 Piper libritts 语音，
#       落地到 vendor/ 与 models/，供 NAS / APK / file:// 离线使用。
set +e
ROOT="/d/dictation-assistant"
VER="1.13.8"
BASE="https://github.com/k2-fsa/sherpa-onnx/releases/download/v$VER"
TMP="$ROOT/_tmp_fetch"
mkdir -p "$TMP"
cd "$TMP"

echo "[1/2] 下载中文离线包 matcha-icefall-zh-baker（含 wasm 运行时 + 模型）…"
if [ ! -d sherpa_zh ]; then
  curl -L --max-time 1200 -o zh.tar.bz2 "$BASE/sherpa-onnx-wasm-simd-$VER-matcha-icefall-zh-baker.tar.bz2"
  mkdir -p sherpa_zh && tar -xjf zh.tar.bz2 -C sherpa_zh
fi
echo "[2/2] 下载英文 Piper libritts_r-medium 语音…"
if [ ! -d piper_libritts ]; then
  curl -L --max-time 1200 -o lib.tar.bz2 "$BASE/sherpa-onnx-wasm-simd-$VER-vits-piper-en_US-libritts_r-medium.tar.bz2"
  mkdir -p piper_libritts && tar -xjf lib.tar.bz2 -C piper_libritts
fi
echo "FETCH_DONE"
ls -R sherpa_zh 2>/dev/null | head -40
