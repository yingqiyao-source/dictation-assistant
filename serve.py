#!/usr/bin/env python3
# 本地静态服务器：用于加载离线语音模型（ESM/wasm/onnx 需经 HTTP 提供正确 MIME）
import http.server, socketserver, os

os.chdir(os.path.dirname(os.path.abspath(__file__)))


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.js': 'text/javascript',
        '.mjs': 'text/javascript',
        '.wasm': 'application/wasm',
        '.onnx': 'application/octet-stream',
        '.bin': 'application/octet-stream',
        '.data': 'application/octet-stream',
        '.json': 'application/json',
    }

    def guess_type(self, path):
        # jsdelivr 的 ESM 导出文件名为「xxx/+esm」（无扩展名），必须按 JavaScript 返回，
        # 否则浏览器会以「Failed to fetch dynamically imported module」拒绝加载（Kokoro 链依赖它）
        if path.endswith('+esm') or path.endswith('.mjs') or path.endswith('.js'):
            return 'text/javascript'
        return super().guess_type(path)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        # 多线程 wasm（ort-wasm-simd-threaded.jsep）需要跨源隔离策略才能用 SharedArrayBuffer；
        # 同时给所有响应加 CORP，使同源 ES 模块 / worker 在 COEP=require-corp 下不被拦截
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        super().end_headers()


PORT = 8000
if __name__ == '__main__':
    with socketserver.TCPServer(('', PORT), Handler) as httpd:
        print(f'默写助手本地服务已启动： http://localhost:{PORT}')
        print('在浏览器打开上面的地址即可使用（含离线语音模型）。按 Ctrl+C 停止。')
        httpd.serve_forever()
