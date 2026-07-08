import SwiftUI
import KunAppKit
import SnapperCore

// MARK: - 表示名

extension Fraction {
    var displayName: String {
        switch self {
        case .keep: return L.string("common.keep")
        case .full: return L.string("fraction.full")
        // 分数表記は言語非依存のためそのまま表示する。
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
        case .keep: return L.string("common.keep")
        case .left: return L.string("anchor.left")
        case .center: return L.string("anchor.center")
        case .right: return L.string("anchor.right")
        }
    }
}

extension VerticalAnchor {
    var displayName: String {
        switch self {
        case .keep: return L.string("common.keep")
        case .top: return L.string("anchor.top")
        case .middle: return L.string("anchor.middle")
        case .bottom: return L.string("anchor.bottom")
        }
    }
}

extension DisplayTarget {
    var displayName: String {
        switch self {
        case .current: return L.string("display.current")
        case .next: return L.string("display.next")
        case .previous: return L.string("display.previous")
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
    /// ログイン時の自動起動（ホットキー設定とは独立した即時反映項目）。
    @ObservedObject var loginItem: LoginItemController
    /// OK/キャンセル時にウィンドウを閉じるためのコールバック。
    let onClose: () -> Void
    /// 設定をファイルにエクスポートする。
    let onExport: () -> Void
    /// 設定をファイルからインポートする。
    let onImport: () -> Void

    /// 自動起動の切り替えに失敗した際のエラーメッセージ。
    @State private var loginItemError: String?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // 「一般」タブは左端に置く。
                generalTab
                    .tabItem { Text(L.string("tab.general")) }
                hotkeyTab
                    .tabItem { Text(L.string("tab.hotkey")) }
            }
            .padding([.top, .horizontal])

            Divider()

            // フッター: 保存系ボタン（全タブ共通）
            HStack {
                Spacer()
                Button(L.string("button.cancel")) {
                    viewModel.revert()
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                Button(L.string("button.apply")) {
                    viewModel.apply()
                }
                .disabled(!viewModel.hasChanges)
                Button(L.string("button.ok")) {
                    viewModel.apply()
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 460)
        .alert(L.string("alert.error.title"), isPresented: Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }

    /// 一般タブ: ログイン時の自動起動（即時反映）とバージョン表示。
    @ViewBuilder
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ホットキー設定とは独立。トグル操作で即時反映する。
            Toggle(L.string("settings.launch_at_login"), isOn: Binding(
                get: { loginItem.isEnabled },
                set: { newValue in
                    if let message = loginItem.setEnabled(newValue) {
                        loginItemError = message
                    }
                }
            ))
            .toggleStyle(.checkbox)

            Text(L.format("settings.version", appVersion))
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// ホットキータブ: ホットキー一覧と追加/インポート/エクスポート。
    @ViewBuilder
    private var hotkeyTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.string("settings.hotkey.title")).font(.headline)
                Spacer()
                Button(L.string("settings.import"), action: onImport)
                Button(L.string("settings.export"), action: onExport)
                Button {
                    viewModel.addBinding()
                } label: {
                    Label(L.string("settings.add_hotkey"), systemImage: "plus")
                }
            }

            if viewModel.settings.bindings.isEmpty {
                Spacer()
                Text(L.string("settings.empty"))
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BindingRowView: View {
    @SwiftUI.Binding var binding: SnapperCore.Binding
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.string("settings.shortcut_label"))
                ShortcutRecorder(keyCombo: $binding.keyCombo)
                    .frame(width: 170, height: 24)
                Button {
                    binding.keyCombo = nil
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help(L.string("settings.clear_shortcut"))
                .disabled(binding.keyCombo == nil)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .help(L.string("settings.delete_hotkey"))
            }

            Text(L.string("settings.specs_caption"))
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
                Label(L.string("settings.add_spec"), systemImage: "plus.circle")
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
            labeledPicker(L.string("settings.col.display"), selection: $spec.display, options: DisplayTarget.allCases) { $0.displayName }
            labeledPicker(L.string("settings.col.width"), selection: $spec.width, options: Fraction.allCases) { $0.displayName }
            labeledPicker(L.string("settings.col.height"), selection: $spec.height, options: Fraction.allCases) { $0.displayName }
            labeledPicker(L.string("settings.col.horizontal"), selection: $spec.horizontal, options: HorizontalAnchor.allCases) { $0.displayName }
            labeledPicker(L.string("settings.col.vertical"), selection: $spec.vertical, options: VerticalAnchor.allCases) { $0.displayName }
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
