# Manual test log

Stage K acceptance: a manual pass on at least one small phone, one large phone and one tablet per platform. Record each pass here: the date, device, OS, build (`flutter build ... --release`, or profile for frame times) and the result of each check. Note anything that fails, with what was seen.

## Checklist

Run on a fresh install unless noted.

1. **First launch:** the welcome screen explains the download; tapping Download the archive fetches all 72 issues with progress. Note how long it takes.
2. **Cold start with the archive stored:** force-stop, then launch. Note the seconds to the library.
3. **Library:** issues newest first; open an issue, then a phile; Continue reading returns to it after a restart.
4. **Reader:** 80 columns at fit in portrait and landscape; rotate mid-phile and the same line stays on top; pinch zoom; tap toggles the chrome without moving text; long-press copies a block exactly.
5. **Fonts and themes:** each font and built-in theme; a custom theme survives a restart.
6. **Search:** a known phrase finds its phile; opening a result lands on the highlighted line; works in airplane mode.
7. **Sections:** a modern phile (e.g. 57/8, Vudo malloc tricks) shows the jump list; an early phile shows none.
8. **CRT effect:** visible at 60%; the debug overlay shows 0 frames over 16.7 ms while scrolling (profile or release build).
9. **Largest phile:** 71/7 opens and scrolls end to end.
10. **Accessibility:** TalkBack / VoiceOver reads the library and each reader line; the chrome stays while the screen reader runs. System text at the largest size: library screens lay out.
11. **Interruptions:** airplane mode mid-download shows a retryable error; killing the app mid-download resumes on the next launch.
12. **Tablet / foldable only:** resize the window (split screen or freeform) mid-phile and the position holds; on a foldable, half-open the hinge and the text stays in one pane.

## Passes

| Date | Device | OS | Build | Result |
|---|---|---|---|---|
| 2026-10-17 | Galaxy S23 Ultra (SM-S918W), large phone | Android | owner's build | Owner: "responsive and looks good". The CRT effect at the first tuning was too subtle (since retuned). Frame times not yet recorded. |
| 2026-10-18 | Android emulator (sdk_gphone64_x86_64, 1080x2400), large phone | Android 16, Impeller GLES | profile and release | Checks 1-9 and 11 over Stages B-K (see docs/decisions.md). Release build downloads the archive (needed the INTERNET fix). Cold start with the archive stored: 5.8-7.4 s in release (5-7 s in profile), dominated by an emulator main-thread stall. Killing the app mid-download (at issue 53) resumed on the next launch ("Downloading issue 63 (1 of 10)" after further kills). 71/7 open: 204 MB PSS, stable across repeated opens. |
| 2026-10-18 | Same emulator at 1600x2560 and 2560x1600, tablet sizes | Android 16 | profile | Library lays out; reader fits 80 columns; resizing between the two kept the position (check 12, resize). Not a real tablet. |
| 2026-10-19 | Android emulator (Pixel 7, API 36), cold-booted | Android 16 | debug | Full archive downloaded in 162 s (debug build) and indexed; `app_test` with the archive stored passes (library, issue, phile, reader, back) after fixing the test's race. |
| 2026-10-19 | Galaxy S23 Ultra (SM-S918W), large phone, 120 Hz | Android 16 | profile | Owner's pass. Cold start with the archive stored: under 1 s. CRT effect on: almost always 60 fps (debug overlay), with an occasional dropped frame. Search for a known phrase: 24 ms. 71/7 renders and scrolls smoothly. Download fast enough; time not recorded. Skipped by the owner: airplane-mode interruption, and TalkBack (a personal app; the automated accessibility tests stand). |
| | Small Android phone | | | **To do** |
| | Android tablet | | | **To do** |
| | Small iPhone | | | **To do** (needs a Mac for the build) |
| | Large iPhone | | | **To do** |
| | iPad | | | **To do** |
