//
// ShellIntegrationSetup.swift
// Kasten
//
// Created by inugaminé on 2026/06/20.
//
  

import Foundation

enum ShellIntegrationSetup {
    
    struct Result {
        let zdotdir: String   // zsh に渡す ZDOTDIR（Kastenの一時ディレクトリ）
    }
    
    /// Kasten の zsh 統合スクリプト本体（OSC 133 フック）。
    /// 文字列で持つことで Xcode のリソース設定を不要にしている。
    private static let integrationScript = #"""
    # kasten-integration.zsh （Kasten が自動生成）
    if [[ -n "$KASTEN_SHELL_INTEGRATION_LOADED" ]]; then
        return 0
    fi
    typeset -g KASTEN_SHELL_INTEGRATION_LOADED=1
    
    autoload -Uz add-zsh-hook
    typeset -g __kasten_first_prompt=1
    
    __kasten_precmd() {
        local exit_code=$?
        if [[ -n "$__kasten_first_prompt" ]]; then
            unset __kasten_first_prompt
        else
            print -n "\e]133;D;${exit_code}\a"
        fi

        # ディレクトリ・ブランチはプロンプト開始(A)より先に送る。
        # A で区切り線を引く瞬間に、最新の値が揃っているようにするため。
        # （逆にすると、線に添える情報が１テンポ遅れる）

        # カレントディレクトリを通知（VSCode 互換の OSC 633;P;Cwd=...）
        print -n "\e]633;P;Cwd=${PWD}\a"

        # Git ブランチを通知（Kasten 独自プロパティ）。
        # git リポジトリ外では空文字を送って「ブランチ無し」を伝える。
        local __kasten_branch=""
        if command git rev-parse --is-inside-work-tree &>/dev/null; then
            __kasten_branch=$(command git symbolic-ref --short HEAD 2>/dev/null)
            if [[ -z "$__kasten_branch" ]]; then
                # detached HEAD の場合は短いコミットハッシュ
                __kasten_branch=$(command git rev-parse --short HEAD 2>/dev/null)
            fi
        fi
        print -n "\e]633;P;KastenGitBranch=${__kasten_branch}\a"

        # 最後にプロンプト開始を送る（この時点でディレクトリ・ブランチが揃っている）
        print -n "\e]133;A\a"
    }
    
    __kasten_preexec() {
        print -n "\e]133;C\a"
    }
    
    add-zsh-hook precmd __kasten_precmd
    add-zsh-hook preexec __kasten_preexec
    """#
    
    /// 一時ディレクトリに .zshrc と統合スクリプトを書き出し、ZDOTDIR を返す。
    static func prepare() -> Result? {
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let userZdotdir = ProcessInfo.processInfo.environment["ZDOTDIR"] ?? homeDir
        
        let kastenDir = fm.temporaryDirectory
            .appendingPathComponent("kasten-shell-integration", isDirectory: true)
        do {
            try fm.createDirectory(at: kastenDir, withIntermediateDirectories: true)
        } catch { return nil }
        
        let scriptURL = kastenDir.appendingPathComponent("kasten-integration.zsh")
        let zshrcURL = kastenDir.appendingPathComponent(".zshrc")
        
        let zshrcContents = """
        # Kasten が自動生成した一時 .zshrc
        export ZDOTDIR="\(userZdotdir)"
        
        if [[ -f "\(userZdotdir)/.zprofile" ]]; then
            source "\(userZdotdir)/.zprofile"
        fi
        
        if [[ -f "\(userZdotdir)/.zshrc" ]]; then
            source "\(userZdotdir)/.zshrc"
        fi
        
        if [[ -f "\(userZdotdir)/.zlogin" ]]; then
            source "\(userZdotdir)/.zlogin"
        fi
        
        if [[ -f "\(scriptURL.path)" ]]; then
            source "\(scriptURL.path)"
        fi
        """
        
        do {
            try integrationScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try zshrcContents.write(to: zshrcURL, atomically: true, encoding: .utf8)
        } catch { return nil }
        
        return Result(zdotdir: kastenDir.path)
    }
}
