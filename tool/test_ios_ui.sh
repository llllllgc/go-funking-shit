#!/usr/bin/env bash
# Always creates a fresh disposable simulator; never accepts an existing device.
set -euo pipefail
cd "$(dirname "$0")/.."
# Notification authorization persists outside the app process. Each scenario
# therefore starts on its own new device, including in the default full suite.
if [[ -z "${LALEMA_UI_TEST:-}" ]]; then
  for qa_case in testRecordPersistsAndBackupRestoresThroughSystemFiles testFirstNotificationApprovalPersists testReminderPermissionRecoveryAndDelivery; do
    LALEMA_UI_TEST="$qa_case" bash tool/test_ios_ui.sh
  done
  exit 0
fi
qa_flutter="${LALEMA_FLUTTER:-flutter}"
qa_runtime="${LALEMA_UI_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-4}"
qa_type="${LALEMA_UI_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
mkdir -p build/ui-test-results
qa_results="$(mktemp -d build/ui-test-results/run.XXXXXX)"
qa_build="$(mktemp -d "${TMPDIR:-/tmp}/lalema-ui-build.XXXXXX")"
qa_device=''
cleanup_ui_test() {
  qa_exit=$?
  trap - EXIT
  if [[ "${LALEMA_KEEP_UI_SIMULATOR:-0}" != 1 ]]; then
    if [[ -n "$qa_device" ]]; then
      xcrun simctl shutdown "$qa_device" >/dev/null 2>&1 || true
      xcrun simctl delete "$qa_device" || true
    fi
    rm -rf "$qa_build"
  fi
  exit "$qa_exit"
}
trap cleanup_ui_test EXIT
qa_device="$(xcrun simctl create 'Lalema Disposable UI QA' "$qa_type" "$qa_runtime")"
printf '%s\n' "$qa_device" > "$qa_results/simulator-id.txt"
printf '%s\n' "$qa_build" > "$qa_results/build-path.txt"
printf 'UI test results: %s\n' "$qa_results"
"$qa_flutter" build ios --simulator --debug --no-pub --target lib/main.dart > "$qa_results/flutter-build.log" 2>&1
xcrun simctl bootstatus "$qa_device" -b
qa_test_args=(test)
if [[ -n "${LALEMA_UI_TEST:-}" ]]; then
  qa_test_args=("-only-testing:RunnerUITests/RunnerUITests/$LALEMA_UI_TEST" test)
fi
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner-UI -configuration Debug \
  -destination "platform=iOS Simulator,id=$qa_device" \
  -parallel-testing-enabled NO \
  -derivedDataPath "$qa_build" -resultBundlePath "$qa_results/results.xcresult" \
  CODE_SIGNING_ALLOWED=NO FLUTTER_BUILD_MODE=debug "${qa_test_args[@]}"
