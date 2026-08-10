#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
web_output=$(mktemp -d "${TMPDIR:-/tmp}/crave-storefront-web.XXXXXX")
trap 'rm -rf "$web_output"' EXIT HUP INT TERM

cd "$repository_root"

dart compile js example/main.dart -o "$web_output/example.js"
dart test --platform chrome \
  test/errors_test.dart \
  test/http/transport_test.dart \
  test/models/json_reader_test.dart \
  test/runtime/request_runtime_test.dart \
  test/runtime/cart_session_runtime_test.dart \
  test/session/session_store_test.dart

echo 'SDK web verification passed.'
