# ATDT: Specification

A native, cross-platform mobile app for reading the Phrack archive as the original fixed-width text. No reformatting, no reflow. The reading experience is the product.

This document is written for an implementing agent. Work proceeds in stages, each producing a testable, runnable unit. Do not start a stage until the previous stage's acceptance criteria pass. Items marked **Verify** are assumptions that must be checked before code depends on them; record findings in `docs/decisions.md`.

## Product summary

- Reads every Phrack issue and phile offline, after a one-time download.
- Renders text exactly as published: 80 columns, monospace, no soft wrap. Lines longer than 80 columns scroll horizontally.
- Portrait for readers with good eyesight; landscape for comfortable reading. Rotation preserves the reading position exactly.
- Ships multiple bundled fonts, including retro pixel fonts, and multiple colour themes.
- Immersive reading: app chrome hides while scrolling and returns via gesture, browser-style.

## Non-goals

- Reflowing, rewrapping, or otherwise reformatting text.
- Bundling Phrack content in the app binary. Content is downloaded on-device from the source.
- Accounts, sync, social features, comments.
- A web build.

## Technology

| Concern | Choice |
|---|---|
| Framework | Flutter (stable channel), Dart |
| Platforms | iOS and Android, phones and tablets |
| Storage | SQLite via `drift` + `sqlite3_flutter_libs` |
| Search | SQLite FTS5 (**Verify** FTS5 is included in the bundled SQLite build) |
| State management | Implementer's choice; prefer Riverpod. Keep it consistent. |
| Testing | `flutter_test` unit and widget tests, golden tests for rendering, `integration_test` for device behaviour |

## Core rendering rules

These rules apply from the first stage onward and must not drift.

### Text model

- A phile is an ordered list of lines. Each line is a string of already-normalised characters (see the ingestion stage). The renderer never decodes bytes.
- Tabs are expanded to 8-column stops before rendering.
- Soft wrapping is disabled everywhere. Every line renders on exactly one visual row.

### Column width and font size

The viewport always shows exactly 80 columns at fit, regardless of font.

```
availableWidth   = viewportLogicalWidth - safeAreaLeft - safeAreaRight - 2 * horizontalPadding
advanceRatio     = measured glyph advance / fontSize   (per font, cached)
fitFontSize      = availableWidth / (80 * advanceRatio)
lineHeight       = fitFontSize * font.lineHeightRatio
```

Measure `advanceRatio` once per font with `TextPainter` by laying out a string of 80 identical characters (for example `M`) at a reference size of 100 and dividing the width by 80 × 100. Do not assume 0.6.

### Pixel fonts and integer scaling

Fonts flagged `integerScale: true` in the font manifest are bitmap-derived and must render at whole-number multiples of their native cell size to stay crisp.

```
physicalWidth = availableWidth * devicePixelRatio
scale         = floor(physicalWidth / (80 * font.cellWidthPx))
if scale >= 1:
    fontSize = scale * font.nativeSizePx / devicePixelRatio
    // the 80-column block may be narrower than availableWidth; centre it
else:
    fall back to fitFontSize and log a warning
```

Line height for these fonts must also land on whole physical pixels.

### Horizontal overflow

- Content width = `max(80, longestLineInPhile)` × glyph advance.
- All lines scroll horizontally together, as one block. Individual lines never scroll independently.
- At fit, columns 1 to 80 are visible at horizontal offset zero.
- App chrome must never scroll horizontally with the content.

### Font rendering

- Disable ligatures and contextual alternates on every font: `FontFeature.disable('liga')`, `FontFeature.disable('calt')`.
- Never allow system glyph fallback to change column alignment. A character missing from the active font is drawn as a same-width placeholder (see the fonts stage). In the spike, it is acceptable to note fallback without handling it.

### Virtualisation and position

- Render lines lazily with a fixed item extent equal to `lineHeight`. Scroll offset and line index then map 1:1 by arithmetic.
- Reading position is stored as `(topLineIndex, fractionIntoLine, columnOffset)`, never as a pixel offset.
- On any metrics change (rotation, font change, zoom change, safe-area change), restore position from that tuple after the new layout.

### Chrome

- Chrome (top bar and any bottom bar) is an **overlay** on top of the text. Showing or hiding it must not change the text layout or move any line.
- Scrolling down hides chrome. Scrolling up reveals it. A single tap on the text toggles it.
- When chrome is hidden, the system UI enters immersive mode (`SystemUiMode.immersiveSticky`). When shown, edge-to-edge (`SystemUiMode.edgeToEdge`).

## Test fixtures

Copyright note: Phrack text is not committed to the repository. Two kinds of fixtures are used.

- **Synthetic fixtures** in `test/fixtures/` written by the implementer: exact 80-column lines, lines of 79 and 132 columns, tab-indented code, CRLF and LF endings, box-drawing characters, Latin-1 accented characters, raw CP437 high bytes, a form feed, an ANSI escape sequence, a 10,000-line file, and an empty file. These drive all automated tests.
- **Real philes** for manual testing, placed by the developer in `assets/dev/` (git-ignored). Use one phile from the 1980s and one from the most recent issue. Provide a script `tool/fetch_dev_philes.dart` that downloads them from the Phrack site on demand.

## Stage overview

Build in this order. Each stage ends in a runnable app and a passing test suite.

| Stage | Name | Outcome |
|---|---|---|
| A | Rendering spike | Proves the reader works: fit-to-80, overflow, rotation, chrome, two fonts |
| B | Ingestion and normalisation | Raw bytes become clean line lists, fully unit-tested |
| C | Archive download and storage | Full archive on device, in SQLite |
| D | Library navigation | Browse issues and philes, open the reader |
| E | Font system | Manifest-driven fonts, coverage checks, credits |
| F | Themes | Built-in and custom colour themes |
| G | Reader polish | Persistence, zoom, copy, orientation controls, keep-awake |
| H | Search | Full-text search across the archive |
| I | Section navigation | Jump list parsed from phile headers |
| J | CRT effect | Optional shader effect |
| K | Release hardening | Accessibility, performance, store readiness |

## Stage A: Rendering spike

**Purpose:** prove or kill the hard parts before any other investment. This stage is throwaway-quality outside the reader widget, but the reader's layout logic should be written cleanly enough to keep.

### Scope

- New Flutter project, single screen: the reader.
- Loads one text file from `assets/dev/` (or a synthetic fixture if absent), splits it into lines, expands tabs. Assume UTF-8 with Latin-1 fallback; full decoding comes in Stage B.
- Implements every rule in Core rendering rules, except glyph placeholder substitution.
- Two bundled fonts:
  - One modern vector monospace font under SIL OFL that ships ligatures by default, to prove ligatures are disabled (**Verify** licence).
  - One pixel font from VileR's Ultimate Oldschool PC Font Pack (**Verify** licence; believed CC BY-SA 4.0).
- Two hardcoded themes: a dark green phosphor theme and a light paper theme.
- A debug menu in the chrome to switch file, font, theme, and orientation mode (Auto, Portrait, Landscape) using `SystemChrome.setPreferredOrientations`.
- A debug overlay, toggleable, showing: computed font size, scale factor (pixel fonts), lineHeight, top line index, column offset, devicePixelRatio, and available width.

### Implementation notes

- A layout calculator should be a pure Dart class with no Flutter widget dependencies: input viewport metrics, font metrics, and file stats; output font size, line height, content width, and block offset. This is the main unit-test target.
- For the scroll structure, either a `TwoDimensionalScrollView` or a horizontal scroll view wrapping a fixed-width vertical list with a fixed item extent is acceptable. Choose whichever makes chrome-as-overlay and line-anchored restore simplest, and record the choice and why in `docs/decisions.md`.
- Each line is a single `Text` (or `RichText`) with `softWrap: false`, `maxLines: 1`, and `overflow: TextOverflow.visible`, or a custom painter if profiling shows `Text` is too slow.

### Acceptance criteria

- At fit, in portrait and landscape on a phone, exactly 80 columns are visible for both fonts. Verified by a golden test at fixed viewport sizes and on a physical device.
- A 132-column line scrolls horizontally, and all other lines move with it. Chrome does not move.
- Rotating the device at any point in a 10,000-line file returns to the same top line within ±1 line, and the same column offset. Covered by an integration test that triggers metrics changes programmatically.
- Switching fonts mid-file preserves the top line.
- The pixel font renders at an integer scale. The debug overlay shows the scale. Text is visibly crisp on a physical device at 100% screenshot zoom.
- Ligature-prone sequences (`->`, `!=`, `==`, `<=`, `www`) render as separate characters in the vector font. Covered by a golden test.
- Chrome hides on downward scroll, reveals on upward scroll, and toggles on tap. No line moves when chrome appears or disappears.
- Scrolling a 10,000-line file holds 60 fps in profile mode on a mid-range Android device. Record results.
- Unit tests cover the layout calculator: fit size, integer scaling, the scale-below-one fallback, safe-area handling, and content width for overflow files.

### Decision gate

At the end of this stage, write a short report in `docs/spike-report.md` covering:

- Whether 80-column portrait is legible with each font on a typical phone (subjective, with screenshots).
- How pixel fonts behave on devices where integer scale is only 1×, including how much margin is wasted.
- Frame timing results.
- Any rendering differences between iOS and Android.
- Whether the chosen scroll structure should be kept.

Stop and wait for review before starting Stage B.

## Stage B: Ingestion and normalisation

**Purpose:** convert raw phile bytes into the line model, so the renderer never sees encoding problems.

### Scope

A pure Dart library, `lib/ingest/`, with no Flutter dependency.

- **Decoding chain:** strict UTF-8; if invalid, choose between CP437 and Latin-1 using a heuristic based on the high-byte distribution (box-drawing range 0xB0–0xDF suggests CP437). Record the detected encoding per phile. **Verify** the heuristic against the real archive and adjust it; log ambiguous files.
- **Line endings:** CRLF, LF, and lone CR all become line breaks.
- **Tabs:** expanded to 8-column stops.
- **Control characters:** form feeds become an empty line. ANSI escape sequences are stripped (and counted). Other C0 controls become a visible placeholder character. Record counts.
- **Trailing whitespace** is preserved. It costs nothing and keeps the text faithful.
- **Character inventory:** the set of distinct code points used by each phile, stored for font coverage checks in Stage E.
- **Statistics:** line count and longest line in columns.

### Acceptance criteria

- Every synthetic fixture produces the expected line list. Each fixture has a test.
- A batch run over every phile in the archive (developer tool, not a test) completes with no exceptions, and outputs a CSV of encoding, line count, longest line, and control-character counts per phile. This CSV drives the **Verify** item above.
- Re-running normalisation on its own output is a no-op.

## Stage C: Archive download and storage

**Purpose:** get the full archive on the device, once, robustly.

### Scope

- **Source:** the Phrack site's per-issue archives. **Verify** the archive URL pattern, format (believed to be gzipped tarballs of raw text), and whether issue and phile metadata are inside the archive or must come from elsewhere. Document findings before writing the downloader.
- **Fetching:** first-launch download of all issues with visible progress, cancellation, and resume after interruption. Fetch issues sequentially with a polite delay and an identifying user agent. Handle offline and partial-failure states.
- **Updates:** a manual "Check for new issues" action that fetches only issues not already stored.
- **Storage schema (drift):**
  - `issues`: number, release date if known, title if known, fetched-at timestamp, source checksum.
  - `philes`: issue number, phile number, title, author (nullable), encoding, line count, longest line, character inventory.
  - `phile_text`: phile id, normalised text stored as a single blob with line-start offsets, so a line can be read without splitting the whole file.
  - `reading_state`: phile id, top line index, fraction, column offset, updated-at.
- **Metadata:** extract title and author from phile headers where present. Fall back to "Phile N" when absent. Do not guess.
- Content lives in the app's support directory, excluded from cloud backup.

### Acceptance criteria

- Fresh install, airplane mode off: the full archive downloads, and the app reports the counts of issues and philes stored.
- Killing the app mid-download and relaunching resumes without re-downloading completed issues.
- Airplane mode during download produces a clear, recoverable error.
- Reading any line of any phile from storage completes in under 5 ms (measure on a mid-range device).
- Unit tests for the archive parser use a small synthetic tarball fixture.

## Stage D: Library navigation

**Purpose:** a usable app.

### Scope

- Issues screen: list of all issues, newest first, with release date where known. Downloaded state is visible.
- Issue screen: list of philes with title and author.
- Tapping a phile opens the Stage A reader, now fed from storage.
- First-launch flow: explain the download, its approximate size, and start it on confirmation.
- Settings screen stub (font, theme, orientation), carried over from the spike's debug menu.

### Acceptance criteria

- Navigate from launch to any phile in three taps or fewer.
- Back navigation from the reader returns to the same scroll position in the phile list.
- Widget tests for each screen with a seeded in-memory database.

## Stage E: Font system

**Purpose:** multiple bundled fonts, including retro fonts, without breaking alignment.

### Scope

- **Font manifest** at `assets/fonts/manifest.json`. Each entry includes: id, display name, family, file paths, `integerScale` (bool), `cellWidthPx` and `nativeSizePx` (pixel fonts only), `lineHeightRatio`, licence name, licence URL, and attribution text.
- Ship four to six fonts covering both styles. Candidates to evaluate (**Verify** each licence before inclusion): fonts from VileR's Ultimate Oldschool PC Font Pack, VT323, IBM Plex Mono, Terminus. Prefer fonts with full CP437 and Latin-1 coverage.
- **Coverage map:** at build or first launch, compute the set of code points each font supports.
- **Placeholder substitution:** at render time, characters missing from the active font are drawn as a same-width placeholder glyph from that font (for example `?` or `·`), never via system fallback.
- **Coverage warning:** when opening a phile whose character inventory is not fully covered by the active font, show a dismissible notice that offers a compatible font.
- **Credits screen** listing every font with licence and attribution.
- Font selection persists globally.

### Acceptance criteria

- A golden test renders the box-drawing fixture in every bundled font, with columns aligned in all of them.
- A golden test confirms placeholder substitution keeps alignment when a glyph is missing.
- Adding a font requires only an asset file and a manifest entry, with no code changes.

## Stage F: Themes

### Scope

- A theme defines: background, foreground, selection, accent (chrome and highlights), and dim (secondary text in lists).
- Built-ins: green phosphor, amber phosphor, paper, and high contrast. Implementer may add one or two more.
- Custom themes: create, edit, and delete via colour pickers, with a live preview using a sample of text.
- Contrast check: warn (do not block) when foreground/background contrast falls below WCAG AA for normal text.
- The theme applies to the reader and the whole app chrome.

### Acceptance criteria

- Golden tests for the reader in each built-in theme.
- Custom themes survive restarts.
- The contrast warning triggers correctly in unit tests.

## Stage G: Reader polish

### Scope

- **Reading position** persisted per phile and restored on open. A "continue reading" entry on the issues screen.
- **Zoom:** pinch to zoom beyond fit (minimum is fit). Vector fonts zoom continuously; integer-scale fonts step through integer scales. Zoom resets to fit on rotation. Horizontal scrolling covers the extra width.
- **Copy:** long-press a line to select the contiguous non-blank block around it (a paragraph or code block) and offer Copy. Selection within the visible screen is a nice-to-have. **Verify** the behaviour of Flutter's selection in lazily built lists before attempting cross-screen selection.
- **Orientation control** in the reader chrome: Auto, Portrait, Landscape. This works even when the system rotation lock is on.
- **Keep-awake** while the reader is open (setting, on by default).
- **Volume-button paging** on Android only (setting, off by default). Do not attempt it on iOS.
- **Progress indicator** in the chrome: percentage through the phile.

### Acceptance criteria

- Close and reopen the app: the reader restores the exact line and column.
- Zoom is preserved during scrolling and reset on rotation, with position held.
- Copy produces the exact original text of the block, including leading whitespace.
- Integration tests for position persistence and the orientation toggle.

## Stage H: Search

### Scope

- FTS5 index over normalised text, built after download and updated when new issues arrive. Index build runs in a background isolate with progress.
- Search screen with results grouped by issue, showing phile title and a one-line snippet.
- Opening a result jumps to the matching line, with the match highlighted.
- Filters: issue range, and title/author only.

### Acceptance criteria

- Searching for a known string returns it in under 300 ms on a mid-range device.
- Jump-to-match lands with the matched line visible and highlighted.
- Search works with no network connection.

## Stage I: Section navigation

### Scope

- Parse section headers from philes where a recognisable pattern exists. Modern issues use consistent section markers; older ones mostly do not. **Verify** the patterns against the archive and keep the parser conservative: no table of contents is better than a wrong one.
- A jump list in the reader chrome, shown only when sections were found.

### Acceptance criteria

- Unit tests for the parser on synthetic examples of each supported pattern.
- No false positives on a sample of twenty early-era philes (developer check, recorded in `docs/decisions.md`).

## Stage J: CRT effect

### Scope

- An optional fragment shader over the reader: scanlines, slight bloom, and a phosphor tint taken from the theme's foreground colour.
- Off by default. Intensity slider.
- Disabled automatically when the system's reduce-motion or reduce-transparency accessibility setting is on.

### Acceptance criteria

- The reader still holds 60 fps in profile mode with the effect on, on a mid-range device. If not, the effect ships disabled on devices that fail a quick benchmark.

## Stage K: Release hardening

### Scope

- **Accessibility:** library screens are fully screen-reader accessible. In the reader, screen readers should read line by line; ASCII art will be read as noise, and that is accepted. Support system text scaling in library screens (the reader's size is governed by the 80-column rule and zoom).
- **Tablets and foldables:** verify layout, including folds and window resizing.
- **Performance pass:** cold start, archive import, and memory use while reading the largest phile.
- **Store readiness:** app icons, privacy statement (no data collection), and credits for Phrack and every font. Contact the Phrack staff about the app before public release.
- **Crash-free behaviour** on malformed or truncated archives.

### Acceptance criteria

- Full test suite green on both platforms in CI.
- Manual test pass on at least one small phone, one large phone, and one tablet per platform, recorded in `docs/test-log.md`.

## Conventions for the implementing agent

- Keep layout maths, ingestion, and archive parsing in pure Dart with no Flutter imports, so they can be unit-tested directly.
- Every **Verify** item gets a dated entry in `docs/decisions.md` with what was checked, what was found, and what changed as a result.
- Never commit Phrack text to the repository.
- At the end of each stage, update `README.md` with how to run the app and the tests, then stop for review.
