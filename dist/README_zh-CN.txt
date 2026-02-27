=====================================
File Tab Opener (macOS) - 自述文件
=====================================

【应用概要】
用于将文件夹以 Finder 标签页方式批量打开的 macOS 原生应用程序。
按项目分组文件夹，一键打开为 Finder 标签页。

【系统要求】
- macOS 12 (Monterey) 或更高版本
- 支持 Apple Silicon / Intel Mac
- 需要辅助功能权限

【安装方法】
1. 将 FileTabOpenerM.app 拖至应用程序文件夹
2. 启动应用程序
3. 首次启动时请允许辅助功能权限
   （系统设置 > 隐私与安全性 > 辅助功能）

【主要功能】
- 标签组管理（创建、重命名、复制、删除、重新排序）
- 一键将所有文件夹以 Finder 标签页打开
- 现代布局（侧边栏＋详情面板）及经典布局
- 文件夹历史记录（支持置顶）
- 窗口位置与大小保存及恢复
- 自动支持深色模式
- 5 种语言（英语、日语、韩语、繁体中文、简体中文）

【配置文件】
~/Library/Application Support/FileTabOpenerM/config.json
※ 与 Python 版 (file_tab_opener) 兼容

【卸载方法】
从应用程序文件夹中删除即可。
如需同时删除配置文件：
  rm -rf ~/Library/Application\ Support/FileTabOpenerM
  rm -rf ~/Library/Logs/FileTabOpenerM

【支持】
- GitHub: https://github.com/obott9/FileTabOpenerM
- Email: obott9.dev@gmail.com

【许可证】
MIT License
Copyright (c) 2026 obott9
