# Vocabulary Data Sources and Attribution

The vocabulary expansion in Weeks 11–50 uses the following sources. Definitions, translations, IPA, and example translations are draft study material and should be reviewed before publication as an authoritative dictionary.

- **ECDICT** provides candidate headwords, exam-list tags, dictionary definitions, Chinese meanings, and source phonetics. The upstream repository identifies its license as MIT: <https://github.com/skywind3000/ECDICT>. Candidate terms are filtered by exam tags, word-family deduplication, pronunciation availability, and frequency rank. The application does not bundle the downloaded ECDICT CSV.
- **CMU Pronouncing Dictionary** provides pronunciations converted to IPA when available. Copyright (C) 1993–2015 Carnegie Mellon University. Redistribution is permitted under its BSD-style license: <https://github.com/cmusphinx/cmudict/blob/master/COPYING>.
- **Tatoeba** supplies the English example sentences used in the expansion. Each sentence is attributed in the application to its contributor, linked to its Tatoeba sentence page, and labeled with the sentence dataset's CC BY 2.0 license: <https://tatoeba.org/en/downloads> and <https://creativecommons.org/licenses/by/2.0/>. Attribution should remain attached when sentences are copied or redistributed.
- **Princeton WordNet 3.0** is an optional example fallback in the generation script. WordNet 3.0 is copyright 2006 Princeton University and is distributed under its own permissive license, which includes the full copyright notice, disclaimer, and restriction on using Princeton's name in advertising: <https://wordnet.princeton.edu/license-and-commercial-use>.

The locally downloaded source archives and intermediate translation cache are kept under the ignored `mac/.build/` directory and are not part of the repository. The generated word records retain per-sentence attribution in `data/words.json` and display it alongside the example.
