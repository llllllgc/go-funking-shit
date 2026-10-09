#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_simulator="${LALEMA_QA_SIMULATOR:-}"
if [[ -z "$qa_simulator" && -n "${CI:-}" ]]; then
  qa_simulator="$(xcrun simctl list devices available --json | python3 -c 'import json,sys; print(next(d["udid"] for group in json.load(sys.stdin)["devices"].values() for d in group if d["name"].startswith("iPhone") and d["isAvailable"]))')"
fi
if [[ -z "$qa_simulator" ]]; then
  echo 'Set LALEMA_QA_SIMULATOR to an isolated iPhone simulator UUID.' >&2
  exit 1
fi
xcrun simctl bootstatus "$qa_simulator" -b
mkdir -p build/native-test-results
qa_results="$(mktemp -d build/native-test-results/run.XXXXXX)"
qa_build="$(mktemp -d "${TMPDIR:-/tmp}/lalema-native-build.XXXXXX")"
trap 'rm -rf "$qa_build"' EXIT
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination "platform=iOS Simulator,id=$qa_simulator" \
  -parallel-testing-enabled YES -maximum-parallel-testing-workers 1 \
  -derivedDataPath "$qa_build" \
  -resultBundlePath "$qa_results/results.xcresult" \
  CODE_SIGNING_ALLOWED=NO FLUTTER_BUILD_MODE=debug test
