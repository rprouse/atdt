# Decisions log

Dated record of every **Verify** item from the spec, plus significant design decisions. Newest entries at the bottom.

Each entry records:

- **Checked:** what was examined, and how
- **Found:** the result
- **Changed:** what was done as a result (or "nothing")

## Open Verify items

| Stage | Item | Status |
|---|---|---|
| — | FTS5 included in the SQLite build bundled by `sqlite3_flutter_libs` | Open |
| A | Licence of the vector monospace font (SIL OFL, ships ligatures) | Open |
| A | Licence of VileR's Ultimate Oldschool PC Font Pack (believed CC BY-SA 4.0) | Open |
| A | Scroll structure choice (`TwoDimensionalScrollView` vs nested scroll views) | Open |
| B | CP437 vs Latin-1 heuristic against the real archive | Open |
| C | Archive URL pattern, format, and metadata location | Open |
| E | Licence of each candidate font | Open |
| G | Flutter selection behaviour in lazily built lists | Open |
| I | Section header patterns across the archive | Open |

---

## 2026-10-16: Repository housekeeping

- **Checked:** how to keep the byte-exact fixtures required by the spec (CRLF, lone CR, CP437 bytes) intact on a Windows dev machine.
- **Found:** Git's line-ending normalisation and editor settings would rewrite them.
- **Changed:** `.gitattributes` marks `test/fixtures/**` as `-text`; `.editorconfig` turns off its rules for that folder.
