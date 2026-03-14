# TODO

- <!-- agent --> Enable local Flutter web support on the development machine so the same scaffold can be run in a browser during day-to-day iteration.
- <!-- agent --> Replace `SharedPreferencesProgressRepository` with a normalized SQLite-backed store once progress history, multi-device sync, or richer reporting is needed.
- <!-- agent --> Review the earlier web-support TODO item; web support is now configured, but this file is append-only under repo rules so the completed item could not be removed here.
- <!-- agent --> Review the earlier SQLite migration TODO item; learner progress is now stored in SQLite, but this file is append-only under repo rules so the superseded item could not be removed here.
- <!-- agent --> Replace the manual sync key with authenticated user identity before exposing the sync backend beyond personal use, because the current key-based model is convenience sync rather than real access control.

- a settings menu
  - opportunity to choose if selected go to next word in day
