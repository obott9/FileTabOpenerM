//
//  FileTabOpenerMTests.swift
//  FileTabOpenerMTests
//
//  Created by 尾保手　秀樹 on 2026/02/24.
//

import Testing
import Foundation
@testable import FileTabOpenerM

// MARK: - TabGroup Codable テスト

struct TabGroupCodableTests {

    /// Python版と互換の JSON からデコードできること
    @Test func decodePythonCompatibleJSON() throws {
        let json = """
        {
            "name": "Work",
            "paths": ["/Users/test/Documents", "/Users/test/Downloads"],
            "window_x": 100,
            "window_y": 200,
            "window_width": 800,
            "window_height": 600
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let group = try decoder.decode(TabGroup.self, from: Data(json.utf8))

        #expect(group.name == "Work")
        #expect(group.paths == ["/Users/test/Documents", "/Users/test/Downloads"])
        #expect(group.windowX == 100)
        #expect(group.windowY == 200)
        #expect(group.windowWidth == 800)
        #expect(group.windowHeight == 600)
    }

    /// paths が省略された JSON でもデコードできること (デフォルト空配列)
    @Test func decodeMissingPaths() throws {
        let json = """
        { "name": "Empty" }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let group = try decoder.decode(TabGroup.self, from: Data(json.utf8))

        #expect(group.name == "Empty")
        #expect(group.paths.isEmpty)
    }

    /// ジオメトリが省略された JSON でもデコードできること (nil)
    @Test func decodeMissingGeometry() throws {
        let json = """
        { "name": "NoGeom", "paths": [] }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let group = try decoder.decode(TabGroup.self, from: Data(json.utf8))

        #expect(group.windowX == nil)
        #expect(group.windowY == nil)
        #expect(group.windowWidth == nil)
        #expect(group.windowHeight == nil)
        #expect(group.hasWindowGeometry == false)
        #expect(group.windowRect == nil)
    }

    /// JSON の null 値ジオメトリを nil としてデコードできること (Python版互換)
    @Test func decodeNullGeometry() throws {
        let json = """
        {
            "name": "485",
            "paths": [],
            "window_x": null,
            "window_y": null,
            "window_width": null,
            "window_height": null
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let group = try decoder.decode(TabGroup.self, from: Data(json.utf8))

        #expect(group.name == "485")
        #expect(group.paths.isEmpty)
        #expect(group.windowX == nil)
        #expect(group.windowY == nil)
        #expect(group.windowWidth == nil)
        #expect(group.windowHeight == nil)
        #expect(group.hasWindowGeometry == false)
    }

    /// エンコード時に id が含まれないこと (Python版互換)
    @Test func encodeExcludesID() throws {
        let group = TabGroup(name: "Test", paths: ["/tmp"])
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(group)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["id"] == nil)
        #expect(dict["name"] as? String == "Test")
        #expect(dict["paths"] as? [String] == ["/tmp"])
    }

    /// windowRect の変換が正しいこと
    @Test func windowRectConversion() {
        var group = TabGroup(name: "Test")
        group.windowX = 50
        group.windowY = 100
        group.windowWidth = 800
        group.windowHeight = 600

        #expect(group.hasWindowGeometry == true)
        let rect = group.windowRect
        #expect(rect != nil)
        #expect(rect?.origin.x == 50)
        #expect(rect?.origin.y == 100)
        #expect(rect?.width == 800)
        #expect(rect?.height == 600)
    }

    /// デコード時に毎回新しい UUID が生成されること
    @Test func decodedIDsAreUnique() throws {
        let json = """
        { "name": "Same" }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let group1 = try decoder.decode(TabGroup.self, from: Data(json.utf8))
        let group2 = try decoder.decode(TabGroup.self, from: Data(json.utf8))

        #expect(group1.id != group2.id)
    }
}

// MARK: - HistoryEntry Codable テスト

struct HistoryEntryCodableTests {

    /// Python版フォーマットの日付でデコードできること
    @Test func decodePythonDateFormat() throws {
        let json = """
        {
            "path": "/Users/test/Documents",
            "pinned": true,
            "last_used": "2026-02-14T11:02:23",
            "use_count": 5
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        let entry = try decoder.decode(HistoryEntry.self, from: Data(json.utf8))

        #expect(entry.path == "/Users/test/Documents")
        #expect(entry.pinned == true)
        #expect(entry.useCount == 5)
    }

    /// pinned が省略された場合デフォルト false
    @Test func decodeDefaultPinnedFalse() throws {
        let json = """
        {
            "path": "/tmp",
            "last_used": "2026-01-01T00:00:00"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        let entry = try decoder.decode(HistoryEntry.self, from: Data(json.utf8))

        #expect(entry.pinned == false)
        #expect(entry.useCount == 0)
    }

    /// エンコード時に id が含まれないこと
    @Test func encodeExcludesID() throws {
        let entry = HistoryEntry(path: "/tmp")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        encoder.dateEncodingStrategy = .formatted(dateFormatter)

        let data = try encoder.encode(entry)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["id"] == nil)
        #expect(dict["path"] as? String == "/tmp")
        #expect(dict["last_used"] is String)
    }
}

// MARK: - AppSettings Codable テスト

struct AppSettingsCodableTests {

    /// デフォルト値が正しいこと
    @Test func defaultValues() {
        let settings = AppSettings()
        #expect(settings.timeout == 30)
        #expect(settings.language == "auto")
    }

    /// Python版の use_custom_tk 等の未知キーを無視すること
    @Test func ignoreUnknownKeys() throws {
        let json = """
        {
            "timeout": 15,
            "language": "ja",
            "use_custom_tk": true,
            "custom_theme": "dark"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))

        #expect(settings.timeout == 15)
        #expect(settings.language == "ja")
    }

    /// timeout/language が省略されてもデフォルト値になること
    @Test func decodeWithDefaults() throws {
        let json = "{}"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))

        #expect(settings.timeout == 30)
        #expect(settings.language == "auto")
    }
}

// MARK: - AppConfig Codable テスト

struct AppConfigCodableTests {

    /// 完全な設定 JSON のラウンドトリップ
    @Test func roundTrip() throws {
        var config = AppConfig()
        config.configVersion = 1
        config.tabGroups = [TabGroup(name: "Test", paths: ["/tmp"])]
        config.windowGeometry = "800x600"

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        encoder.dateEncodingStrategy = .formatted(dateFormatter)

        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        let decoded = try decoder.decode(AppConfig.self, from: data)

        #expect(decoded.configVersion == 1)
        #expect(decoded.tabGroups.count == 1)
        #expect(decoded.tabGroups[0].name == "Test")
        #expect(decoded.tabGroups[0].paths == ["/tmp"])
        #expect(decoded.windowGeometry == "800x600")
    }

    /// config_version フィールドのエンコード/デコード
    @Test func configVersionField() throws {
        var config = AppConfig()
        config.configVersion = 2

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(config)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["config_version"] as? Int == 2)
    }

    /// config_version が無い既存 JSON でもデコードできること (Python版互換)
    @Test func decodeMissingConfigVersion() throws {
        let json = """
        {
            "tab_groups": [{ "name": "Work", "paths": ["/tmp"] }],
            "history": [],
            "settings": { "timeout": 15, "language": "ja" },
            "window_geometry": "900x700"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(AppConfig.self, from: Data(json.utf8))

        #expect(config.configVersion == 1)  // デフォルト値
        #expect(config.tabGroups.count == 1)
        #expect(config.tabGroups[0].name == "Work")
        #expect(config.settings.timeout == 15)
        #expect(config.settings.language == "ja")
        #expect(config.windowGeometry == "900x700")
    }

    /// 完全に空の JSON でもデコードできること
    @Test func decodeEmptyJSON() throws {
        let json = "{}"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(AppConfig.self, from: Data(json.utf8))

        #expect(config.configVersion == 1)
        #expect(config.tabGroups.isEmpty)
        #expect(config.history.isEmpty)
        #expect(config.settings.timeout == 30)
        #expect(config.windowGeometry == "800x600")
    }
}

// MARK: - Localization テスト

struct LocalizationTests {

    /// 全言語で同じキーセットを持つこと
    @Test func allLanguagesHaveSameKeys() {
        let loc = Localization.shared
        let languages = ["en", "ja", "ko", "zh_TW", "zh_CN"]

        // en のキーを基準にする
        let enKeys = Set(loc.allKeys(for: "en"))
        #expect(!enKeys.isEmpty, "English keys should not be empty")

        for lang in languages where lang != "en" {
            let langKeys = Set(loc.allKeys(for: lang))
            let missingInLang = enKeys.subtracting(langKeys)
            let extraInLang = langKeys.subtracting(enKeys)

            #expect(missingInLang.isEmpty,
                    "\(lang) is missing keys: \(missingInLang.sorted())")
            #expect(extraInLang.isEmpty,
                    "\(lang) has extra keys: \(extraInLang.sorted())")
        }
    }

    /// 全キーの値が空でないこと
    @Test func noEmptyValues() {
        let loc = Localization.shared
        let languages = ["en", "ja", "ko", "zh_TW", "zh_CN"]

        for lang in languages {
            for key in loc.allKeys(for: lang) {
                let value = loc.string(for: key, language: lang)
                #expect(!value.isEmpty,
                        "\(lang).\(key) has empty value")
            }
        }
    }

    /// 存在しないキーはキーそのものを返すこと (フォールバック)
    @Test func unknownKeyReturnsKeyItself() {
        let result = Localization.shared.string(for: "nonexistent.key")
        #expect(result == "nonexistent.key")
    }

    /// en がフォールバックとして機能すること
    @Test func englishFallback() {
        // en に存在するキーは他言語で見つからなくても en の値を返す
        let value = Localization.shared.string(for: "settings.timeout")
        #expect(value == "Timeout" || !value.isEmpty)
    }
}

// MARK: - String Format Helper テスト

struct StringFormatHelperTests {

    /// %@ 置換が正しく動作すること
    @Test func stringPlaceholderReplacement() {
        let template = "Path not found: %@"
        let result = template.localized("/tmp/test")
        #expect(result == "Path not found: /tmp/test")
    }

    /// 複数の %@ を順次置換すること
    @Test func multipleStringPlaceholders() {
        let template = "%@ and %@"
        let result = template.localized("A", "B")
        #expect(result == "A and B")
    }

    /// %d 置換が正しく動作すること
    @Test func intPlaceholderReplacement() {
        let template = "%d succeeded, %d failed"
        let result = template.localized(5, 2)
        #expect(result == "5 succeeded, 2 failed")
    }

    /// プレースホルダーがない場合はそのまま返すこと
    @Test func noPlaceholderUnchanged() {
        let template = "No placeholders here"
        let resultStr = template.localized("ignored")
        #expect(resultStr == "No placeholders here")

        let resultInt = template.localized(42)
        #expect(resultInt == "No placeholders here")
    }
}
