// Localization.swift
// FileTabOpenerM
//
// 多言語対応 (i18n)
// 対応言語: en, ja, ko, zh_TW, zh_CN
// キー命名規則: ドット記法 (セクション.項目)

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
            "settings.timeout": "Timeout",
            "settings.seconds": "sec",

            // History
            "history.label": "History:",
            "history.placeholder": "Enter path or drop",
            "history.open": "Open in Finder",
            "history.clear": "Clear",
            "history.empty": "No history",

            // Tab management (shared / Modern context menu)
            "tab.add": "Add",
            "tab.delete": "Delete",
            "tab.rename": "Rename",
            "tab.copy": "Copy",

            // Tab management (Classic buttons — Python版準拠)
            "tab.add_btn": "+ Add Tab",
            "tab.delete_btn": "x Delete Tab",
            "tab.copy_btn": "Copy Tab",

            // Path list
            "path.move_up": "\u{25B2} Up",
            "path.move_down": "\u{25BC} Down",
            "path.add": "+ Add Path",
            "path.remove": "- Remove",
            "path.browse": "Browse...",
            "path.placeholder": "Enter folder path",

            // Geometry
            "geometry.get": "Get from Finder",

            // Open button
            "action.open_tabs": "Open as Tabs",

            // Dialogs
            "dialog.add_tab": "Add Tab",
            "dialog.enter_tab_name": "Enter new tab name:",
            "dialog.delete_title": "Delete Confirmation",
            "dialog.delete_msg": "Delete \"%@\"?",
            "dialog.rename": "Rename",
            "dialog.enter_name": "Enter new name:",
            "dialog.duplicate": "Duplicate",
            "dialog.duplicate_msg": "\"%@\" already exists.",
            "dialog.ok": "OK",
            "dialog.cancel": "Cancel",
            "dialog.yes": "Yes",
            "dialog.no": "No",

            // History dialog
            "dialog.clear_history": "Clear History",
            "dialog.clear_history_msg": "Clear history? (Pinned items will be kept)",

            // Errors
            "error.title": "Error",
            "error.warning": "Warning",
            "error.path_not_found": "Path not found: %@",
            "error.no_finder_window": "No Finder window found",
            "error.tab_bar_hidden": "Tab bar is hidden (View \u{2192} Show Tab Bar)",
            "error.accessibility": "Accessibility permission is required",
            "error.success_count": "%d succeeded, %d failed",
            "error.invalid_paths": "%@ path(s) not found:",
            "error.duplicate_path": "Path \"%@\" already exists in this group.",

            // Accessibility dialog
            "accessibility.title": "Accessibility Permission Required",
            "accessibility.message": "FileTabOpenerM needs Accessibility permission to create and control Finder tabs.\n\nAfter clicking the button below, enable FileTabOpenerM in:\nSystem Settings \u{2192} Privacy & Security \u{2192} Accessibility",
            "accessibility.open_settings": "Open System Settings",

            // Toast
            "toast.opening": "Opening tabs...",
            "toast.progress": "Opening tabs... (%d/%d)",
            "toast.wait": "Please wait.\nDo not use the keyboard or mouse.",

            // Modern layout
            "modern.select_group": "Select a tab group",
            "modern.new_group": "New group name",
        ],

        "ja": [
            // Settings bar
            "settings.timeout": "タイムアウト",
            "settings.seconds": "秒",

            // History
            "history.label": "履歴:",
            "history.placeholder": "パスを入力またはドロップ",
            "history.open": "Finderで開く",
            "history.clear": "クリア",
            "history.empty": "履歴がありません",

            // Tab management (shared / Modern context menu)
            "tab.add": "追加",
            "tab.delete": "削除",
            "tab.rename": "名前変更",
            "tab.copy": "コピー",

            // Tab management (Classic buttons — Python版準拠)
            "tab.add_btn": "+ タブ追加",
            "tab.delete_btn": "x タブ削除",
            "tab.copy_btn": "タブ複製",

            // Path list
            "path.move_up": "\u{25B2} 上へ",
            "path.move_down": "\u{25BC} 下へ",
            "path.add": "+ パス追加",
            "path.remove": "- パス削除",
            "path.browse": "参照...",
            "path.placeholder": "フォルダパスを入力",

            // Geometry
            "geometry.get": "Finderから取得",

            // Open button
            "action.open_tabs": "タブで開く",

            // Dialogs
            "dialog.add_tab": "タブ追加",
            "dialog.enter_tab_name": "新しいタブの名前を入力:",
            "dialog.delete_title": "削除確認",
            "dialog.delete_msg": "「%@」を削除しますか？",
            "dialog.rename": "名前変更",
            "dialog.enter_name": "新しい名前を入力:",
            "dialog.duplicate": "重複",
            "dialog.duplicate_msg": "「%@」は既に存在します。",
            "dialog.ok": "OK",
            "dialog.cancel": "キャンセル",
            "dialog.yes": "はい",
            "dialog.no": "いいえ",

            // History dialog
            "dialog.clear_history": "履歴クリア",
            "dialog.clear_history_msg": "履歴をクリアしますか？（ピン留めは保持）",

            // Errors
            "error.title": "エラー",
            "error.warning": "警告",
            "error.path_not_found": "パスが見つかりません: %@",
            "error.no_finder_window": "Finderウィンドウが見つかりません",
            "error.tab_bar_hidden": "タブバーが非表示です（表示→タブバーを表示）",
            "error.accessibility": "アクセシビリティ権限が必要です",
            "error.success_count": "%d 個成功, %d 個失敗",
            "error.invalid_paths": "%@ 件のパスが見つかりません:",
            "error.duplicate_path": "パス「%@」はこのグループに既に存在します。",

            // Accessibility dialog
            "accessibility.title": "アクセシビリティ権限が必要です",
            "accessibility.message": "FileTabOpenerM が Finder のタブを作成・制御するには、アクセシビリティ権限が必要です。\n\n下のボタンをクリック後、以下で FileTabOpenerM を有効にしてください:\nシステム設定 \u{2192} プライバシーとセキュリティ \u{2192} アクセシビリティ",
            "accessibility.open_settings": "システム設定を開く",

            // Toast
            "toast.opening": "タブを開いています...",
            "toast.progress": "タブを展開中... (%d/%d)",
            "toast.wait": "しばらくお待ちください。\nキーボード・マウスを操作しないでください。",

            // Modern layout
            "modern.select_group": "タブグループを選択してください",
            "modern.new_group": "新規グループ名",
        ],

        "ko": [
            // Settings bar
            "settings.timeout": "타임아웃",
            "settings.seconds": "초",

            // History
            "history.label": "기록:",
            "history.placeholder": "경로 입력 또는 드롭",
            "history.open": "Finder에서 열기",
            "history.clear": "지우기",
            "history.empty": "기록 없음",

            // Tab management (shared / Modern context menu)
            "tab.add": "추가",
            "tab.delete": "삭제",
            "tab.rename": "이름 변경",
            "tab.copy": "복사",

            // Tab management (Classic buttons — Python版準拠)
            "tab.add_btn": "+ 탭 추가",
            "tab.delete_btn": "x 탭 삭제",
            "tab.copy_btn": "탭 복사",

            // Path list
            "path.move_up": "\u{25B2} 위로",
            "path.move_down": "\u{25BC} 아래로",
            "path.add": "+ 경로 추가",
            "path.remove": "- 경로 삭제",
            "path.browse": "찾아보기...",
            "path.placeholder": "폴더 경로 입력",

            // Geometry
            "geometry.get": "Finder에서 가져오기",

            // Open button
            "action.open_tabs": "탭으로 열기",

            // Dialogs
            "dialog.add_tab": "탭 추가",
            "dialog.enter_tab_name": "새 탭 이름 입력:",
            "dialog.delete_title": "삭제 확인",
            "dialog.delete_msg": "\"%@\"을(를) 삭제하시겠습니까?",
            "dialog.rename": "이름 변경",
            "dialog.enter_name": "새 이름 입력:",
            "dialog.duplicate": "중복",
            "dialog.duplicate_msg": "\"%@\"이(가) 이미 존재합니다.",
            "dialog.ok": "확인",
            "dialog.cancel": "취소",
            "dialog.yes": "예",
            "dialog.no": "아니오",

            // History dialog
            "dialog.clear_history": "기록 지우기",
            "dialog.clear_history_msg": "기록을 지우시겠습니까? (고정된 항목은 유지)",

            // Errors
            "error.title": "오류",
            "error.warning": "경고",
            "error.path_not_found": "경로를 찾을 수 없습니다: %@",
            "error.no_finder_window": "Finder 창을 찾을 수 없습니다",
            "error.tab_bar_hidden": "탭 바가 숨겨져 있습니다 (보기 \u{2192} 탭 바 보기)",
            "error.accessibility": "접근성 권한이 필요합니다",
            "error.success_count": "%d개 성공, %d개 실패",
            "error.invalid_paths": "%@개의 경로를 찾을 수 없습니다:",
            "error.duplicate_path": "경로 \"%@\"은(는) 이 그룹에 이미 존재합니다.",

            // Accessibility dialog
            "accessibility.title": "접근성 권한이 필요합니다",
            "accessibility.message": "FileTabOpenerM이 Finder 탭을 생성하고 제어하려면 접근성 권한이 필요합니다.\n\n아래 버튼을 클릭한 후 다음에서 FileTabOpenerM을 활성화하세요:\n시스템 설정 \u{2192} 개인정보 보호 및 보안 \u{2192} 접근성",
            "accessibility.open_settings": "시스템 설정 열기",

            // Toast
            "toast.opening": "탭을 여는 중...",
            "toast.progress": "탭 열는 중... (%d/%d)",
            "toast.wait": "잠시 기다려 주세요.\n키보드와 마우스를 사용하지 마세요.",

            // Modern layout
            "modern.select_group": "탭 그룹을 선택하세요",
            "modern.new_group": "새 그룹 이름",
        ],

        "zh_TW": [
            // Settings bar
            "settings.timeout": "逾時",
            "settings.seconds": "秒",

            // History
            "history.label": "歷史:",
            "history.placeholder": "輸入路徑或拖放",
            "history.open": "在 Finder 中開啟",
            "history.clear": "清除",
            "history.empty": "無歷史記錄",

            // Tab management (shared / Modern context menu)
            "tab.add": "新增",
            "tab.delete": "刪除",
            "tab.rename": "重新命名",
            "tab.copy": "複製",

            // Tab management (Classic buttons — Python版準拠)
            "tab.add_btn": "+ 新增分頁",
            "tab.delete_btn": "x 刪除分頁",
            "tab.copy_btn": "複製分頁",

            // Path list
            "path.move_up": "\u{25B2} 上移",
            "path.move_down": "\u{25BC} 下移",
            "path.add": "+ 新增路徑",
            "path.remove": "- 移除路徑",
            "path.browse": "瀏覽...",
            "path.placeholder": "輸入資料夾路徑",

            // Geometry
            "geometry.get": "從 Finder 取得",

            // Open button
            "action.open_tabs": "以分頁開啟",

            // Dialogs
            "dialog.add_tab": "新增分頁",
            "dialog.enter_tab_name": "輸入新分頁名稱:",
            "dialog.delete_title": "刪除確認",
            "dialog.delete_msg": "確定要刪除「%@」嗎？",
            "dialog.rename": "重新命名",
            "dialog.enter_name": "輸入新名稱:",
            "dialog.duplicate": "重複",
            "dialog.duplicate_msg": "「%@」已經存在。",
            "dialog.ok": "確定",
            "dialog.cancel": "取消",
            "dialog.yes": "是",
            "dialog.no": "否",

            // History dialog
            "dialog.clear_history": "清除歷史",
            "dialog.clear_history_msg": "確定要清除歷史嗎？（釘選項目將保留）",

            // Errors
            "error.title": "錯誤",
            "error.warning": "警告",
            "error.path_not_found": "找不到路徑: %@",
            "error.no_finder_window": "找不到 Finder 視窗",
            "error.tab_bar_hidden": "分頁列已隱藏（顯示 \u{2192} 顯示分頁列）",
            "error.accessibility": "需要輔助使用權限",
            "error.success_count": "%d 個成功, %d 個失敗",
            "error.invalid_paths": "找不到 %@ 個路徑:",
            "error.duplicate_path": "路徑「%@」已存在於此群組中。",

            // Accessibility dialog
            "accessibility.title": "需要輔助使用權限",
            "accessibility.message": "FileTabOpenerM 需要輔助使用權限來建立和控制 Finder 分頁。\n\n點擊下方按鈕後，請在以下位置啟用 FileTabOpenerM:\n系統設定 \u{2192} 隱私權與安全性 \u{2192} 輔助使用",
            "accessibility.open_settings": "開啟系統設定",

            // Toast
            "toast.opening": "正在開啟分頁...",
            "toast.progress": "正在開啟分頁... (%d/%d)",
            "toast.wait": "請稍候。\n請勿使用鍵盤或滑鼠。",

            // Modern layout
            "modern.select_group": "請選擇分頁群組",
            "modern.new_group": "新群組名稱",
        ],

        "zh_CN": [
            // Settings bar
            "settings.timeout": "超时",
            "settings.seconds": "秒",

            // History
            "history.label": "历史:",
            "history.placeholder": "输入路径或拖放",
            "history.open": "在 Finder 中打开",
            "history.clear": "清除",
            "history.empty": "无历史记录",

            // Tab management (shared / Modern context menu)
            "tab.add": "添加",
            "tab.delete": "删除",
            "tab.rename": "重命名",
            "tab.copy": "复制",

            // Tab management (Classic buttons — Python版準拠)
            "tab.add_btn": "+ 添加标签",
            "tab.delete_btn": "x 删除标签",
            "tab.copy_btn": "复制标签",

            // Path list
            "path.move_up": "\u{25B2} 上移",
            "path.move_down": "\u{25BC} 下移",
            "path.add": "+ 添加路径",
            "path.remove": "- 删除路径",
            "path.browse": "浏览...",
            "path.placeholder": "输入文件夹路径",

            // Geometry
            "geometry.get": "从 Finder 获取",

            // Open button
            "action.open_tabs": "以标签页打开",

            // Dialogs
            "dialog.add_tab": "添加标签页",
            "dialog.enter_tab_name": "输入新标签页名称:",
            "dialog.delete_title": "删除确认",
            "dialog.delete_msg": "确定要删除\u{201C}%@\u{201D}吗？",
            "dialog.rename": "重命名",
            "dialog.enter_name": "输入新名称:",
            "dialog.duplicate": "重复",
            "dialog.duplicate_msg": "\u{201C}%@\u{201D}已经存在。",
            "dialog.ok": "确定",
            "dialog.cancel": "取消",
            "dialog.yes": "是",
            "dialog.no": "否",

            // History dialog
            "dialog.clear_history": "清除历史",
            "dialog.clear_history_msg": "确定要清除历史吗？（固定项目将保留）",

            // Errors
            "error.title": "错误",
            "error.warning": "警告",
            "error.path_not_found": "找不到路径: %@",
            "error.no_finder_window": "找不到 Finder 窗口",
            "error.tab_bar_hidden": "标签栏已隐藏（显示 \u{2192} 显示标签栏）",
            "error.accessibility": "需要辅助功能权限",
            "error.success_count": "%d 个成功, %d 个失败",
            "error.invalid_paths": "找不到 %@ 个路径:",
            "error.duplicate_path": "路径「%@」已存在于此组中。",

            // Accessibility dialog
            "accessibility.title": "需要辅助功能权限",
            "accessibility.message": "FileTabOpenerM 需要辅助功能权限来创建和控制 Finder 标签页。\n\n点击下方按钮后，请在以下位置启用 FileTabOpenerM:\n系统设置 \u{2192} 隐私与安全性 \u{2192} 辅助功能",
            "accessibility.open_settings": "打开系统设置",

            // Toast
            "toast.opening": "正在打开标签页...",
            "toast.progress": "正在打开标签页... (%d/%d)",
            "toast.wait": "请稍候。\n请勿使用键盘或鼠标。",

            // Modern layout
            "modern.select_group": "请选择标签页组",
            "modern.new_group": "新组名称",
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
