import SwiftUI
import SnapperCore

// MARK: - 表示名

extension Fraction {
    var displayName: String {
        switch self {
        case .keep: return "現状維持"
        case .full: return "全体"
        case .threeQuarters: return "3/4"
        case .twoThirds: return "2/3"
        case .half: return "1/2"
        case .oneThird: return "1/3"
        case .oneQuarter: return "1/4"
        }
    }
}

extension HorizontalAnchor {
    var displayName: String {
        switch self {
        case .keep: return "現状維持"
        case .left: return "左"
        case .center: return "中央"
        case .right: return "右"
        }
    }
}

extension VerticalAnchor {
    var displayName: String {
        switch self {
        case .keep: return "現状維持"
        case .top: return "上"
        case .middle: return "中央"
        case .bottom: return "下"
        }
    }
}

extension DisplayTarget {
    var displayName: String {
        switch self {
        case .current: return "現在"
        case .next: return "次"
        case .previous: return "前"
        }
    }
}

// MARK: - ViewModel

/// 設定の編集状態を保持する。編集は作業コピー上で行い、Apply/OK で確定する。
final class SettingsViewModel: ObservableObject {
    /// 編集中の作業コピー。
    @Published var settings: SnapperCore.Settings
    /// 直近に確定（Apply/OK）した内容。Cancel 時の復帰先。
    private var committed: SnapperCore.Settings
    private let onApply: (SnapperCore.Settings) -> Void

    init(settings: SnapperCore.Settings, onApply: @escaping (SnapperCore.Settings) -> Void) {
        self.settings = settings
        self.committed = settings
        self.onApply = onApply
    }

    /// 未確定の変更があるか。
    var hasChanges: Bool { settings != committed }

    /// 作業コピーを確定し保存・反映する。
    func apply() {
        committed = settings
        onApply(settings)
    }

    /// 未確定の変更を破棄して直近の確定内容に戻す。
    func revert() {
        settings = committed
    }

    /// インポートした設定を作業コピーに読み込む（確定は Apply/OK で行う）。
    func load(_ newSettings: SnapperCore.Settings) {
        settings = newSettings
    }

    func addBinding() {
        // ショートカットは未割り当て（nil）で開始する。
        let new = SnapperCore.Binding(
            keyCombo: nil,
            specs: [SnapSpec(width: .half, height: .full, horizontal: .left, vertical: .top)]
        )
        settings.bindings.append(new)
    }

    func removeBinding(id: UUID) {
        settings.bindings.removeAll { $0.id == id }
    }
}

// MARK: - Views

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    /// OK/キャンセル時にウィンドウを閉じるためのコールバック。
    let onClose: () -> Void
    /// 設定をファイルにエクスポートする。
    let onExport: () -> Void
    /// 設定をファイルからインポートする。
    let onImport: () -> Void

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ホットキー設定").font(.headline)
                Spacer()
                Button("インポート…", action: onImport)
                Button("エクスポート…", action: onExport)
                Button {
                    viewModel.addBinding()
                } label: {
                    Label("ホットキー追加", systemImage: "plus")
                }
            }

            if viewModel.settings.bindings.isEmpty {
                Spacer()
                Text("ホットキーがありません。「ホットキー追加」で作成してください。")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($viewModel.settings.bindings) { $binding in
                            BindingRowView(binding: $binding) {
                                viewModel.removeBinding(id: binding.id)
                            }
                        }
                    }
                }
            }

            Divider()

            // フッター: バージョン表示 + 保存系ボタン
            HStack {
                Text("バージョン \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("キャンセル") {
                    viewModel.revert()
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                Button("適用") {
                    viewModel.apply()
                }
                .disabled(!viewModel.hasChanges)
                Button("OK") {
                    viewModel.apply()
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 460)
    }
}

struct BindingRowView: View {
    @SwiftUI.Binding var binding: SnapperCore.Binding
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ショートカット:")
                ShortcutRecorder(keyCombo: $binding.keyCombo)
                    .frame(width: 170, height: 24)
                Button {
                    binding.keyCombo = nil
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help("ショートカットをクリア")
                .disabled(binding.keyCombo == nil)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .help("このホットキーを削除")
            }

            Text("サイズ・位置（複数あると押すたびに循環）")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(Array(binding.specs.enumerated()), id: \.offset) { index, _ in
                SpecRowView(spec: $binding.specs[index]) {
                    binding.specs.remove(at: index)
                }
            }

            Button {
                binding.specs.append(
                    SnapSpec(width: .half, height: .full, horizontal: .left, vertical: .top)
                )
            } label: {
                Label("サイズ・位置を追加", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SpecRowView: View {
    @SwiftUI.Binding var spec: SnapSpec
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            labeledPicker("ディスプレイ", selection: $spec.display, options: DisplayTarget.allCases) { $0.displayName }
            labeledPicker("幅", selection: $spec.width, options: Fraction.allCases) { $0.displayName }
            labeledPicker("高さ", selection: $spec.height, options: Fraction.allCases) { $0.displayName }
            labeledPicker("水平", selection: $spec.horizontal, options: HorizontalAnchor.allCases) { $0.displayName }
            labeledPicker("垂直", selection: $spec.vertical, options: VerticalAnchor.allCases) { $0.displayName }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    private func labeledPicker<T: Hashable>(
        _ title: String,
        selection: SwiftUI.Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 80)
        }
    }
}
