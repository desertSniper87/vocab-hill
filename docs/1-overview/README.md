# Overview

Vocab Hill is a study tool for GregMat-style vocabulary learning.

## Current Product Shape

- The app presents vocabulary in numbered groups of 30 words arranged into a day board.
- Each day reveals all groups from `Group 1` through the selected day number, matching the vocab mountain style.
- Users can inspect a word's details and mark words as learned or forgotten for the currently selected day.
- Keyboard control supports arrows for movement, `d` for the study-info details view, `t` for the `Dictionary API` tab, `y` for `M-W Dictionary`, `u` for `M-W Thesaurus`, `g` for learned, and `r` for forgotten.
- The top header can export forgotten words as a comma-separated list using each word's latest recorded status across days.
- The details panel has a `Study Info` mode for local notes plus a top-level previous-day status badge, a free `Dictionary API` mode from `api.dictionaryapi.dev`, and separate `M-W Dictionary` and `M-W Thesaurus` modes backed by learner-supplied Merriam-Webster API keys.
- Reference text inside the details panel is selectable, and source URLs are rendered as clickable links for web use.
- Cells can also show a small right-side marker indicating the most recent earlier-day result for that same word.
- The current scaffold reads source data from `data/final.json`, persists learner progress locally on the device with day-scoped status entries, stores Merriam-Webster API keys in local SQLite settings, and can optionally sync progress through a small backend by using a shared sync key.

## Why The Repo Starts With Flutter

- The project goal already calls for a website now and a mobile app later.
- Flutter keeps that path inside one UI framework and one codebase from the beginning.
