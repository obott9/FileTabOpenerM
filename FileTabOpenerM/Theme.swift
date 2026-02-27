// Theme.swift
// FileTabOpenerM
//
// Python版 customtkinter "blue" テーマの色定数とボタンスタイル
// ContentView.swift から分離

import SwiftUI

// MARK: - Python版 customtkinter "blue" テーマ色定数

/// Python版の customtkinter blue テーマに合わせた色定義
/// blue.json + widgets.py の _update_ctk_highlight() から抽出
enum PythonTheme {
    // タブボタン (選択)
    static let tabSelectedBg = Color(light: Color(hex: "3B8ED0"), dark: Color(hex: "1F6AA5"))
    // タブボタン (未選択) — gray78 / gray28
    static let tabUnselectedBg = Color(light: Color(hex: "C7C7C7"), dark: Color(hex: "474747"))
    // タブボタンテキスト (選択)
    static let tabSelectedText = Color.white
    // タブボタンテキスト (未選択) — gray20 / gray80
    static let tabUnselectedText = Color(light: Color(hex: "333333"), dark: Color(hex: "CCCCCC"))
    // Listbox 選択色
    static let listSelectBg = Color(hex: "1F6AA5")

    // CTkButton デフォルト色 (blue.json CTkButton セクション)
    static let buttonBg = Color(light: Color(hex: "3B8ED0"), dark: Color(hex: "1F6AA5"))
    static let buttonHover = Color(light: Color(hex: "36719F"), dark: Color(hex: "144870"))
    static let buttonText = Color(hex: "DCE4EE")

    // CTkFrame 背景色 — gray86 / gray17
    static let frameBg = Color(light: Color(hex: "DBDBDB"), dark: Color(hex: "2B2B2B"))
}

// MARK: - CTkButtonStyle (Python版 CTkButton を再現)

/// customtkinter の CTkButton (blue テーマ) と同じ外観のボタンスタイル
struct CTkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(isEnabled ? PythonTheme.buttonText : PythonTheme.buttonText.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed
                          ? PythonTheme.buttonHover
                          : (isEnabled ? PythonTheme.buttonBg : PythonTheme.buttonBg.opacity(0.4)))
            )
    }
}

// MARK: - Color Extensions

extension Color {
    /// hex文字列からColorを生成 (例: "3B8ED0", "#3B8ED0")
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// Light/Dark mode で異なる色を返す
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            }
            return NSColor(light)
        })
    }
}
