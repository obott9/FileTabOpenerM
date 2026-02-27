[English](README.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [繁體中文](README_zh_TW.md) | [简体中文](README_zh_CN.md)

# File Tab Opener（macOS 原生版）

用于将文件夹以 Finder 标签页方式批量打开的 macOS 原生 SwiftUI 应用程序。

本应用是 [file_tab_opener](https://github.com/obott9/file_tab_opener)（Python/Tk 版）的 macOS 原生版本，使用 SwiftUI 打造现代化的 macOS 原生 UI 体验。

## 功能

- **标签组管理** - 创建、重命名、复制、删除及重新排序标签组
- **一键打开** - 将标签组中的所有文件夹以单个 Finder 窗口的标签页形式打开
- **现代布局** - 侧边栏＋详情面板、下拉排序、右键菜单、行内编辑 — 同时提供 Python 版兼容的经典布局
- **macOS 原生体验** - 深色模式、拖放操作、系统字体渲染 — 全部自动遵循 macOS 规范
- **文件夹历史** - 最近打开的文件夹记录（支持置顶）
- **窗口位置记忆** - 按标签组保存及恢复 Finder 窗口的位置与大小
- **稳定标签控制** - AX API + AppleScript 混合模式；AX API 无需键盘模拟即可创建标签页，避免 System Events 权限问题
- **多语言支持** - 英语、日语、韩语、繁体中文、简体中文
- **路径验证** - 添加时检查路径是否存在并防止重复
- **拖放操作** - 将文件夹拖放至路径输入栏即可添加

## 为何选择原生版？

Python/Tk 版使用 `System Events` 按键模拟（⌘T）创建 Finder 标签页，这需要键盘模拟权限，且可能与用户输入冲突。原生版改用 **Accessibility API**（AX API）以编程方式按下 Finder 的"新建标签页"按钮，完全不使用键盘事件。

标签页打开速度与 Python 版相当（10 个标签页约 3 秒）。原生版的主要优势在于 **基于 SwiftUI 的现代布局**：侧边栏导航、下拉排序、右键菜单、原生拖放操作、自动深色模式 — 这些功能在 Tk/customtkinter 中难以实现。

## 系统要求

- macOS 12 Monterey 或更高版本
- Xcode 15 或更高版本（从源代码构建时需要）
- 辅助功能权限（首次启动时会提示授权）

## 构建

1. 在 Xcode 中打开 `FileTabOpenerM.xcodeproj`
2. 选择 `FileTabOpenerM` 方案
3. 构建并运行（Cmd+R）

## 使用方法

1. 启动应用程序
2. 授予辅助功能权限（Finder 标签页控制所需）
3. 点击 **+ 添加标签** 创建标签组
4. 通过路径输入栏、**浏览...** 或拖放方式添加文件夹路径
5. 点击 **以标签页打开** 将所有文件夹以 Finder 标签页打开

### 工作原理

本应用采用混合模式控制 Finder 标签页：

1. **AX API**（Accessibility API） - 通过编程方式按下 Finder 的"新建标签页"按钮创建新标签，完全排除键盘模拟。
2. **AppleScript** - 通过 `set target of front Finder window` 设置各标签页的路径。使用预编译的 NSAppleScript 处理程序调用，避免重复编译的额外开销。
3. **备用方案** - 标签页创建失败时，将剩余路径以独立 Finder 窗口打开。

标签页就绪检测采用 AXUIElement 子元素数量变化监控，而非固定延迟轮询，因此不受 Mac 硬件性能差异影响，可稳定运行。

## 配置

配置以 JSON 格式存储于：

```
~/Library/Application Support/FileTabOpenerM/config.json
```

配置文件与 Python 版（file_tab_opener）兼容。

## 日志

日志输出至：

```
~/Library/Logs/FileTabOpenerM/app.log
```

日志文件超过 1 MB 时自动轮转，最多保留 3 个备份世代（`app.log.1`、`app.log.2`、`app.log.3`）。

## 项目结构

```
FileTabOpenerM/
  FileTabOpenerMApp.swift             # 应用入口点、窗口位置保存与恢复
  ContentView.swift                   # 主界面、共享视图、状态属性
  ContentView+ClassicLayout.swift     # 经典布局（Python 版兼容）
  ContentView+ModernLayout.swift      # 现代布局（侧边栏＋详情面板）
  ContentView+Actions.swift           # 全部操作方法（标签页/路径/历史管理）
  Theme.swift                         # 颜色主题、按钮样式
  FlowLayout.swift                    # 标签按钮换行布局
  FinderTabController.swift           # AX API + AppleScript Finder 标签页控制
  ConfigManager.swift                 # JSON 配置管理
  TabGroup.swift                      # 数据模型（Codable、Python 版兼容）
  Localization.swift                  # 多语言支持（5 种语言、53 个键值）
  AppLogger.swift                     # 文件日志记录器（3 世代轮转）
  Assets.xcassets/                    # 应用图标与颜色资源
FileTabOpenerMTests/
  FileTabOpenerMTests.swift           # 单元测试 25 项（Codable、i18n、辅助方法）
```

## 许可证

[MIT License](LICENSE)
