//
// AIAnswerView.swift
// Kasten
//
// Created by inugaminé on 2026/06/20.
//


import SwiftUI

/// ターミナル直打ちで AI質問と判定された入力への回答を表示するパネル。
struct AIAnswerView: View {
    @ObservedObject var viewModel: KastenViewModel
    /// 抽出したコマンドをターミナルに挿入するコールバック
    var onInsertCommand: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { viewModel.dismissAnswerPanel() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 質問文
            HStack(alignment: .top, spacing: 6) {
                Text("Q.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.aiQuestion)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            
            Divider()
            
            // 回答
            if viewModel.isAnswering {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("回答中...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let answer = viewModel.aiAnswer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        // 回答テキスト本体
                        Text(answer)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        
                        // 回答から抽出したコマンドをボタン化
                        ForEach(Array(extractCodeBlocks(answer).enumerated()), id: \.offset) { _, command in
                            commandChip(command)
                        }
                    }
                }
                .frame(maxHeight: 140)
            } else if let message = viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 8, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    /// 抽出したコマンド1つ分の表示（コマンド＋挿入ボタン）
    @ViewBuilder
    private func commandChip(_ command: String) -> some View {
        HStack {
            Text("$")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button("挿入") {
                onInsertCommand(command)
                viewModel.dismissAnswerPanel()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    /// 回答テキストから ``` で囲まれたコードブロックの中身を抽出する。
    /// ```bash や ``` で始まり ``` で終わる範囲を取り出す。複数あれば全部返す。
    private func extractCodeBlocks(_ text: String) -> [String] {
        var results: [String] = []
        let lines = text.components(separatedBy: "\n")
        var inBlock = false
        var current: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inBlock {
                    // ブロック終了
                    let block = current.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !block.isEmpty { results.append(block) }
                    current = []
                    inBlock = false
                } else {
                    // ブロック開始
                    inBlock = true
                }
            } else if inBlock {
                current.append(line)
            }
        }
        return results
    }
}
