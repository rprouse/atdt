#!/usr/bin/env bash
# Runs the Android device tests in CI, one file at a time. Each gets ten
# minutes and one retry: first launches on a fresh emulator occasionally
# never connect or lose the test connection (docs/decisions.md), while a
# real failure fails twice. A failed attempt prints the emulator's Flutter
# and crash log.
set -u
status=0
for file in "$@"; do
  passed=false
  for attempt in 1 2; do
    if timeout 600 flutter test "$file"; then
      passed=true
      break
    fi
    echo "::warning::$file attempt $attempt failed or stalled"
    adb logcat -d | grep -E "flutter|AndroidRuntime|FATAL|DEBUG|Impeller" | tail -150
  done
  $passed || status=1
done
exit $status
