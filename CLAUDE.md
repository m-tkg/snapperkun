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
  - `Settings` / `Binding` / `KeyCombo` / `SettingsStore` / `SettingsCodec` — 設定モデルと JSON 永続化（`SettingsCodec` を永続化と import/export で共有）
  - `ReleaseInfo` / `VersionComparator` — 更新チェック用のリリースモデルとバージョン比較（純粋）
- **`Snapperkun`（実行ファイル）**: AppKit/Carbon/AX 連携と UI。
  - `main.swift` — `NSApplication` 起動（`.accessory`、`MainActor.assumeIsolated`）
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
  - `UpdateService` / `SelfUpdater` / `ProcessRunner` — 更新チェックと自己更新。`UpdateService` は公開 GitHub API（api.github.com）へ URLSession でアクセス（認証不要）。`SelfUpdater` は zip DL→`ditto`展開→bundle ID検証→切り離しスクリプトで入替→再起動（`ProcessRunner` は ditto 実行に使用）
  - `Localization`（`L`）/ `Resources/{en,ja}.lproj/Localizable.strings` — GUI 文字列の多言語対応（後述）

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
- **多重起動防止**: `main.swift` は起動時に同じ bundle ID の他インスタンス
  （`NSRunningApplication.runningApplications(withBundleIdentifier:)`）を検出したら、
  それを前面化して自分は `exit(0)` する。ホットキー登録の二重起動を防ぐため。

## 多言語対応（ローカライズ）

GUI に表示する文字列は **日本語・英語の 2 言語に対応**し、OS の優先言語に追従する（既定 `en`）。

- **必須ルール: GUI に文字列を追加・変更したら、必ず多言語対応すること。**
  ハードコードした日本語/英語リテラルを `Text`/`Button`/`NSMenuItem`/`NSAlert`/ウィンドウタイトル等に
  直接渡してはいけない。新しい文字列を足すときは:
  1. `Sources/Snapperkun/Resources/en.lproj/Localizable.strings` と `ja.lproj/Localizable.strings`
     の**両方**にキーと対訳を追加する（キーは `menu.settings` のようなドット区切りの意味ベース）。
  2. コードでは `L.string("キー")`（静的文字列）または `L.format("キー", 値…)`（`%@`/`%d` 埋め込み）
     で参照する（`Sources/Snapperkun/Localization.swift`）。
- **仕組み**: `L` は SwiftPM 生成のリソースバンドル `Snapperkun_Snapperkun.bundle` を
  **自前探索**してローカライズ文字列を解決する（`Bundle.main.resourceURL` / `bundleURL` /
  `Bundle(for:).resourceURL` / `bundleURL` の順に候補を探し、見つかった最初のものを使う）。
  見つからなければ `.main` にフォールバックする（`Sources/Snapperkun/Localization.swift`）。
  **`Bundle.module` は不在時にクラッシュしうるため使わない**（v1.5.1 で起動クラッシュを修正した経緯）。
  SwiftUI の `Text`/`Button` 等は既定で `Bundle.main` を見るため、`L` で解決した確定済み `String` を渡す。
  `Package.swift` は `defaultLocalization: "en"` と `resources: [.process("Resources")]` を指定済み。
- **`Info.plist` に `CFBundleDevelopmentRegion`（en）と `CFBundleLocalizations`（en, ja）が必須**。
  無いと macOS がアプリ言語を開発リージョン(en)に固定し、ネストした文字列バンドルも en に
  フォールバックして日本語が一切出ないことがある。
- **`.app` への取り込み**: `Scripts/bundle.sh` が SwiftPM 生成の `Snapperkun_Snapperkun.bundle` を
  `Contents/Resources/` にコピーする（これが無いと実行時に文字列が解決できない）。
- **対象外**: 分数表記（`3/4` 等）やアプリ名 `Snapperkun` のような言語非依存な文字列、
  ログ出力（`os.Logger`）は対象外。
- 確認: OS の言語設定を切り替えるか、`Bundle.preferredLocalizations(from:forPreferences:)` で
  言語別の解決を検証できる。

## ローカルビルド（本番と区別する）

- `LOCAL=1 bash Scripts/bundle.sh` でローカル検証ビルドを生成する。`bundle.sh` が
  バンドル ID を `com.mtkg.snapperkun.local`、表示名を `Snapperkun (Local)` に差し替える
  （`CFBundleExecutable` は `Snapperkun` のまま）。
- アプリは `isLocalBuild`（バンドル ID が `.local` で終わる）で判定し、メニューバーアイコンと
  メニュー先頭のバージョン項目に「ローカル」を併記する（`StatusBarController`）。
- バンドル ID が本番と違うため **TCC 権限が別エントリになり衝突しない**（本番版と共存可、
  ローカルには別途アクセシビリティ権限を付与する）。
- **公証は CI のリリースビルドのみ**。ローカルビルドは署名されるが公証されないため、配布物と取り違えない。

## 開発の進め方

- **変更は必ず Pull Request 経由で行う。`main` への直接コミット/push はしない。**
  作業はブランチを切って進め、`gh pr create` で PR を作成する。マージはレビュー後に行う
  （リリース用 Actions は `v*` タグの push で発火するため、main へのマージだけでは
  リリースされない。リリース手順は後述）。
- 作業ブランチは**必ずその時点の最新の `main` から切る**
  （`git fetch origin && git switch -c <branch> origin/main`）。
- **PR 作成後に追加の修正を行うときは、まずその PR が既にマージされていないか確認する**
  （`gh pr view <番号> --json state,mergedAt`）。マージ済みの場合、その PR の作業ブランチへ
  push しても main には反映されない（孤立コミットになる）。マージ済みなら**最新 `main` から
  新しいブランチを切り直し**、必要な修正と（リリースが要るなら）バージョン更新を入れて別 PR を出す。
- 純粋ロジック（`SnapperCore`）は **TDD**（テスト先行）で実装する。UI/AX 連携は手動確認。
- 設定は `~/Library/Application Support/Snapperkun/settings.json` に保存される。
- 動作確認には実機でのアクセシビリティ権限付与（GUI 操作）が必要。
- リリースはバージョン（`Resources/Info.plist` の `CFBundleShortVersionString`）を上げて
  main にマージした後、`make release-tag` でタグを作成・push すると CI がビルド・署名・
  公証してリリースを自動作成する（main へのマージだけではリリースされない）。

## 配布・署名（リリース）

- 配布用の署名＋公証の Secrets（計 6 つ）は、上位ディレクトリの
  **`setup-release-secrets.sh`** で一括登録する（`~/git/github.com/m-tkg/setup-release-secrets.sh -r m-tkg/snapperkun`）。
  - 署名: `SIGNING_IDENTITY` / `SIGNING_CERTIFICATE_PASSWORD` / `SIGNING_CERTIFICATE_P12_BASE64`
  - 公証: `NOTARY_APPLE_ID` / `NOTARY_PASSWORD` / `NOTARY_TEAM_ID`
- 署名は Developer ID Application（Team ID `G72M73C546`）。**安定署名なのでアクセシビリティ権限(TCC)が
  アップデート越しに保持される**（ad-hoc 署名はビルドごとに変わり権限が無効化される）。
- Secrets が無ければワークフローは ad-hoc 署名／公証スキップにフォールバックする。
- `setup-release-secrets.sh` は秘密鍵(.p12)を含むので**リポジトリにコミットしない**（上位ディレクトリは git 管理外）。
- `Scripts/bundle.sh` はローカルでも `SIGN_IDENTITY` を指定すれば Developer ID 署名できる
  （未指定なら ad-hoc）。**公証は CI のリリースビルドのみ**で、ローカルビルドは署名されるが公証されない。

## アップデートの定期監視と赤バッジ（実装済み）

更新チェックは起動時の1回だけでなく、定期＋スリープ復帰時にもサイレントで行い、新版があれば
メニューバーアイコン右下に赤バッジ（小さな赤丸）を出す（最新になったら消す）。共通方針は
`../CLAUDE_base.md`「### 4. アップデート機能を入れる」を正とする。

- **定期監視**（`AppDelegate.startUpdateMonitoring()`）: `Timer.scheduledTimer` で **1時間間隔**の
  サイレントチェック（`updateCheckInterval = 3600`）。GitHub 未認証 API のレート制限 60回/時 に収める。
  `timer.tolerance` を間隔の 10%（6分）付けて省電力のためコアレッシングを許可。`Timer` はスリープ中に
  発火しないため、`NSWorkspace.didWakeNotification` を購読して**復帰時にも即チェック**する。
  どちらのコールバックも `MainActor.assumeIsolated` で `@MainActor` の `startUpdateCheck(interactive:)` を呼ぶ。
- **赤バッジ**（`StatusBarController.setupBadge(on:)` / `badgeView`）: ベースアイコンは
  `isTemplate = true` の**まま維持**し、赤丸は別 view（`NSView` ＋ `wantsLayer` の `CALayer`）として
  `statusItem.button` にオーバーレイする（画像に焼き込むと自動着色が壊れるため）。位置は trailing ではなく
  **アイコン画像の幅基準**で右下に固定する（`leading = button.leading + (iconWidth - badgeSize)`,
  `bottom = button.bottom`）。これで「ローカル」併記時（`imagePosition = .imageLeading`）でも常に
  アイコングリフの右下に乗る。メニューバー背景に溶けないよう細い白の縁取り（`borderWidth`/`borderColor`）を付ける。
- **集約点で同期**: バッジの表示/非表示は更新有無を集約する `StatusBarController.setUpdateAvailable` /
  `clearUpdateAvailable`（メニュー文言変更と同じ箇所）に `badgeView?.isHidden` のトグルとして置く。
  これで起動時・定期・スリープ復帰・手動の**全チェック経路で自動同期**する。
- **注意**: kuntraykun にアイコンを集約させて隠している間（`setManagedHidden(true)`）はアイコンごと
  非表示のためバッジも見えない（集約先へのバッジ伝搬は別途プロトコル拡張が必要で、現状は対象外）。

## Kuntraykun 連携（実装済み）

本アプリは kuntraykun（`com.mtkg.kuntraykun`）にメニューバーアイコンを集約させる連携に対応している。
- 実装: `Sources/Snapperkun/KuntraykunBridge.swift`（分散通知の送受信・アイコン表示制御）、
  `StatusBarController.swift`（`setManagedHidden(_:)` / `popUpMenu(at:)` と `menu` のプロパティ化）、
  `AppDelegate.swift`（`bridge.start()` の配線）。
- 仕様: kuntraykun リポジトリ `docs/kun-integration-protocol.md`、共通方針は `../CLAUDE_base.md`「Kuntraykun 連携」。
- 管理対象フラグは `UserDefaults`（キー `KuntraykunManaged`）に永続化する。
- **実アイコンのライブ書き出し（v2）**: `KuntraykunIconExport.export(_:)`（`Sources/Snapperkun/KuntraykunIconExport.swift`）で、
  `StatusBarController` がメニューバーアイコンを設定する箇所で現在アイコンを
  `~/Library/Application Support/Kuntraykun/MenuBarIcons/<基底ID>.png` に書き出す（テンプレートは `.template` マーカー併記）。
  kuntraykun はこれを優先して一覧に表示する。
- **メニュースナップショットの共有（v4: サブメニュー表示）**: `KuntraykunMenuExport`（`Sources/Snapperkun/KuntraykunMenuExport.swift`）で
  自分のメニュー構造を JSON にして `~/Library/Application Support/Kuntraykun/Menus/<基底ID>.json` へ原子的に書き出し、
  分散通知 `menuSnapshot` で知らせる。kuntraykun はこれをプルダウンの**サブメニュー**として再構築し、
  項目クリックを `invokeMenuItem` で依頼してくる（`KuntraykunBridge` が観測。**世代トークン一致時のみ**
  `performActionForItem(at:)` で実行し、不一致なら再書き出しのみ）。書き出しタイミングは
  起動時／`requestMenu` 受信時／メニュー文言の変化時（`setUpdateAvailable` / `clearUpdateAvailable`）／invoke 実行後。
  非表示項目は省くが ID（インデックスパス）の採番は実インデックスのまま。メニューは init で静的構築のため、
  エクスポート対象は showMenu で popUp するのと同じ `StatusBarController.menu` をそのまま読む。
