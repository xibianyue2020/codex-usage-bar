# Codex Usage Bar

[English](README.en.md)

一个常驻 macOS 菜单栏的 Codex 用量查看器，显示 5 小时和每周额度的剩余比例与重置时间。

## 功能

- 菜单栏显示 5 小时和每周额度的剩余百分比。
- 点击查看额度窗口、重置时间和最近更新时间。
- 每 60 秒自动刷新，也可手动刷新。
- 通过本机 `codex app-server` 的 `account/rateLimits/read` 接口读取用量，不读取、复制或保存认证令牌。
- 可通过 macOS 登录项常驻，也包含可选的 Codex 插件会话启动钩子。

## 环境要求

- macOS
- Xcode Command Line Tools（提供 `xcrun swiftc`）
- 已安装并登录的 Codex CLI，且 `codex` 命令位于 shell 的 `PATH` 中

## 安装

在仓库目录运行：

```bash
bash scripts/install.sh
```

脚本会编译菜单栏应用，并将其注册为当前 macOS 用户的登录项。程序会显示在 macOS 菜单栏，独立于 Codex 窗口。

如需在 Codex 会话启动时也触发程序，可将此目录作为本地插件安装；Codex 会要求审核并信任插件钩子。登录项和插件钩子可同时使用，程序会避免重复启动。

## 卸载

```bash
bash scripts/uninstall.sh
```

这会停止程序并移除登录项。已编译的应用和日志保留在 `~/Library/Application Support/CodexUsageBar`，如需彻底清理可自行删除该目录。

## 开源许可

[MIT License](LICENSE)
