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

/// 設定の編集状態を保持し、変更を onChange で通知する。
final class SettingsViewModel: ObservableObject {
    @Published var settings: SnapperCore.Settings {
        didSet { onChange(settings) }
    }
    private let onChange: (SnapperCore.Settings) -> Void

    init(settings: SnapperCore.Settings, onChange: @escaping (SnapperCore.Settings) -> Void) {
        self.settings = settings
        self.onChange = onChange
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ホットキー設定").font(.headline)
                Spacer()
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
