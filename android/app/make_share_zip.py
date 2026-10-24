#!/usr/bin/env python3
"""Pack OpenSCAD's resource folders (what `make install` puts in share/openscad) into one zip asset.

usage: make_share_zip.py <openscad-src> <fonts.conf> <out.zip> <dir>...

The app unpacks it to <files>/openscad/share/openscad on first start, and again whenever `.stamp` (a hash of the
contents) changes. fonts.conf goes to fonts/, where OpenSCAD's FontCache picks it up.
"""
import ast
import hashlib
import os
import struct
import sys
import zipfile

SKIP_DIRS = {".git", ".github", "__pycache__"}
SKIP_FILES = {".uuid", ".gitignore", ".gitmodules", ".git"}


def parse_po(path):
    """{msgid: msgstr} of a .po file (msgctxt as "ctxt\\x04id", plurals joined by NUL), skipping fuzzy entries."""
    entries = {}
    cur, key = {}, None
    cur_fuzzy = next_fuzzy = False

    def has_msgstr():
        return any(k == "msgstr" or k.startswith("msgstr[") for k in cur)

    def flush():
        nonlocal cur, cur_fuzzy
        if "msgid" in cur and not cur_fuzzy:
            mid = cur["msgid"]
            if "msgid_plural" in cur:
                mid += "\0" + cur["msgid_plural"]
                text = "\0".join(cur[k] for k in sorted((k for k in cur if k.startswith("msgstr[")),
                                                        key=lambda k: int(k[7:-1])))
            else:
                text = cur.get("msgstr", "")
            if "msgctxt" in cur:
                mid = cur["msgctxt"] + "\x04" + mid
            if text.replace("\0", "") or mid == "":
                entries[mid] = text
        cur, cur_fuzzy = {}, False

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("#,"):
                if has_msgstr():
                    flush()
                next_fuzzy = "fuzzy" in line
            elif line.startswith("#") or not line:
                continue
            elif line.startswith('"'):
                cur[key] += ast.literal_eval(line)
            else:
                k, _, v = line.partition(" ")
                if k in ("msgid", "msgctxt") and has_msgstr():
                    flush()
                if not cur:  # first keyword of a new entry
                    cur_fuzzy, next_fuzzy = next_fuzzy, False
                key = k
                cur[key] = ast.literal_eval(v)
    flush()
    return entries


def mo_bytes(entries):
    """GNU .mo catalog, as Python's Tools/i18n/msgfmt.py writes it."""
    keys = sorted(entries)
    ids = strs = b""
    offsets = []
    for k in keys:
        kb, vb = k.encode(), entries[k].encode()
        offsets.append((len(ids), len(kb), len(strs), len(vb)))
        ids += kb + b"\0"
        strs += vb + b"\0"
    n = len(keys)
    keystart = 7 * 4 + 16 * n
    valuestart = keystart + len(ids)
    koffsets, voffsets = [], []
    for o1, l1, o2, l2 in offsets:
        koffsets += [l1, o1 + keystart]
        voffsets += [l2, o2 + valuestart]
    return (struct.pack("Iiiiiii", 0x950412DE, 0, n, 7 * 4, 7 * 4 + n * 8, 0, 0)
            + struct.pack(f"{len(koffsets)}i", *koffsets) + struct.pack(f"{len(voffsets)}i", *voffsets) + ids + strs)


def files(src, top):
    for root, dirs, names in os.walk(os.path.join(src, top)):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for n in sorted(names):
            if n not in SKIP_FILES:
                yield os.path.join(root, n)


def main():
    src, fonts_conf, out, dirs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    entries = []
    generated = {}
    for d in dirs:
        if d == "locale":  # compile the catalogs, as `make install` does with msgfmt
            for po in sorted(os.listdir(os.path.join(src, "locale"))):
                if po.endswith(".po"):
                    arc = f"locale/{po[:-3]}/LC_MESSAGES/openscad.mo"
                    generated[arc] = mo_bytes(parse_po(os.path.join(src, "locale", po)))
                    entries.append((arc, None))
            continue
        for f in files(src, d):
            entries.append((os.path.relpath(f, src), f))
    entries.append(("fonts/fonts.conf", fonts_conf))
    entries.sort()
    h = hashlib.sha1()
    def data(arc, f):
        if f is None:
            return generated[arc]
        with open(f, "rb") as fh:
            return fh.read()

    for arc, f in entries:
        h.update(arc.encode())
        h.update(data(arc, f))
    tmp = out + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for arc, f in entries:
            z.writestr(arc, data(arc, f))
        z.writestr(".stamp", h.hexdigest())
    os.replace(tmp, out)
    print(f"{out}: {len(entries)} files, stamp {h.hexdigest()[:12]}")


if __name__ == "__main__":
    main()
