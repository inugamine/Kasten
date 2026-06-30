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
    var cursor: RGB
    var selection: RGB
    /// ANSI 16 色（0..7 が通常、8..15 が明るい色）。必ず 16 要素。
    var ansi: [RGB]
    
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
    /// ダーク（スレート基調）。
    static let dark = KastenTheme(
        foreground: RGB("#C0CAF5"),
        background: RGB("#1A1B26"),
        cursor: RGB("#5BE49B"),
        selection: RGB("#28304A"),
        ansi: [
            RGB("#15161E"), RGB("#F7768E"), RGB("#9ECE6A"), RGB("#E0AF68"),
            RGB("#7AA2F7"), RGB("#BB9AF7"), RGB("#7DCFFF"), RGB("#A9B1D6"),
            RGB("#414868"), RGB("#F7768E"), RGB("#9ECE6A"), RGB("#E0AF68"),
            RGB("#7AA2F7"), RGB("#BB9AF7"), RGB("#7DCFFF"), RGB("#C0CAF5"),
        ]
    )
    
    /// ライト。
    static let light = KastenTheme(
        foreground: RGB("#3A3D4D"),
        background: RGB("#FAFAFA"),
        cursor: RGB("#1A8F5A"),
        selection: RGB("#C8E1FF"),
        ansi: [
            RGB("#5C5F77"), RGB("#D20F39"), RGB("#40A02B"), RGB("#DF8E1D"),
            RGB("#1E66F5"), RGB("#EA76CB"), RGB("#179299"), RGB("#ACB0BE"),
            RGB("#6C6F85"), RGB("#D20F39"), RGB("#40A02B"), RGB("#DF8E1D"),
            RGB("#1E66F5"), RGB("#EA76CB"), RGB("#179299"), RGB("#BCC0CC"),
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
