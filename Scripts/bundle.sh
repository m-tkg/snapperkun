#!/usr/bin/env bash
# ビルド成果物を .app バンドルにまとめる。
# 使い方: bash Scripts/bundle.sh [debug|release]   (既定: release)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"

# ローカル検証ビルド（LOCAL=1）はバンドル ID/表示名を分けて本番と権限(TCC)を分離する。
if [[ "${LOCAL:-}" == "1" ]]; then
  APP_NAME="Snapperkun (Local)"
  BUNDLE_ID="com.mtkg.snapperkun.local"
else
  APP_NAME="Snapperkun"
  BUNDLE_ID="com.mtkg.snapperkun"
fi
APP="$ROOT/$APP_NAME.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)"

echo "==> Bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_DIR/Snapperkun" "$APP/Contents/MacOS/Snapperkun"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# ローカル検証ビルドはバンドル ID/表示名を差し替える（CFBundleExecutable は Snapperkun のまま）。
if [[ "${LOCAL:-}" == "1" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$APP/Contents/Info.plist"
fi

# SwiftPM が生成するリソースバンドル（ローカライズ文字列 en/ja を含む）。
# Localization.swift の `L` が Contents/Resources から解決するため、ここに配置する。
# 取りこぼすと GUI が未ローカライズになるため、無ければビルドを失敗させる。
RES_BUNDLE="$BIN_DIR/Snapperkun_Snapperkun.bundle"
if [[ ! -d "$RES_BUNDLE" ]]; then
  echo "error: リソースバンドルが見つかりません: $RES_BUNDLE" >&2
  exit 1
fi
cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"

# メニューバー用アイコン（実行時に Bundle.main から読み込む）
if [[ -f "$ROOT/Resources/MenuBarIcon.png" ]]; then
  cp "$ROOT/Resources/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"
fi

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

# コード署名。
# SIGN_IDENTITY が指定されていれば、その安定した署名アイデンティティで署名する。
# 安定署名にすると、アップデートで .app を入れ替えてもアクセシビリティ権限(TCC)が保持される
# （アドホック署名はビルドごとに署名が変わり、権限が無効化されてしまう）。
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -n "$SIGN_IDENTITY" ]]; then
  # Developer ID 署名 + Hardened Runtime + セキュアタイムスタンプ（notarization の要件）。
  echo "==> Codesign ($SIGN_IDENTITY)"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  echo "==> Codesign (ad-hoc)"
  codesign --force --deep --sign - "$APP"
fi

echo "==> Done: $APP"
echo "起動: open \"$APP\"   （初回はシステム設定 > プライバシーとセキュリティ > アクセシビリティ で許可）"
