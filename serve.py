#!/usr/bin/env python3
# 本地静态服务器：用于加载离线语音模型（ESM/wasm/onnx 需经 HTTP 提供正确 MIME）
import http.server, socketserver, os, sys

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


PORT = int(os.environ.get('PORT', 8000))
# 允许命令行覆盖端口：python serve.py --port 5077 或 serve.py 5077
for _a in sys.argv[1:]:
    if _a == '--port' and len(sys.argv) > sys.argv.index(_a) + 1:
        PORT = int(sys.argv[sys.argv.index(_a) + 1])
    elif _a.isdigit():
        PORT = int(_a)

if __name__ == '__main__':
    with socketserver.TCPServer(('0.0.0.0', PORT), Handler) as httpd:
        print(f'默写助手本地服务已启动： http://0.0.0.0:{PORT}  （按 Ctrl+C 停止）')
        print('在浏览器打开上面的地址即可使用（含离线语音模型）。')
        httpd.serve_forever()
