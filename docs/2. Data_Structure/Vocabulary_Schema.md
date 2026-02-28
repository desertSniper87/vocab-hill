# Vocabulary Schema

This document defines the schema used in the JSON vocabulary files.

## Main Word Entry

Each word in the `words` array follows this structure:

| Field | Type | Description |
|-------|------|-------------|
| `group` | String | The group identifier (e.g., "Group 1"). |
| `word` | String | The vocabulary word itself. |
| `definition` | String | English definition of the word. |
| `bangla` | String | Bengali (Bangla) translation/meaning. |
| `mnemonic` | String/Null | A mnemonic aid for learning the word. |

## Examples

### With Mnemonic
From `gregmat-full-from-claude-batch-1-with-mnemonics.json`:
```json
{
  "group": "Group 2",
  "word": "adulterate",
  "definition": "To make a substance impure by adding inferior or harmful ingredients",
  "bangla": "মিশ্রিত করা, অখাঁটি করা, নিম্নমানের উপাদান যোগ করা",
  "mnemonic": "dull+the+rate = impure, means to decrease the rate"
}
```

### Basic Entry
From `claude-batch-1.json`:
```json
{
  "group": "Group 1",
  "word": "abound",
  "definition": "To exist or be present in large quantities; to be plentiful or numerous",
  "bangla": "প্রচুর পরিমাণে থাকা, অধিক সংখ্যায় বিস্তৃত থাকা"
}
```
