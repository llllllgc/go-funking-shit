#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f android/key.properties ]]; then
  echo 'Run this check only in a checkout without signing credentials.' >&2
  exit 2
fi
signing_check_log=$(mktemp)
trap 'rm -f "$signing_check_log"' EXIT
if flutter build apk --release --no-pub >"$signing_check_log" 2>&1; then
  echo 'Release unexpectedly built without release signing credentials.' >&2
  exit 1
fi
if ! grep -Fq "Execution failed for task ':app:verifyReleaseSigning'." "$signing_check_log" ||
   ! grep -Fq 'Release signing is not configured' "$signing_check_log"; then
  cat "$signing_check_log"
  echo 'Release failed for a different reason; signing guard is not verified.' >&2
  exit 1
fi
echo 'PASS: release build refused missing signing credentials.'
