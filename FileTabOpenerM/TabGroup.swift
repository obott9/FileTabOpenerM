// TabGroup.swift
// FileTabOpenerM
//
// タブグループのデータモデル

import AppKit

/// タブグループ: 名前 + パスリスト + ウィンドウジオメトリ
struct TabGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var paths: [String]
    var windowX: Int?
    var windowY: Int?
    var windowWidth: Int?
    var windowHeight: Int?

    init(name: String, paths: [String] = []) {
        self.id = UUID()
        self.name = name
        self.paths = paths
    }

    /// ウィンドウジオメトリが設定されているか
    var hasWindowGeometry: Bool {
        windowX != nil && windowY != nil && windowWidth != nil && windowHeight != nil
    }

    /// NSRect に変換 (ジオメトリ未設定なら nil)
    var windowRect: NSRect? {
        guard let x = windowX, let y = windowY,
              let w = windowWidth, let h = windowHeight else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }
}

/// 履歴エントリ
struct HistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var pinned: Bool
    var lastUsed: Date
    var useCount: Int

    init(path: String, pinned: Bool = false) {
        self.id = UUID()
        self.path = path
        self.pinned = pinned
        self.lastUsed = Date()
        self.useCount = 1
    }
}

/// アプリ設定
struct AppSettings: Codable, Equatable {
    var timeout: Int = 30
    var language: String = "auto"
}

/// アプリ全体の設定データ
struct AppConfig: Codable {
    var tabGroups: [TabGroup] = []
    var history: [HistoryEntry] = []
    var settings: AppSettings = AppSettings()
    var windowGeometry: String = "600x400"
}
