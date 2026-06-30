//
// Theming.swift
// Kasten
//
// ターミナルの配色テーマと、その永続化・選択を担う。
//

import SwiftUI
import SwiftTerm
import Combine

/// 配色の見た目モード。システム追従／手動ライト・ダーク／カスタム。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case custom
    
    var id: String { rawValue }
    
    /// セグメント表示用の短いラベル。
    var label: String {
        switch self {
        case .system: return "システム"
        case .light:  return "ライト"
        case .dark:   return "ダーク"
        case .custom: return "カスタム"
        }
    }
}

/// ターミナルの配色テーマ。前景・背景・カーソル・選択色と ANSI 16 色を持つ。
struct KastenTheme: Codable, Equatable {
    var foreground: RGB
    var background: RGB
    /// 背景グラデーションの下端の色。nil なら background の単色。
    var backgroundGradientBottom: RGB? = nil
    var cursor: RGB
    var selection: RGB
    /// ANSI 16 色（0..7 が通常、8..15 が明るい色）。必ず 16 要素。
    var ansi: [RGB]

    /// 背景グラデーションの上端∕下端。下端が無ければ上端と同色（＝単色扱い）。
    var gradientTopColor: RGB { background }
    var gradientBottomColor: RGB { backgroundGradientBottom ?? background }
    
    /// 8bit の RGB を表す軽量な色。AppKit と SwiftTerm の両方へ変換でき、
    /// JSON には "#RRGGBB" 文字列として保存される。
    struct RGB: Equatable, Codable {
        var r: UInt8
        var g: UInt8
        var b: UInt8
        
        init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
            self.r = r; self.g = g; self.b = b
        }
        
        /// "#RRGGBB"（先頭の # は任意）から生成する。
        init(_ hex: String) {
            var s = Substring(hex)
            if s.hasPrefix("#") { s = s.dropFirst() }
            let v = UInt32(s, radix: 16) ?? 0
            self.r = UInt8((v >> 16) & 0xFF)
            self.g = UInt8((v >> 8) & 0xFF)
            self.b = UInt8(v & 0xFF)
        }
        
        /// NSColor（カラーピッカーの結果など）から生成する。sRGB に正規化して取り出す。
        init(nsColor: NSColor) {
            let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
            func byte(_ v: CGFloat) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
            self.r = byte(c.redComponent)
            self.g = byte(c.greenComponent)
            self.b = byte(c.blueComponent)
        }
        
        /// "#RRGGBB" 表記。
        var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
        
        var nsColor: NSColor {
            NSColor(srgbRed: CGFloat(r) / 255.0,
                    green: CGFloat(g) / 255.0,
                    blue: CGFloat(b) / 255.0,
                    alpha: 1.0)
        }
        
        /// SwiftTerm の Color（各成分 0..65535）。8bit 値を 257 倍して 16bit へ。
        var swiftTermColor: SwiftTerm.Color {
            SwiftTerm.Color(red: UInt16(r) * 257,
                            green: UInt16(g) * 257,
                            blue: UInt16(b) * 257)
        }
        
        // JSON では "#RRGGBB" の単一文字列として読み書きする。
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.init(try container.decode(String.self))
        }
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(hex)
        }
    }
}

extension KastenTheme {
    /// ダーク。
    static let dark = KastenTheme(
        foreground: RGB("#C7D2E8"),
        background: RGB("#1F2A44"),
        backgroundGradientBottom: RGB("#10131F"),
        cursor: RGB("#7FB7C4"),
        selection: RGB("#2E3E5E"),
        ansi: [
            RGB("#2A3450"), RGB("#E8728C"), RGB("#8FC9A8"), RGB("#E0C081"),
            RGB("#7AA2E0"), RGB("#B69AE0"), RGB("#86C7D6"), RGB("#C7D2E8"),
            RGB("#4A5878"), RGB("#F08CA0"), RGB("#A6D9BC"), RGB("#ECCF96"),
            RGB("#93B5EC"), RGB("#C7AEEC"), RGB("#9FD7E4"), RGB("#E3EAF6"),
        ]
    )
    
    /// ライト。
    static let light = KastenTheme(
        foreground: RGB("#4A3B2E"),
        background: RGB("#FFFFFF"),
        backgroundGradientBottom: RGB("#FCE8D4"),
        cursor: RGB("#E08A3C"),
        selection: RGB("#FBD9B5"),
        ansi: [
            RGB("#5A4A3A"), RGB("#D2502E"), RGB("#5C8A3A"), RGB("#C8881C"),
            RGB("#3A78B0"), RGB("#B5567E"), RGB("#2F8A86"), RGB("#6E5C48"),
            RGB("#7A6650"), RGB("#E26A45"), RGB("#6FA04A"), RGB("#DDA02E"),
            RGB("#4E8DC4"), RGB("#C76B91"), RGB("#3DA39E"), RGB("#4A3B2E"),
        ]
    )
}

/// 見た目モードとカスタムテーマを保持し、UserDefaults に永続化する。
final class ThemeStore: ObservableObject {
    private static let modeKey = "kasten.appearanceMode"
    private static let customKey = "kasten.customTheme"
    
    // @Published + didSet が strict concurrency 下で ObservableObject 準拠の
    // 自動合成に失敗するケースを避け、objectWillChange を手動で実装する。
    let objectWillChange = ObservableObjectPublisher()
    
    /// 現在の見た目モード。
    var mode: AppearanceMode {
        willSet { objectWillChange.send() }
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }
    
    /// カスタムモードで使う配色。各色は設定パネルのカラーピッカーで編集する。
    var customTheme: KastenTheme {
        willSet { objectWillChange.send() }
        didSet {
            if let data = try? JSONEncoder().encode(customTheme) {
                UserDefaults.standard.set(data, forKey: Self.customKey)
            }
        }
    }
    
    init() {
        let rawMode = UserDefaults.standard.string(forKey: Self.modeKey) ?? AppearanceMode.system.rawValue
        self.mode = AppearanceMode(rawValue: rawMode) ?? .system
        
        if let data = UserDefaults.standard.data(forKey: Self.customKey),
           let theme = try? JSONDecoder().decode(KastenTheme.self, from: data) {
            self.customTheme = theme
        } else {
            // 初回はダークを種にする（ユーザーはここから各色を編集していく）。
            self.customTheme = .dark
        }
    }
}
