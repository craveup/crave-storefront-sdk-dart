#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  echo 'Release verification requires a clean working tree.' >&2
  exit 1
fi

package_version=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml)
release_tag=$(git tag --points-at HEAD --list "v${package_version}")
if [ "$release_tag" != "v${package_version}" ]; then
  echo "Release verification requires exact tag v${package_version} at HEAD." >&2
  exit 1
fi
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo 'Release verification requires HEAD to be contained in origin/main.' >&2
  exit 1
fi
pana_version=${PANA_VERSION:-0.23.17}
case "$pana_version" in
  '0.23.12' | '0.23.17') ;;
  *)
    echo 'PANA_VERSION must be the current release pin or documented compatibility fallback.' >&2
    exit 1
    ;;
esac
installed_pana=$(dart pub global list | sed -n 's/^pana[[:space:]]*//p')
if [ "$installed_pana" != "$pana_version" ]; then
  echo "Install pana ${pana_version} before release verification." >&2
  exit 1
fi

./tool/verify.sh
./tool/verify_web.sh
dart pub global run pana --no-warning --exit-code-threshold=0 .

# Validate the exact archive last, after every command that can execute package
# code, then prove no tracked or untracked release input changed.
dart pub publish --dry-run
if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  echo 'Release verification changed the working tree.' >&2
  exit 1
fi

echo 'SDK release verification passed.'
