#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
documentation_output=$(mktemp -d "${TMPDIR:-/tmp}/crave-storefront-docs.XXXXXX")
trap 'rm -rf "$documentation_output"' EXIT HUP INT TERM

cd "$repository_root"

dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart doc --output="$documentation_output"
dart pub outdated --no-dependency-overrides
./tool/check_secrets.sh

if [ "${SKIP_FLUTTER_CONSUMER:-0}" = '1' ]; then
  echo 'Flutter consumer verification skipped by explicit request.'
elif command -v flutter >/dev/null 2>&1; then
  (
    cd tool/flutter_consumer
    flutter pub get
    flutter analyze
    flutter test
  )
else
  echo 'Flutter is required. Install Flutter stable or set SKIP_FLUTTER_CONSUMER=1 for a Dart-only local check.' >&2
  exit 1
fi

echo 'SDK development verification passed.'
