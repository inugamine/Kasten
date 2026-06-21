//
// AIAnswerView.swift
// Kasten
//
// Created by inugaminé on 2026/06/20.
//


import SwiftUI

/// ターミナルで "?〜" と打ったときの、AIコマンド提案を表示するパネル。
/// 自由テキストの長い回答ではなく、コマンド＋短い説明をピンポイントで出す。
struct AIAnswerView: View {
    @ObservedObject var viewModel: KastenViewModel
    /// 提案コマンドをターミナルに挿入するコールバック
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

            // コマンド提案
            if viewModel.isAnswering {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("考え中...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let suggestion = viewModel.aiSuggestion {
                suggestionCard(suggestion)
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

    /// コマンド提案カード（コマンド＋説明＋警告＋挿入/コピーボタン）。
    @ViewBuilder
    private func suggestionCard(_ suggestion: CommandSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // コマンド表示
            HStack {
                Text("$")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(suggestion.command)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                Spacer()

                Button("挿入") {
                    onInsertCommand(suggestion.command)
                    viewModel.dismissAnswerPanel()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(suggestion.command, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // 説明
            Text(suggestion.explanation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            // 警告（あれば）
            if !suggestion.warning.isEmpty {
                Label(suggestion.warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
    }
}
