#!/usr/bin/env python3
"""Build Resources/zh.txt (reading<TAB>text<TAB>score) and Resources/en.txt from vendor data."""
import math, os, collections
V = os.path.join(os.path.dirname(__file__), "..", "vendor")
R = os.path.join(os.path.dirname(__file__), "..", "Resources")

occ = {}
for line in open(os.path.join(V, "phrase.occ"), encoding="utf-8"):
    p = line.split()
    if len(p) == 2 and p[1].isdigit():
        occ[p[0]] = int(p[1])

het = {}
for i, w in ((1, 1.0), (2, 0.1), (3, 0.01)):
    for line in open(os.path.join(V, f"heterophony{i}.list"), encoding="utf-8"):
        p = line.split()
        if len(p) >= 2:
            het[(p[0], p[1])] = w
het_chars = {c for c, _ in het}

entries = collections.defaultdict(float)   # (reading, text) -> count
char_readings = collections.defaultdict(list)
for line in open(os.path.join(V, "BPMFBase.txt"), encoding="utf-8"):
    p = line.split()
    if len(p) >= 2 and not line.startswith("#"):
        if p[1] not in char_readings[p[0]]:
            char_readings[p[0]].append(p[1])
for ch, rs in char_readings.items():
    if len(ch) != 1 or ch == rs[0] or "ㄅ" <= ch <= "ㄩ":
        continue   # skip bopomofo symbols themselves
    c = occ.get(ch, 0)
    for r in rs:
        if len(rs) == 1:
            w = 1.0
        elif ch in het_chars:
            w = het.get((ch, r), 0.001)
        else:
            w = 1.0 if r == rs[0] else 0.05
        entries[(r, ch)] = max(entries[(r, ch)], c * w + 0.2)

for line in open(os.path.join(V, "BPMFMappings.txt"), encoding="utf-8"):
    p = line.split()
    if len(p) >= 3 and len(p[0]) == len(p) - 1:
        key = ("-".join(p[1:]), p[0])
        entries[key] = max(entries[key], occ.get(p[0], 0) + 0.5)

total = sum(entries.values())
with open(os.path.join(R, "zh.txt"), "w", encoding="utf-8") as f:
    for (r, t), c in sorted(entries.items()):
        f.write(f"{r}\t{t}\t{math.log10(c / total):.4f}\n")

n = 0
with open(os.path.join(R, "en.txt"), "w", encoding="utf-8") as f:
    for line in open(os.path.join(V, "en_50k.txt"), encoding="utf-8"):
        w = line.split()[0]
        if w.isascii() and w.isalpha() and (len(w) > 1 or w in "ai"):
            f.write(w + "\n"); n += 1
            if n >= 30000: break
print(len(entries), "zh entries;", n, "en words")
