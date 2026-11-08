#!/usr/bin/env python3
"""Expand the locale review table to every scheduled learning day."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
CHECKLIST = ROOT / "docs/language-pack-review.md"
LOCALES = ("ja", "ko", "fr", "es", "ar")
text = CHECKLIST.read_text(encoding="utf-8")

existing = {}
row_pattern = re.compile(r"^\| W(?P<week>\d+) D(?P<day>\d+) \| `w(?P<id_week>\d+)-d(?P<id_day>\d+)-01`–`w\d+-d\d+-20` \| (?P<checks>.*) \|$")
for line in text.splitlines():
    match = row_pattern.match(line)
    if not match:
        continue
    key = (int(match.group("week")), int(match.group("day")))
    existing[key] = dict(zip(LOCALES, re.findall(r"\[(x| )\]", match.group("checks"))))

rows = [
    "| Batch | Word IDs | ja | ko | fr | es | ar |",
    "| --- | --- | --- | --- | --- | --- | --- |",
]
for week in range(1, 51):
    for offset in range(1, 7):
        day = (week - 1) * 7 + offset
        checks = existing.get((week, day), {locale: " " for locale in LOCALES})
        cells = " | ".join("[" + checks[locale] + "]" for locale in LOCALES)
        rows.append(f"| W{week} D{day} | `w{week}-d{day}-01`–`w{week}-d{day}-20` | {cells} |")

table_pattern = re.compile(r"\| Batch \| Word IDs \| ja \| ko \| fr \| es \| ar \|.*?(?=\n\n\| Interface review)", re.S)
updated, count = table_pattern.subn("\n".join(rows), text, count=1)
if count != 1:
    raise SystemExit("Could not locate the vocabulary review table.")
CHECKLIST.write_text(updated, encoding="utf-8")
print(f"Expanded locale review checklist to {len(rows) - 2} study-day batches.")
