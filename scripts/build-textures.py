#!/usr/bin/env python3
"""
Convert the guide positioning screenshots into WoW-loadable textures.

WoW cannot fetch an image over the network -- there is no HTTP in the addon
API -- and it does not read PNG or JPG. Addon art has to ship as a local BLP or
TGA file, with power-of-two dimensions. So the guide diagrams become
uncompressed 24-bit TGAs under Textures/.

WHY 512x512 AND NOT THE SOURCE ASPECT
    Power-of-two is the constraint, so the source is squashed to a square and
    UI/PosMap.lua stretches it back out across the room rectangle when it
    draws. The distortion cancels. The panel shows the map about 500px wide,
    so 512 across is roughly native resolution anyway -- going to 1024 would
    quadruple the addon's size to buy detail nobody can see.

    Uncompressed rather than RLE: WoW's TGA support for run-length encoding is
    not dependable, and a texture that silently fails to load is worse than a
    larger file.

SOURCES
    Mount Hyjal   Jurdi's Mount Hyjal Cheat Sheet    twitch.tv/jurdijd
    Black Temple  cosmophile's Black Temple guide

    The images are theirs. They are redistributed here with credit, at the
    project owner's decision -- see Textures/CREDITS.txt.

USAGE
    python3 scripts/build-textures.py --hyjal <dir> --bt <dir> [--out Textures]

    --hyjal   directory holding the sheet's extracted imageNN.png files
    --bt      directory holding the guide's cellImage_*.jpg resources
"""

import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  pip install Pillow")

SIZE = (512, 512)

# Layout key -> source filename.
#
# The Hyjal mapping was read off the images themselves, NOT off sheet order --
# they do not match. image15 carries "Fight ends at 10%" and Air Burst, so it is
# Archimonde, and taking it for the first boss would have put the wrong diagram
# on Winterchill.
HYJAL = {
    "winterchill": "image22.png",   # "Rage will come from the same spot as the trash"
    "anetheron":   "image20.png",   # "Infernals are NOT tauntable"
    "kazrogal":    "image24.png",   # "12 yards to avoid the Warstomp stun"
    "azgalor":     "image21.png",   # draws the 30-yard Rain of Fire circle
    "archimonde":  "image15.png",   # "Fight ends at 10%", Air Burst, Tears of the Goddess
}

BT = {
    "najentus":    "cellImage_265547645_0.jpg",
    "supremus":    "cellImage_1800682938_0.jpg",
    "akama":       "cellImage_1034197849_0.jpg",
    "teron":       "cellImage_1640462487_0.jpg",
    "bloodboil":   "cellImage_1592821885_0.jpg",
    "reliquary":   "cellImage_2023211977_0.jpg",
    "shahraz":     "cellImage_1898555320_0.jpg",
    "council":     "cellImage_1657089132_0.jpg",
    "illidan":     "cellImage_319542884_0.jpg",    # phase 1
    "illidan_p2":  "cellImage_319542884_5.jpg",    # Flames of Azzinoth
    "illidan_p3":  "cellImage_319542884_12.jpg",
    "illidan_p4":  "cellImage_319542884_14.jpg",   # demon form
    "illidan_p5":  "cellImage_319542884_20.jpg",   # Maiev
}


def convert(src, dest):
    with Image.open(src) as im:
        # Flatten onto black first: some sources carry alpha, and a 24-bit TGA
        # has nowhere to put it. Compositing beats letting it default to white.
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            flat = Image.new("RGB", im.size, (0, 0, 0))
            flat.paste(im, mask=im.split()[-1])
            im = flat
        else:
            im = im.convert("RGB")
        im = im.resize(SIZE, Image.LANCZOS)
        im.save(dest)          # uncompressed 24-bit TGA
    return os.path.getsize(dest)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hyjal", required=True)
    ap.add_argument("--bt", required=True)
    ap.add_argument("--out", default="Textures")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)

    total = 0
    missing = []
    for label, (srcdir, table) in (("hyjal", (args.hyjal, HYJAL)), ("bt", (args.bt, BT))):
        for key, filename in sorted(table.items()):
            src = os.path.join(srcdir, filename)
            if not os.path.exists(src):
                missing.append(f"{key}: {src}")
                continue
            dest = os.path.join(args.out, key + ".tga")
            size = convert(src, dest)
            total += size
            print(f"  {key:14} {filename:32} {size / 1024:7.0f} KB")

    print(f"\n{total / 1024 / 1024:.1f} MB across {len(HYJAL) + len(BT) - len(missing)} textures")

    if missing:
        print("\nMISSING SOURCES:", file=sys.stderr)
        for m in missing:
            print("  " + m, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
