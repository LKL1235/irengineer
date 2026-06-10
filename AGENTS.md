# AGENTS.md

## Cursor Cloud specific instructions

### 产品概览

iREngineer 是面向 iRacing 的 **Windows 桌面 Flutter 应用**（`irengineer/`）。练车模式依赖 `win32` 共享内存、系统托盘等 Windows API；**复盘模式**可在 Linux 上构建与验收（`linux/` 平台已启用）。

### 环境前提

- Flutter stable 由 `.cursor/install.sh` 安装到 `/home/ubuntu/flutter`（可通过 `FLUTTER_ROOT` 覆盖；脚本会写入 `PATH`）
- Linux 构建依赖由 `.cursor/install.sh` 安装（`.cursor/environment.json` 在 Agent 启动时自动执行）
- Cloud Agent VM 自带图形显示（`DISPLAY=:1`），无需 `xvfb-run`
- 样本 CSV 位于仓库根目录 `data/`（Laguna Seca F4 圈速）

### 常用命令

均在 `irengineer/` 目录下执行。Linux 构建前需设置编译器路径（`install.sh` 已写入，手动执行时自行 export）：

```bash
export PATH="/home/ubuntu/flutter/bin:$PATH"
export LIBRARY_PATH="/usr/lib/gcc/x86_64-linux-gnu/13:${LIBRARY_PATH:-}"
export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/x86_64-linux-gnu/c++/13"
```

| 任务 | 命令 |
|------|------|
| 安装依赖 | `flutter pub get`（`install.sh` 已包含） |
| 静态分析（lint） | `flutter analyze` |
| 图表 widget 测试 | `flutter test test/widgets/` |
| Linux 友好测试子集 | `flutter test test/domain/ test/features/ test/platform/ test/services/coach_loop_test.dart test/widget_test.dart test/widgets/` |
| Linux 复盘 GUI 构建 | `flutter build linux --debug` |
| Linux 复盘 GUI 启动 | `DISPLAY=:1 ./build/linux/x64/debug/bundle/irengineer` |

### 平台限制（重要）

- **练车模式 GUI / 实机 E2E**：需要 Windows 10/11 + iRacing 会话 + Sherpa TTS
- **Linux 上 `flutter test` 全量**：`test/services/tts/sherpa_test.dart` 的 3 个用例使用 `.bat` 模拟 Sherpa CLI，在 Linux 上会因无法执行而失败；其余用例可通过
- **Linux GUI 验收**：设置 `IRENGINEER_FIXTURE_PATHS`（逗号分隔绝对路径）与可选 `IRENGINEER_REPO_ROOT`，构建后运行 bundle；详见 `irengineer/README.md` Cloud Agent 节
- **启动应用**：优先 `flutter build linux --debug` + 直接运行 bundle；避免在 tmux 中 `Ctrl+C` 后立即输入 `flutter run`（可能截断首字母）

### 发布（仅 Windows）

```bash
flutter build windows --release
dart run tool/bundle_release.dart
```
