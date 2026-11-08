#!/usr/bin/env python3
"""Append 4,800 exam-tagged, deduplicated words and examples to the 1,200-word plan."""

import bz2
import concurrent.futures
import csv
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
SOURCE_DIR = ROOT / "mac/.build/word-sources"
OUTPUT_DIR = ROOT / "mac/.build/vocabulary-expansion"
CACHE_PATH = ROOT / "mac/.build/vocabulary-translation-cache.json"
SOURCE_WORDS = ROOT / "data/words.json"
TARGET_COUNT = 6000
ADD_COUNT = TARGET_COUNT - 1200
MIN_FREQUENCY_RANK = 3000
EXAM_TAGS = {"ielts", "cet6", "toefl", "gre"}
EXAM_LABELS = {"ielts": "IELTS", "cet6": "CET-6", "toefl": "TOEFL", "gre": "GRE"}
TOKEN_RE = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")
BAD_EXAMPLE_RE = re.compile(r"\b(?:fuck|shit|bitch|cunt|nigger|retard)\b", re.I)
POS_RE = re.compile(r"^(vt|vi|adj|adv|pron|prep|conj|n|v|a|s|r)\.\s*(.*)$", re.I)
TRANSLATE_URL = "https://clients5.google.com/translate_a/t"
STOP_WORDS = set("a an the to of in on at by for from with without and or but as is are was were be been being it this that these those their his her our your my you i we they he she can could may might will would should has have had do does did".split())


def unescape_dictionary_text(value):
    return value.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\r", "\n").strip()


def normalise_term(value):
    return re.sub(r"[^a-z0-9]+", " ", value.casefold()).strip()


def read_lemma_map(path):
    forms = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith(";") or " -> " not in line:
            continue
        head, raw_forms = line.split(" -> ", 1)
        lemma = head.split("/", 1)[0].strip().lower()
        forms[lemma] = lemma
        for form in raw_forms.split(","):
            form = form.strip().lower()
            if form:
                forms[form] = lemma
    return forms


def read_cmu_pronunciations(path):
    pronunciations = {}
    for line in path.read_text(encoding="ascii", errors="ignore").splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        word = re.sub(r"\(\d+\)$", "", parts[0]).lower()
        pronunciations.setdefault(word, parts[1:])
    return pronunciations


def cmu_to_ipa(phonemes):
    symbols = {
        "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ",
        "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "EH": "ɛ", "ER": "ɚ", "EY": "eɪ",
        "F": "f", "G": "ɡ", "HH": "h", "IH": "ɪ", "IY": "i", "JH": "dʒ", "K": "k",
        "L": "l", "M": "m", "N": "n", "NG": "ŋ", "OW": "oʊ", "OY": "ɔɪ", "P": "p",
        "R": "ɹ", "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "UH": "ʊ", "UW": "u",
        "V": "v", "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
    }
    vowel_symbols = {"AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW"}
    parsed = []
    syllables = sum(1 for phoneme in phonemes if re.sub(r"\d+$", "", phoneme) in vowel_symbols)
    for phoneme in phonemes:
        stress = phoneme[-1] if phoneme[-1:].isdigit() else "0"
        symbol = phoneme[:-1] if phoneme[-1:].isdigit() else phoneme
        mapped = symbols.get(symbol)
        if mapped is None:
            continue
        if symbol == "AH" and stress == "0":
            mapped = "ə"
        parsed.append((mapped, stress if symbol in vowel_symbols else "", symbol in vowel_symbols))
    output = []
    previous_vowel = -1
    for mapped, stress, is_vowel in parsed:
        if is_vowel and syllables > 1 and stress in {"1", "2"}:
            output.insert(previous_vowel + 1, "ˈ" if stress == "1" else "ˌ")
            previous_vowel += 1
        output.append(mapped)
        if is_vowel:
            previous_vowel = len(output) - 1
    return "/" + "".join(output) + "/" if output else ""


def clean_ipa(value, cmu):
    converted = cmu_to_ipa(cmu) if cmu else ""
    if converted:
        return converted
    raw = value.strip()
    if raw:
        raw = raw.replace("ә", "ə").replace(":", "ː").replace("'", "ˈ")
        raw = raw.replace(".", "").replace(" ", "")
        raw = raw.strip("/[]")
        if raw:
            return "/" + raw + "/"
    return ""


def first_gloss(raw_definition):
    for line in unescape_dictionary_text(raw_definition).splitlines():
        match = POS_RE.match(line.strip())
        if match and match.group(2).strip():
            return match.group(2).strip().strip('"')
    return ""


def dictionary_pos(raw_definition):
    labels = []
    mapping = {"n": "n.", "v": "v.", "vt": "v.", "vi": "v.", "a": "adj.", "s": "adj.", "adj": "adj.", "r": "adv.", "adv": "adv.", "pron": "pron.", "prep": "prep.", "conj": "conj."}
    for line in unescape_dictionary_text(raw_definition).splitlines():
        match = POS_RE.match(line.strip())
        if not match:
            continue
        label = mapping.get(match.group(1).lower())
        if label and label not in labels:
            labels.append(label)
    return "/".join(labels[:3]) or "n."


def chinese_meaning(raw_translation, pos):
    lines = [line.strip() for line in unescape_dictionary_text(raw_translation).splitlines() if line.strip()]
    desired = set(pos.split("/"))
    selected = []
    for line in lines:
        match = POS_RE.match(line)
        if match:
            code = match.group(1).lower()
            label = {"n": "n.", "v": "v.", "vt": "v.", "vi": "v.", "a": "adj.", "s": "adj.", "adj": "adj.", "r": "adv.", "adv": "adv."}.get(code)
            if label not in desired:
                continue
            line = match.group(2)
        line = re.sub(r"\[[^\]]{1,12}\]", "", line).strip(" ,;，；")
        if line and re.search(r"[\u3400-\u9fff]", line):
            selected.append(line)
        if len(selected) == 2:
            break
    if not selected:
        selected = [re.sub(r"\[[^\]]{1,12}\]", "", line).strip(" ,;，；") for line in lines if re.search(r"[\u3400-\u9fff]", line)][:2]
    meaning = "；".join(selected).strip()
    return meaning[:110]


def word_family(exchange):
    labels = {"s": "plural", "p": "past", "d": "past participle", "i": "-ing", "3": "third-person singular", "r": "comparative", "t": "superlative"}
    parts = []
    for item in exchange.split("/"):
        code, separator, form = item.partition(":")
        label = labels.get(code.strip())
        form = form.strip()
        if separator and label and form and form.lower() != "unknown":
            parts.append(label + ": " + form)
    return "; ".join(parts[:5]) or "该词没有常见词形记录。"


def candidate_rows(path, words, lemmas, pronunciations):
    existing = {normalise_term(word["term"]) for word in words}
    existing_lemmas = {lemmas.get(word["term"].lower(), word["term"].lower()) for word in words if re.fullmatch(r"[a-z]+", word["term"].lower())}
    by_lemma = {}
    with path.open(encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            term = row["word"].strip()
            tags = set(row["tag"].lower().split())
            if not re.fullmatch(r"[a-z]{3,}", term) or not tags.intersection(EXAM_TAGS):
                continue
            if normalise_term(term) in existing or not row["translation"].strip() or not first_gloss(row["definition"]):
                continue
            frq = int(row["frq"]) if row["frq"].isdigit() else 0
            bnc = int(row["bnc"]) if row["bnc"].isdigit() else 0
            known_ranks = [rank for rank in (frq, bnc) if rank > 0]
            frequency = min(known_ranks) if known_ranks else 999999
            if known_ranks and frequency <= MIN_FREQUENCY_RANK:
                continue
            lemma = lemmas.get(term, term)
            if lemma in existing_lemmas:
                continue
            ipa = clean_ipa(row["phonetic"], pronunciations.get(term))
            if not ipa:
                continue
            rank = (
                0 if "ielts" in tags else 1,
                0 if "cet6" in tags else 1,
                0 if "toefl" in tags else 1,
                0 if "gre" in tags else 1,
                frequency,
                -int(row["collins"] or 0),
                term,
            )
            value = {"row": row, "term": term, "lemma": lemma, "ipa": ipa, "pos": dictionary_pos(row["definition"]), "meaning": chinese_meaning(row["translation"], dictionary_pos(row["definition"])), "gloss": first_gloss(row["definition"]), "rank": rank}
            value["examTags"] = [EXAM_LABELS[tag] for tag in ("ielts", "cet6", "toefl", "gre") if tag in tags]
            if not value["meaning"]:
                continue
            previous = by_lemma.get(lemma)
            if previous is None or rank < previous["rank"]:
                by_lemma[lemma] = value
    return sorted(by_lemma.values(), key=lambda item: item["rank"])


def sample_score(text, tokens):
    lowered = text.lower()
    first_person = bool(re.search(r"\b(?:i|we|you|my|our|your|he|she|they)\b", lowered))
    fragment = text.rstrip()[-1:] not in ".?!"
    first_letter = bool(tokens and tokens[0][0].isupper())
    return (int(first_person), int(fragment), int(text.rstrip().endswith("?")), abs(len(tokens) - 14), int(first_letter), len(text))


def read_tatoeba(path, terms):
    best = {}
    with bz2.open(path, "rt", encoding="utf-8") as source:
        for line in source:
            row = line.rstrip("\n").split("\t")
            if len(row) < 4:
                continue
            sentence_id, _, text, author = row[:4]
            if not author or author == r"\N" or BAD_EXAMPLE_RE.search(text):
                continue
            tokens = TOKEN_RE.findall(text)
            if not 8 <= len(tokens) <= 22:
                continue
            for term in set(token.lower() for token in tokens).intersection(terms):
                score = sample_score(text, tokens)
                if term not in best or score < best[term][0]:
                    best[term] = (score, text, "tatoeba:" + sentence_id + ":" + author)
    return best


def read_wordnet_examples(root, terms):
    best = {}
    token_terms = set(terms)
    for filename in ("data.noun", "data.verb", "data.adj", "data.adv"):
        path = root / filename
        if not path.exists():
            continue
        with path.open(encoding="utf-8") as source:
            for line in source:
                if line.startswith(" ") or "|" not in line:
                    continue
                synset = line.split(None, 1)[0]
                gloss = line.split("|", 1)[1]
                for example in re.findall(r'"([^"\n]+)"', gloss):
                    tokens = TOKEN_RE.findall(example)
                    if not 6 <= len(tokens) <= 24 or BAD_EXAMPLE_RE.search(example):
                        continue
                    score = sample_score(example, tokens)
                    for term in set(token.lower() for token in tokens).intersection(token_terms):
                        if term not in best or score < best[term][0]:
                            best[term] = (score, example, "wordnet:" + synset)
    return best


def collocations(sentence, term):
    tokens = [token.lower() for token in TOKEN_RE.findall(sentence)]
    positions = [index for index, token in enumerate(tokens) if token == term]
    choices = []
    for index in positions:
        for width in (3, 4, 2):
            for start in range(max(0, index - width + 1), min(index + 1, len(tokens) - width + 1)):
                phrase = tokens[start:start + width]
                if term not in phrase:
                    continue
                if phrase[0] in STOP_WORDS or phrase[-1] in STOP_WORDS:
                    continue
                content = sum(token not in STOP_WORDS for token in phrase)
                if content >= 2:
                    choices.append((abs(width - 3), -content, phrase))
    result = []
    for _, _, phrase in sorted(choices):
        value = " ".join(phrase)
        if value not in result:
            result.append(value)
        if len(result) == 3:
            break
    return result


def translate_batch(locale, source_locale, batch):
    params = [("client", "dict-chrome-ex"), ("sl", source_locale), ("tl", locale)]
    params.extend(("q", value) for value in batch)
    request = urllib.request.Request(TRANSLATE_URL + "?" + urllib.parse.urlencode(params), headers={"User-Agent": "IELTS-Vocabulary-Lab/1.0"})
    context = getattr(translate_batch, "ssl_context", None)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=35, context=context) as response:
                output = json.load(response)
            if not isinstance(output, list) or len(output) != len(batch) or not all(isinstance(item, str) and item.strip() for item in output):
                raise ValueError("Unexpected translation response")
            return output
        except (OSError, ValueError) as error:
            if isinstance(error, urllib.error.HTTPError) and error.code == 400 and len(batch) > 1:
                middle = len(batch) // 2
                return translate_batch(locale, source_locale, batch[:middle]) + translate_batch(locale, source_locale, batch[middle:])
            if attempt == 3:
                raise RuntimeError("Translation batch failed: " + str(error)) from error
            time.sleep(min(2 ** attempt, 8))


def batches(items, locale, source_locale):
    batch = []
    for item in items:
        params = [("client", "dict-chrome-ex"), ("sl", source_locale), ("tl", locale)] + [("q", value) for value in batch + [item]]
        if batch and (len(urllib.parse.urlencode(params)) > 6500 or len(batch) >= 32):
            yield batch
            batch = []
        batch.append(item)
    if batch:
        yield batch


def sha(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def translate_chinese_fields(words):
    try:
        import certifi
        translate_batch.ssl_context = ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        translate_batch.ssl_context = ssl.create_default_context()
    cache = json.loads(CACHE_PATH.read_text(encoding="utf-8")) if CACHE_PATH.exists() else {}
    source_values = {}
    for word in words:
        source_values.setdefault(word["gloss"], None)
        source_values.setdefault(word["exampleEn"], None)
    pending = [value for value in source_values if sha("en\0zh-CN\0" + value) not in cache]
    jobs = list(batches(pending, "zh-CN", "en"))
    print("Translating " + str(len(pending)) + " unique English glosses and examples to Chinese in " + str(len(jobs)) + " batches.", flush=True)

    def save():
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        temporary = CACHE_PATH.with_suffix(".tmp")
        temporary.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
        temporary.replace(CACHE_PATH)

    errors = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(translate_batch, "zh-CN", "en", batch): batch for batch in jobs}
        for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
            batch = futures[future]
            try:
                translated = future.result()
                cache.update({sha("en\0zh-CN\0" + source): target for source, target in zip(batch, translated)})
            except Exception as error:
                errors.append(str(error))
                print("Translation batch pending retry: " + str(error), flush=True)
            if index % 25 == 0 or index == len(jobs):
                save()
                print(str(index) + "/" + str(len(jobs)) + " batches complete.", flush=True)
    save()
    if errors:
        raise RuntimeError(str(len(errors)) + " translation batches failed; rerun to resume from cache.")
    for word in words:
        word["note"] = "词典义项：" + cache[sha("en\0zh-CN\0" + word.pop("gloss"))]
        word["exampleZh"] = cache[sha("en\0zh-CN\0" + word["exampleEn"])]


def markdown_entry(number, word):
    collocations_text = "; ".join(word["collocations"])
    source_line = ""
    if word["exampleSource"].startswith("tatoeba:"):
        _, sentence_id, author = word["exampleSource"].split(":", 2)
        source_line = f"   - **例句来源**：Tatoeba sentence {sentence_id} by {author} · CC BY 2.0\n"
    elif word["exampleSource"].startswith("wordnet:"):
        source_line = "   - **例句来源**：Princeton WordNet 3.0 · " + word["exampleSource"].split(":", 1)[1] + "\n"
    return (
        f"{number}. **{word['term']}** {word['ipa']} · *{word['partOfSpeech']}* · {word['meaningZh']}\n"
        f"   - **例句片段**：{collocations_text or '暂无合适片段'}\n"
        f"   - **考试词表**：{' · '.join(word['examTags'])}\n"
        f"   - **例句**：{word['exampleEn']}\n"
        f"   - **译文**：{word['exampleZh']}\n"
        f"   - **词族**：{word['wordFamily']}\n"
        f"   - **提醒**：{word['note']}\n"
        f"{source_line}"
    )


def main():
    required = [SOURCE_DIR / name for name in ("ecdict.csv", "lemma.en.txt", "cmudict.dict", "eng_sentences_detailed.tsv.bz2")]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("Missing vocabulary source files:\n" + "\n".join(missing) + "\nSee data/THIRD-PARTY-NOTICES.md for source links.")
    if OUTPUT_DIR == ROOT and any((ROOT / ("week-" + str(week) + ".md")).exists() for week in range(11, 51)):
        raise SystemExit("A Week 11-50 Markdown file already exists; refusing to overwrite existing vocabulary.")

    words = [word for word in json.loads(SOURCE_WORDS.read_text(encoding="utf-8")) if word["week"] <= 10]
    lemmas = read_lemma_map(SOURCE_DIR / "lemma.en.txt")
    pronunciations = read_cmu_pronunciations(SOURCE_DIR / "cmudict.dict")
    candidates = candidate_rows(SOURCE_DIR / "ecdict.csv", words, lemmas, pronunciations)
    print("Prepared " + str(len(candidates)) + " deduplicated exam-tagged candidates.", flush=True)
    terms = {word["term"] for word in candidates}
    tatoeba = read_tatoeba(SOURCE_DIR / "eng_sentences_detailed.tsv.bz2", terms)
    wordnet = read_wordnet_examples(SOURCE_DIR / "wordnet/wordnet", terms)
    chosen = []
    for item in candidates:
        example = tatoeba.get(item["term"]) or wordnet.get(item["term"])
        if not example:
            continue
        source_row = item.pop("row")
        sentence, example_source = example[1], example[2]
        item.update({
            "week": 11 + len(chosen) // 120,
            "day": 71 + len(chosen) // 20,
            "dayTitle": "IELTS 词汇拓展",
            "collocations": collocations(sentence, item["term"]),
            "exampleEn": sentence,
            "exampleSource": example_source,
            "meaningZh": item.pop("meaning"),
            "partOfSpeech": item.pop("pos"),
            "wordFamily": word_family(source_row["exchange"]),
            "note": "",
        })
        chosen.append(item)
        if len(chosen) == ADD_COUNT:
            break
    if len(chosen) != ADD_COUNT:
        raise SystemExit("Only found " + str(len(chosen)) + " entries with source examples and pronunciations; expected " + str(ADD_COUNT) + ".")

    translate_chinese_fields(chosen)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for offset in range(0, len(chosen), 120):
        week = 11 + offset // 120
        start_day = (week - 1) * 7 + 1
        lines = [f"# 第 {week} 周 雅思词汇拓展\n", "\n每天 20 个新词，每周第 7 天用于复习；本周词汇优先取自 ECDICT 的 IELTS、CET6、TOEFL 和 GRE 标注，并筛除词频排名 3,000 以内的基础高频项。例句选自 Tatoeba 或 Princeton WordNet，英文释义和例句译文为机器翻译初稿。例句片段由例句自动截取，仅作语境参考，不等同于经校对的固定搭配。\n"]
        week_words = chosen[offset:offset + 120]
        for day_offset in range(6):
            day = start_day + day_offset
            lines.append(f"\n## 第 {day} 天 IELTS 词汇拓展\n")
            day_words = week_words[day_offset * 20:(day_offset + 1) * 20]
            for number, word in enumerate(day_words, 1):
                lines.append(markdown_entry(number, word))
        (OUTPUT_DIR / ("week-" + str(week) + ".md")).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Prepared " + str(len(chosen)) + " new entries in " + str(TARGET_COUNT) + " total; translated word notes and Chinese example meanings.", flush=True)
    print("Generated Markdown is in " + str(OUTPUT_DIR) + "; review it before running scripts/build_data.py.", flush=True)


if __name__ == "__main__":
    main()
