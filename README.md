# NovaBar

在 macOS 菜单栏显示 Cursor 用量的原生小工具（Swift + SwiftUI，零第三方依赖）。

## 功能

- 菜单栏按钮实时显示用量百分比，点击弹出 Dashboard 同款用量卡片（`$431.20 / $500` + 进度条 + 重置日期）
- 内嵌浏览器登录 Cursor 一次即可，登录凭证保存在本机钥匙串（Keychain），不上传、不落盘明文
- 定时自动刷新（1/5/15/30 分钟可调）+ 手动刷新
- 快用完变色提醒：<60% 绿 / 60–85% 橙 / >85% 红
- 可选：菜单栏只显示图标、开机自启（需打包版）

## 构建与运行

要求：macOS 26.5+，Xcode Command Line Tools（含 Swift 工具链）。

```bash
# 编译（本机环境用 swiftc 直编脚本，原因见下方说明）
./Scripts/build.sh
.build/release/NovaBar      # 运行菜单栏应用
.build/release/NovaBarCLI   # 只验证数据链路：打印会话状态 + 用量数据

# 正式打包（编译 + 组装 .app + ad-hoc 签名）
./Scripts/make_app.sh
open build/NovaBar.app
```

> 说明：本机 Command Line Tools（6.4.0.34.1）的 27.0 SDK 缺少 SwiftUI 宏插件
>（SwiftUIMacros），且 SwiftPM 在受限终端下不可用，因此 `Scripts/build.sh`
> 用 swiftc 指向 26.5 SDK 直接编译（该 SDK 的 SwiftUI 仍是传统属性包装器，
> 无需宏插件）。模块缓存保留在项目内 `.build/modulecache265`，
> `Package.swift` 保留供 IDE 索引；若日后安装完整版 Xcode，可直接改用 `swift build`。

## 使用流程

1. 启动后菜单栏右上角出现「Cursor」
2. 点击 → 面板 → 「登录 Cursor」→ 在内嵌窗口里登录 Cursor 官网
   - 推荐使用**邮箱验证码**或 **GitHub** 登录；Google 登录在内嵌浏览器里偶尔会被 Google 风控拦截
3. 登录成功后窗口自动关闭，面板立即显示用量
4. 设置里可调整：刷新间隔、菜单栏图标模式、开机自启、退出登录

## 数据来源与隐私

- 数据来自 Cursor 官网 Dashboard 同一接口：`cursor.com/api/usage-summary`，显示数字与 cursor.com/dashboard 完全一致
- 登录会话（Cookie）只保存在本机 macOS 钥匙串，服务名 `app.novabar.cursor`
- 该接口为 Cursor 官网内部接口，未公开文档化；官方改版可能需要小改适配

## 项目结构

```
NovaBar/
├── Package.swift                 # SwiftPM 配置（IDE 索引用）
├── Sources/
│   ├── NovaBarKit/               # 数据层
│   │   ├── CursorSessionStore.swift  # 会话存取（Keychain）
│   │   └── CursorUsage.swift         # 用量接口 + 解析 + 格式化
│   ├── NovaBar/                  # 菜单栏应用
│   │   ├── NovaBarApp.swift          # 入口 + 菜单栏 + 窗口场景
│   │   ├── UsageViewModel.swift      # 状态管理 + 定时刷新
│   │   ├── MenuContentView.swift     # 用量面板
│   │   ├── LoginView.swift           # 内嵌浏览器登录
│   │   └── SettingsView.swift        # 设置窗口
│   └── NovaBarCLI/
│       └── main.swift                # 命令行调试工具
└── Scripts/
    ├── build.sh                  # swiftc 直编脚本（绕过 SwiftPM）
    └── make_app.sh               # 打包 .app
```

## 常见问题

- **菜单栏显示 ⚠︎**：数据获取失败，打开面板看具体错误；提示「登录已过期」时点重新登录即可
- **CLI 提示未找到会话**：先启动 NovaBar.app 完成一次登录
- **开机自启设置失败**：需使用打包后的 NovaBar.app（建议放入 /Applications 后再开）
- **卸载**：退出应用，并在「钥匙串访问」中删除 `app.novabar.cursor` 即可