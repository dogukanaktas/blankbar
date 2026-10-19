#!/bin/bash
# Writes the Homebrew formula for a released version into the tap repository.
#   scripts/update-formula.sh 1.0.0 [path/to/homebrew-tap]
set -euo pipefail

version=${1:?usage: $0 <version> [tap directory]}
tap=${2:-"$(cd "$(dirname "$0")/../.." && pwd)/homebrew-tap"}
url="https://github.com/dogukanaktas/blankbar/archive/refs/tags/v$version.tar.gz"

[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: '$version' is not X.Y.Z" >&2; exit 64; }
[ -d "$tap/Formula" ] || { echo "error: $tap/Formula does not exist" >&2; exit 1; }

# -f: fail on HTTP errors, so a missing tag cannot produce the checksum of an error page.
sha256=$(curl -fsSL "$url" | shasum -a 256 | cut -d' ' -f1)

sed "s|@URL@|$url|; s|@SHA256@|$sha256|" "$(dirname "$0")/blankbar.rb.in" > "$tap/Formula/blankbar.rb"
echo "Wrote $tap/Formula/blankbar.rb for v$version ($sha256)"
echo "Check it with: brew audit --strict --online dogukanaktas/tap/blankbar && brew install --build-from-source dogukanaktas/tap/blankbar && brew test blankbar"
