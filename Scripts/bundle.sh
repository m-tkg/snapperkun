#!/usr/bin/env bash
# ビルド成果物を .app バンドルにまとめる。
# 使い方: bash Scripts/bundle.sh [debug|release]   (既定: release)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/Snapperkun.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)"

echo "==> Bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_DIR/Snapperkun" "$APP/Contents/MacOS/Snapperkun"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# アプリアイコン: Resources/AppIcon.png から .icns を生成する。
ICON_SRC="$ROOT/Resources/AppIcon.png"
if [[ -f "$ICON_SRC" ]]; then
  echo "==> Generating app icon"
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
fi

# ad-hoc 署名。自前ビルドでもアクセシビリティ権限の付与を安定させる。
echo "==> Codesign (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
echo "起動: open \"$APP\"   （初回はシステム設定 > プライバシーとセキュリティ > アクセシビリティ で許可）"
