"""Конвейер модели из Hunyuan3D до Roblox одной командой.

    python tools/asset_pipeline.py probe <Name>          # забрать свежий .glb из ~/Downloads, показать размеры и где «верх»
    python tools/asset_pipeline.py build <Name> --yaw N   # Blender (≤18k треугольников, «перед» на +Z) + загрузка в Roblox

probe кладёт файл в assets/hunyuan/<name>.glb и печатает, с какой стороны у модели самая высокая часть
(у мебели это спинка: «перед» — с противоположной стороны), чтобы выбрать --yaw.
build пишет assets/hunyuan/ready/<Name>.glb и печатает assetId загруженной модели.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLENDER = r"C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe"
DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")

PROBE = r'''
import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
vs = []
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        vs += [o.matrix_world @ v.co for v in o.data.vertices]
lo = [min(v[i] for v in vs) for i in range(3)]
hi = [max(v[i] for v in vs) for i in range(3)]
top = [v for v in vs if v.z > hi[2] - (hi[2] - lo[2]) * 0.1]
mx = sum(v.x for v in top) / len(top) - (lo[0] + hi[0]) / 2
my = sum(v.y for v in top) / len(top) - (lo[1] + hi[1]) / 2
print("PROBE size x=%.3f y=%.3f z(up)=%.3f  top-offset x=%+.3f y=%+.3f" % (hi[0]-lo[0], hi[1]-lo[1], hi[2]-lo[2], mx, my))
'''


def latest_download(since):
    for _ in range(120):
        files = [f for f in glob.glob(os.path.join(DOWNLOADS, "*.glb")) if os.path.getmtime(f) >= since]
        partial = glob.glob(os.path.join(DOWNLOADS, "*.glb.crdownload"))
        if files and not partial:
            return max(files, key=os.path.getmtime)
        time.sleep(2)
    raise SystemExit("no fresh .glb in Downloads")


def probe(name, since):
    src = latest_download(since)
    dst = os.path.join(ROOT, "assets", "hunyuan", name.lower() + ".glb")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(src, dst)
    script = os.path.join(ROOT, "assets", "hunyuan", "_probe.py")
    open(script, "w").write(PROBE)
    out = subprocess.run([BLENDER, "-b", "-P", script, "--", dst], capture_output=True, text=True).stdout
    os.remove(script)
    print(os.path.relpath(dst, ROOT))
    print("\n".join(l for l in out.splitlines() if l.startswith("PROBE")))
    print("Blender axes: -Y = Roblox +Z (front). yaw 0 keeps -Y as front; 90 turns -X to front; 180 turns +Y; 270 turns +X.")


def build(name, yaw, tris):
    src = os.path.join(ROOT, "assets", "hunyuan", name.lower() + ".glb")
    dst = os.path.join(ROOT, "assets", "hunyuan", "ready", name + ".glb")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out = subprocess.run([BLENDER, "-b", "-P", os.path.join(ROOT, "blender", "prep_asset.py"), "--", src, dst,
                          "--tris", str(tris), "--yaw", str(yaw)], capture_output=True, text=True).stdout
    print("\n".join(l for l in out.splitlines() if l.startswith("DONE")))
    sys.path.insert(0, os.path.dirname(__file__))
    import roblox_upload
    roblox_upload.upload(dst, "PS5 ChillZone " + name, f"{name} for the PS5 Sandbox chill zone (Hunyuan3D)")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=("probe", "build"))
    p.add_argument("name")
    p.add_argument("--yaw", type=float, default=0)
    p.add_argument("--tris", type=int, default=18000)
    p.add_argument("--since", type=float, default=time.time() - 600, help="ignore downloads older than this")
    a = p.parse_args()
    if a.cmd == "probe":
        probe(a.name, a.since)
    else:
        build(a.name, a.yaw, a.tris)
