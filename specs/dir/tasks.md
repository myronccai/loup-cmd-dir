# Tasks: dir

- [x] 1. Copy the shared Windows code into `source/win/` (bbaf257)
  - _Requirements: 2.1, 2.2, 3.9_
- [x] 2. Parse dir's switches and validate `/A`, `/O`, `/T` values
  - _Requirements: 3.1–3.10, 4.4_
- [x] 3. Plan operands into directory groups; path and name errors
  - _Requirements: 1.6, 1.7, 4.2, 4.3_
- [x] 4. Collect entries: patterns, `/A` filter, sizes, `.` and `..`
  - _Requirements: 1.4, 2.1, 3.3_
- [x] 5. Sort by `/O` keys with a stable merge sort
  - _Requirements: 3.4_
- [x] 6. Long, wide (`/W`, `/D`) and bare (`/B`) formats; `/L`, `/-C`
  - _Requirements: 1.3, 1.5, 3.1, 3.5, 3.6, 3.7_
- [x] 7. Headers, per-block and total summaries, `/S`
  - _Requirements: 1.1, 1.2, 1.7, 3.2_
- [x] 8. `File Not Found` and exit statuses
  - _Requirements: 4.1, 4.5_
- [x] 9. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
