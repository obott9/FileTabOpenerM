[English](README.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [繁體中文](README_zh_TW.md) | [简体中文](README_zh_CN.md)

# File Tab Opener (macOS ネイティブ)

フォルダを Finder のタブとしてまとめて開くための macOS ネイティブ SwiftUI アプリケーションです。

[file_tab_opener](https://github.com/obott9/file_tab_opener)（Python/Tk版）の macOS ネイティブ版で、SwiftUI と Accessibility API により高速で安定した Finder タブ制御を実現しています。

## 機能

- **タブグループ管理** - タブグループの作成、名前変更、複製、削除、並べ替え
- **ワンクリックで開く** - タブグループ内の全フォルダを1つの Finder ウィンドウのタブとして開く
- **クラシック / モダン レイアウト** - 従来のボタン型レイアウトとモダンなサイドバー＋詳細パネルレイアウトを切替可能
- **フォルダ履歴** - 最近開いたフォルダの履歴（ピン留め対応）
- **ウィンドウジオメトリ** - タブグループごとに Finder ウィンドウの位置・サイズを保存・復元
- **高速タブ制御** - AX API + AppleScript のハイブリッド方式（10タブを約3秒で展開）
- **ダークモード** - macOS の外観設定に自動追従
- **多言語対応** - 英語、日本語、韓国語、繁体中国語、簡体中国語
- **パス検証** - 追加時にパスの存在確認と重複チェック
- **ドラッグ＆ドロップ** - パス入力フィールドにフォルダをドロップして追加

## 動作環境

- macOS 12 Monterey 以降
- Xcode 15 以降（ソースからビルドする場合）
- アクセシビリティ権限（初回起動時に確認ダイアログが表示されます）

## ビルド

1. Xcode で `FileTabOpenerM.xcodeproj` を開く
2. `FileTabOpenerM` スキームを選択
3. ビルド＆実行（Cmd+R）

## 使い方

1. アプリケーションを起動
2. アクセシビリティ権限を許可（Finder タブ制御に必要）
3. **+ タブ追加** でタブグループを作成
4. パス入力フィールド、**参照...**、またはドラッグ＆ドロップでフォルダパスを追加
5. **タブで開く** をクリックして全フォルダを Finder タブとして開く

### 動作の仕組み

本アプリケーションは Finder タブ制御にハイブリッド方式を採用しています：

1. **AX API**（Accessibility API） - Finder の「新規タブ」ボタンをプログラムで押下して新しいタブを作成。キャッシュされた AXUIElement 参照と軽量な子要素数ポーリングでパフォーマンスを確保。
2. **AppleScript** - `set target of front Finder window` で各タブのパスを設定。プリコンパイルされた NSAppleScript のハンドラ呼び出しにより、再コンパイルのオーバーヘッドを排除。
3. **フォールバック** - タブ作成に失敗した場合、残りのパスを個別の Finder ウィンドウとして開く。

タブの準備完了は固定遅延ではなく AXUIElement の子要素数の変化を監視して検出するため、Mac のハードウェア性能に関わらず安定動作します。

## 設定

設定は JSON 形式で以下に保存されます：

```
~/Library/Application Support/FileTabOpenerM/config.json
```

設定ファイルは Python 版（file_tab_opener）と互換性があります。

## ログ

ログは以下に出力されます：

```
~/Library/Logs/FileTabOpenerM/app.log
```

ログファイルは 1 MB を超えると自動ローテーションされ、最大3世代のバックアップ（`app.log.1`、`app.log.2`、`app.log.3`）が保持されます。

## プロジェクト構成

```
FileTabOpenerM/
  FileTabOpenerMApp.swift       # アプリエントリポイント、ウィンドウジオメトリ保存・復元
  ContentView.swift             # メインUI（クラシック・モダン両レイアウト）
  FinderTabController.swift     # AX API + AppleScript による Finder タブ制御
  ConfigManager.swift           # JSON 設定ファイル管理
  TabGroup.swift                # データモデル（Codable、Python版互換）
  Localization.swift            # 多言語対応（5言語、53キー）
  AppLogger.swift               # ファイルロガー（3世代ローテーション）
  Assets.xcassets/              # アプリアイコン・カラーアセット
```

## ライセンス

[MIT License](LICENSE)
