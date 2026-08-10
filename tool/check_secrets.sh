#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

file_list=$(mktemp "${TMPDIR:-/tmp}/crave-storefront-files.XXXXXX")
hit_list=$(mktemp "${TMPDIR:-/tmp}/crave-storefront-hits.XXXXXX")
trap 'rm -f "$file_list" "$hit_list"' EXIT HUP INT TERM

git ls-files --cached --others --exclude-standard >"$file_list"

credential_pattern='-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----|AKIA[A-Z0-9]{16}|AIza[A-Za-z0-9_-]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk_live_[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9-]{16,}|eyJ[A-Za-z0-9_-]{16,}\.eyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}'

while IFS= read -r path; do
  [ -f "$path" ] || continue

  case "$path" in
    .dart_tool/* | build/* | doc/api/* | tool/flutter_consumer/.dart_tool/* | tool/flutter_consumer/build/*)
      continue
      ;;
    .env | .env.*)
      case "$path" in
        *.example | *.sample) ;;
        *) printf '%s\n' "$path" >>"$hit_list" ;;
      esac
      continue
      ;;
  esac

  if LC_ALL=C grep -I -E -l -- "$credential_pattern" "$path" >/dev/null 2>&1; then
    printf '%s\n' "$path" >>"$hit_list"
  fi
done <"$file_list"

if [ -s "$hit_list" ]; then
  echo 'Potential credential material was found in these files:' >&2
  sort -u "$hit_list" >&2
  echo 'Values were intentionally not printed. Remove or rotate them before continuing.' >&2
  exit 1
fi

echo 'Credential-material scan passed.'
