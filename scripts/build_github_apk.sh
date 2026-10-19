#!/usr/bin/env bash
# Builds the GitHub-release APKs without Bookerly (Amazon's font, not licensed
# for redistribution). The Play Store build keeps it.
#
# How: for the length of the build it swaps in the public versions of the two
# font files that differ locally (they are git skip-worktree), and moves
# Bookerly.ttf out of the font folder (sakura_epub bundles the whole folder).
# Everything is put back on exit, even if the build fails.
#
# Usage: scripts/build_github_apk.sh [extra flutter build args]
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

FONT_DIR=third_party/sakura_epub-0.1.3-aread/lib/assets/fonts
SWAPPED=(
  lib/src/data/engine/sakura_fonts.dart
  third_party/sakura_epub-0.1.3-aread/pubspec.yaml
)
NOT_FOR_GITHUB=(Bookerly.ttf)
# Must never appear in a GitHub APK.
BANNED='Bookerly|Amazon-Ember|NewYork|Gilroy'

STASH=$(mktemp -d)
restore() {
  for f in "${SWAPPED[@]}"; do
    [[ -f "$STASH/files/$f" ]] && cp "$STASH/files/$f" "$f"
  done
  for font in "${NOT_FOR_GITHUB[@]}"; do
    [[ -f "$STASH/fonts/$font" ]] && mv "$STASH/fonts/$font" "$FONT_DIR/$font"
  done
  rm -rf "$STASH"
}
trap restore EXIT

mkdir -p "$STASH/fonts"
for f in "${SWAPPED[@]}"; do
  mkdir -p "$STASH/files/$(dirname "$f")"
  cp "$f" "$STASH/files/$f"
  git show ":$f" > "$f"  # staged = public version
done
for font in "${NOT_FOR_GITHUB[@]}"; do
  [[ -f "$FONT_DIR/$font" ]] && mv "$FONT_DIR/$font" "$STASH/fonts/$font"
done

# Old GitHub APKs may predate this script; don't let them linger.
rm -f build/app/outputs/flutter-apk/app-*github-release.apk*

flutter build apk --release --flavor github --split-per-abi "$@"

# Check every GitHub APK before calling it done.
status=0
for apk in build/app/outputs/flutter-apk/app-*github-release.apk; do
  if unzip -l "$apk" | grep -E "$BANNED"; then
    echo "ERROR: $apk contains a font that must not be published." >&2
    status=1
  fi
done
[[ $status -eq 0 ]] && echo "OK: GitHub APKs contain only freely licensed fonts."
exit $status
