# HSK catalog sources

Bundled files cover **HSK 3.0 levels 1–6 only** (levels 7–9 are omitted).

## Official syllabus

Center for Language Education and Cooperation, *新版HSK考试大纲* (2025): vocabulary lists and 语法大纲.

## Vocabulary (`hsk-vocabulary.json`)

- Membership and level: exclusive per-level word lists from [krmanik/HSK-3.0](https://github.com/krmanik/HSK-3.0) (`New HSK (2025)/HSK Words/HSK_Level_{1–6}_words.txt`). Word lists in that project are CC BY-SA 4.0.
- Pinyin: [drkameleon/complete-hsk-vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary) (MIT). English/CC-CEDICT glosses are **not** bundled.
- Sense numbers on official rows (e.g. `点1`) are stripped. Duplicate hanzi keep the **lowest** level.

## Grammar (`hsk-grammar.json`)

Flattened from [krmanik/HSK-3.0](https://github.com/krmanik/HSK-3.0) `New HSK (2025)/HSK Grammar/json/HSK {1–6}.json`, itself an extract of the official 语法大纲. Each official row is one grammar point. `matchTokens` are Chinese leaves/patterns used to recognize user flashcards. Chinese Grammar Wiki content is not included.
