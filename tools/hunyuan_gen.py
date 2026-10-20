"""Генерация 3D-моделей: текст → картинка (FLUX.1-schnell) → текстурированный GLB (Hunyuan3D-2).

    python tools/hunyuan_gen.py <name> "<описание предмета>" [--seed N] [--image-only] [--from-image path.png]

Результат: assets/hunyuan/<name>.png (референс) и assets/hunyuan/<name>.glb (модель с текстурой).
Оба Space на Hugging Face вызываются через gradio_client; на бесплатной квоте ZeroGPU генераций в день немного.

Лицензии: FLUX.1-schnell — Apache-2.0; Hunyuan3D-2 — Tencent Hunyuan Community License
(нельзя использовать в ЕС, Великобритании и Южной Корее; свыше 1 млн MAU нужна отдельная лицензия).
"""
import argparse
import os
import shutil
import sys
import time

from gradio_client import Client, handle_file

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "hunyuan")

# Hunyuan лучше всего восстанавливает предмет с одного чистого ракурса на белом фоне
STYLE = ("product photo of a single {subject}, three-quarter view from slightly above, whole object fully visible "
         "and centered, isolated on a plain pure white background, soft even studio lighting, no shadows, "
         "no text, no other objects, high detail, realistic materials")


def make_image(name, subject, seed):
    client = Client("black-forest-labs/FLUX.1-schnell", verbose=False)
    result, _ = client.predict(prompt=STYLE.format(subject=subject), seed=seed, randomize_seed=False,
                               width=1024, height=1024, num_inference_steps=4, api_name="/infer")
    path = os.path.join(OUT, name + ".png")
    shutil.copy(result if isinstance(result, str) else result["path"], path)
    return path


def make_model(name, image, seed):
    client = Client("tencent/Hunyuan3D-2", verbose=False)
    textured, white, _html, stats, _seed = client.predict(
        caption=None, image=handle_file(image), mv_image_front=None, mv_image_back=None, mv_image_left=None,
        mv_image_right=None, steps=30, guidance_scale=5.0, seed=seed, octree_resolution=256, check_box_rembg=True,
        num_chunks=8000, randomize_seed=False, api_name="/generation_all")
    path = os.path.join(OUT, name + ".glb")
    shutil.copy(textured, path)
    return path, stats


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("subject", nargs="?", default="")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--image-only", action="store_true")
    parser.add_argument("--from-image")
    args = parser.parse_args()
    os.makedirs(OUT, exist_ok=True)
    t = time.time()
    image = args.from_image or make_image(args.name, args.subject, args.seed)
    print("image", os.path.relpath(image, ROOT), f"{time.time() - t:.0f}s", flush=True)
    if args.image_only:
        return
    model, stats = make_model(args.name, image, args.seed)
    print("model", os.path.relpath(model, ROOT), f"{time.time() - t:.0f}s", stats, flush=True)


if __name__ == "__main__":
    sys.exit(main())
