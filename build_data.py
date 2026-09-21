"""Build a browser-friendly structured vocabulary dataset from the Markdown plans."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "data"
OUT.mkdir(exist_ok=True)

entry_re = re.compile(
    r"^\d+\. \*\*(?P<term>.+?)\*\* (?P<ipa>/[^/]+/) · \*(?P<pos>[^*]+)\* · (?P<meaning>.+)$"
)
day_re = re.compile(r"^## 第 (?P<day>\d+) 天 (?P<title>.+)$")

words: list[dict] = []
week_paths = sorted(
    ROOT.glob("week-*.md"),
    key=lambda path: int(re.search(r"week-(\d+)", path.name).group(1)),
)
for week_path in week_paths:
    week = int(re.search(r"week-(\d+)", week_path.name).group(1))
    day = None
    day_title = ""
    current = None
    for raw in week_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        day_match = day_re.match(line)
        if day_match:
            day = int(day_match.group("day"))
            day_title = day_match.group("title")
            continue
        entry_match = entry_re.match(line)
        if entry_match:
            if current:
                words.append(current)
            current = {
                "id": f"w{week}-d{day}-{len([x for x in words if x['week'] == week and x['day'] == day]) + 1:02d}",
                "week": week,
                "day": day,
                "dayTitle": day_title,
                "term": entry_match.group("term"),
                "ipa": entry_match.group("ipa"),
                "partOfSpeech": entry_match.group("pos"),
                "meaningZh": entry_match.group("meaning"),
                "collocations": [],
                "exampleEn": "",
                "exampleZh": "",
                "wordFamily": "",
                "note": "",
                "source": week_path.name,
            }
            continue
        if not current:
            continue
        for label, field in (
            ("搭配", "collocations"),
            ("例句", "exampleEn"),
            ("译文", "exampleZh"),
            ("词族", "wordFamily"),
            ("提醒", "note"),
        ):
            prefix = f"- **{label}**："
            if line.startswith(prefix):
                value = line[len(prefix):].strip().replace("`", "")
                if field == "collocations":
                    current[field] = [x.strip() for x in value.split(";") if x.strip()]
                else:
                    current[field] = value
                break
    if current:
        words.append(current)

for index, word in enumerate(words, 1):
    word["index"] = index
    # Useful for context questions: replace the target phrase when it occurs.
    masked = word["exampleEn"]
    pattern = re.compile(re.escape(word["term"]), re.IGNORECASE)
    word["maskedExample"] = pattern.sub("_____", masked, count=1)

words_path = OUT / "words.json"
words_path.write_text(json.dumps(words, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(OUT / "words.js").write_text(
    "window.IELTS_WORDS = " + json.dumps(words, ensure_ascii=False, separators=(",", ":")) + ";\n",
    encoding="utf-8",
)
print(f"Built {len(words)} entries")
