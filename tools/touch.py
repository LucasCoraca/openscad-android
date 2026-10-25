#!/usr/bin/env python3
"""Two-finger gestures on the emulator (adb's `input` has only one finger): raw multi-touch events written to the
touchscreen's evdev node (needs `adb root`).

usage: touch.py pinch CX CY FROM_DIST TO_DIST [steps]     fingers on a horizontal line through (CX, CY)
       touch.py pan X Y DX DY [steps]                      two fingers 120 px apart, moved together by (DX, DY)
       touch.py paths X1 Y1 X2 Y2 X1E Y1E X2E Y2E [steps]  each finger from its start to its end point
Screen coordinates in pixels. Env: ANDROID_SERIAL (default emulator-5590), TOUCH_DEV (default /dev/input/event2).
"""
import os
import struct
import subprocess
import sys
import tempfile

SERIAL = os.environ.get("ANDROID_SERIAL", "emulator-5590")
DEV = os.environ.get("TOUCH_DEV", "/dev/input/event2")
ADB = [os.path.expanduser("~/Android/sdk/platform-tools/adb"), "-s", SERIAL]
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT, BTN_TOUCH = 0, 0x14a
ABS_MT_SLOT, ABS_MT_TRACKING_ID, ABS_MT_X, ABS_MT_Y, ABS_MT_PRESSURE = 0x2F, 0x39, 0x35, 0x36, 0x3A


def screen_size():
    out = subprocess.check_output(ADB + ["shell", "wm", "size"], text=True)
    w, h = out.strip().split()[-1].split("x")
    return int(w), int(h)


def ev(t, c, v):
    return struct.pack("<qqHHi", 0, 0, t, c, v)


def frames(paths, steps, size):
    """paths: [((x0, y0), (x1, y1)), ...] per finger -> list of event blobs, one per frame"""
    w, h = size
    sx = lambda x: int(round(x * 32767 / (w - 1)))
    sy = lambda y: int(round(y * 32767 / (h - 1)))
    out = []
    for i in range(steps + 1):
        f = i / steps
        b = b""
        for slot, ((x0, y0), (x1, y1)) in enumerate(paths):
            b += ev(EV_ABS, ABS_MT_SLOT, slot)
            if i == 0:
                b += ev(EV_ABS, ABS_MT_TRACKING_ID, 100 + slot)
                b += ev(EV_ABS, ABS_MT_PRESSURE, 512)
            b += ev(EV_ABS, ABS_MT_X, sx(x0 + (x1 - x0) * f)) + ev(EV_ABS, ABS_MT_Y, sy(y0 + (y1 - y0) * f))
        if i == 0:
            b += ev(EV_KEY, BTN_TOUCH, 1)
        out.append(b + ev(EV_SYN, SYN_REPORT, 0))
    end = b""
    for slot in range(len(paths)):
        end += ev(EV_ABS, ABS_MT_SLOT, slot) + ev(EV_ABS, ABS_MT_TRACKING_ID, -1)
    out.append(end + ev(EV_KEY, BTN_TOUCH, 0) + ev(EV_SYN, SYN_REPORT, 0))
    return out


def play(blobs, delay=0.03):
    with tempfile.TemporaryDirectory() as d:
        script = ["cd /data/local/tmp/touch"]
        for i, b in enumerate(blobs):
            with open(os.path.join(d, f"f{i}"), "wb") as fh:
                fh.write(b)
            script.append(f"cat f{i} > {DEV}; sleep {delay}")
        with open(os.path.join(d, "run.sh"), "w") as fh:
            fh.write("\n".join(script) + "\n")
        subprocess.check_call(ADB + ["shell", "rm -rf /data/local/tmp/touch; mkdir -p /data/local/tmp/touch"])
        subprocess.check_call(ADB + ["push", "-q", d + "/.", "/data/local/tmp/touch/"], stdout=subprocess.DEVNULL)
        subprocess.check_call(ADB + ["shell", "sh /data/local/tmp/touch/run.sh"])


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        sys.exit(1)
    cmd, n = a[0], [float(x) for x in a[1:]]
    if cmd == "pinch":
        cx, cy, d0, d1 = n[:4]
        steps = int(n[4]) if len(n) > 4 else 12
        paths = [((cx - d0 / 2, cy), (cx - d1 / 2, cy)), ((cx + d0 / 2, cy), (cx + d1 / 2, cy))]
    elif cmd == "pan":
        x, y, dx, dy = n[:4]
        steps = int(n[4]) if len(n) > 4 else 12
        paths = [((x - 60, y), (x - 60 + dx, y + dy)), ((x + 60, y), (x + 60 + dx, y + dy))]
    elif cmd == "paths":
        steps = int(n[8]) if len(n) > 8 else 12
        paths = [((n[0], n[1]), (n[4], n[5])), ((n[2], n[3]), (n[6], n[7]))]
    else:
        print(__doc__)
        sys.exit(1)
    play(frames(paths, steps, screen_size()))


if __name__ == "__main__":
    main()
