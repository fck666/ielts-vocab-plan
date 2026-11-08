# Language Packs

The app keeps the English IELTS vocabulary and learner progress separate from translated explanations. Word IDs remain stable across packs. IPA belongs to the English entry and is not translated; the selected pack supplies localized topic labels, meanings, example translations, notes, word-family explanations, and interface text.

Supported locale targets are Simplified Chinese (zh-CN), Japanese (ja), Korean (ko), French (fr), Spanish (es), and Arabic (ar). Arabic uses right-to-left page direction while English words, IPA, examples, and collocations stay left-to-right.

The pack format is defined by data/language-pack.schema.json. Pack readiness is recorded in data/language-packs/manifest.json. A locale is not ready for selection until every source word has all required fields, its interface strings have been translated, and the vocabulary has been reviewed. Partial translations must not silently fall back to Chinese.

The existing Chinese word data is the source of truth for the initial zh-CN pack. Run node scripts/sync-source-language-pack.mjs after changing Chinese source translations, then run node scripts/build-language-pack-assets.mjs and node scripts/validate-language-packs.mjs.

Japanese, Korean, French, Spanish, and Arabic each have draft entries for all 6,000 word IDs. The first pass used Google Translate's public web translation endpoint: Chinese topics, meanings, and notes were translated from Simplified Chinese; English example sentences were translated from English. English vocabulary terms inside Chinese text are protected from translation when the endpoint accepts the protected phrase. Word-family spellings and English part-of-speech abbreviations are intentionally shared across packs. This draft generation is not a claim of native-speaker or exam-quality review. The generator resumes from a local ignored cache at `mac/.build/language-draft-cache.json` and can be rerun with `python3 scripts/draft-language-packs.py --through-week 50`.

Every translated sentence and meaning needs review before release. Review should proceed in small, tracked word-ID batches per locale. The source dataset also contains template-like English examples in Weeks 4-10, so those examples need correction in the source vocabulary before relying on their translations. User-interface labels, messages, and training instructions have not been localized. All five packs therefore remain drafts, are excluded from locale selection, and must stay that way until vocabulary and UI review are complete.

The pack files are static resources bundled with the Mac app. No language-pack server or database service is required. Language is a single global learning preference, not a multi-profile feature. There is no requirement to merge or synchronize progress between language choices; a later language change can begin a fresh learning record.
