#!/usr/bin/env bash
# Resolve the latest STABLE Intel ethernet-linux-i40e release and its tarball
# checksum. GitHub's releases/latest excludes pre-releases. Prints shell-style
# key=value lines suitable for $GITHUB_OUTPUT.
set -euo pipefail

api="https://api.github.com/repos/intel/ethernet-linux-i40e/releases/latest"
ver=$(curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} "$api" \
        | jq -r '.tag_name' | sed 's/^v//')
[ -n "$ver" ] && [ "$ver" != "null" ] || { echo "could not resolve latest i40e release" >&2; exit 1; }

url="https://github.com/intel/ethernet-linux-i40e/releases/download/v${ver}/i40e-${ver}.tar.gz"
tmp=$(mktemp)
curl -fsSL -o "$tmp" "$url"
sha=$(sha256sum "$tmp" | cut -d' ' -f1)
rm -f "$tmp"

echo "version=$ver"
echo "url=$url"
echo "sha256=$sha"
