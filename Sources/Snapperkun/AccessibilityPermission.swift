import ApplicationServices

/// アクセシビリティ権限の確認・要求。
enum AccessibilityPermission {
    /// 既に許可されているか。
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 未許可ならシステムのダイアログを表示して要求する。許可済みなら true。
    @discardableResult
    static func requestIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
