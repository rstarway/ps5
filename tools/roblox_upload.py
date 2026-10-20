"""Загружает модель (GLB/FBX) в Roblox как ассет Model через Open Cloud и печатает её assetId.

    python tools/roblox_upload.py <file.glb> "<Name>" ["описание"]

Ключ берётся из .secrets/roblox_api_key (папка в .gitignore) или переменной ROBLOX_API_KEY.
Владелец — пользователь из ключа (ROBLOX_USER_ID или ownerId внутри ключа).
"""
import base64
import json
import os
import sys
import time
import urllib.request
import uuid

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
API = "https://apis.roblox.com/assets/v1/"
TYPES = {".glb": "model/gltf-binary", ".gltf": "model/gltf+json", ".fbx": "model/fbx"}


def api_key():
    path = os.path.join(ROOT, ".secrets", "roblox_api_key")
    if os.path.exists(path):
        return open(path).read().strip()
    return os.environ["ROBLOX_API_KEY"]


def owner_id(key):
    if os.environ.get("ROBLOX_USER_ID"):
        return os.environ["ROBLOX_USER_ID"]
    # ключ Open Cloud: base64 с JWT внутри, в нём есть ownerId
    raw = base64.b64decode(key + "==").decode("latin-1")
    for part in raw.split("."):
        try:
            data = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))
        except ValueError:
            continue
        if isinstance(data, dict) and "ownerId" in data:
            return data["ownerId"]
    raise SystemExit("set ROBLOX_USER_ID")


def request(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code}: {e.read().decode(errors='replace')}")


def upload(path, name, description=""):
    key = api_key()
    meta = {"assetType": "Model", "displayName": name, "description": description or name,
            "creationContext": {"creator": {"userId": str(owner_id(key))}}}
    boundary = uuid.uuid4().hex
    ext = os.path.splitext(path)[1].lower()
    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n".encode(),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
        f"Content-Type: {TYPES[ext]}\r\n\r\n".encode() + open(path, "rb").read() + b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ]
    op = request("POST", API + "assets", key, b"".join(parts), {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    for _ in range(120):
        if op.get("done"):
            break
        time.sleep(3)
        op = request("GET", API + op["path"], key)
    if "response" not in op:
        raise SystemExit(f"upload failed: {op}")
    asset_id = op["response"]["assetId"]
    print(f"UPLOADED {name} assetId={asset_id}")
    return asset_id


if __name__ == "__main__":
    upload(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
