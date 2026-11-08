#!/usr/bin/env python3
"""Generate resumable, explicitly unreviewed language-pack drafts.

Only public vocabulary content is sent to the translation service. Existing
translations are preserved. Run offline validators before publishing any pack.
"""

import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
PACKS = ROOT / "data/language-packs"
CACHE = ROOT / "mac/.build/language-draft-cache.json"
LANGUAGES = ("ja", "ko", "fr", "es", "ar")
ENDPOINT = "https://clients5.google.com/translate_a/t"
ENGLISH = re.compile(r"[A-Za-z][A-Za-z0-9]*(?:[ -][A-Za-z0-9]+)*(?:['’][a-z]+)?")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def protect_english(value):
    terms = []

    def replace(match):
        terms.append(match.group())
        return "ZXQ" + str(len(terms) - 1) + "XQZ"

    return ENGLISH.sub(replace, value), terms


def restore_english(value, terms):
    for index, term in enumerate(terms):
        pattern = r"ZXQ\s*" + str(index) + r"\s*XQZ"
        value, count = re.subn(pattern, lambda _: term, value, flags=re.I)
        if count != 1:
            raise ValueError("Translation changed a protected English term: " + str(index))
    if re.search(r"ZXQ|XQZ", value, re.I):
        raise ValueError("Unresolved translation placeholder")
    return value.strip()


def cache_key(locale, source, value):
    return hashlib.sha256((locale + "\0" + source + "\0" + value).encode()).hexdigest()


def make_url(locale, source, values):
    params = [("client", "dict-chrome-ex"), ("sl", source), ("tl", locale)]
    params.extend(("q", value) for value in values)
    return ENDPOINT + "?" + urllib.parse.urlencode(params)


def batches(locale, source, values):
    batch = []
    for item in values:
        if batch and (len(make_url(locale, source, [entry[1] for entry in batch + [item]])) > 6800 or len(batch) >= 12):
            yield locale, source, batch
            batch = []
        batch.append(item)
    if batch:
        yield locale, source, batch


def translate(job, context):
    locale, source, batch = job
    request = urllib.request.Request(make_url(locale, source, [item[1] for item in batch]), headers={"User-Agent": "IELTS-Language-Pack-Draft/1.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=35, context=context) as response:
                result = json.load(response)
            if not isinstance(result, list) or len(result) != len(batch) or not all(isinstance(value, str) and value.strip() for value in result):
                raise ValueError("Translation response has an unexpected shape")
            return [(item[0], restore_english(value, item[2])) for item, value in zip(batch, result)]
        except (OSError, ValueError) as error:
            if isinstance(error, urllib.error.HTTPError) and error.code == 400 and len(batch) > 1:
                middle = len(batch) // 2
                return translate((locale, source, batch[:middle]), context) + translate((locale, source, batch[middle:]), context)
            if isinstance(error, urllib.error.HTTPError) and error.code == 400 and len(batch) == 1 and batch[0][2]:
                item = batch[0]
                raw_value = item[1]
                for index, term in enumerate(item[2]):
                    raw_value = re.sub(r"ZXQ\s*" + str(index) + r"\s*XQZ", lambda _: term, raw_value, flags=re.I)
                fallback = urllib.request.Request(make_url(locale, source, [raw_value]), headers={"User-Agent": "IELTS-Language-Pack-Draft/1.0"})
                try:
                    with urllib.request.urlopen(fallback, timeout=35, context=context) as response:
                        result = json.load(response)
                    if isinstance(result, list) and len(result) == 1 and isinstance(result[0], str) and result[0].strip():
                        return [(item[0], result[0].strip())]
                except (OSError, ValueError):
                    pass
            if attempt == 3:
                raise RuntimeError(locale + " / " + source + ": " + str(error)) from error
            time.sleep(min(2 ** attempt, 8))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--through-week", type=int, default=50, choices=range(1, 51))
    parser.add_argument("--workers", type=int, default=6, choices=range(1, 13))
    args = parser.parse_args()
    try:
        import certifi
        context = ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        context = ssl.create_default_context()
    words = read_json(ROOT / "data/words.json")
    manifest = read_json(PACKS / "manifest.json")
    packs = {locale: read_json(PACKS / (locale + ".json")) for locale in LANGUAGES}
    cache = read_json(CACHE) if CACHE.exists() else {}
    fields = [("dayTitle", "dayTitle", "zh-CN"), ("meaning", "meaningZh", "zh-CN"), ("exampleTranslation", "exampleEn", "en"), ("note", "note", "zh-CN")]
    pending = {}
    for locale in LANGUAGES:
        if next(item for item in manifest["locales"] if item["locale"] == locale)["status"] != "draft":
            raise ValueError("Refusing to overwrite a non-draft pack: " + locale)
        for word in words:
            if word["week"] > args.through_week or word["id"] in packs[locale]["words"]:
                continue
            for target, original, source in fields:
                value = word[original]
                key = cache_key(locale, source, value)
                if key not in cache:
                    masked, terms = protect_english(value) if source == "zh-CN" else (value, [])
                    pending.setdefault((locale, source), {})[key] = (key, masked, terms)
    jobs = [job for (locale, source), values in pending.items() for job in batches(locale, source, list(values.values()))]
    print("Draft generation: " + str(len(jobs)) + " translation batches, through Week " + str(args.through_week) + ".", flush=True)
    errors = []

    def save_completed():
        for locale in LANGUAGES:
            for word in words:
                if word["week"] > args.through_week or word["id"] in packs[locale]["words"]:
                    continue
                keys = [cache_key(locale, source, word[original]) for _, original, source in fields]
                if all(key in cache for key in keys):
                    entry = {field[0]: cache[key] for field, key in zip(fields, keys)}
                    entry["wordFamily"] = word["wordFamily"]
                    packs[locale]["words"][word["id"]] = entry
            # Keep stable source order even when concurrent batches finish out of order.
            packs[locale]["words"] = {word["id"]: packs[locale]["words"][word["id"]] for word in words if word["id"] in packs[locale]["words"]}
            write_json(PACKS / (locale + ".json"), packs[locale])
        write_json(CACHE, cache)

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(translate, job, context): job for job in jobs}
            for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
                try:
                    cache.update(future.result())
                except Exception as error:
                    errors.append(str(error))
                    failed_values = [item[1] for item in futures[future][2]]
                    print("Batch pending retry: " + str(error) + " | source=" + repr(failed_values), flush=True)
                if index % 20 == 0 or index == len(jobs):
                    save_completed()
                    print(str(index) + "/" + str(len(jobs)) + " batches; entries " + ", ".join(locale + "=" + str(len(packs[locale]["words"])) for locale in LANGUAGES), flush=True)
    finally:
        save_completed()
    if errors:
        print(str(len(errors)) + " batches still need retry. Run this command again to resume.", flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
