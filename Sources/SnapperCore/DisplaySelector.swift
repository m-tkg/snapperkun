/// スナップ適用先のディスプレイ。
public enum DisplayTarget: String, Codable, CaseIterable, Sendable {
    case current
    case next
    case previous
}

/// 現在のディスプレイ index と台数から、移動先ディスプレイの index を返す純粋ロジック。
public enum DisplaySelector {
    public static func targetIndex(current: Int, count: Int, target: DisplayTarget) -> Int {
        guard count > 0 else { return 0 }
        switch target {
        case .current:
            return current
        case .next:
            return (current + 1) % count
        case .previous:
            return (current - 1 + count) % count
        }
    }
}
