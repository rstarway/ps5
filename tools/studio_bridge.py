"""Мост между Roblox Studio и репозиторием (для работы через Studio MCP).

    python tools/studio_bridge.py            # слушает http://127.0.0.1:34877

GET  /<путь>                  отдаёт файл репозитория (синхронизация исходников в Studio)
POST /save?path=<путь>        тело — base64 файла; пишет его в репозиторий (модели .rbxm из Studio)
POST /save?path=<путь>&raw=1  тело — сам файл (страница Hunyuan в Chrome отдаёт GLB прямо сюда)

Слушает только localhost и пишет только внутрь репозитория.
"""
import base64
import http.server
import os
import urllib.parse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PORT = 34877


def inside_repo(rel):
    path = os.path.abspath(os.path.join(ROOT, rel))
    if os.path.commonpath([path, ROOT]) != ROOT:
        raise ValueError("path outside repo: " + rel)
    return path


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def cors(self):
        # страница https://3d.hunyuan.tencent.com шлёт сюда GLB: разрешаем CORS и доступ к локальной сети
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.end_headers()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(url.query)
        try:
            if url.path != "/save" or "path" not in query:
                raise ValueError("expected POST /save?path=...")
            target = inside_repo(query["path"][0])
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            data = body if query.get("raw") == ["1"] else base64.b64decode(body)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "wb") as f:
                f.write(data)
            reply = f"saved {os.path.relpath(target, ROOT)} ({len(data)} bytes)".encode()
            self.send_response(200)
        except Exception as e:  # noqa: BLE001 — ошибку отдаём в Studio текстом
            reply = str(e).encode()
            self.send_response(400)
        self.cors()
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
