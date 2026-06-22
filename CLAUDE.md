# CLAUDE.md

このファイルは、このリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

Snapperkun は macOS 用のウィンドウスナップツール（メニューバー常駐アプリ）。ホットキーでアクティブ
ウィンドウを移動・リサイズする。外部依存なし（AppKit / Carbon / Accessibility のみ）の
Swift Package Manager プロジェクト。

## コマンド

```sh
swift build                  # ビルド
swift test                   # 全テスト
swift test --filter <Name>   # 個別テスト（例: SnapCalculatorTests）
bash Scripts/bundle.sh       # .app バンドル生成（ad-hoc 署名、既定 release）
swift run                    # 直接実行（開発時）
```

## アーキテクチャ

2 ターゲット構成。**純粋ロジックとプラットフォーム依存を分離**しているのが要点。

- **`SnapperCore`（ライブラリ / テスト対象）**: AppKit/Carbon/AX に依存しないモデルと計算。
  - `SnapSpec` / `Fraction` / `HorizontalAnchor` / `VerticalAnchor` / `DisplayTarget` — スナップ指定のモデル
  - `SnapCalculator` — 現在フレーム + 移動元/移動先 `visibleFrame` + `SnapSpec` → 目標フレーム（AppKit 座標）の純粋関数。各軸は独立で、`Fraction.keep` / アンカー `.keep` なら現在のサイズ・相対位置を維持する
  - `RotationController` — ホットキー連打時の循環・リセット判定（純粋ロジック）
  - `CoordinateConverter` — AppKit 座標（左下原点）↔ CG/AX 座標（左上原点）の相互変換
  - `DisplaySelector` — 現在ディスプレイ index + 台数から移動先 index を循環で算出
  - `Settings` / `Binding` / `KeyCombo` / `SettingsStore` — 設定モデルと JSON 永続化
  - `ReleaseInfo` / `VersionComparator` — 更新チェック用のリリースモデルとバージョン比較（純粋）
- **`Snapperkun`（実行ファイル）**: AppKit/Carbon/AX 連携と UI。
  - `main.swift` — `NSApplication` 起動（`.accessory`、`MainActor.assumeIsolated`）
  - `AppDelegate` — 権限要求・設定読込・各 Manager 配線・更新フロー（`@MainActor`）
  - `StatusBarController` — メニューバー常駐メニュー
  - `WindowManager` — AX でアクティブウィンドウ取得・座標変換・フレーム適用
  - `HotkeyManager` — Carbon `RegisterEventHotKey` でグローバルホットキー
  - `SnapEngine` — ホットキー押下 → ウィンドウ取得 → 計算 → 適用 → 循環状態更新
  - `SettingsWindowController` / `SettingsView` / `ShortcutRecorderView` — SwiftUI 設定 UI
  - `UpdateService` / `SelfUpdater` / `ProcessRunner` — `gh` 経由の更新チェックと自己更新（DL→`ditto`展開→bundle ID検証→切り離しスクリプトで入替→再起動）。private リポジトリのため `gh` 認証が前提

データの流れ:
ホットキー押下（`HotkeyManager`）→ `SnapEngine.handle(binding:)` →
`WindowManager` がフォーカスウィンドウと所属スクリーンを取得 →
`DisplaySelector` で対象スクリーン決定 → `SnapCalculator` で目標フレーム算出 →
`CoordinateConverter` で CG 座標へ変換し AX で適用 → `RotationController` が循環状態を更新。

## 設計上の重要な前提（変更時に注意）

- **座標変換が最重要**。`NSScreen.visibleFrame` は AppKit 座標（原点=左下, y 上向き）、
  AX API は CG 座標（原点=メインディスプレイ左上, y 下向き）。内部計算は AppKit 座標で統一し、
  AX 読み書き時のみ `CoordinateConverter` で変換する。基準高さはメインディスプレイ
  （`NSScreen.screens.first`）の高さ。
- **ローテーション**: `RotationController` は「同じホットキー連打 かつ 現在フレームが前回適用
  フレームと許容誤差内で一致」なら次の index、そうでなければ先頭に戻す。アプリ側がサイズを
  丸めるため、適用後の **実フレーム** を `recordApplied` で記録して比較する。
- **`SnapSpec.display`** はディスプレイ間移動用。後方互換のため `SnapSpec` の Codable は手書きで、
  `display` キーが無い旧 JSON は `.current` にフォールバックする（`SettingsStore` も読込失敗時は
  `Settings.empty` にフォールバック）。
- **`Binding.keyCombo` は省略可能（`KeyCombo?`）**。`nil` は「ショートカット未割り当て」を表し、
  `HotkeyManager` は登録をスキップする。初回起動は `Settings.empty`（バインディングなし）。
- **修飾キーの保持形式**: `KeyCombo` は `Set<Modifier>` で保持し、Carbon フラグへの変換は
  `HotkeyManager` 側で行う（コア層を Carbon 非依存に保つため）。
- **`Settings` の名前衝突**: SwiftUI を import するファイルでは `Settings` / `Binding` が
  SwiftUI の同名型と衝突するため `SnapperCore.Settings` / `SnapperCore.Binding`、
  SwiftUI 側は `@SwiftUI.Binding` と明示する。

## 開発の進め方

- 純粋ロジック（`SnapperCore`）は **TDD**（テスト先行）で実装する。UI/AX 連携は手動確認。
- 設定は `~/Library/Application Support/Snapperkun/settings.json` に保存される。
- 動作確認には実機でのアクセシビリティ権限付与（GUI 操作）が必要。
