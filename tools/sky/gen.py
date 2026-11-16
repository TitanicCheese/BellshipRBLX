# Draws the cartoon skybox faces (sky_Bk/Dn/Ft/Lf/Rt/Up.png) into the folder given as the first
# argument. Needs numpy and pillow. The uploaded asset ids live in src/server/World.luau.
import numpy as np, math, random, sys
from PIL import Image
N = 1024
out = sys.argv[1]
ZEN = np.array([38, 132, 230.0]); MID = np.array([86, 182, 250.0]); HOR = np.array([196, 238, 255.0]); LOW = np.array([170, 222, 252.0])
ys, xs = np.mgrid[0:N, 0:N].astype(float)
u = (xs + 0.5) / (N / 2) - 1
v = (ys + 0.5) / (N / 2) - 1

def grad(elev):
    t = np.clip(elev / (math.pi / 2), -1, 1)[..., None]
    up = np.clip(t, 0, 1)
    a = np.clip(up / 0.18, 0, 1)            # horizon -> mid over the first ~16 degrees
    b = np.clip((up - 0.18) / 0.82, 0, 1) ** 0.8  # mid -> zenith
    col = HOR + (MID - HOR) * a
    col = col + (ZEN - col) * b
    down = np.clip(-t * 4, 0, 1)
    return np.where(t < 0, HOR + (LOW - HOR) * down, col)

WHITE = np.array([255, 255, 255.0]); SHADE = np.array([214, 233, 252.0]); LINE = np.array([140, 190, 236.0])
def cloud(img, cx, base, w, rng):
    # A row of overlapping circles on a flat bottom, tallest in the middle.
    n = rng.randint(4, 6)
    circles = []
    for i in range(n):
        f = i / (n - 1)
        x = cx - w / 2 + f * w
        r = (0.55 + 0.45 * math.sin(f * math.pi)) * w / n * rng.uniform(1.1, 1.4)
        circles.append((x, base - r * rng.uniform(0.35, 0.7), r))
    circles.append((cx + rng.uniform(-0.15, 0.15) * w, base - w / n * 1.3, w / n * 1.5))
    def mask(grow):
        m = np.zeros((N, N), bool)
        for x, y, r in circles:
            m |= (xs - x) ** 2 + (ys - y) ** 2 < (r + grow) ** 2
        return m & (ys < base + grow)
    inner, outer = mask(0), mask(4)
    # Underside shading: the bottom band of the cloud plus the lower edge of each puff.
    shade = np.zeros((N, N), bool)
    for x, y, r in circles:
        d = np.sqrt((xs - x) ** 2 + (ys - (y - r * 0.25)) ** 2)
        shade |= d < r * 0.95
    shade = inner & ~shade | (inner & (ys > base - w * 0.06))
    img[outer & ~inner] = LINE
    img[inner] = WHITE
    img[shade] = SHADE

def side(seed):
    rng = random.Random(seed)
    elev = np.arctan2(-v, np.sqrt(u ** 2 + 1))
    img = grad(elev)
    count = rng.randint(2, 4)
    slots = rng.sample([0.18, 0.4, 0.62, 0.84], count)
    for s in slots:
        cx = s * N + rng.uniform(-40, 40)
        base = N / 2 - rng.uniform(60, 260)
        cloud(img, cx, base, rng.uniform(90, 160), rng)
    return img

faces = {}
for i, name in enumerate(["Bk", "Ft", "Lf", "Rt"]):
    faces[name] = side(i * 7 + 3)
faces["Up"] = grad(np.arctan2(1, np.sqrt(u ** 2 + v ** 2)))
faces["Dn"] = grad(-np.arctan2(1, np.sqrt(u ** 2 + v ** 2)))
for name, img in faces.items():
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(f"{out}/sky_{name}.png")
# Preview strip
strip = np.concatenate([faces[n] for n in ["Ft", "Rt", "Bk", "Lf"]], axis=1)
Image.fromarray(np.clip(strip, 0, 255).astype(np.uint8)).resize((2048, 512)).save(f"{out}/preview.png")
