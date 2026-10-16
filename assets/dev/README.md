# Real philes for manual testing

Put real Phrack philes here as `.txt` files. Everything in this folder except
this README is git-ignored: **never commit Phrack text**.

Fetch the two default philes (one from 1985, one from the latest issue) with:

```sh
dart run tool/fetch_dev_philes.dart
```

When this folder has no `.txt` files, the Stage A reader falls back to the
synthetic fixtures in `test/fixtures/`.
