#!/usr/bin/env bash
set -euo pipefail

output_directory=${1:-out/deps/hashlink}
mkdir -p "$output_directory"
output_directory="$(cd "$output_directory" && pwd)"
archive="${output_directory}.tar.gz"

case "$(uname -m)" in
	x86_64) architecture=amd64 ;;
	aarch64 | arm64) architecture=arm64 ;;
	i386 | i686) architecture=i386 ;;
	*)
		echo "Unsupported HashLink Linux architecture: $(uname -m)" >&2
		exit 1
		;;
esac

asset_url=$(curl --fail --silent --show-error --location \
	https://api.github.com/repos/HaxeFoundation/hashlink/releases/tags/latest \
	| jq --raw-output --arg architecture "$architecture" \
		'first(.assets[] | select(.name | endswith("linux-" + $architecture + ".tar.gz")) | .browser_download_url) // empty')

if [[ -z "$asset_url" ]]; then
	echo "Could not find a Linux HashLink nightly release asset for $architecture." >&2
	exit 1
fi

curl --fail --location "$asset_url" --output "$archive"
tar -xzf "$archive" -C "$output_directory"

header=$(find "$output_directory" -type f -path '*/include/hl.h' -print -quit)
if [[ -z "$header" ]]; then
	echo "Could not locate the extracted HashLink SDK." >&2
	exit 1
fi

root=$(dirname "$(dirname "$header")")
if [[ -n "${GITHUB_ENV:-}" ]]; then
	echo "HASHLINK=$root" >> "$GITHUB_ENV"
	echo "LD_LIBRARY_PATH=$root${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" >> "$GITHUB_ENV"
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
	echo "$root" >> "$GITHUB_PATH"
fi
echo "$root"
