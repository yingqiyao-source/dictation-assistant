#!/usr/bin/env bash
# 构建默写助手 APK（本机 Android SDK build-tools 直接打包，无需 Gradle）
# 产出：android_build/build/dictation-assistant-v1.0.48.apk
set -e
SDK=/c/Users/lenovo/.android/sdk
BT=$SDK/build-tools/35.0.0
ANDROID_JAR=$SDK/platforms/android-35/android.jar
JDK="/c/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot"
JAVA="$JDK/bin/java"
JAVAC="$JDK/bin/javac"
WORK=/d/dictation-assistant/android_build
SRC=$WORK/App/src/main/java
MANIFEST=$WORK/App/src/main/AndroidManifest.xml
ASSETS=$WORK/App/src/main/assets
KEY=$WORK/keystore/debug.keystore
BLD=$WORK/build
OUT=$BLD/dictation-assistant-v1.0.48.apk

rm -rf "$BLD/classes" "$BLD/dex" "$BLD/base.apk" "$BLD/app-unsigned.apk" "$BLD/app-aligned.apk" "$OUT"
mkdir -p "$BLD/classes" "$BLD/dex"

# 从仓库根目录同步网页资源到 assets（assets 不进 git，避免与根 index.html 漂移）
ROOT=$(cd "$WORK/.." && pwd)
echo "[0/6] 同步根目录网页资源 -> assets"
mkdir -p "$ASSETS"
for f in index.html icon.png manifest.json sw.js; do
  if [ -f "$ROOT/$f" ]; then cp -f "$ROOT/$f" "$ASSETS/$f" && echo "  copied $f"; else echo "  WARN: 根目录缺少 $f，跳过"; fi
done

echo "[1/6] 编译 MainActivity.java"
"$JAVAC" -encoding UTF-8 -cp "$ANDROID_JAR" -d "$BLD/classes" "$SRC/com/dictation/app/MainActivity.java"

echo "[2/6] d8 -> classes.dex"
CLASSES=$(find "$BLD/classes" -name "*.class")
"$JAVA" -cp "$BT/lib/d8.jar" com.android.tools.r8.D8 --output "$BLD/dex" --lib "$ANDROID_JAR" $CLASSES

echo "[3/6] aapt2 link（清单 + assets）"
"$BT/aapt2.exe" link -o "$BLD/base.apk" -I "$ANDROID_JAR" --manifest "$MANIFEST" -A "$ASSETS" --min-sdk-version 21 --target-sdk-version 35

echo "[4/6] 将 classes.dex 写入 apk"
python3 - "$BLD/base.apk" "$BLD/dex/classes.dex" "$BLD/app-unsigned.apk" <<'PY'
import sys, zipfile
base, dex, out = sys.argv[1], sys.argv[2], sys.argv[3]
with zipfile.ZipFile(base, 'r') as zin, zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        if item.filename == 'classes.dex':
            continue
        zout.writestr(item, zin.read(item.filename))
    zout.write(dex, 'classes.dex')
print('added classes.dex ->', out)
PY

echo "[5/6] zipalign 对齐"
"$BT/zipalign.exe" -p 4 "$BLD/app-unsigned.apk" "$BLD/app-aligned.apk"

echo "[6/6] apksigner 签名"
"$JAVA" -jar "$BT/lib/apksigner.jar" sign --ks "$KEY" --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out "$OUT" "$BLD/app-aligned.apk"

echo "DONE -> $OUT"
ls -la "$OUT"
