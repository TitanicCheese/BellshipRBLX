# Draws the cartoon skybox: a smooth blue gradient by elevation (the clouds are 3D parts built in
# src/server/World.luau). Writes sky_Side.png (used for all four sides), sky_Up.png and
# sky_Dn.png into the folder given as the first argument. Needs numpy and pillow.
import math
import sys

import numpy as np
from PIL import Image

N = 1024
ZENITH = np.array([38, 132, 230.0])
MID = np.array([86, 182, 250.0])
HORIZON = np.array([196, 238, 255.0])
BELOW = np.array([170, 222, 252.0])

ys, xs = np.mgrid[0:N, 0:N].astype(float)
u = (xs + 0.5) / (N / 2) - 1
v = (ys + 0.5) / (N / 2) - 1


def gradient(elevation):
    t = np.clip(elevation / (math.pi / 2), -1, 1)[..., None]
    up = np.clip(t, 0, 1)
    low = np.clip(up / 0.18, 0, 1)  # horizon -> mid over the first ~16 degrees
    high = np.clip((up - 0.18) / 0.82, 0, 1) ** 0.8  # mid -> zenith
    color = HORIZON + (MID - HORIZON) * low
    color = color + (ZENITH - color) * high
    down = np.clip(-t * 4, 0, 1)
    return np.where(t < 0, HORIZON + (BELOW - HORIZON) * down, color)


faces = {
    "Side": gradient(np.arctan2(-v, np.sqrt(u**2 + 1))),
    "Up": gradient(np.arctan2(1, np.sqrt(u**2 + v**2))),
    "Dn": gradient(-np.arctan2(1, np.sqrt(u**2 + v**2))),
}
for name, img in faces.items():
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(f"{sys.argv[1]}/sky_{name}.png")
