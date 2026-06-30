//
// SettingsView.swift
// Kasten
//
// ⌘, で開く設定ウィンドウ。Stage 1 は外観（テーマ）の切り替えのみ。
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        TabView {
            appearanceTab
                .tabItem {
                    Label("外観", systemImage: "paintbrush")
                }
        }
        .frame(width: 460, height: 260)
    }

    private var appearanceTab: some View {
        Form {
            Section {
                Picker("テーマ", selection: $themeStore.mode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("「システムに合わせる」を選ぶと、macOS のライト/ダーク設定に追従します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
