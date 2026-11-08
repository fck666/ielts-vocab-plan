#!/usr/bin/env python3
"""Check vocabulary totals, schedule shape, deduplication, and source attribution."""

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDS = json.loads((ROOT / "data/words.json").read_text(encoding="utf-8"))
TARGET_COUNT = 6000
TARGET_WEEKS = 50


def normalise(term):
    return re.sub(r"[^a-z0-9]+", " ", term.casefold()).strip()


errors = []
if len(WORDS) != TARGET_COUNT:
    errors.append(f"Expected {TARGET_COUNT} words, found {len(WORDS)}.")

ids = [word["id"] for word in WORDS]
if len(ids) != len(set(ids)):
    errors.append("Word IDs are not unique.")

terms = [normalise(word["term"]) for word in WORDS]
duplicates = [term for term, count in Counter(terms).items() if count > 1]
if duplicates:
    errors.append("Normalized duplicate terms: " + ", ".join(duplicates[:20]))

by_week = defaultdict(list)
for word in WORDS:
    by_week[word["week"]].append(word)
if sorted(by_week) != list(range(1, TARGET_WEEKS + 1)):
    errors.append("Weeks must cover 1–50 without gaps.")

for week in range(1, TARGET_WEEKS + 1):
    entries = by_week.get(week, [])
    if len(entries) != 120:
        errors.append(f"Week {week}: expected 120 entries, found {len(entries)}.")
    by_day = defaultdict(list)
    for word in entries:
        by_day[word["day"]].append(word)
    expected_days = list(range((week - 1) * 7 + 1, (week - 1) * 7 + 7))
    if sorted(by_day) != expected_days:
        errors.append(f"Week {week}: learning-day numbering is incomplete or incorrect.")
    for day, day_entries in by_day.items():
        if len(day_entries) != 20:
            errors.append(f"Week {week}, day {day}: expected 20 entries, found {len(day_entries)}.")

for word in WORDS:
    required = ("term", "ipa", "partOfSpeech", "meaningZh", "exampleEn", "exampleZh", "note")
    for field in required:
        if not isinstance(word.get(field), str) or not word[field].strip():
            errors.append(f"{word.get('id', '?')}: missing {field}.")
            break
    if word["week"] <= 10:
        continue
    if not word.get("examTags") or not set(word["examTags"]).issubset({"IELTS", "CET-6", "TOEFL", "GRE"}):
        errors.append(f"{word['id']}: missing or invalid exam-list tags.")
    if word.get("collocationsSource") != "example":
        errors.append(f"{word['id']}: example snippets are not labeled as such.")
    if not word.get("exampleSource", "").startswith("Tatoeba sentence by "):
        errors.append(f"{word['id']}: missing Tatoeba contributor attribution.")
    if not word.get("exampleSourceUrl", "").startswith("https://tatoeba.org/en/sentences/show/"):
        errors.append(f"{word['id']}: missing Tatoeba sentence link.")
    if word.get("exampleLicenseUrl") != "https://creativecommons.org/licenses/by/2.0/":
        errors.append(f"{word['id']}: missing CC BY 2.0 link.")

if errors:
    raise SystemExit("\n".join(errors[:100]))

print("Vocabulary validation passed: 6,000 unique entries, 50 weeks, 300 learning days, 20 words per day, and attributed expansion examples.")
