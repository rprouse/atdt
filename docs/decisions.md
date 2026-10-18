# Decisions log

Dated record of every **Verify** item from the spec, plus significant design decisions. Newest entries at the bottom.

Each entry records:

- **Checked:** what was examined, and how
- **Found:** the result
- **Changed:** what was done as a result (or "nothing")

## Open Verify items

| Stage | Item | Status |
|---|---|---|
| — | FTS5 included in the bundled SQLite build, and whether `sqlite3_flutter_libs` or `sqlite3` v3 build hooks is the right way to bundle it | Verified 2026-10-16 (build hooks; FTS5 present; pinned by a test) |
| — | Golden test platform | Decided 2026-10-16 |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Verified 2026-10-16 |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack | Verified 2026-10-16 |
| A | Scroll structure choice | Decided 2026-10-16; confirm at the decision gate |
| A | Horizontal insets that stay put when system bars hide | Decided 2026-10-16; check on device |
| B | CP437 vs Latin-1 heuristic against the real archive | Verified 2026-10-16 (archive is all UTF-8; heuristic kept as fallback) |
| B | YAML front matter added to archive `.txt` files | Handled 2026-10-16 |
| C | Archive URL pattern, format, and metadata location | Verified 2026-10-16 (all 72 tarballs; dates from the issue picker) |
| E | Licence of each candidate font | Open (JetBrains Mono, BigBlue TerminalPlus and C64 Pro Mono verified) |
| G | Flutter selection behaviour in lazily built lists | Open |
| I | Section header patterns across the archive | Open |

---|---|---|
| — | FTS5 included in the bundled SQLite build, and whether `sqlite3_flutter_libs` or `sqlite3` v3 build hooks is the right way to bundle it | Open (Stage C) |
| — | Golden test platform: CI runs Linux, development is on Windows | Open (Stage A) |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Open |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack (believed CC BY-SA 4.0) | Open |
| A | Scroll structure choice (`TwoDimensionalScrollView` vs nested scroll views) | Open |
| B | CP437 vs Latin-1 heuristic against the real archive | Verified 2026-10-16 (archive is all UTF-8; heuristic kept as fallback) |
| C | Archive URL pattern, format, and metadata location | Open |
| E | Licence of each candidate font | Open |
| G | Flutter selection behaviour in lazily built lists | Open |
| I | Section header patterns across the archive | Open |

---

## 2026-10-16: Repository housekeeping

- **Checked:** how to keep the byte-exact fixtures required by the spec (CRLF, lone CR, CP437 bytes) intact on a Windows dev machine.
- **Found:** Git's line-ending normalisation and editor settings would rewrite them.
- **Changed:** `.gitattributes` marks `test/fixtures/**` as `-text`; `.editorconfig` turns off its rules for that folder.

## 2026-10-16: Project scaffold

- **Checked:** the Flutter toolchain (3.47.7 stable, Dart 3.13.5) and what the scaffold needs before Stage A.
- **Found:** Stage A needs no storage. The `sqlite3` package v3 bundles SQLite through Dart build hooks, and `sqlite3_flutter_libs` (named in the spec) is being phased out because of that. Whether FTS5 is present depends on which route is used.
- **Changed:**
  - Generated with `flutter create --org org.prouse --project-name atdt --platforms android,ios`. Bundle ID and application ID are `org.prouse.atdt`.
  - Added only `flutter_riverpod` and `integration_test`. Drift and SQLite packages are deferred to Stage C, where the FTS5 Verify item decides how SQLite is bundled.
  - `analysis_options.yaml` turns on strict casts, inference and raw types, and treats `unawaited_futures` as an error.
  - `test/architecture_test.dart` fails the build if `lib/layout/`, `lib/ingest/` or `lib/archive/` imports Flutter, Riverpod or `dart:ui`. It was checked against a planted violation.
  - CI (GitHub Actions, Ubuntu) runs format, analyze and tests. Goldens rendered on Windows will not match Linux pixel for pixel. Stage A must decide where goldens are generated (likely CI-only or a Linux container) before committing any.

## 2026-10-16: Stage A fonts

- **Checked:** licences from the primary sources (JetBrains Mono `OFL.txt` in the official repo; the int10h.org readme and the pack's own `LICENSE.TXT`). Also inspected both shipped binaries with fontTools.
- **Found:**
  - **JetBrains Mono 2.304** is SIL OFL 1.1. Its ligatures are in `calt` only; the compiled font has no `liga` table. Advance is 600/1000 = 0.6 and natural line height is 1.32 em. It covers all 128 box-drawing characters, all block elements and all of Latin-1. It is **missing 21 CP437 symbols** (☺☻♥♦♣♠◘◙♂♀♪♫☼▬↨∟₧⌐⌠⌡ⁿ), which fall back to a system font for now; Stage E's placeholder substitution has to handle them.
  - **PxPlus IBM VGA 8x16** from VileR's Ultimate Oldschool PC Font Pack v2.2 is CC BY-SA 4.0. VileR asks for credit as "VileR" with a link to int10h.org. Units per em is 1600 and advance is 800, so at 16px each glyph is exactly 8px wide and the line box is exactly 16px tall. It covers all of CP437 and all of Latin-1, and has no GSUB features.
  - The Px variant is right for us. Ac (aspect-corrected) variants use non-square pixels and break integer scaling. Mx variants add embedded bitmaps that Flutter does not use.
- **Changed:**
  - Both fonts are bundled unmodified, with their licence files and an `ATTRIBUTION.md`, under `assets/fonts/`.
  - JetBrains Mono uses `lineHeightRatio` 1.32, its natural height, so box-drawing verticals join. PxPlus uses 1.0, with `cellWidthPx` 8 and `nativeSizePx` 16.
  - **Open legal question:** whether bundling a CC BY-SA font in a store app counts as an adaptation. My reading is that it doesn't: the file is unmodified and only credit is required. Confirm before release (Stage K).

## 2026-10-16: Phrack archive source

- **Checked:** the live site, response headers, the issue 1 tarball listing, and `robots.txt`.
- **Found:**
  - The archive has moved to `https://archives.phrack.org/`. The old `phrack.org/archives/...` URLs redirect there with a 301.
  - Single philes are at `/issues/<n>/<m>.txt`, served as `text/plain` with no charset. Issue tarballs are at `/tgz/phrack<N>.tar.gz` for N = 1 to 72. They are really gzip, even though the server labels them `application/x-tar`. Issue 1's tarball has a flat layout (`./1.txt` … `./8.txt`).
  - **Every `.txt` file starts with a YAML front-matter block** (`title:`, `author:`) that is not part of the original phile. It is the best metadata source, but it has to be stripped from the text.
  - The latest issue is 72, released 2025-08-19. Phile counts in headers are not reliable: 72/1 says "of 0x12" but the issue has 19 files.
  - `robots.txt` allows everything. There is no stated policy on automated downloads. The site sits behind Cloudflare with ETags.
- **Changed:**
  - `tool/fetch_dev_philes.dart` fetches 7/3 (*The Conscience of a Hacker*) and 72/1 into `assets/dev/`, with an identifying user agent and a 1 s delay between requests.
  - Stage B must strip front matter before normalising, and Stage C should parse it for title and author.
  - Still open for Stage C: the contents of other tarballs (does 72 include the PDF?) and `archives.phrack.org/robots.txt`.

## 2026-10-16: Reader scroll structure

- **Checked:** `TwoDimensionalScrollView` against a horizontal `SingleChildScrollView` wrapping a fixed-width `ListView.builder` with `itemExtent`.
- **Found:**
  - Nested scroll views give everything the spec asks for with stock widgets. All lines scroll sideways as one block, and line index maps to offset by `index * itemExtent`. The chrome overlay just sits in a `Stack` above both.
  - Their one cost: a diagonal drag locks to one axis. For reading that is arguably a feature.
  - `TwoDimensionalScrollView` would need a custom viewport and delegate to get the same lazily built fixed-extent rows.
- **Changed:**
  - Using nested scroll views.
  - Restoring position means rebuilding the scroll controllers whenever the layout changes, with `initialScrollOffset` computed from the stored `ReadingPosition`, instead of calling `jumpTo` after layout. The first frame at the new metrics is then already correct, and scroll clamping during that frame cannot overwrite the saved position.
  - `ReadingPosition.fromOffsets` snaps fractions within 1e-6 of a line boundary. Floating point otherwise turns line 7 at a 29/3 line height into 6.999…, and a rotation lands one line early. This has regression tests.

## 2026-10-16: Insets that do not move text

- **Checked:** which insets change when the chrome shows or hides.
- **Found:** in Android landscape with 3-button navigation, the nav bar sits on a side edge and immersive mode removes it, so `viewPadding.left`/`right` change with the chrome. Display cutouts never hide. `DisplayFeature.bounds` are in logical pixels (unlike `FlutterView.padding`, which is physical). On iOS, the landscape safe areas don't change when the status bar hides.
- **Changed:** `stableHorizontalInsets` uses cutout bounds on Android and `viewPadding` on iOS. Top and bottom insets are ignored entirely: chrome and system bars overlay the text. Widget tests cover both cases (system bars appearing; a side cutout), and a mutation check confirmed the test catches a `viewPadding`-based implementation. **Still to check on physical devices**, especially Android phones with a side cutout and iPhones in landscape.

## 2026-10-16: Golden test platform

- **Checked:** Windows and Linux text rasterisation differ, and the newest `ghcr.io/cirruslabs/flutter` image is 3.44, three minor versions behind.
- **Found:** goldens have to be generated by one OS and one Flutter version.
- **Changed:**
  - Goldens are Linux-only and skip on other OSes.
  - CI pins Flutter 3.47.7. `tool/goldens/Dockerfile` builds the same version from a git tag, and `tool/goldens/update.ps1` regenerates (or `-Check`s) goldens from Windows.
  - The acceptance checks that must hold everywhere don't rely on goldens: 80-column widths measured from shaped glyph boxes, a pixel-equality ligature test with a `calt`-on control, and geometry checks for overflow and chrome.

## 2026-10-16: Retro fonts as outlines, not integer-scaled pixels

- **Checked:** PxPlus IBM VGA 8x16 with integer scaling, on the emulator and in the calculator for common phone widths. Also the licences and binaries of BigBlue TerminalPlus and C64 Pro Mono, from their primary sources.
- **Found:**
  - With integer scaling, an 8-pixel cell reaches only **1x on every phone in portrait**: 8 physical pixels per glyph, with 38–43% of the width unused. Review judged the pixel font "not great".
  - **BigBlue TerminalPlus 1.0** (VileR, int10h.org) is CC BY-SA 4.0. Advance is 800/1200 = 0.667 and line height is 1.0 em. It has full CP437 and Latin-1 coverage and no GSUB features. The original `BigBlue_TerminalPlus.TTF` is better for us than the Nerd Font patch: the patch adds thousands of icon glyphs we don't need and is an adaptation.
  - **C64 Pro Mono 1.2.1** (Style, style64.org) is under Style's own licence. It may be included in a software package **only unmodified, under its original file name, and only if the software is free to end users**. It may not be sold, put in a font collection, or offered for direct download. Advance is 1.0 (square cells) and line height is 1.0 em. Coverage is ASCII and PETSCII: 29/128 box-drawing characters, no double-line boxes, and most accented Latin-1 letters missing.
- **Changed:**
  - Dropped PxPlus IBM VGA 8x16. BigBlue TerminalPlus and C64 Pro Mono now render as outlines at fit size, like JetBrains Mono, so all three fill 80 columns in every orientation.
  - `C64_Pro_Mono-STYLE.ttf` keeps its original file name. `.gitattributes` gains `*.TTF binary` for BigBlue's upper-case extension.
  - Added an About dialog (chrome info button) with each font's credit. Each font's shipped licence file is registered with Flutter's `LicenseRegistry`, so "View licenses" shows the full texts. Tests check both.
  - The integer-scale code path and its unit tests stay in the layout calculator. The spec keeps it as a core rule and Stage E's manifest has the flag; no bundled font sets it today.
  - **Release constraint:** C64 Pro Mono can only ship while ATDT is free. Any paid tier needs a licence from Style, or the font must be removed from that build.

## 2026-10-16: Stage B ingestion against the real archive

- **Checked:** ran `tool/ingest_archive.dart` over all 72 issue tarballs (1,026 philes). Then scanned the raw files for conversion damage (U+FFFD, UTF-8-read-as-Latin-1 mojibake) and for every control character, with its context.
- **Found:**
  - **Every phile is valid UTF-8.** The maintainers have converted the archive: box drawing appears as real Unicode (1,899 box characters), and there is no U+FFFD or mojibake. The CP437 / Latin-1 heuristic never fires on the live source.
  - **Every phile has front matter** with a title and an author (1,026/1,026).
  - **C0 bytes survived the conversion as raw bytes** in 26 philes (305 characters), and they look like DOS display glyphs:
    - ESC in 22/4 and 22/5 is border art: `/|←/|←…` and `←|/`, probably backslashes mangled long ago, but aligned as one column each.
    - 0x03 ♥ appears in 6 philes, 0x14 ¶ in 3, and 0x18/0x19 ↑↓ in diagrams.
    - 0x1F appears in 46/19, 46/20, 46/23 and 48/3 as WordStar soft hyphens at line ends (`dif
ferent`).
  - **No real ANSI escape sequences exist.** The 4 "sequences" my first version stripped were false positives: `ESC _` and `ESC O` in art. Stripping them deleted the following art character and shifted the art by two columns.
  - **^Z:** 26 philes end with a single ^Z (trailing padding), and 6 have a ^Z at a line end where concatenated parts meet (46/15, 46/16, 46/18, 46/25, 46/26 and 55/3).
  - Form feeds: 5, all in 50/6.
  - **Size:** median 474 lines and 79 columns. 15% of philes exceed 80 columns, and the widest is 559 (62/6). **71/7 is 16.4 million characters (265,732 lines)**; ingesting it takes 1.9 s on a desktop JIT.
- **Changed:**
  - **The spec says "other C0 controls become a visible placeholder". C0 bytes and DEL now show as their CP437 glyphs in every encoding instead.** That is how DOS displayed them, and it keeps art and symbols intact. The `∙` placeholder (U+2219, present in every bundled font) is kept for NUL (blank in CP437) and C1 controls. Soft hyphens therefore show as `▼` at line ends, faithful to DOS if not to WordStar.
  - ANSI stripping is limited to full CSI sequences (`ESC [ … final`). A bare ESC is a `←` glyph.
  - A ^Z immediately before a line break is dropped (DOS stopped reading there), as well as trailing ^Z/NUL padding.
  - The decoding heuristic (CP437 when box-drawing bytes appear outside words; Latin-1 when accented letters sit inside them; Windows-1252 when bytes 0x80–0x9F are prose punctuation) stays as the fallback for non-UTF-8 sources. It is covered by fixtures. Ambiguous decisions are flagged on `PhileText.encodingAmbiguous` and in the CSV; none occur in the archive.
  - **For Stage C:** import must run off the UI isolate (71/7 alone takes seconds on a phone). Line-offset storage must cope with philes over 16 MB.

## 2026-10-16: SQLite bundling and FTS5

- **Checked:** pub.dev, the changelogs and READMEs of `drift`, `drift_flutter`, `sqlite3` and `sqlite3_flutter_libs`, and the drift docs. Ran FTS5 under `flutter test` on Windows and in the Linux CI container.
- **Found:**
  - `sqlite3` 3.x bundles SQLite (3.54 in 3.7.x) through Dart build hooks on Android, iOS, Windows and Linux. The prebuilt binaries are compiled with `SQLITE_ENABLE_FTS5`, and iOS uses the bundled copy, not the system SQLite.
  - **`sqlite3_flutter_libs` is end-of-life** (0.6.0+eol does nothing). Its README says to remove it after moving to `sqlite3` 3.x. `drift_flutter` 0.3.x pulls in the empty eol stub on purpose.
  - The `sqlite3` Dart API has no incremental blob I/O (`sqlite3_blob_open`).
  - The hook downloads the SQLite binary (sha256-checked), so CI needs network access, which GitHub Actions has.
- **Changed:**
  - Using `drift` 2.35 + `drift_flutter` 0.3 + `path_provider`; `sqlite3_flutter_libs` is not a direct dependency, unlike the spec.
  - `build.yaml` tells `drift_dev` about the fts5 module, ready for Stage H.
  - `test/storage/archive_database_test.dart` creates an FTS5 table and runs a `MATCH` query, so losing FTS5 fails CI.

## 2026-10-16: Archive format and metadata (Stage C)

- **Checked:** all 72 cached tarballs with Python's `tarfile`; phrack.org issue pages; `archives.phrack.org/robots.txt`.
- **Found:**
  - Every tarball has the same flat layout: a `./` entry plus `./N.txt` files only. There are no PDFs, nested paths, symlinks or unsafe paths. The archive is 31.1 MB compressed and 61 MB once stored.
  - Tar timestamps are all 1985-11-17 00:00 (normalised), so they are **not release dates**.
  - Release dates for all 72 issues are in the issue-jump `<select>` on every issue page (`Issue N (YYYY-MM-DD)`). `/issues/1/1` is a meta-refresh stub to the slugged page, so two requests fetch every date.
  - `archives.phrack.org/robots.txt` only *defines* Cloudflare content signals (search, ai-input, ai-train) and sets none, so under its own clause (c) it neither grants nor restricts. An offline reader on the user's device is none of those uses anyway.
- **Changed:**
  - Issues are discovered from the `tgz/` directory index, so "check for new issues" finds issue 73 when it appears.
  - Release dates are fetched best effort; a failure leaves them null ("if known").
  - Title and author come from front matter, falling back to "Phile N" and no author. Nothing is guessed.

## 2026-10-16: Text storage in line-aligned chunks

- **Checked:** how to read one line without loading a 16 MB phile, given no incremental blob I/O. Measured on the emulator.
- **Found:**
  - SQLite's `substr()` on a BLOB materialises the whole value, so the spec's "single blob with line-start offsets" would read 16 MB per line for 71/7. The offsets alone would be 1 MB.
  - With line-aligned chunks, `readLine` (debug build, x86 emulator, after warm-up) has p50 2.4–3.9 ms and p95 4.1–7.7 ms. **The median equals the empty-query round trip to drift's database isolate** (2.5–3.1 ms), so the lookup itself is negligible. Chunk size barely matters: 64 KiB gave p95 4.55 ms, 16 KiB 4.22 ms, and 4 KiB 3.78 ms in one run.
- **Changed:**
  - The `phile_text` table holds ~16 KiB chunks of whole lines, each tagged with `first_line` and `line_count` and indexed by `(phile_id, first_line)`. Any line is one indexed lookup of one chunk. That meets the spec's purpose ("read a line without splitting the whole file"), but not its literal design.
  - `readLine` uses a raw prepared query; the query builder cost more than the lookup in debug.
  - `integration_test/storage_perf_test.dart` asserts p95 < 5 ms only in profile and release builds. **Pending:** run it on a mid-range physical phone in profile mode.

## 2026-10-16: Download robustness and backup exclusion

- **Checked:** a fresh emulator install downloading the real archive, killed mid-download, then airplane mode mid-download.
- **Found and fixed during testing:**
  - Dart's gzip decoder accepts a truncated stream silently, which would have stored a half-downloaded issue as empty. There are now three guards: the gzip ISIZE trailer, the tar end-of-archive marker, and rejection of an issue with no philes.
  - On device, a kill after 9 issues relaunched straight into a resumed run of the 63 remaining issues, without a tap. Airplane mode showed "Can't reach the Phrack archive…" with Retry, keeping the 25 issues done; Retry stored the other 47. Final state: 72 issues, 1,026 philes, all release dates, SQLite integrity ok.
- **Changed:**
  - Each issue is saved in one transaction. A persisted `archive.download` flag ("requested" or "settled") drives the auto-resume at launch.
  - The database is `<application support>/atdt/archive.sqlite`. Android excludes `files/atdt/` with `fullBackupContent` (API ≤ 30) and `dataExtractionRules` (API 31+, cloud backup and device transfer). iOS sets `isExcludedFromBackup` on the folder through a method channel in `AppDelegate`. **Not yet built or verified on iOS: needs a Mac.**
  - Reading positions share the database, so they are excluded from backup too. They are per-device state, and the archive can be fetched again; a separate backed-up store can be added in Stage G if wanted.

## 2026-10-16: Library navigation (Stage D)

- **Checked:** the navigation flow, the first-launch flow and back-navigation on the emulator against the real archive. Also an upgrade from the Stage C build (schema v1, 18 issues downloaded) to this build.
- **Found:**
  - **drift reads `DateTime` back in local time.** Release dates are stored as UTC midnight, so 1999-09-09 came back as 1999-09-08 18:00 west of Greenwich, and the library would have shown every issue a day early. On the `America/Denver` emulator, all displayed dates now match phrack.org's picker exactly (e.g. Issue 18, 6 Jul 1988).
  - **`flutter test integration_test/...` uninstalls the app when it finishes on Android,** taking its data with it. Upgrade and real-archive checks must install builds with `adb install -r`, not run integration tests in between.
  - **The v1→v2 upgrade works on a real device database:** the 18 issues, their dates and phile counts all survived, and the app opened into the library. A v1 database has no catalog, so undownloaded issues appear only after the next "Check for new issues". A fresh install records the catalog on its first check.
  - Decoding the 16 MB phile (71/7) on the UI isolate would freeze the app. Real isolates also never finish under the widget tester's fake clock.
- **Changed:**
  - **The issues list is home, and the first-launch flow is its empty state.** It explains the download (about 31 MB, from archives.phrack.org, resumable) and starts it only on confirmation. While downloading, a progress banner shows and issues appear as they are stored. Launch → issue → phile is **two taps**.
  - **Schema v2** adds a `catalog` table (issue and release date), written by the downloader on every check, before it downloads anything. Undownloaded issues are listed, dimmed, with a cloud icon, even offline. Release dates are read back in UTC and formatted from UTC fields.
  - `readAllLines` decodes on a short-lived isolate above 256 KB. Widget-test databases raise that threshold; the storage unit tests cover the isolate path in real time.
  - The issue screen stays mounted under the reader, so back returns to the same scroll position. A widget test covers it.
  - **The app no longer bundles any text.** The fixture and `assets/dev/` asset declarations are gone, along with `tool/fetch_dev_philes.dart`. Any build made on a machine with dev philes would otherwise have shipped Phrack text inside the app, against a spec non-goal. Real philes come from the in-app download. Device tests generate their 10,000-line text in code.
  - The settings screen stub carries over the spike's font, theme and orientation menus, plus the debug overlay and About/licences. The reader chrome keeps quick font, theme and orientation menus and gains a back button. Settings are not persisted yet (Stage G).

## 2026-10-16: Font system (Stage E)

- **Checked:**
  - Licences, from the primary sources, of three more candidates: IBM Plex Mono (google/fonts), VT323 (google/fonts) and Terminus TTF 4.49.3 (files.ax86.net). Their coverage was inspected with fontTools.
  - Our `cmap` reader against fontTools' code-point counts.
  - On the emulator: runtime font loading, the coverage notice, and the placeholders.
- **Found:**
  - **IBM Plex Mono:** OFL 1.1, Reserved Font Name "Plex". Full box drawing and Latin-1; missing 37 CP437 symbols; no ligature tables.
  - **Terminus TTF 4.49.3:** OFL 1.1, Reserved Font Names "Terminus Font" and "Terminus (TTF)". Complete CP437 and Latin-1, the best coverage of any font we ship. Its 0.09 em line gap would open gaps in box-drawing verticals, so its `lineHeightRatio` is 1.0.
  - **VT323:** OFL 1.1, but **no box-drawing characters at all** (0/128). Phrack has 1,899 of them, so every one would be a placeholder. Not shipped.
  - Flutter has no API for a font's character set, but the app holds the font bytes. The pure-Dart `cmap` reader (formats 4 and 12) matches fontTools exactly on all five fonts (781–1,496 code points each).
  - C64 Pro Mono draws U+2219 as a heavy disc, indistinguishable from real `●` content, so it is no good as a "missing" mark.
  - Test gotcha: `rootBundle` caches load futures. One cached inside a widget test's fake-async zone never completes when awaited later under `runAsync`, which caused a 10-minute hang. Clear the bundle cache in such tests.
- **Changed:**
  - **Fonts: JetBrains Mono, IBM Plex Mono, BigBlue Terminal, Terminus and C64 Pro Mono,** spanning modern and retro.
  - **`assets/fonts/manifest.json`** lists each font's id, display name, family, files, `integerScale`, cell sizes (pixel fonts only), `lineHeightRatio`, licence name, URL and file, and attribution. Font files and licences live in flat `files/` and `licences/` folders, each declared once in `pubspec.yaml`. The pubspec has **no `fonts:` section**: `FontRegistry` registers each family with `FontLoader` at startup. **Adding a font is a file plus a manifest entry.** Tests enforce this: no Dart file in `lib/` may name a font id or family, every manifest path must exist, and every file in the font folders must be used.
  - **Coverage map:** each font's code points come from its own bytes at startup.
  - **Placeholder substitution:** a character the active font lacks is drawn as that font's `·` (U+00B7), or `?` if it has none. It is one code point for one, so columns never move, and the system fallback font is never used. When the font covers the phile's stored inventory, lines are not touched at all. A widget test checks every font: on each line of a mixed-coverage fixture, the closing bar's glyph box starts exactly 11 columns in. Goldens show the same.
  - **Coverage notice:** when the font cannot draw part of a phile, a dismissible card offers the first manifest font that can draw all of it. Verified on the emulator: C64 Pro Mono on 17/9 (its `¶`) offers JetBrains Mono. The card floats like the chrome and never moves text.
  - **Credits screen** (Settings → Credits): every font with attribution, licence name and URL, and its full licence text. The About dialog and Flutter's licence page are fed from the same manifest.
  - **The font choice persists** (`reader.font` in the settings table). A stored id that is no longer bundled falls back to the default.

## 2026-10-16: Themes (Stage F)

- **Checked:** the WCAG contrast of the Stage A themes, and of candidate palettes for the new built-ins. On the emulator: the editor, live preview and whole-app theming.
- **Found:**
  - The Stage A themes' *dim* colours failed AA: green 3.52:1 and paper 3.19:1.
  - Restoring the saved theme asynchronously would flash the default theme for a frame at every launch, because the theme colours the whole app.
  - The editor's preview drew glyphs the reader font lacks with the system font, against AGENTS.md rule 9.
- **Changed:**
  - **Product decision (owner, 2026-10-16): no contrast warning for custom themes.** Themes are personal, not shared, so the spec's "warn below WCAG AA" is dropped. Instead, **every built-in theme meets AA (4.5:1)** for text, accent and dim against the background, and for text against the selection colour. High contrast reaches AAA. `test/themes/built_in_themes_test.dart` enforces this.
  - A theme has five colours: background, foreground, selection, accent and dim. Brightness is derived from the background's luminance. **Built-ins:** green phosphor, amber phosphor, paper, high contrast and VGA blue (an IBM DOS-style blue, which suits the retro fonts). Dim colours were corrected to pass AA.
  - **The theme drives the whole app:** the `ThemeData` maps accent to app bars, icons and buttons, foreground and dim to list text, and selection to text selection. A widget test checks that the app bar takes the theme's colours.
  - **Custom themes:** create (starting from the current theme), edit and delete in Settings. The editor has an HSV + hex colour picker and a live preview of all five colours, in the reader font with placeholder substitution. Built-ins can't be edited. Custom themes are JSON in the settings table (`themes.custom`), and malformed entries are skipped. The choice is saved as `reader.theme`; deleting the theme in use falls back to the default.
  - `main` waits (up to 2 s) for saved settings and themes before the first frame, so there is no flash. A storage error never blocks startup.
  - Goldens: the reader in each built-in theme (`theme_<id>.png`).

## 2026-10-17: Reader polish (Stage G)

- **Checked (Verify: selection in lazy lists):** a probe wrapping `SelectionArea` around a 1,000-line `ListView.builder` (Flutter 3.47.7), then select-all and copy. On the Android emulator: volume-key paging, position restore across app sessions, and the orientation control.
- **Found:**
  - **Selection only reaches built lines.** Select-all copied lines 0 to 42 of 1,000, which is the viewport plus the cache extent. Lines the lazy list has not built are not selectable.
  - **Separate `Text` widgets are joined with no newline** ("line 0line 1…"), which would corrupt fixed-width text.
  - **Volume keys reach Android first.** Returning `KeyEventResult.handled` from a Dart `Focus.onKeyEvent` did not stop the volume changing (5 → 4), and the reader didn't page. The framework never handled the key, so the embedding passed it back to Android.
  - Gradle's Kotlin incremental caches fail to close ("Could not close incremental caches") when the pub cache (C:) and the project (D:) are on different drives.
- **Changed:**
  - **Copy is block-based, not `SelectionArea`.** A long press selects the contiguous non-blank lines around the pressed line (`lib/layout/text_block.dart`, pure Dart). A copy bar offers Copy and Cancel, and a tap clears the selection. The copied text is the stored lines joined with `\n`, byte for byte, leading whitespace included. Cross-screen free selection is not attempted.
  - **Volume paging is native.** `MainActivity.dispatchKeyEvent` consumes `KEYCODE_VOLUME_UP` and `KEYCODE_VOLUME_DOWN` only while a gate is on. The gate is set over the `org.prouse.atdt/volume_keys` channel: on while a reader is open with the setting on (Android only), off when it closes. Key-down (not repeats) calls `page(±1)` in Dart, which animates by one screen less one line. Verified on the emulator: the reader pages both ways, the volume is unchanged and no volume panel appears; after the reader closes the keys change the volume again.
  - **Orientation is scoped to the reader.** The chosen mode applies while a reader is open (it works with the system rotation lock on) and is released to all orientations on exit, so the library always rotates freely. Choosing it in Settings only stores it.
  - **Zoom** is a multiplier on the fit size, never below fit. Vector fonts scale continuously; integer-scale fonts round to whole scales. While pinching, a `Transform.scale` preview anchored at the top left is shown. On release the zoom commits as a new layout, restored from the position tuple, so the top line holds. Zoom resets to fit when the available width changes (rotation). Extra width scrolls horizontally.
  - **Reading position** is saved 500 ms after scrolling stops, when the reader closes, and when the app becomes inactive. "Continue reading" shows the most recently saved phile; its percentage is based on the top line. A phile that is opened but never scrolled is not recorded.
  - **Keep-awake** (`wakelock_plus`) is on by default while a reader is open, and released on exit.
  - `android/gradle.properties` sets `kotlin.incremental=false`.

## 2026-10-17: Search (Stage H)

- **Checked:** `tool/search_bench.dart` builds the index over the real archive (72 issues, 1,026 philes, 1,154,989 lines) on the desktop, with several FTS5 layouts. `integration_test/search_perf_test.dart` builds a synthetic archive of the same size on the device (profile build on the Android emulator). The full app was also checked on the emulator, with all 72 issues downloaded.
- **Found:**
  - **One FTS row per line is fast.** Specific queries take 0.2–4 ms on the desktop. `the`, which matches 173,106 lines in every phile, takes 98 ms.
  - **Index size is the cost.** A contentless line index adds 67 MB to the 61 MB archive. `columnsize=0` saves 15 MB, leaving 52 MB. `detail=column` saves only 0.5 MB more, because short lines rarely repeat a token, so positions are nearly free; it would also break phrase queries. `optimize` made no measurable difference to query time, because automerge keeps the index compact.
  - `contentless_delete=1` cannot be combined with `columnsize=0`.
  - **On the device:**
    - The known string is found in **5.5 ms**. Words matching half or more of all 1.16 M lines take 280–360 ms.
    - Indexing the whole synthetic archive takes 120 s on the emulator. When downloading the real archive, the index kept pace with the polite, rate-limited download and was complete when it finished.
    - In the app, queries never run before return in 49–189 ms. The first queries made within seconds of a launch were slower (316 and 799 ms), while startup work was still running.
- **Changed:**
  - **Index layout (schema v3):**
    - `line_fts` is FTS5 with `content=''`, `columnsize=0` and `tokenize='unicode61 remove_diacritics 2'`. It has one row per non-blank line, with rowid `phileId << 24 | line`. A match is therefore already a phile and a line, and grouping by phile reads no text.
    - `title_fts` holds titles and authors for the titles-and-authors filter.
    - `search_indexed` records which philes are indexed; it cascades with `philes`.
    - Snippets come from `readLine`, and only for rows on screen.
  - **Trade-off:** a phrase split across a line break does not match. Words are ANDed on a single line.
  - **Re-imports:** contentless rows can't be deleted with `columnsize=0`. A re-imported issue removes its titles and orphans its old lines. Search joins on `philes`, and AUTOINCREMENT never reuses an id, so orphans never match (tested). `indexPhile` refuses a phile that is already indexed, because a contentless table would accept duplicate rowids.
  - **Query language** (`lib/search/`, pure Dart):
    - Bare words are ANDed prefixes ("hack" finds "hacker"); words shorter than 3 letters match exactly.
    - A word with punctuation inside ("AT&T") and anything in double quotes is a phrase.
    - Every token is quoted in the `MATCH` expression, so nothing typed is read as FTS5 syntax.
    - Highlighting re-tokenises lines the way unicode61 does (case and accent folding, one UTF-16 unit for one), so its ranges are ranges in the displayed text.
  - **Indexing** follows the index status stream. Philes stored by a download, or left unindexed after the v3 upgrade, are indexed as they appear, one transaction per phile, newest issue first. SQLite runs on drift's background isolate, and philes over 256 KB decode on their own isolate (`readAllLines`). The search screen shows progress, and results refresh when indexing finishes.
  - **Search screen:**
    - It is entered from the library once anything is downloaded, and typing is debounced (250 ms).
    - Results are grouped by issue, newest first, each with a one-line snippet in the reader font, with placeholder substitution. The snippet starts near its first match.
    - It shows match counts and the query time.
    - Filters: issue range (a range slider), and titles and authors only.
    - It reads only the local database, so it works offline (tested with the archive offline).
  - **Jump to match:** the reader opens with the first matching line a third of the way down the screen, clear of the chrome overlay. It scrolls sideways only if the match lies beyond the visible columns of a wide line. Matches on every line are highlighted with a span background in the theme's selection colour, which never changes glyph advances; a test checks that every character stays on the column grid, and a golden records it.
- **Not part of Stage H:** with data stored, the emulator takes 10–16 s to show the first frame (4.2 s of it before framework init). A profile build of `main` from before this stage behaves the same, and a launch with no data takes about 3 s. This needs a look on a real device in Stage K.

## 2026-10-17: Section navigation (Stage I)

- **Checked (Verify: section patterns):** surveyed every line of all 1,026 philes for heading-like shapes: bracketed dashes, `|=[ ]=` boxes, numbered and Roman-numeral lists, `[N]` references. Then iterated the parser against the archive with `tool/sections_report.dart`. That tool lists each phile's outline, any repeated heading, and every phile with numbered-looking lines that got no outline. It also runs the early-era check.
- **Found:**
  - **One family dominates modern Phrack:** `--[ N - Title`, with the number giving the nesting (`----[ 2.1 - …`, `------[ 2.1.1 - …`).
  - **Variants:**
    - Compilations mark articles with `|=[ 0xNN - Title ]=---=|`, `|=[ 0xNN ]=---=[ Title ]=---=|`, or a decimal `|=---=[ N - Title ]=---=|`, and restart numbering inside each article.
    - Some philes close the number in the bracket: `--[1.1]-- Title` (52/3), or `----[  3.0]  Overview` (55/14).
    - 70/4 uses three-digit numbers (`001.002`), and 62/13 uses `-[0x01] :: Title`.
  - **No reliable pattern before issue 52.**
    - Numbered and Roman-numeral lines are lists ("1. When the operator answers…").
    - `[1]` lines are references.
    - Unnumbered `--[ Title` lines mix real headings with banners (`---[ Phrack Magazine Volume 7…`), `[ END OF FILE ]`, author emails and shell prompts.
    - Loopback's `|=[ 0x00 ]=` dividers carry numbers but no titles.
  - **Contents lists:** some philes (67/9, 68/9, 69/4) repeat every heading in a contents list in the heading format, sometimes worded slightly differently ("Further readings" against "Further reading").
- **Changed:**
  - **Parser** (`lib/sections/`, pure Dart). It accepts only numbered headings starting at column 0, in the four formats above, plus "Appendix X". Titles are trimmed of brackets, rules and box edges; titles over 72 characters are rejected.
  - **Nesting:**
    - Nesting comes from the number, never the dashes.
    - `N.0` is top level, unless it directly follows plain `N`.
    - Hex numbers and `|=[ ]=` boxes are articles, and everything else sits one level below them.
  - **Conservative rules:**
    - At least two headings, or nothing.
    - Numbers may only go forwards or restart at 0 or 1 (the next article). Any other backwards step discards the whole outline.
    - In a dense run of headings whose entries mostly reappear later, the part up to the last repeated entry is a contents list. It's dropped, so entries jump to the real headings. A two-entry run must repeat exactly, so a compilation repeating "1 - Introduction" per article keeps both.
  - **Result:** 174 of 1,026 philes (issues 52–72) get a jump list, with 2,949 headings in all. The only repeated headings left are in 72/3, a compilation, one per article. The 12 philes with numbered-looking lines but no outline are all correct refusals: untitled Loopback dividers (57/2, 57/3, 58/2, 58/3, 59/2, 60/2, 61/2, 62/2, 63/2, 71/4), an ASCII diagram (40/7), and unnumbered headings (69/9).
  - **Early-era check (spec acceptance):** the 20 philes from issues 1–40 with the most heading-like lines (numbered lists, Roman numerals, bracketed banners, references), and how many each had: 25/2 (263), 36/6 (113), 20/4 (83), 40/7 (78), 35/8 (54), 9/6 (36), 13/9 (29), 27/5 (23), 37/4 (20), 26/11 (20), 15/5 (19), 5/3 (17), 17/5 (14), 29/11 (14), 27/12 (13), 20/1 (12), 27/1 (12), 29/9 (12), 15/8 (11), 21/1 (11). **Sections found: 0 in all 20, so no false positives.**
  - **Reader:**
    - Sections are parsed when a phile loads. A first-character prefilter keeps the scan cheap, even for 71/7.
    - A **Sections** button appears in the chrome only when headings were found. It opens a sheet, indented by level, that marks and scrolls to the section being read.
    - Choosing a section puts its heading on the top line and hides the chrome, so nothing covers it.

## 2026-10-17: CRT effect (Stage J)

- **Checked:**
  - The `dart:ui` sources in Flutter 3.47.7: accessibility flags, and `ImageFilter.shader`'s requirements.
  - On the Android emulator, which renders with Impeller on OpenGL ES: the effect on the real archive, and the scroll perf test in profile mode, with and without the effect.
- **Found:**
  - **No reduce-transparency flag.** Flutter reports `disableAnimations` (Android's Remove animations, iOS Reduce Motion), `reduceMotion` (iOS only) and `highContrast` (iOS, Android 34+), but not Reduce Transparency. Android has no such setting.
  - **`ImageFilter.shader` is Impeller-only** (`isShaderFilterSupported`), so it isn't available in `flutter test` or on Android devices that fall back to Skia.
  - **The y-flip documentation is wrong for this version.** The docs say shaders must flip y on OpenGL ES. On this engine the documented `#ifdef IMPELLER_TARGET_OPENGLES` flip turned the reader **upside down**; without it the image is upright. **Not yet checked on a Vulkan phone or on iOS (Metal).**
  - **The emulator can't judge 60 fps.** Its emulated GPU rasterises the plain reader at an average of 201 ms per frame in profile mode (130 of 135 frames over budget). The CRT pass ran afterwards, warmed up, and averaged 73 ms. Neither says anything about a phone.
- **Changed:**
  - **Shader** (`shaders/crt.frag`). At full intensity:
    - **Scanlines:** dark gaps (up to 75%) every 2.5 logical pixels, sized with the device pixel ratio.
    - **Bloom:** two tight eight-tap rings (¾ and 1½ logical pixels).
    - **Phosphor:** a 55% pull toward the theme's foreground at each pixel's brightness, plus a faint lift of the background in that colour, so scanlines show across the black too.
    - **Vignette:** the edges darken up to 45%.
    - Every pixel keeps its own sample at its own coordinate, with no distortion or curvature, so no line can move.
  - **Owner feedback (2026-10-17, Galaxy S23 Ultra):** "responsive and looks good", but the first tuning was "overly subtle", noticeable only at 100% and zoomed in. Causes:
    - Scanlines could only darken a mostly black screen, by at most 35% in a soft 3-point cosine.
    - The glow was too small to see at arm's length.
    - The retune above fixes both. A first retune widened the bloom to 3 logical pixels along the axes only, which drew ghost copies of each glyph; tight eight-tap rings fixed that.
  - **Where it applies:** `ImageFiltered` wraps the reader only, never the chrome. It's off by default, with an intensity slider (default 60%), and all three settings persist.
  - **Accessibility:** the effect stays off while Remove animations, Reduce Motion, high contrast or Reduce Transparency is on. Reduce Transparency is read from `UIAccessibility.isReduceTransparencyEnabled` over the `org.prouse.atdt/accessibility` channel, again when the app resumes. **That Swift code is not built or verified: it needs a Mac.**
  - **Benchmark fallback:** no reference phone is available, so the "quick benchmark" runs on the device itself. In profile and release builds `FrameBudgetGuard` watches raster times while the effect is on. If more than a quarter of a 120-frame window misses **16.7 ms**, it turns the effect off, says so in Settings and a snackbar, and remembers. Turning the effect on again clears that.
    - It was first written against the display's refresh rate, which would wrongly fail a 120 Hz phone (8.3 ms per refresh) that easily holds the spec's 60 fps. It now always uses 16.7 ms.
    - Seen working on the emulator: its slow GPU tripped the guard, and Settings said "Turned off: this device could not keep up with it".
  - **Debug overlay frame figures** (asked for by the owner): display refresh rate, 90th-percentile build and raster times, and how many of the last 60 frames went over 16.7 ms, from engine `FrameTiming`s. Zero over budget while scrolling means 60 fps or better.
  - **Settings** explain why the effect isn't showing: unavailable (no Impeller), paused (accessibility), or turned off (too slow).
  - **The acceptance check needs a person:** 60 fps in profile mode with the effect on, on a mid-range phone. `integration_test/scroll_perf_test.dart` now writes `scroll_perf_crt.timeline_summary.json` next to the plain runs for that comparison.

## 2026-10-18: Release hardening (Stage K)

- **Cold start:**
  - **Checked:** timed each step of `main`, then each font load, in profile builds on the emulator.
  - **Found:**
    - With the archive stored, launches took 16–26 s. Fonts took 3.6–11 s, although reading and parsing them takes milliseconds (cmap parsing: 0–11 ms per font on the desktop).
    - Asset loads are platform messages answered on Android's main thread. That thread stalls for seconds after it logs `Initializing Window Extensions` (the androidx.window set-up behind fold detection), and the stall landed on whichever font was loading: BigBlue in one run, IBM Plex in another.
    - The five loads waited one at a time, followed by restoring settings.
    - The earlier "slow only with data" pattern was variance in that stall.
  - **Changed:** every font file is requested at once, and settings (database only) are restored while fonts load. Launches now take 5–7 s on the emulator, the remainder being the platform stall. The owner's S23 Ultra didn't show a slow launch; its time goes in `docs/test-log.md`.
- **Memory with the largest phile:** 71/7 (16.4 M characters, 265,732 lines) takes the app from 143 MB to 204 MB PSS on the emulator. Repeated opens stay at 204–211 MB: the text is released, and the Dart VM keeps the pages for reuse rather than leaking.
- **Archive import:** the full download (72 issues, 1 s polite delay between them, imports on an isolate, indexing alongside) took about 3 minutes on the emulator in profile builds, and longer in the release check while indexing competed for CPU. A real-device time goes in the test log.
- **Malformed archives:**
  - Deterministic fuzz tests cover truncation at every length, corrupted gzip, corrupted tar re-gzipped, header fields rewritten with valid checksums (huge, non-octal, negative and blank sizes, odd type flags, unterminated names), garbage, and arbitrary bytes into text decoding. Every case imports or throws `ArchiveFormatException`. Controls prove the hostile headers reach field parsing. No parser bug found.
  - The downloader now also contains any unexpected import or storage error to that one issue (logged, reported as failed).
- **Accessibility:**
  - Every library screen meets Android and iOS tap-target sizes, labelled tap targets and text contrast (contrast also in every built-in theme), and lays out at 2× and 3× text on a 360×640 phone. All of them passed as they were.
  - In the reader, the tap-to-toggle area looked to screen readers like one unlabelled button over every line. It's now excluded from semantics. The chrome never hides while a screen reader runs, and hidden chrome is excluded from semantics. Each line is its own node, read in order.
- **Tablets and foldables:**
  - At tablet sizes on the emulator (1600×2560 and 2560×1600) the library lays out, and the reader fits 80 columns and keeps the position across a live resize.
  - A separating vertical feature (a hinge, or a fold that's half open) now confines the reader to the larger pane. A flat fold keeps the full width. A horizontal (tabletop) fold crosses lines rather than splitting them and is left alone.
  - Not yet tried on a real tablet or foldable.
- **Store readiness:**
  - **Release builds had no INTERNET permission.** Flutter's template grants it only in the debug and profile manifests, so a release build couldn't have downloaded anything. Every earlier device check used debug or profile builds, which is why it went unseen. Fixed, and a release build now downloads on the emulator.
  - Release signing reads `android/key.properties` (git-ignored), falling back to the debug key.
  - App icons are generated by `tool/make_icon.py` and `flutter_launcher_icons`. That tool's edit to the Xcode project, which set a boolean build setting to `AppIcon`, was reverted.
  - The privacy statement is in `docs/privacy.md` and in Settings, kept identical by a test.
  - Credits for Phrack and every font were already in place (Stage E).
- **CI:**
  - Android job: a release build, then the device tests on an API 34 emulator.
  - iOS job: `flutter build ios --release --no-codesign`, the first compile of `AppDelegate.swift`, then the device tests on an iPhone simulator.
  - The search and scroll benchmarks stay manual (real device).
- **Owner actions:**
  - Contact the Phrack staff before public release (spec).
  - Create the Android upload key and the App Store / Play Console listings.
  - Run the manual passes still open in `docs/test-log.md`.
