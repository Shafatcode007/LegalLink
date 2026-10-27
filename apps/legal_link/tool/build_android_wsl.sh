#!/usr/bin/env bash
set -euo pipefail

flutter_bin="${1:?Pass the native Flutter executable}"
android_sdk="${2:?Pass the native Android SDK directory}"
export JAVA_HOME="${3:?Pass the native JDK directory}"
export ANDROID_HOME="$android_sdk"
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.jvmargs=-Xmx2g -Dorg.gradle.workers.max=2"
app_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$app_dir"

backup="$(mktemp)"
had_properties=0
if [ -f android/local.properties ]; then
  cp android/local.properties "$backup"
  had_properties=1
fi
restore_properties() {
  if [ "$had_properties" = 1 ]; then cp "$backup" android/local.properties; fi
  rm -f "$backup"
}
trap restore_properties EXIT
flutter_root="$(cd "$(dirname "$flutter_bin")/.." && pwd)"
printf 'sdk.dir=%s\nflutter.sdk=%s\n' "$android_sdk" "$flutter_root" > android/local.properties
"$flutter_bin" build apk --debug --no-pub
