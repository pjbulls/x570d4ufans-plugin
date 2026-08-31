#!/bin/bash
# build.sh - packages source/ into a Slackware .txz for the x570d4ufans plugin.

set -euo pipefail
cd "$(dirname "$0")"

NAME="x570d4ufans"
VERSION="$(date +%Y.%m.%d)"
OUT="${NAME}-${VERSION}"

if ! command -v makepkg >/dev/null 2>&1; then
  echo "makepkg not found -- run this on Unraid or another Slackware-based system." >&2
  exit 1
fi

chmod +x source/etc/rc.d/rc.x570d4ufans
chmod +x source/usr/local/emhttp/plugins/x570d4ufans/scripts/*.sh
chmod +x source/usr/local/emhttp/plugins/x570d4ufans/event/*

mkdir -p archive/
rm -f "${OUT}.txz" "${OUT}.sha256" "archive/${OUT}.txz" "archive/${OUT}.sha265"
( cd source && makepkg -l y -c n "../$OUT.txz" )

echo "Built $OUT"
echo "$(sha256sum "${OUT}.txz" | awk '{print $1}')" > "${OUT}.sha256"
mv "${OUT}.txz" "${OUT}.sha256" archive/
