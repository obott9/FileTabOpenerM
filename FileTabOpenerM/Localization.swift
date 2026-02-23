// Localization.swift
// FileTabOpenerM
//
// 多言語対応 (i18n)
// 対応言語: en, ja, ko, zh_TW, zh_CN

import Foundation

/// ローカライズ文字列を取得
func L(_ key: String) -> String {
    Localization.shared.string(for: key)
}

final class Localization {

    static let shared = Localization()

    /// 現在の言語コード
    var currentLanguage: String {
        let setting = ConfigManager.shared.config.settings.language
        if setting == "auto" {
            return detectSystemLanguage()
        }
        return setting
    }

    /// システム言語を検出
    private func detectSystemLanguage() -> String {
        guard let preferred = Locale.preferredLanguages.first else { return "en" }
        let lower = preferred.lowercased()
        if lower.hasPrefix("ja") { return "ja" }
        if lower.hasPrefix("ko") { return "ko" }
        if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh_tw") || lower.hasPrefix("zh-tw") {
            return "zh_TW"
        }
        if lower.hasPrefix("zh") { return "zh_CN" }
        return "en"
    }

    /// キーからローカライズ文字列を取得
    func string(for key: String) -> String {
        let lang = currentLanguage
        if let table = translations[lang], let value = table[key] {
            return value
        }
        // フォールバック: en → key そのまま
        if let value = translations["en"]?[key] {
            return value
        }
        return key
    }

    // MARK: - 翻訳テーブル

    private let translations: [String: [String: String]] = [
        "en": [
            // Settings bar
            "timeout": "Timeout",
            "seconds": "sec",

            // History
            "history": "History:",
            "enter_path_or_drop": "Enter path or drop",
            "open_in_finder": "Open in Finder",
            "clear": "Clear",
            "no_history": "No history",

            // Tab management
            "add": "Add",
            "delete": "Delete",
            "rename": "Rename",
            "copy": "Copy",

            // Path list
            "move_up": "\u{25B2} Up",
            "move_down": "\u{25BC} Down",
            "add_path": "+ Add",
            "remove_path": "- Remove",
            "browse": "Browse...",
            "enter_folder_path": "Enter folder path",

            // Geometry
            "get_from_finder": "Get from Finder",

            // Open button
            "open_as_tabs": "Open as Tabs",

            // Dialogs
            "add_tab": "Add Tab",
            "enter_new_tab_name": "Enter new tab name:",
            "delete_confirm": "Delete Confirmation",
            "delete_confirm_msg": "Delete \"%@\"?",
            "rename_tab": "Rename",
            "enter_new_name": "Enter new name:",
            "duplicate": "Duplicate",
            "duplicate_msg": "\"%@\" already exists.",
            "ok": "OK",
            "cancel": "Cancel",
            "yes": "Yes",
            "no": "No",

            // History dialog
            "clear_history": "Clear History",
            "clear_history_msg": "Clear history? (Pinned items will be kept)",

            // Errors
            "error": "Error",
            "warning": "Warning",
            "path_not_found": "Path not found: %@",
            "no_finder_window": "No Finder window found",
            "tab_bar_hidden": "Tab bar is hidden (View \u{2192} Show Tab Bar)",
            "accessibility_required": "Accessibility permission is required",
            "success_count": "%d succeeded, %d failed",
            "invalid_paths_msg": "%@ path(s) not found:",

            // Accessibility dialog
            "accessibility_dialog_title": "Accessibility Permission Required",
            "accessibility_dialog_message": "FileTabOpenerM needs Accessibility permission to create and control Finder tabs.\n\nAfter clicking the button below, enable FileTabOpenerM in:\nSystem Settings \u{2192} Privacy & Security \u{2192} Accessibility",
            "open_system_settings": "Open System Settings",

            // Toast
            "opening_tabs": "Opening tabs...",

            // Modern layout
            "select_tab_group": "Select a tab group",
            "new_group_name": "New group name",
        ],

        "ja": [
            // Settings bar
            "timeout": "タイムアウト",
            "seconds": "秒",

            // History
            "history": "履歴:",
            "enter_path_or_drop": "パスを入力またはドロップ",
            "open_in_finder": "Finderで開く",
            "clear": "クリア",
            "no_history": "履歴がありません",

            // Tab management
            "add": "追加",
            "delete": "削除",
            "rename": "名前変更",
            "copy": "コピー",

            // Path list
            "move_up": "\u{25B2} 上へ",
            "move_down": "\u{25BC} 下へ",
            "add_path": "+ 追加",
            "remove_path": "- 削除",
            "browse": "参照...",
            "enter_folder_path": "フォルダパスを入力",

            // Geometry
            "get_from_finder": "Finderから取得",

            // Open button
            "open_as_tabs": "タブで開く",

            // Dialogs
            "add_tab": "タブ追加",
            "enter_new_tab_name": "新しいタブの名前を入力:",
            "delete_confirm": "削除確認",
            "delete_confirm_msg": "「%@」を削除しますか？",
            "rename_tab": "名前変更",
            "enter_new_name": "新しい名前を入力:",
            "duplicate": "重複",
            "duplicate_msg": "「%@」は既に存在します。",
            "ok": "OK",
            "cancel": "キャンセル",
            "yes": "はい",
            "no": "いいえ",

            // History dialog
            "clear_history": "履歴クリア",
            "clear_history_msg": "履歴をクリアしますか？（ピン留めは保持）",

            // Errors
            "error": "エラー",
            "warning": "警告",
            "path_not_found": "パスが見つかりません: %@",
            "no_finder_window": "Finderウィンドウが見つかりません",
            "tab_bar_hidden": "タブバーが非表示です（表示→タブバーを表示）",
            "accessibility_required": "アクセシビリティ権限が必要です",
            "success_count": "%d 個成功, %d 個失敗",
            "invalid_paths_msg": "%@ 件のパスが見つかりません:",

            // Accessibility dialog
            "accessibility_dialog_title": "アクセシビリティ権限が必要です",
            "accessibility_dialog_message": "FileTabOpenerM が Finder のタブを作成・制御するには、アクセシビリティ権限が必要です。\n\n下のボタンをクリック後、以下で FileTabOpenerM を有効にしてください:\nシステム設定 \u{2192} プライバシーとセキュリティ \u{2192} アクセシビリティ",
            "open_system_settings": "システム設定を開く",

            // Toast
            "opening_tabs": "タブを開いています...",

            // Modern layout
            "select_tab_group": "タブグループを選択してください",
            "new_group_name": "新規グループ名",
        ],

        "ko": [
            // Settings bar
            "timeout": "타임아웃",
            "seconds": "초",

            // History
            "history": "기록:",
            "enter_path_or_drop": "경로 입력 또는 드롭",
            "open_in_finder": "Finder에서 열기",
            "clear": "지우기",
            "no_history": "기록 없음",

            // Tab management
            "add": "추가",
            "delete": "삭제",
            "rename": "이름 변경",
            "copy": "복사",

            // Path list
            "move_up": "\u{25B2} 위로",
            "move_down": "\u{25BC} 아래로",
            "add_path": "+ 추가",
            "remove_path": "- 삭제",
            "browse": "찾아보기...",
            "enter_folder_path": "폴더 경로 입력",

            // Geometry
            "get_from_finder": "Finder에서 가져오기",

            // Open button
            "open_as_tabs": "탭으로 열기",

            // Dialogs
            "add_tab": "탭 추가",
            "enter_new_tab_name": "새 탭 이름 입력:",
            "delete_confirm": "삭제 확인",
            "delete_confirm_msg": "\"%@\"을(를) 삭제하시겠습니까?",
            "rename_tab": "이름 변경",
            "enter_new_name": "새 이름 입력:",
            "duplicate": "중복",
            "duplicate_msg": "\"%@\"이(가) 이미 존재합니다.",
            "ok": "확인",
            "cancel": "취소",
            "yes": "예",
            "no": "아니오",

            // History dialog
            "clear_history": "기록 지우기",
            "clear_history_msg": "기록을 지우시겠습니까? (고정된 항목은 유지)",

            // Errors
            "error": "오류",
            "warning": "경고",
            "path_not_found": "경로를 찾을 수 없습니다: %@",
            "no_finder_window": "Finder 창을 찾을 수 없습니다",
            "tab_bar_hidden": "탭 바가 숨겨져 있습니다 (보기 \u{2192} 탭 바 보기)",
            "accessibility_required": "접근성 권한이 필요합니다",
            "success_count": "%d개 성공, %d개 실패",
            "invalid_paths_msg": "%@개의 경로를 찾을 수 없습니다:",

            // Accessibility dialog
            "accessibility_dialog_title": "접근성 권한이 필요합니다",
            "accessibility_dialog_message": "FileTabOpenerM이 Finder 탭을 생성하고 제어하려면 접근성 권한이 필요합니다.\n\n아래 버튼을 클릭한 후 다음에서 FileTabOpenerM을 활성화하세요:\n시스템 설정 \u{2192} 개인정보 보호 및 보안 \u{2192} 접근성",
            "open_system_settings": "시스템 설정 열기",

            // Toast
            "opening_tabs": "탭을 여는 중...",

            // Modern layout
            "select_tab_group": "탭 그룹을 선택하세요",
            "new_group_name": "새 그룹 이름",
        ],

        "zh_TW": [
            // Settings bar
            "timeout": "逾時",
            "seconds": "秒",

            // History
            "history": "歷史:",
            "enter_path_or_drop": "輸入路徑或拖放",
            "open_in_finder": "在 Finder 中開啟",
            "clear": "清除",
            "no_history": "無歷史記錄",

            // Tab management
            "add": "新增",
            "delete": "刪除",
            "rename": "重新命名",
            "copy": "複製",

            // Path list
            "move_up": "\u{25B2} 上移",
            "move_down": "\u{25BC} 下移",
            "add_path": "+ 新增",
            "remove_path": "- 刪除",
            "browse": "瀏覽...",
            "enter_folder_path": "輸入資料夾路徑",

            // Geometry
            "get_from_finder": "從 Finder 取得",

            // Open button
            "open_as_tabs": "以分頁開啟",

            // Dialogs
            "add_tab": "新增分頁",
            "enter_new_tab_name": "輸入新分頁名稱:",
            "delete_confirm": "刪除確認",
            "delete_confirm_msg": "確定要刪除「%@」嗎？",
            "rename_tab": "重新命名",
            "enter_new_name": "輸入新名稱:",
            "duplicate": "重複",
            "duplicate_msg": "「%@」已經存在。",
            "ok": "確定",
            "cancel": "取消",
            "yes": "是",
            "no": "否",

            // History dialog
            "clear_history": "清除歷史",
            "clear_history_msg": "確定要清除歷史嗎？（釘選項目將保留）",

            // Errors
            "error": "錯誤",
            "warning": "警告",
            "path_not_found": "找不到路徑: %@",
            "no_finder_window": "找不到 Finder 視窗",
            "tab_bar_hidden": "分頁列已隱藏（顯示 \u{2192} 顯示分頁列）",
            "accessibility_required": "需要輔助使用權限",
            "success_count": "%d 個成功, %d 個失敗",
            "invalid_paths_msg": "找不到 %@ 個路徑:",

            // Accessibility dialog
            "accessibility_dialog_title": "需要輔助使用權限",
            "accessibility_dialog_message": "FileTabOpenerM 需要輔助使用權限來建立和控制 Finder 分頁。\n\n點擊下方按鈕後，請在以下位置啟用 FileTabOpenerM:\n系統設定 \u{2192} 隱私權與安全性 \u{2192} 輔助使用",
            "open_system_settings": "開啟系統設定",

            // Toast
            "opening_tabs": "正在開啟分頁...",

            // Modern layout
            "select_tab_group": "請選擇分頁群組",
            "new_group_name": "新群組名稱",
        ],

        "zh_CN": [
            // Settings bar
            "timeout": "超时",
            "seconds": "秒",

            // History
            "history": "历史:",
            "enter_path_or_drop": "输入路径或拖放",
            "open_in_finder": "在 Finder 中打开",
            "clear": "清除",
            "no_history": "无历史记录",

            // Tab management
            "add": "添加",
            "delete": "删除",
            "rename": "重命名",
            "copy": "复制",

            // Path list
            "move_up": "\u{25B2} 上移",
            "move_down": "\u{25BC} 下移",
            "add_path": "+ 添加",
            "remove_path": "- 删除",
            "browse": "浏览...",
            "enter_folder_path": "输入文件夹路径",

            // Geometry
            "get_from_finder": "从 Finder 获取",

            // Open button
            "open_as_tabs": "以标签页打开",

            // Dialogs
            "add_tab": "添加标签页",
            "enter_new_tab_name": "输入新标签页名称:",
            "delete_confirm": "删除确认",
            "delete_confirm_msg": "确定要删除\u{201C}%@\u{201D}吗？",
            "rename_tab": "重命名",
            "enter_new_name": "输入新名称:",
            "duplicate": "重复",
            "duplicate_msg": "\u{201C}%@\u{201D}已经存在。",
            "ok": "确定",
            "cancel": "取消",
            "yes": "是",
            "no": "否",

            // History dialog
            "clear_history": "清除历史",
            "clear_history_msg": "确定要清除历史吗？（固定项目将保留）",

            // Errors
            "error": "错误",
            "warning": "警告",
            "path_not_found": "找不到路径: %@",
            "no_finder_window": "找不到 Finder 窗口",
            "tab_bar_hidden": "标签栏已隐藏（显示 \u{2192} 显示标签栏）",
            "accessibility_required": "需要辅助功能权限",
            "success_count": "%d 个成功, %d 个失败",
            "invalid_paths_msg": "找不到 %@ 个路径:",

            // Accessibility dialog
            "accessibility_dialog_title": "需要辅助功能权限",
            "accessibility_dialog_message": "FileTabOpenerM 需要辅助功能权限来创建和控制 Finder 标签页。\n\n点击下方按钮后，请在以下位置启用 FileTabOpenerM:\n系统设置 \u{2192} 隐私与安全性 \u{2192} 辅助功能",
            "open_system_settings": "打开系统设置",

            // Toast
            "opening_tabs": "正在打开标签页...",

            // Modern layout
            "select_tab_group": "请选择标签页组",
            "new_group_name": "新组名称",
        ],
    ]
}

// MARK: - String format helper

extension String {
    /// %@ を置換する簡易フォーマット
    func localized(_ args: String...) -> String {
        var result = self
        for arg in args {
            if let range = result.range(of: "%@") {
                result.replaceSubrange(range, with: arg)
            }
        }
        return result
    }

    /// %d を置換する簡易フォーマット
    func localized(_ args: Int...) -> String {
        var result = self
        for arg in args {
            if let range = result.range(of: "%d") {
                result.replaceSubrange(range, with: String(arg))
            }
        }
        return result
    }
}
