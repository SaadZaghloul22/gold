#!/usr/bin/env bash
# Runs on the CI emulator: screen walkthrough with live prices + alert notification check.
set -u
mkdir -p screenshots
PKG=com.goldprices.today
( while true; do adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS >/dev/null 2>&1; sleep 1; done ) &
NOTIF=$!
: > screenshots/drive.txt
( until grep -q "Installing" screenshots/drive.txt; do sleep 1; done
  for i in $(seq 1 400); do
    if adb shell dumpsys notification --noredact | grep -q "pkg=$PKG.*id=1001"; then
      echo ok > screenshots/alert_ok
      adb shell cmd statusbar expand-notifications; sleep 3
      adb exec-out screencap -p > screenshots/14_alert_shade.png
      adb shell cmd statusbar collapse; break
    fi
    sleep 1
  done ) &
WATCH=$!
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart >> screenshots/drive.txt 2>&1
MAIN=$?
sleep 3; kill $WATCH $NOTIF 2>/dev/null
ALERT=1; [ -f screenshots/alert_ok ] && ALERT=0
adb shell dumpsys notification --noredact | grep -A8 "pkg=$PKG" > screenshots/notif_dump.txt
echo "main=$MAIN alert=$ALERT" > screenshots/status.txt
grep -E "GOLD|Some tests|All tests|EXCEPTION|Expected|Actual" screenshots/drive.txt | head -40
[ $MAIN -eq 0 ] && [ $ALERT -eq 0 ]
