"""Build the browser seed database from the canonical JSON vocabulary data."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "data" / "words.json"
TARGET = ROOT / "data" / "ielts-vocab.sqlite"


SCHEMA = """
PRAGMA foreign_keys = ON;
CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE words (
  id TEXT PRIMARY KEY,
  week INTEGER NOT NULL,
  day INTEGER NOT NULL,
  day_title TEXT NOT NULL,
  term TEXT NOT NULL,
  ipa TEXT NOT NULL,
  part_of_speech TEXT NOT NULL,
  meaning_zh TEXT NOT NULL,
  collocations_json TEXT NOT NULL,
  example_en TEXT NOT NULL,
  example_zh TEXT NOT NULL,
  word_family TEXT NOT NULL,
  note TEXT NOT NULL
);
CREATE TABLE word_progress (
  word_id TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL DEFAULT 0,
  correct INTEGER NOT NULL DEFAULT 0,
  wrong INTEGER NOT NULL DEFAULT 0,
  streak INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 0,
  last_reviewed_at TEXT,
  next_review_at TEXT,
  history_json TEXT NOT NULL DEFAULT '[]',
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
);
CREATE TABLE exams (
  id TEXT PRIMARY KEY,
  score INTEGER NOT NULL,
  total INTEGER NOT NULL,
  correct INTEGER NOT NULL,
  results_json TEXT NOT NULL,
  config_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE practice_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mode TEXT NOT NULL,
  prompt TEXT NOT NULL,
  response TEXT NOT NULL,
  rating INTEGER NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX idx_word_progress_next_review ON word_progress(next_review_at);
CREATE INDEX idx_exams_created_at ON exams(created_at);
CREATE INDEX idx_practice_created_at ON practice_records(created_at);
"""


def main() -> None:
    words = json.loads(SOURCE.read_text(encoding="utf-8"))
    TARGET.unlink(missing_ok=True)
    with sqlite3.connect(TARGET) as connection:
        connection.executescript(SCHEMA)
        connection.executemany(
            """
            INSERT INTO words (
              id, week, day, day_title, term, ipa, part_of_speech, meaning_zh,
              collocations_json, example_en, example_zh, word_family, note
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    word["id"],
                    word["week"],
                    word["day"],
                    word["dayTitle"],
                    word["term"],
                    word["ipa"],
                    word["partOfSpeech"],
                    word["meaningZh"],
                    json.dumps(word.get("collocations", []), ensure_ascii=False),
                    word["exampleEn"],
                    word["exampleZh"],
                    word.get("wordFamily", ""),
                    word.get("note", ""),
                )
                for word in words
            ],
        )
        connection.executemany(
            "INSERT INTO metadata (key, value) VALUES (?, ?)",
            [("schema_version", "1"), ("word_count", str(len(words)))],
        )
        connection.commit()
    print(f"Built {TARGET} with {len(words)} words")


if __name__ == "__main__":
    main()
