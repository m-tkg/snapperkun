# CLAUDE.md — snapperkun

このリポジトリで作業する際のガイド。

**メニューバー常駐アプリ（kun シリーズ）共通の方針は上位ディレクトリの [`../CLAUDE_base.md`](../CLAUDE_base.md) を参照**
（Swift Package 構成・日英ローカライズ・アップデート・kunkit 連携・リリース手順／ブランチ運用・ローカルビルド・署名／公証など）。
共通方針を変えるときは `CLAUDE_base.md`（[kun-template](https://github.com/m-tkg/kun-template) が canonical）を編集する。
本ファイルには snapperkun 固有の事項のみを記す。

---

# snapperkun 固有事項

**概要**: macOS 用のウィンドウスナップツール。ホットキーでアクティブウィンドウを移動・リサイズする。
bundle ID は `com.mtkg.snapperkun`。ターゲットは `SnapperCore`（純粋ロジック）＋ `Snapperkun`（App）。

## コマンド

```sh
swift build                  # ビルド
swift test                   # 全テスト
swift test --filter <Name>   # 個別テスト（例: SnapCalculatorTests）
bash Scripts/bundle.sh       # .app バンドル生成（既定 release）
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
  - `Settings` / `Binding` / `KeyCombo` / `SettingsCodec` — 設定モデルと JSON エンコード/デコード（`SettingsCodec` は永続化と import/export で共有。設定ファイルの永続化自体は kunkit の `KunSettingsStore` が担う）
- **`Snapperkun`（実行ファイル）**: AppKit/Carbon/AX 連携と UI。
  - `main.swift` — `NSApplication` 起動（`.accessory`、`MainActor.assumeIsolated`）。多重起動防止は kunkit の `KunAppLaunch`
  - `AppDelegate` — 権限要求・設定読込・各 Manager 配線・更新フロー（`@MainActor`）。
    更新チェックは起動時1回に加え `startUpdateMonitoring()` で定期＋スリープ復帰時にも実行（後述）
  - `StatusBarController` — メニューバー常駐メニュー。先頭に操作不可のバージョン項目
    （`Snapperkun <version>`）を置く。ローカルビルドはメニューバーアイコンとバージョン項目に
    「ローカル」を併記する（`isLocalBuild` = バンドル ID が `.local` で終わる）。
    新版があるときはアイコン右下に赤バッジ（`badgeView`）を出す（後述）
  - `WindowManager` — AX でアクティブウィンドウ取得・座標変換・フレーム適用
  - `HotkeyManager` — Carbon `RegisterEventHotKey` でグローバルホットキー
  - `SnapEngine` — ホットキー押下 → ウィンドウ取得 → 計算 → 適用 → 循環状態更新
  - `SettingsWindowController` / `SettingsView` / `ShortcutRecorderView` — SwiftUI 設定 UI。
    `SettingsView` は `TabView` で「一般」（自動起動・バージョン、左端）と「ホットキー」タブに分割し、
    OK/Apply/Cancel フッターは全タブ共通。表示中は Dock アイコンを出す（`SettingsWindowController` が
    `setActivationPolicy(.regular)` ↔ `.accessory` を切り替え）
  - `UpdateService` — 更新チェック（公開 GitHub API から最新リリース取得）。HTTP 取得と自己更新の本体は
    kunkit（`GitHubReleaseFetcher` / `SelfUpdater`）が担い、`UpdateService` は repo 名や userAgent を注入する薄いラッパ
  - `Localization`（`L`）/ `Resources/{en,ja}.lproj/Localizable.strings` — GUI 文字列の多言語対応（方針は base 参照）

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
  `display` キーが無い旧 JSON は `.current` にフォールバックする（設定全体の読込失敗時は
  `KunSettingsStore` に注入した既定値 `Settings.empty` にフォールバック）。
- **`Binding.keyCombo` は省略可能（`KeyCombo?`）**。`nil` は「ショートカット未割り当て」を表し、
  `HotkeyManager` は登録をスキップする。初回起動は `Settings.empty`（バインディングなし）。
- **修飾キーの保持形式**: `KeyCombo` は `Set<Modifier>` で保持し、Carbon フラグへの変換は
  `HotkeyManager` 側で行う（コア層を Carbon 非依存に保つため）。
- **`Settings` の名前衝突**: SwiftUI を import するファイルでは `Settings` / `Binding` が
  SwiftUI の同名型と衝突するため `SnapperCore.Settings` / `SnapperCore.Binding`、
  SwiftUI 側は `@SwiftUI.Binding` と明示する。

## アップデートの定期監視と赤バッジ

更新チェックは起動時の1回だけでなく、定期＋スリープ復帰時にもサイレントで行い、新版があれば
メニューバーアイコン右下に赤バッジ（小さな赤丸）を出す（最新になったら消す）。方式の共通方針は
`../CLAUDE_base.md`「### 4. アップデート機能を入れる」を正とする。snapperkun 固有の要点:

- **定期監視**（`AppDelegate.startUpdateMonitoring()`）: `Timer.scheduledTimer` で kunkit の
  `KunUpdateSchedule.checkInterval`（6時間）間隔のサイレントチェック。`tolerance` も
  `KunUpdateSchedule.checkIntervalTolerance` を使う。`Timer` はスリープ中に発火しないため、
  `NSWorkspace.didWakeNotification` を購読して**復帰時にも即チェック**する。どちらのコールバックも
  `MainActor.assumeIsolated` で `@MainActor` の `startUpdateCheck(interactive:)` を呼ぶ。
- **赤バッジ**（`StatusBarController.setupBadge(on:)` / `badgeView`）: ベースアイコンは
  `isTemplate = true` の**まま維持**し、赤丸は別 view（`NSView` ＋ `wantsLayer` の `CALayer`）として
  `statusItem.button` にオーバーレイする（画像に焼き込むと自動着色が壊れるため）。位置は trailing ではなく
  **アイコン画像の幅基準**で右下に固定する（`leading = button.leading + (iconWidth - badgeSize)`,
  `bottom = button.bottom`）。これで「ローカル」併記時（`imagePosition = .imageLeading`）でも常に
  アイコングリフの右下に乗る。メニューバー背景に溶けないよう細い白の縁取り（`borderWidth`/`borderColor`）を付ける。
- **集約点で同期**: バッジの表示/非表示は更新有無を集約する `StatusBarController.setUpdateAvailable` /
  `clearUpdateAvailable`（メニュー文言変更と同じ箇所）に `badgeView?.isHidden` のトグルとして置く。
  これで起動時・定期・スリープ復帰・手動の**全チェック経路で自動同期**する。
- **注意**: kuntraykun にアイコンを集約させて隠している間（`statusItem.isVisible = false`）はアイコンごと
  非表示のためバッジも見えない（集約先へのバッジ伝搬は別途プロトコル拡張が必要で、現状は対象外）。

## Kuntraykun 連携（実装済み・kunkit 利用）

本アプリは kuntraykun（`com.mtkg.kuntraykun`）にメニューバーアイコンを集約させる連携（v1〜v4:
アイコン集約・実アイコン書き出し・アップデート集約・サブメニュー表示）に対応している。
- **実装は共有ライブラリ [kunkit](https://github.com/m-tkg/kunkit)**（SPM 依存、`KunIntegrationBridge` プロダクト）。
  `KuntraykunBridge` / `KuntraykunIconExport` / `KuntraykunMenuExport` を提供し、アプリ側に連携ロジックの複製は持たない。
- 配線: `StatusBarController.makeKuntraykunBridge()`（`KuntraykunBridge(statusItem:menu:)` の標準配線）を
  `AppDelegate` が `bridge.start()` する。start() が観測開始・`appLaunched` 送信・初回メニュー書き出しまで行う。
  アイコン書き出し（v2）は `StatusBarController` init の `KuntraykunIconExport.export(_:)`、
  アップデート報告（v3）は `kuntraykunBridge?.reportUpdate(_:)`、
  メニュー文言の変化（v4）は `statusBar.onMenuContentChanged` → `bridge.exportMenuSnapshot()`（表示中は自動保留）。
- **アクター分離の注意**: kunkit の `KuntraykunBridge` / `KuntraykunMenuExport` は `@MainActor` だが、
  本アプリの `StatusBarController` は非分離クラス。ブリッジ生成は `@MainActor` 限定の
  `makeKuntraykunBridge()` に閉じ込め、MainActor 隔離の `AppDelegate` から呼ぶ。
- 仕様: kuntraykun リポジトリ `docs/kun-integration-protocol.md`、共通方針は `../CLAUDE_base.md`「Kuntraykun 連携」。
- 管理対象フラグは kunkit が `UserDefaults`（キー `KuntraykunManaged`）に永続化する。
- **kunkit 由来の共通実装**: 自己更新（`SelfUpdater`）・ログイン項目（`LoginItemController`）・多重起動防止（`KunAppLaunch`、`main.swift`）・設定永続化（`KunSettingsStore`）・外部プロセス実行（`ProcessRunner`）・更新チェック（`GitHubReleaseFetcher` / `ReleaseInfo` / `VersionComparator` / `KunUpdateSchedule` / `ReleaseDownloader`）は kunkit（`KunAppKit` / `KunSupport` / `KunUpdateKit`）が提供する。アプリ側に複製は持たず、アプリ名・文言・repo は注入する。設定の import/export 用 JSON 変換（`SettingsCodec`）は snapperkun 固有のため `SnapperCore` に残す。
- **ローカル自己更新の修正**: 従来の自前 `SelfUpdater` は bundle ID を完全一致で検証していたため、ローカルビルド（`.local` サフィックス）から本番リリースへ自己更新できなかった。kunkit の `SelfUpdater` は `BundleIdentity` で**基底 ID（`.local` 除去）比較**するのでこの不具合が解消される。
- **連携のデバッグ**: まず `~/Library/Application Support/Kuntraykun/Menus/<基底ID>.json` の中身
  （空なら書き出し側の問題）と、Console の subsystem `com.mtkg.snapperkun` / category `kuntraykun` の
  ログを確認する。
