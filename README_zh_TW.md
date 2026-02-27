[English](README.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [繁體中文](README_zh_TW.md) | [简体中文](README_zh_CN.md)

# File Tab Opener（macOS 原生版）

用於將資料夾以 Finder 分頁方式批次開啟的 macOS 原生 SwiftUI 應用程式。

本應用是 [file_tab_opener](https://github.com/obott9/file_tab_opener)（Python/Tk 版）的 macOS 原生版本，使用 SwiftUI 打造現代化的 macOS 原生 UI 體驗。

## 功能

- **分頁群組管理** - 建立、重新命名、複製、刪除及重新排序分頁群組
- **一鍵開啟** - 將分頁群組中的所有資料夾以單一 Finder 視窗的分頁形式開啟
- **現代佈局** - 側邊欄＋詳細面板、下拉式排序、右鍵選單、行內編輯 — 同時提供 Python 版相容的經典佈局
- **macOS 原生體驗** - 深色模式、拖放操作、系統字型渲染 — 全部自動遵循 macOS 慣例
- **資料夾歷史** - 最近開啟的資料夾記錄（支援釘選）
- **視窗位置記憶** - 按分頁群組儲存及還原 Finder 視窗的位置與大小
- **穩定分頁控制** - AX API + AppleScript 混合模式；AX API 無需鍵盤模擬即可建立分頁，避免 System Events 權限問題
- **多語言支援** - 英語、日語、韓語、繁體中文、簡體中文
- **路徑驗證** - 新增時檢查路徑是否存在並防止重複
- **拖放操作** - 將資料夾拖放至路徑輸入欄位即可新增

## 截圖

| 經典佈局 | 現代佈局 |
|:-:|:-:|
| ![Classic](docs/images/classic_layout.png) | ![Modern](docs/images/modern_layout.png) |

## 為何選擇原生版？

Python/Tk 版使用 `System Events` 按鍵模擬（⌘T）建立 Finder 分頁，這需要鍵盤模擬權限，且可能與使用者輸入衝突。原生版改用 **Accessibility API**（AX API）以程式化方式按下 Finder 的「新增分頁」按鈕，完全不使用鍵盤事件。

分頁開啟速度與 Python 版相當（10 個分頁約 3 秒）。原生版的主要優勢在於 **基於 SwiftUI 的現代佈局**：側邊欄導覽、下拉式排序、右鍵選單、原生拖放操作、自動深色模式 — 這些功能在 Tk/customtkinter 中難以實現。

## 下載

從 [GitHub Releases](https://github.com/obott9/FileTabOpenerM/releases) 下載最新的 `.app`。

> **注意：** 此應用程式未經公證（Notarization）。首次啟動時 macOS Gatekeeper 可能會阻擋。請右鍵點擊應用程式 →「打開」，然後在對話框中點擊「打開」。

## 系統需求

- macOS 12 Monterey 或更新版本
- 輔助使用權限（首次啟動時會提示授權）

## 建置

1. 在 Xcode 中開啟 `FileTabOpenerM.xcodeproj`
2. 選擇 `FileTabOpenerM` 方案
3. 建置並執行（Cmd+R）

## 使用方式

1. 啟動應用程式
2. 授予輔助使用權限（Finder 分頁控制所需）
3. 點擊 **+ 新增分頁** 建立分頁群組
4. 透過路徑輸入欄位、**瀏覽...** 或拖放方式新增資料夾路徑
5. 點擊 **以分頁開啟** 將所有資料夾以 Finder 分頁開啟

### 運作原理

本應用採用混合模式控制 Finder 分頁：

1. **AX API**（Accessibility API） - 透過程式化方式按下 Finder 的「新增分頁」按鈕建立新分頁，完全排除鍵盤模擬。
2. **AppleScript** - 透過 `set target of front Finder window` 設定各分頁的路徑。使用預編譯的 NSAppleScript 處理程序呼叫，避免重複編譯的額外開銷。
3. **備援機制** - 分頁建立失敗時，將剩餘路徑以獨立 Finder 視窗開啟。

分頁就緒偵測採用 AXUIElement 子元素數量變化監控，而非固定延遲輪詢，因此不受 Mac 硬體效能差異影響，可穩定運作。

## 設定

設定以 JSON 格式儲存於：

```
~/Library/Application Support/FileTabOpenerM/config.json
```

設定檔與 Python 版（file_tab_opener）相容。

## 記錄檔

記錄檔輸出至：

```
~/Library/Logs/FileTabOpenerM/app.log
```

記錄檔超過 1 MB 時自動輪替，最多保留 3 個備份世代（`app.log.1`、`app.log.2`、`app.log.3`）。

## 專案結構

```
FileTabOpenerM/
  FileTabOpenerMApp.swift             # 應用程式進入點、視窗位置儲存與還原
  ContentView.swift                   # 主要 UI、共用視圖、狀態屬性
  ContentView+ClassicLayout.swift     # 經典佈局（Python 版相容）
  ContentView+ModernLayout.swift      # 現代佈局（側邊欄＋詳細面板）
  ContentView+Actions.swift           # 全部動作方法（分頁/路徑/歷史管理）
  Theme.swift                         # 色彩主題、按鈕樣式
  FlowLayout.swift                    # 分頁按鈕換行佈局
  FinderTabController.swift           # AX API + AppleScript Finder 分頁控制
  ConfigManager.swift                 # JSON 設定管理
  TabGroup.swift                      # 資料模型（Codable、Python 版相容）
  Localization.swift                  # 多語言支援（5 種語言、53 個鍵值）
  AppLogger.swift                     # 檔案記錄器（3 世代輪替）
  Assets.xcassets/                    # 應用程式圖示與色彩資源
FileTabOpenerMTests/
  FileTabOpenerMTests.swift           # 單元測試 25 件（Codable、i18n、輔助方法）
```

## 授權條款

[MIT License](LICENSE)
