"""Референс-картинка предмета для режима «图生3D» (Hunyuan): API нейросети вместо 150 символов текста.

    python tools/ref_image.py <Name> "<предмет по-английски>" [--n 2] [--provider gemini|openai]

Результат: assets/pack/refs/<Name>_<i>.png. Ключи — только из переменных окружения (в вывод и в файлы не попадают):
  Gemini  — GEMINI_API_KEY, модель REF_GEMINI_MODEL (иначе первая модель с "image" в имени из списка ключа);
  OpenAI-совместимый — OPENAI_API_KEY, OPENAI_BASE_URL (по умолчанию api.openai.com/v1), REF_OPENAI_MODEL (gpt-image-1).
Hunyuan лучше всего восстанавливает один предмет с одного чистого ракурса на белом фоне, поэтому шаблон такой.
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "pack", "refs")

STYLE = ("Product render of a single {subject}. Minimalist modern outdoor furniture style, warm oak wood, matte black "
         "metal, cream linen fabric, terracotta and sage green accents. Three-quarter view from slightly above, the whole "
         "object fully visible and centered, isolated on a plain pure white background, soft even studio lighting, no "
         "shadow, no ground, no text, no logo, no other objects, clean simple geometry, realistic PBR materials.")


def post(url, body, headers, timeout=240):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **headers})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503) or attempt == 2:
                raise SystemExit(f"ошибка {e.code}: {e.read().decode(errors='ignore')[:300]}")
            time.sleep(6 * (attempt + 1))


def gemini(prompt, n):
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        return None
    base = "https://generativelanguage.googleapis.com/v1beta"
    model = os.environ.get("REF_GEMINI_MODEL")
    if not model:
        req = urllib.request.Request(f"{base}/models", headers={"x-goog-api-key": key})
        names = [m["name"].split("/")[-1] for m in json.loads(urllib.request.urlopen(req, timeout=60).read()).get("models", [])]
        cands = [x for x in names if "image" in x and x.startswith("gemini-") and "preview" not in x] or [x for x in names if "image" in x and x.startswith("gemini-")]
        if not cands:
            print("gemini: у ключа нет моделей с картинками")
            return None
        model = sorted(cands)[-1]
    print("gemini model:", model)
    imgs = []
    for _ in range(n):
        out = post(f"{base}/models/{model}:generateContent", {"contents": [{"parts": [{"text": prompt}]}],
                   "generationConfig": {"responseModalities": ["IMAGE"]}}, {"x-goog-api-key": key})
        for p in out.get("candidates", [{}])[0].get("content", {}).get("parts", []):
            d = p.get("inline_data") or p.get("inlineData")
            if d:
                imgs.append(base64.b64decode(d["data"]))
    return imgs


def openai(prompt, n):
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    base = (os.environ.get("OPENAI_BASE_URL") or "https://api.openai.com/v1").rstrip("/")
    model = os.environ.get("REF_OPENAI_MODEL", "gpt-image-1")
    print("openai model:", model)
    out = post(f"{base}/images/generations", {"model": model, "prompt": prompt, "n": n, "size": "1024x1024"},
               {"Authorization": f"Bearer {key}"}, timeout=600)
    imgs = []
    for d in out.get("data", []):
        if d.get("b64_json"):
            imgs.append(base64.b64decode(d["b64_json"]))
        elif d.get("url"):
            imgs.append(urllib.request.urlopen(d["url"], timeout=120).read())
    return imgs


def proxy_base():
    return (os.environ.get("GEMINI_PROXY_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api.openai.com/v1").rstrip("/")


def proxy_models():
    """Список моделей перепродавца (Gemini через OpenAI-совместимый адрес): видно, какие умеют картинки."""
    key = os.environ.get("GEMINI_PROXY_API_KEY")
    if not key:
        sys.exit("нет GEMINI_PROXY_API_KEY в окружении")
    req = urllib.request.Request(f"{proxy_base()}/models", headers={"Authorization": f"Bearer {key}"})
    names = sorted(m["id"] for m in json.loads(urllib.request.urlopen(req, timeout=60).read()).get("data", []))
    for n in names:
        print(n)


def gemini_proxy(prompt, n):
    """Платный Gemini через перепродавца: сначала /images/generations, потом chat/completions с картинкой в ответе."""
    key = os.environ.get("GEMINI_PROXY_API_KEY")
    if not key:
        return None
    base = proxy_base()
    model = os.environ.get("REF_PROXY_MODEL", "gemini-3.1-flash-image")
    print("proxy model:", model)
    hdr = {"Authorization": f"Bearer {key}"}
    imgs = []
    try:
        out = post(f"{base}/images/generations", {"model": model, "prompt": prompt, "n": n, "size": "1024x1024"}, hdr, 600)
        for d in out.get("data", []):
            if d.get("b64_json"):
                imgs.append(base64.b64decode(d["b64_json"]))
            elif d.get("url"):
                imgs.append(urllib.request.urlopen(d["url"], timeout=120).read())
    except SystemExit as e:
        print("images/generations:", str(e)[:120])
    if imgs:
        return imgs
    import re
    for _ in range(n):
        out = post(f"{base}/chat/completions", {"model": model, "messages": [{"role": "user", "content": prompt}]}, hdr, 600)
        msg = out["choices"][0]["message"]
        blob = json.dumps(msg)
        for m in re.findall(r"data:image/[a-z]+;base64,([A-Za-z0-9+/=]+)", blob.replace("\\/", "/")):
            imgs.append(base64.b64decode(m))
    return imgs


def main():
    p = argparse.ArgumentParser()
    p.add_argument("name", nargs="?", default="")
    p.add_argument("subject", nargs="?", default="")
    p.add_argument("--n", type=int, default=2)
    p.add_argument("--provider", choices=("gemini", "openai", "proxy"))
    p.add_argument("--list-models", action="store_true", help="показать модели прокси (GEMINI_PROXY_*)")
    a = p.parse_args()
    if a.list_models:
        return proxy_models()
    os.makedirs(OUT, exist_ok=True)
    prompt = STYLE.format(subject=a.subject)
    order = [a.provider] if a.provider else ["proxy", "gemini", "openai"]
    imgs = None
    for prov in order:
        imgs = {"gemini": gemini, "openai": openai, "proxy": gemini_proxy}[prov](prompt, a.n)
        if imgs:
            break
        print(f"{prov}: нет ключа или картинок, пробую дальше")
    if not imgs:
        sys.exit("ни один провайдер не вернул картинку")
    for i, data in enumerate(imgs):
        path = os.path.join(OUT, f"{a.name}_{i}.png")
        open(path, "wb").write(data)
        print("saved", os.path.relpath(path, ROOT), len(data))


main()
