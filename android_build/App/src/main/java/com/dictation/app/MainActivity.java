package com.dictation.app;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.JavascriptInterface;

import java.io.InputStream;
import java.util.HashMap;
import java.util.Locale;

/**
 * 极简 WebView 壳：在 shouldInterceptRequest 中把 APK 内 assets/ 目录以
 * https://appassets.androidplatform.net/assets/... 形式提供给 WebView。
 *
 * 为什么这么做（而非直接 file:///android_asset）：
 *  - Android WebView 在 file:// 下禁止 ES 模块 / import maps / 动态 import()，而本应用
 *    （PWA、动态 import 等）依赖这些特性。以 https 形式提供资源后，行为与“普通 https
 *    静态服务器部署”完全一致，_fileMode 判定为 false，网页逻辑正常工作。
 *  - 网页与少量资源（index.html 等）已打进 APK 的 assets，纯离线可用。
 *
 * 语音方案：Android WebView 内 speechSynthesis 通常不可用，且把数百 MB 的离线神经网络
 * 模型（Sherpa/Piper，约 330MB）打进 APK 会令安装包膨胀、WebView 加载/推理卡死。
 * 因此本 App 改用【原生系统 TTS 桥】：通过 @JavascriptInterface 暴露 AndroidTTS 对象，
 * 网页检测到后直接调用系统语音（中文/英文），即时、高质量、零模型、零卡顿。
 *
 * 不依赖 WebViewAssetLoader（部分平台桩包未暴露该符号），直接自行拦截请求读取 assets，
 * 并显式设置 MIME（尤其 .js=text/javascript、.wasm=application/wasm），避免模块脚本被拒绝执行。
 */
public class MainActivity extends Activity implements TextToSpeech.OnInitListener {

    private static final String ASSET_HOST = "appassets.androidplatform.net";

    private WebView webView;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private final Object ttsLock = new Object();

    private static String guessMime(String p) {
        String ext = p.contains(".") ? p.substring(p.lastIndexOf('.') + 1).toLowerCase() : "";
        switch (ext) {
            case "html": case "htm": return "text/html";
            case "js":   case "mjs": return "text/javascript";
            case "json": case "map": return "application/json";
            case "wasm":              return "application/wasm";
            case "onnx": case "bin": case "data": return "application/octet-stream";
            case "css":               return "text/css";
            case "png":               return "image/png";
            case "svg":               return "image/svg+xml";
            case "xml":               return "application/xml";
            default:                  return "application/octet-stream";
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);                  // 必需：应用逻辑 / WebAssembly
        settings.setDomStorageEnabled(true);                  // 必需：localStorage（应用数据持久化）
        settings.setAllowFileAccess(false);                   // 安全：仅走 asset 拦截
        settings.setAllowContentAccess(false);
        settings.setMediaPlaybackRequiresUserGesture(false);  // 允许语音自动播放
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (uri == null || !ASSET_HOST.equals(uri.getHost())) {
                    return null; // 非本应用资源：交回 WebView 默认处理
                }
                String path = uri.getPath();                   // 形如 /assets/index.html
                if (path == null) return null;
                if (path.startsWith("/")) path = path.substring(1);
                try {
                    InputStream is = getAssets().open(path);
                    return new WebResourceResponse(guessMime(path), null, is);
                } catch (Exception e) {
                    return null;
                }
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() { request.grant(request.getResources()); }
                });
            }
        });

        // 原生 TTS 桥：让网页用系统语音（中文/英文），无需离线模型、即时、高质量
        tts = new TextToSpeech(this, this);
        webView.addJavascriptInterface(new TTSBridge(), "AndroidTTS");

        setContentView(webView);
        webView.loadUrl("https://" + ASSET_HOST + "/assets/index.html");
    }

    @Override
    public void onInit(int status) {
        synchronized (ttsLock) {
            if (status != TextToSpeech.SUCCESS || tts == null) return;
            int r = tts.setLanguage(Locale.CHINESE);
            if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                // 设备缺少中文语音数据包：引导系统安装（一次性），同时退回英文引擎保证可用
                try {
                    Intent install = new Intent("android.speech.tts.engine.INSTALL_TTS_DATA");
                    install.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(install);
                } catch (Exception ignore) {}
                tts.setLanguage(Locale.US);
            }
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override public void onStart(String utteranceId) {}
                @Override public void onDone(String utteranceId) { notifyEnd(); }
                @Override public void onError(String utteranceId) { notifyEnd(); }
            });
            ttsReady = true;
            runOnUiThread(new Runnable() {
                @Override public void run() {
                    if (webView != null) webView.evaluateJavascript("if(window.__androidTtsReady)window.__androidTtsReady()", null);
                }
            });
        }
    }

    private void notifyEnd() {
        runOnUiThread(new Runnable() {
            @Override public void run() {
                if (webView != null) webView.evaluateJavascript("if(window.__androidTtsOnEnd)window.__androidTtsOnEnd()", null);
            }
        });
    }

    private class TTSBridge {
        @JavascriptInterface
        public boolean isAvailable() { return ttsReady; }

        @JavascriptInterface
        public void setRate(float rate) {
            synchronized (ttsLock) {
                if (tts != null) tts.setSpeechRate(rate <= 0 ? 1.0f : rate);
            }
        }

        @JavascriptInterface
        public void speak(String text, String lang, float rate) {
            if (text == null || text.isEmpty()) { notifyEnd(); return; }
            synchronized (ttsLock) {
                if (tts == null || !ttsReady) { notifyEnd(); return; }
                Locale loc = "en".equals(lang) ? Locale.US : Locale.CHINESE;
                int r = tts.setLanguage(loc);
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts.setLanguage(Locale.US);
                }
                tts.setSpeechRate(rate <= 0 ? 1.0f : rate);
                HashMap<String, String> params = new HashMap<>();
                params.put(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "utt");
                tts.speak(text, TextToSpeech.QUEUE_FLUSH, params);
            }
        }

        @JavascriptInterface
        public void stop() {
            synchronized (ttsLock) { if (tts != null) tts.stop(); }
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onPause() {
        if (webView != null) webView.onPause();
        synchronized (ttsLock) { if (tts != null) tts.stop(); }
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (webView != null) webView.onResume();
    }

    @Override
    protected void onDestroy() {
        synchronized (ttsLock) {
            if (tts != null) { tts.stop(); tts.shutdown(); tts = null; }
        }
        if (webView != null) {
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
