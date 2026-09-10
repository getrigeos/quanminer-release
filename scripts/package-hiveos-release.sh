#!/usr/bin/env bash
# Build the canonical quanminer-<version>.tar.gz HiveOS package around the
# unmodified third-party quanpool-miner linux binary.
set -euo pipefail
[[ $# -ge 1 && $# -le 2 ]] || { echo 'usage: package-hiveos-release.sh <quanpool-miner-binary> [output-dir]' >&2; exit 2; }
for tool in bash gzip install sha256sum tar; do
  command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done
binary=$1
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output=${2:-"$root/dist"}
test -x "$binary" || { echo "binary missing or not executable: $binary" >&2; exit 1; }
version=$("$binary" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
test -n "$version" || { echo 'cannot determine quanpool-miner version' >&2; exit 1; }
manifest_version=$(awk -F= '/^CUSTOM_VERSION=/ {print $2; exit}' "$root/packaging/hiveos/h-manifest.conf")
[[ $manifest_version == "$version" ]] || { echo "h-manifest CUSTOM_VERSION=$manifest_version != binary $version" >&2; exit 1; }

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
package="$stage/quanminer"
install -d -m 0755 "$package"
install -m 0755 "$binary" "$package/quanpool-miner"
install -m 0644 "$root/packaging/hiveos/h-manifest.conf" "$package/h-manifest.conf"
install -m 0755 "$root/packaging/hiveos/h-config.sh" "$package/h-config.sh"
install -m 0755 "$root/packaging/hiveos/h-run.sh" "$package/h-run.sh"
install -m 0755 "$root/packaging/hiveos/h-stats.sh" "$package/h-stats.sh"
install -m 0644 "$root/packaging/hiveos/h-readme.md" "$package/h-readme.md"
bash -n "$package/h-config.sh" "$package/h-run.sh" "$package/h-stats.sh"

install -d -m 0755 "$output"
artifact="$output/quanminer-${version}.tar.gz"
tar -C "$stage" -czf "$artifact" quanminer
( cd "$output" && sha256sum "$(basename "$artifact")" > "$(basename "$artifact").sha256" )
sha256sum "$binary" > "$output/quanpool-miner-linux-x86_64.sha256.upstream"
echo "package: $artifact"
cat "$artifact.sha256"
