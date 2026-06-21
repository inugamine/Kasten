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
    /// ルール:
    ///   1. 行頭が "?"/"？" → AI質問（明示トリガー）
    ///   2. それ以外 → コマンド
    ///
    /// 日本語の自動判別は行わない。英単語と日本語を半角スペースで区切る
    /// 書き方（例: "git でコミット"）や、日本語を含むコマンド（例: echo "こんにちは"）
    /// を誤判定しないよう、AI質問は "?"/"？" で明示する方式に統一する。
    static func classify(_ raw: String) -> InputClassification {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .command(trimmed) }
        
        if let first = trimmed.first, first == "?" || first == "？" {
            let question = String(trimmed.dropFirst())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .aiQuery(question)
        }
        
        return .command(trimmed)
    }
}
