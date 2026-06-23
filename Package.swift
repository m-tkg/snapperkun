// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snapperkun",
    // ローカライズ済みリソース（en/ja）を持つため既定言語を指定する。
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // 純粋ロジック（テスト対象）: AppKit/Carbon/AX に依存しない計算・モデル
        .target(
            name: "SnapperCore"
        ),
        // 実行ファイル本体: メニューバー常駐・ホットキー・AX 連携・設定UI
        .executableTarget(
            name: "Snapperkun",
            dependencies: ["SnapperCore"],
            // en.lproj / ja.lproj の Localizable.strings をリソースバンドルに含める。
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SnapperCoreTests",
            dependencies: ["SnapperCore"]
        ),
    ]
)
