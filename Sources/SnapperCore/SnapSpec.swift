import CoreGraphics

/// ウィンドウ幅・高さの分数。全体 / 3/4 / 2/3 / 1/2 / 1/3 / 1/4、または現状維持(keep)。
public enum Fraction: String, Codable, CaseIterable, Sendable {
    case keep
    case full
    case threeQuarters
    case twoThirds
    case half
    case oneThird
    case oneQuarter

    /// 現在のサイズを維持するか。
    public var isKeep: Bool { self == .keep }

    /// 0〜1 の倍率。`keep` では使用されない（呼び出し側でサイズ計算をスキップする）。
    public var value: CGFloat {
        switch self {
        case .keep: return 1
        case .full: return 1
        case .threeQuarters: return 3.0 / 4.0
        case .twoThirds: return 2.0 / 3.0
        case .half: return 1.0 / 2.0
        case .oneThird: return 1.0 / 3.0
        case .oneQuarter: return 1.0 / 4.0
        }
    }
}

/// 水平方向の寄せ位置（左端 / 中央 / 右端 / 現状維持）。
public enum HorizontalAnchor: String, Codable, CaseIterable, Sendable {
    case keep
    case left
    case center
    case right
}

/// 垂直方向の寄せ位置（上 / 中央 / 下 / 現状維持）。AppKit 座標系（y 上向き）で解釈する。
public enum VerticalAnchor: String, Codable, CaseIterable, Sendable {
    case keep
    case top
    case middle
    case bottom
}

/// 「移動 + サイズ」1 つ分の指定。`display` で適用先ディスプレイを選べる。
public struct SnapSpec: Codable, Equatable, Sendable {
    public var width: Fraction
    public var height: Fraction
    public var horizontal: HorizontalAnchor
    public var vertical: VerticalAnchor
    public var display: DisplayTarget

    public init(
        width: Fraction,
        height: Fraction,
        horizontal: HorizontalAnchor,
        vertical: VerticalAnchor,
        display: DisplayTarget = .current
    ) {
        self.width = width
        self.height = height
        self.horizontal = horizontal
        self.vertical = vertical
        self.display = display
    }

    private enum CodingKeys: String, CodingKey {
        case width, height, horizontal, vertical, display
    }

    // display キーを持たない旧フォーマットとの後方互換のため手書きする。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.width = try container.decode(Fraction.self, forKey: .width)
        self.height = try container.decode(Fraction.self, forKey: .height)
        self.horizontal = try container.decode(HorizontalAnchor.self, forKey: .horizontal)
        self.vertical = try container.decode(VerticalAnchor.self, forKey: .vertical)
        self.display = try container.decodeIfPresent(DisplayTarget.self, forKey: .display) ?? .current
    }
}
