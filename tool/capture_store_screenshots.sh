#!/usr/bin/env bash
# Only use explicitly selected, isolated Lalema simulators. Produces synthetic
# screen images, not test evidence for navigation or actual notification delivery.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_command="${LALEMA_FLUTTER:-flutter}"
if [[ -z "${LALEMA_CAPTURE_SIMULATORS:-}" ]]; then
  echo 'Set LALEMA_CAPTURE_SIMULATORS to comma-separated isolated simulator UUIDs.' >&2
  exit 1
fi
IFS=' ' read -r -a capture_screens <<< "${LALEMA_CAPTURE_SCREENS:-today record history data settings knowledge about}"
for capture_screen in "${capture_screens[@]}"; do
  case "$capture_screen" in today|record|history|data|settings|knowledge|about) ;; *) echo 'Invalid capture screen' >&2; exit 1 ;; esac
done
IFS=',' read -r -a capture_devices <<< "$LALEMA_CAPTURE_SIMULATORS"
for capture_device in "${capture_devices[@]}"; do
  xcrun simctl list devices --json | python3 -c 'import json,sys; uid=sys.argv[1]; device=next(x for values in json.load(sys.stdin)["devices"].values() for x in values if x["udid"]==uid); assert device["name"].startswith("Lalema "), "Use an isolated Lalema simulator"' "$capture_device"
  xcrun simctl bootstatus "$capture_device" -b
  xcrun simctl status_bar "$capture_device" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState discharging --batteryLevel 100
  mkdir -p "build/release-materials/screenshots/$capture_device"
done
mkdir -p build/release-materials/logs
restore_capture_environment() {
  capture_exit_code=$?
  trap - EXIT
  if "$flutter_command" build ios --simulator --debug --no-pub --target lib/main.dart > build/release-materials/logs/restore-main.log 2>&1; then
    for capture_device in "${capture_devices[@]}"; do
      xcrun simctl install "$capture_device" build/ios/iphonesimulator/Runner.app || capture_exit_code=1
    done
  else
    capture_exit_code=1
  fi
  for capture_device in "${capture_devices[@]}"; do
    xcrun simctl status_bar "$capture_device" clear || capture_exit_code=1
    xcrun simctl shutdown "$capture_device" || capture_exit_code=1
  done
  exit "$capture_exit_code"
}
trap restore_capture_environment EXIT
for capture_screen in "${capture_screens[@]}"; do
  "$flutter_command" build ios --simulator --debug --no-pub --target tool/store_capture_main.dart --dart-define="CAPTURE_SCREEN=$capture_screen" > "build/release-materials/logs/$capture_screen.log" 2>&1
  for capture_device in "${capture_devices[@]}"; do
    xcrun simctl install "$capture_device" build/ios/iphonesimulator/Runner.app
    capture_container="$(xcrun simctl get_app_container "$capture_device" com.lalema.lalema data)"
    python3 -c 'from pathlib import Path; import sys; Path(sys.argv[1]).unlink(missing_ok=True)' "$capture_container/tmp/lalema-capture-version.json"
    xcrun simctl launch --terminate-running-process "$capture_device" com.lalema.lalema
    python3 -c 'import json,sys,time; from pathlib import Path; f=Path(sys.argv[1]); deadline=time.monotonic()+20
while not f.exists():
  if time.monotonic()>deadline: raise SystemExit("Capture metadata did not arrive")
  time.sleep(.2)
time.sleep(1)' "$capture_container/tmp/lalema-capture-version.json"
    python3 -c 'import json,sys; value=json.load(open(sys.argv[1])); assert value["screen"]==sys.argv[2] and value["syntheticRecords"] is True and "renderError" in value and value["renderError"] is None and value.get("viewPaddingTop", 0)>0; print(value["version"],value["build"],value["screen"])' "$capture_container/tmp/lalema-capture-version.json" "$capture_screen"
    cp "$capture_container/tmp/lalema-capture-version.json" "build/release-materials/screenshots/$capture_device/$capture_screen.json"
    xcrun simctl io "$capture_device" screenshot --type=jpeg "build/release-materials/screenshots/$capture_device/$capture_screen.jpg"
  done
done
# The EXIT handler restores and shuts down all selected simulators.
