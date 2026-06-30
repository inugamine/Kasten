//
// AIService.swift
// Kasten
//
// Created by inugaminé on 2026/06/20.
//

import Foundation
import FoundationModels
import Combine

/// Apple Foundation Models をラップしてコマンドサジェストとエラー解析を提供する。
///
/// サジェスト用とエラー解析用でセッションを分けている。
/// Apple は「個別の単発タスクごとに新しいセッションを作る」ことを推奨しているため、
/// 役割ごとに instructions 付きの専用セッションを用意している。
@MainActor
final class AIService: ObservableObject {

    /// モデルが利用可能かどうか
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// 利用不可の理由（UI 表示用）。利用可能なら nil。
    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "この Mac は Apple Intelligence に対応していません。"
            case .appleIntelligenceNotEnabled:
                return "設定から Apple Intelligence を有効にしてください。"
            case .modelNotReady:
                return "モデルを準備中です。しばらく待ってから再度お試しください。"
            @unknown default:
                return "Apple Intelligence が利用できません。"
            }
        @unknown default:
            return "Apple Intelligence が利用できません。"
        }
    }

    // MARK: - 回答言語の決定

    /// AI の回答に使う言語（英語表記の言語名 "Japanese" "German" など）を返す。
    /// ユーザーが OS で設定している優先言語の先頭をそのまま使う。
    private static func responseLanguageName() -> String {
        // Locale.current はアプリがローカライズ対応済みの言語に制限されるため、
        // UI 翻訳の整備が済む前は OS が ja でも en に丸められてしまう。
        // preferredLanguages ならアプリのローカライズ状況に関係なく、
        // ユーザー本来の優先言語（"ja-JP" "de-DE" など）がそのまま取れる。
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        // モデルへ渡す言語名は英語表記にする（最も確実に伝わる形）。
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
    }

    // MARK: - エラー解析

    /// ターミナルの画面テキストを解析して、原因と解決策を説明する。
    /// こちらも単発タスクなので呼び出しごとに専用セッションを生成する。
    func analyzeError(terminalText: String) async throws -> ErrorAnalysis {
        guard isAvailable else { throw AIServiceError.modelUnavailable }

        let language = Self.responseLanguageName()
        let instructions = """
        You are an assistant that analyzes macOS terminal errors.
        You will be given the entire text shown on the terminal screen. From it, identify the most recently executed command and its error output, then explain the cause and the solution.
        - In `cause`, concisely explain the cause of the error.
        - In `solution`, explain how to resolve it.
        - If there is a command that can fix the issue, put it on a single line in `fixCommand`. Otherwise leave it as an empty string.
        - Always write `cause` and `solution` in \(language).
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: "Analyze the following terminal screen:\n\n\(terminalText)",
            generating: ErrorAnalysis.self
        )
        return response.content
    }

    // MARK: - コマンドサジェスト

    /// 自然言語の説明からシェルコマンドを提案する。
    /// ターミナルで "?〜" と打ったときに呼ばれる。
    /// 自由テキストの長い回答ではなく、コマンド＋短い説明をピンポイントで返す。
    func suggestCommand(from naturalLanguage: String) async throws -> CommandSuggestion {
        guard isAvailable else { throw AIServiceError.modelUnavailable }

        let language = Self.responseLanguageName()
        let instructions = """
        You are an assistant well-versed in the macOS terminal.
        The user describes what they want to do; propose an appropriate shell command to achieve it.
        - Put the command to run on a single line in `command`. If multiple steps are required, join them with &&.
        - In `explanation`, concisely describe what the command does.
        - Only when the operation is dangerous (e.g. rm -rf or anything that could destroy data), write a caution in `warning`. If it is safe, leave `warning` as an empty string.
        - Always write `explanation` and `warning` in \(language).
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: naturalLanguage,
            generating: CommandSuggestion.self
        )
        return response.content
    }
}

// MARK: - Generable 構造体

@Generable
struct CommandSuggestion: Equatable {
    @Guide(description: "The shell command to run, on a single line")
    var command: String

    @Guide(description: "A concise explanation of what the command does")
    var explanation: String

    @Guide(description: "A caution note when the command is dangerous; empty string if safe")
    var warning: String
}

@Generable
struct ErrorAnalysis: Equatable {
    @Guide(description: "A concise explanation of the cause of the error")
    var cause: String

    @Guide(description: "A proposed solution")
    var solution: String

    @Guide(description: "A command that can fix the issue, if any; empty string otherwise")
    var fixCommand: String
}

// MARK: - エラー型

enum AIServiceError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence が利用できません。設定から有効にしてください。"
        }
    }
}
