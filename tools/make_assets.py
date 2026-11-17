#!/usr/bin/env python3
"""Sprites, icon and a short night loop for Ночной прилавок."""

import math
import os
import random
import shutil
import struct
import wave
import zlib
from array import array

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(ROOT, "assets")
SR = 22050


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: str, w: int, h: int, rgba: bytes) -> None:
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def save_wav(path: str, samples) -> None:
    frames = array("h")
    for sample in samples:
        frames.append(int(max(-1.0, min(1.0, float(sample))) * 32767))
    with wave.open(path, "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(frames.tobytes())


def ground(size: int = 128) -> bytes:
    rng = random.Random(3)
    pix = bytearray((18, 20, 30, 255) * (size * size))

    def setp(x: int, y: int, color) -> None:
        x %= size
        y %= size
        i = (y * size + x) * 4
        pix[i:i + 4] = bytes(color)

    for _ in range(30):
        cx = rng.randrange(size)
        cy = rng.randrange(size)
        rx = rng.randint(14, 26)
        ry = rng.randint(10, 18)
        col = rng.choice([(36, 42, 60), (44, 49, 70), (31, 35, 51), (52, 46, 64), (40, 44, 58)])
        for y in range(cy - ry - 1, cy + ry + 2):
            for x in range(cx - rx - 1, cx + rx + 2):
                nx = (x - cx) / rx
                ny = (y - cy) / ry
                dist = nx * nx + ny * ny
                if dist <= 1.0:
                    shade = 1.0 - 0.07 * ny
                    setp(x, y, (
                        max(0, min(255, int(col[0] * shade))),
                        max(0, min(255, int(col[1] * shade))),
                        max(0, min(255, int(col[2] * shade))),
                        255,
                    ))
                elif dist <= 1.18:
                    setp(x, y, (12, 13, 20, 255))
    return bytes(pix)


def glow(size: int = 128) -> bytes:
    pix = bytearray(size * size * 4)
    center = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x - center) ** 2 + (y - center) ** 2) / center
            alpha = 0 if dist >= 1.0 else int(255 * (1.0 - dist) ** 2)
            i = (y * size + x) * 4
            pix[i:i + 4] = bytes((255, 236, 210, alpha))
    return bytes(pix)


def icon(size: int = 128) -> bytes:
    pix = bytearray((22, 24, 36, 255) * (size * size))

    def setp(x: int, y: int, color) -> None:
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            pix[i:i + 4] = bytes(color)

    def disc(cx, cy, r, color) -> None:
        rr = int(r) + 1
        for y in range(int(cy) - rr, int(cy) + rr + 1):
            for x in range(int(cx) - rr, int(cx) + rr + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    setp(x, y, color)

    disc(64, 78, 34, (255, 190, 110, 40))
    for y in range(36, 92):
        setp(62, y, (58, 42, 34, 255))
        setp(63, y, (58, 42, 34, 255))
        setp(64, y, (90, 62, 42, 255))
    disc(64, 40, 18, (255, 210, 122, 255))
    disc(64, 40, 8, (255, 246, 216, 255))
    return bytes(pix)


def add_loop_sine(buf, freq: float, amp: float, wobble: float, dur: float) -> None:
    n = len(buf)
    cycles = max(1, round(freq * dur))
    for i in range(n):
        phase = 2.0 * math.pi * cycles * i / n
        env = 1.0 if wobble == 0 else 0.86 + 0.14 * math.sin(2.0 * math.pi * wobble * i / n)
        buf[i] += math.sin(phase) * amp * env


def add_pluck(buf, start_s: float, freq: float, dur_s: float, amp: float) -> None:
    start = int(start_s * SR)
    length = int(dur_s * SR)
    for i in range(length):
        idx = start + i
        if idx < 0 or idx >= len(buf):
            continue
        t = i / SR
        env = math.exp(-3.1 * t) * min(1.0, t / 0.01) * (1.0 - t / dur_s)
        buf[idx] += math.sin(2.0 * math.pi * freq * t) * amp * env
        buf[idx] += math.sin(2.0 * math.pi * freq * 2.0 * t) * amp * 0.12 * env


def night_loop():
    dur = 16.0
    n = SR * 16
    buf = [0.0] * n
    add_loop_sine(buf, 73.42, 0.11, 2, dur)
    add_loop_sine(buf, 146.83, 0.055, 2, dur)
    add_loop_sine(buf, 220.0, 0.03, 4, dur)
    notes = [
        (0, 293.66), (2, 349.23), (4, 392.00), (6, 440.00),
        (8, 349.23), (10, 293.66), (12, 440.00), (14, 392.00),
        (16, 587.33), (18, 440.00), (20, 392.00), (22, 349.23),
        (24, 440.00), (26, 392.00), (28, 349.23), (30, 293.66),
    ]
    for beat, freq in notes:
        add_pluck(buf, beat * 0.5, freq, 0.85, 0.16)
    for bar in range(8):
        add_pluck(buf, bar * 2.0, 880.0, 0.32, 0.035)
    rng = random.Random(11)
    for quarter in range(0, 32, 2):
        start = int(quarter * 0.5 * SR)
        length = int(0.045 * SR)
        acc = 0.0
        amp = 0.045 if quarter % 8 == 0 else 0.022
        for i in range(length):
            acc += (rng.uniform(-1.0, 1.0) - acc) * 0.22
            buf[start + i] += acc * amp * (1.0 - i / length) ** 2
    peak = max(abs(s) for s in buf) or 1.0
    return [s * (0.4 / peak) for s in buf]


def tone(freq, dur, amp=0.32, decay=8.0):
    n = max(1, int(dur * SR))
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t) * min(1.0, t / 0.004) * (1.0 - i / n)
        out.append(math.sin(2.0 * math.pi * freq * t) * amp * env)
    return out


def sweep(f0, f1, dur, amp, decay):
    n = max(1, int(dur * SR))
    out = []
    for i in range(n):
        t = i / SR
        freq = f0 + (f1 - f0) * (i / max(1, n - 1))
        env = math.exp(-decay * t) * min(1.0, t / 0.005)
        out.append(math.sin(2.0 * math.pi * freq * t) * amp * env)
    return out


def whoosh():
    rng = random.Random(2)
    n = int(0.18 * SR)
    acc = 0.0
    out = []
    for i in range(n):
        acc += (rng.uniform(-1.0, 1.0) - acc) * 0.12
        out.append(acc * 0.5 * math.sin(math.pi * i / n) ** 2)
    return out


def level_chime():
    parts = []
    for delay, freq in [(0.0, 293.66), (0.09, 349.23), (0.18, 440.0), (0.3, 587.33)]:
        note = tone(freq, 0.34, 0.22, 5.5)
        start = int(delay * SR)
        if len(parts) < start + len(note):
            parts.extend([0.0] * (start + len(note) - len(parts)))
        for i, sample in enumerate(note):
            parts[start + i] += sample
    return parts


def copy_fonts() -> None:
    dest = os.path.join(ASSETS, "fonts")
    os.makedirs(dest, exist_ok=True)
    base = "/usr/share/fonts/truetype/dejavu"
    shutil.copy(os.path.join(base, "DejaVuSans.ttf"), os.path.join(dest, "DejaVuSans.ttf"))
    shutil.copy(os.path.join(base, "DejaVuSans-Bold.ttf"), os.path.join(dest, "DejaVuSans-Bold.ttf"))
    license_src = "/usr/share/doc/fonts-dejavu-core/copyright"
    if os.path.exists(license_src):
        shutil.copy(license_src, os.path.join(dest, "LICENSE-DejaVu.txt"))


def main() -> None:
    os.makedirs(os.path.join(ASSETS, "audio"), exist_ok=True)
    write_png(os.path.join(ASSETS, "ground.png"), 128, 128, ground())
    write_png(os.path.join(ASSETS, "glow.png"), 128, 128, glow())
    write_png(os.path.join(ASSETS, "icon.png"), 128, 128, icon())
    save_wav(os.path.join(ASSETS, "audio", "night.wav"), night_loop())
    sounds = {
        "whoosh": whoosh(),
        "tick": tone(1480, 0.045, 0.28, 28),
        "coin": [a + b for a, b in zip(tone(988, 0.09, 0.22, 14) + [0] * 40, [0] * 40 + tone(1318, 0.08, 0.16, 16))],
        "pickup": [a + b for a, b in zip(tone(660, 0.12, 0.22, 12) + [0] * 50, [0] * 30 + tone(990, 0.1, 0.16, 10))],
        "level": level_chime(),
        "hurt": sweep(180, 70, 0.16, 0.35, 6),
        "death": sweep(150, 48, 0.55, 0.4, 3.2),
        "click": tone(1680, 0.03, 0.2, 40),
    }
    for name, samples in sounds.items():
        save_wav(os.path.join(ASSETS, "audio", f"{name}.wav"), samples)
    copy_fonts()
    print("assets ready")


if __name__ == "__main__":
    main()
