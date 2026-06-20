//
// KastenViewModel.swift
// Kasten
//
// Created by inugaminé on 2026/06/20.
//

import Foundation
import SwiftUI
import Combine

/// Kasten のメイン状態管理
@MainActor
final class KastenViewModel: ObservableObject {

    // MARK: - AI サービス

    let aiService = AIService()

    // MARK: - コマンドバー状態

    @Published var commandBarInput: String = ""
    @Published var suggestion: CommandSuggestion?
    @Published var isSuggesting: Bool = false
    @Published var isCommandBarVisible: Bool = false

    // MARK: - エラーパネル状態

    @Published var errorAnalysis: ErrorAnalysis?
    @Published var isAnalyzing: Bool = false
    @Published var isErrorPanelVisible: Bool = false
    @Published var detectedError: String = ""

    // MARK: - エラーメッセージ（サジェスト失敗時など）

    @Published var errorMessage: String?

    // MARK: - AI質問応答（ターミナル直打ちの自動判別経由）

    /// ユーザーが投げた質問文
    @Published var aiQuestion: String = ""
    /// AI の回答
    @Published var aiAnswer: String?
    /// 回答待ち中か
    @Published var isAnswering: Bool = false
    /// 回答パネルを表示するか
    @Published var isAnswerPanelVisible: Bool = false

    /// ターミナルで AI質問と判定された入力を受けて AI に問い合わせる。
    func askAI(_ question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        aiQuestion = trimmed
        aiAnswer = nil
        isAnswerPanelVisible = true
        isAnswering = true
        errorMessage = nil

        do {
            let answer = try await aiService.askQuestion(trimmed)
            aiAnswer = answer
        } catch {
            errorMessage = "AIへの問い合わせに失敗しました: \(error.localizedDescription)"
        }

        isAnswering = false
    }

    func dismissAnswerPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isAnswerPanelVisible = false
        }
        aiAnswer = nil
        aiQuestion = ""
    }

    // MARK: - コマンドサジェスト

    func requestSuggestion() async {
        let input = commandBarInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isSuggesting = true
        suggestion = nil
        errorMessage = nil

        do {
            let result = try await aiService.suggestCommand(from: input)
            suggestion = result
        } catch {
            errorMessage = "サジェストに失敗しました: \(error.localizedDescription)"
        }

        isSuggesting = false
    }

    // MARK: - エラー解析

    /// ターミナル画面のスナップショットを渡して解析する。
    /// 画面テキスト全体を AI に見せ、直近のコマンドとエラーを判断させる。
    func analyzeTerminal(snapshot: String) async {
        let trimmed = snapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "ターミナルに解析できる内容がありません。"
            return
        }

        detectedError = trimmed
        isErrorPanelVisible = true
        isAnalyzing = true
        errorAnalysis = nil
        errorMessage = nil

        do {
            let result = try await aiService.analyzeError(terminalText: trimmed)
            errorAnalysis = result
        } catch {
            errorMessage = "エラー解析に失敗しました: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    func dismissErrorPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isErrorPanelVisible = false
        }
        errorAnalysis = nil
        detectedError = ""
    }

    // MARK: - コマンドバー表示切替

    func toggleCommandBar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCommandBarVisible.toggle()
        }
        if isCommandBarVisible {
            commandBarInput = ""
            suggestion = nil
        }
    }

    func dismissCommandBar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCommandBarVisible = false
        }
        commandBarInput = ""
        suggestion = nil
    }
}
