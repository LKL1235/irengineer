# AGENTS.md

## Cursor Cloud specific instructions

### 产品概览

iREngineer 是面向 iRacing 的 **Windows 桌面 Flutter 应用**（`irengineer/`）。主应用依赖 `win32` 共享内存、系统托盘等 Windows API，**无法在 Linux/macOS 上 `flutter run`**。云端 Linux VM 上的开发验证以静态分析与测试为主。

### 环境前提

- Flutter stable 安装在 `/home/ubuntu/flutter`（已加入 `PATH`）
- 无需数据库、Docker 或本地 HTTP 服务
- 样本 CSV 位于仓库根目录 `data/`（Laguna Seca F4 圈速）

### 常用命令

均在 `irengineer/` 目录下执行：

| 任务 | 命令 |
|------|------|
| 安装依赖 | `flutter pub get` |
| 静态分析（lint） | `flutter analyze` |
| 全量测试 | `flutter test` |
| Linux 友好测试子集 | `flutter test test/domain/ test/features/ test/platform/ test/services/coach_loop_test.dart test/widget_test.dart` |

### 平台限制（重要）

- **运行 GUI 应用**：需要 Windows 10/11，执行 `flutter run -d windows`
- **Linux 上 `flutter test` 全量**：`test/services/tts/sherpa_test.dart` 的 3 个用例使用 `.bat` 模拟 Sherpa CLI，在 Linux 上会因无法执行而失败；其余 47 个用例可通过
- **练车模式实机 E2E**：需要 iRacing 会话 + Sherpa TTS 资源 + 参考圈 CSV（见 `irengineer/README.md`）
- 项目未配置 Linux desktop target，不要尝试 `flutter build linux`

### 发布（仅 Windows）

```bash
flutter build windows --release
dart run tool/bundle_release.dart
```
