# Overview

Vocab Hill is a study tool for GregMat-style vocabulary learning.

## Current Product Shape

- The app presents vocabulary in numbered groups of 30 words arranged into a day board.
- Each day reveals all groups from `Group 1` through the selected day number, matching the vocab mountain style.
- Users can inspect a word's details and mark words as learned or forgotten.
- The current scaffold reads source data from `data/final.json` and persists learner progress locally on the device.

## Why The Repo Starts With Flutter

- The project goal already calls for a website now and a mobile app later.
- Flutter keeps that path inside one UI framework and one codebase from the beginning.
