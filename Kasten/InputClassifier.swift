//
// InputClassifier.swift
// Kasten
//
// Created by inugaminé on 2026/06/20.
//


import Foundation

/// 入力の判別結果。
enum InputClassification: Equatable {
    case command(String)   // シェルコマンドとして実行
    case aiQuery(String)   // AI への自然言語の質問
}

enum InputClassifier {
    
    /// 入力1行を判別する。前後の空白は取り除いて返す。
    /// ルール（上から順）:
    ///   1. 行頭が "?"/"？" → AI質問（明示トリガー）
    ///   2. 日本語を含む → AI質問
    ///   3. それ以外 → コマンド
    static func classify(_ raw: String) -> InputClassification {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .command(trimmed) }
        
        if let first = trimmed.first, first == "?" || first == "？" {
            let question = String(trimmed.dropFirst())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .aiQuery(question)
        }
        
        if containsJapanese(trimmed) {
            return .aiQuery(trimmed)
        }
        
        return .command(trimmed)
    }
    
    /// ひらがな・カタカナ・漢字・半角カナを含むか判定する。
    private static func containsJapanese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x3040...0x309F).contains(v) { return true }  // ひらがな
            if (0x30A0...0x30FF).contains(v) { return true }  // カタカナ
            if (0x4E00...0x9FFF).contains(v) { return true }  // CJK統合漢字
            if (0x3400...0x4DBF).contains(v) { return true }  // 拡張A
            if (0xFF66...0xFF9D).contains(v) { return true }  // 半角カナ
        }
        return false
    }
}
