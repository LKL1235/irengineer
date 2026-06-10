# irengineer

Windows 桌面端 iRacing 教练与本地复盘工具。单进程 Flutter 应用，算法与 UI 均为 **纯 Dart**，通过 `package:win32` 直接读取 iRacing 共享内存。

仓库：[https://github.com/LKL1235/irengineer](https://github.com/LKL1235/irengineer)

## 环境要求

- Flutter stable（已启用 Windows 桌面）
- Windows 10/11
- iRacing（练车模式实机采集）
- `tar` 在 PATH 中（Sherpa TTS 一键安装）

## 开发与测试

```bash
cd irengineer
flutter pub get
flutter run -d windows
```

```bash
flutter analyze
flutter test
```

Golden 样本位于仓库根目录 `data/`（Garage 61 导出 CSV）。

## 发布打包

```bash
flutter build windows --release
dart run tool/bundle_release.dart
```

脚本会将 `%LocalAppData%/irengineer/tts` 下已安装的 Sherpa 资源复制进 Release 目录。

---

## 项目架构

采用分层设计：`domain` 无 Flutter 依赖，可独立 `dart test`；`platform` 封装 OS 绑定；`services` 编排长生命周期流程；`features` 承载 UI。

```text
lib/
├── main.dart / app.dart          # 入口、三 Tab 导航、模式切换生命周期
├── core/                         # 路径、settings.json 读写与 ReadyGate
├── domain/                       # 纯 Dart 领域算法（禁止 import flutter）
│   ├── lap/                      # LapSample / LapSeries
│   ├── ref/                      # CSV 加载、圈时推导、赛道指纹校验
│   ├── delta/                    # 双圈分析、弯道切分、rolling delta
│   ├── coach/                    # 规则报告、模板渲染、语音队列
│   ├── race/                     # 前车追及估算
│   ├── cloud/                    # 可选 LLM 解释与数字校验
│   └── telemetry/                # SDK 快照、isolate 轮询编解码
├── platform/windows/irsdk/       # win32 共享内存客户端、圈缓冲、CSV 回放
├── services/                     # 跨层编排
│   ├── coach_loop.dart           # 60Hz 轮询 → 圈末分析 → 入队播报
│   ├── coach_provider.dart       # Riverpod 状态
│   ├── tts/                      # Sherpa 子进程合成 + just_audio 播放
│   └── tray/                     # 系统托盘与最小化到托盘
├── features/                     # 功能页
│   ├── review/                   # 复盘：导入、选圈、分析控制器
│   ├── practice/                 # 练车：连接状态、最近一圈报告
│   └── settings/                 # 设置与 TTS 安装向导
└── widgets/                      # 图表、弯道表、地图等可复用组件
```

### 数据流（复盘）

```text
用户选 CSV → ref.loadCsv（Isolate）→ 圈列表元数据
     → 选参考圈 + 对比圈 → validateTrackMatch
     → delta.analyze（Isolate）→ CoachReport + 网格采样
     → fl_chart / flutter_map 渲染；顶层手势联动 highlightedPct
```

### 数据流（练车）

```text
IrSdkClient（worker Isolate 60Hz 轮询）→ LapBuffer 累积样本
     → 圈完成 → validateTrackMatch + delta.analyze + buildReport
     → SpeechQueue → Sherpa 子进程 TTS → just_audio 播放
     → 可选 CloudClient 深度解释（校验 LLM 输出数字）
```

### 模式与生命周期

- **复盘**：不依赖 TTS 安装，ReadyGate 恒为可用。
- **练车**：需配置参考圈 CSV 且 TTS 就绪；切回复盘时暂停 SDK 轮询并取消当前播报。
- **托盘**：点 X 隐藏到托盘；托盘退出时停止教练循环并释放 TTS 进程。

### 功能实现状态

| 模块 | 状态 | 说明 |
|------|------|------|
| 复盘分析 | ✅ | CSV 导入、双圈 delta、图表与地图 |
| SDK 遥测 | ✅ | `win32` 共享内存 + Isolate 轮询 |
| 规则教练 | ✅ | 弯道 delta、进站/赛道校验、语音模板 |
| Sherpa TTS | ✅ | 设置向导一键安装，子进程合成 + `just_audio` 播放 |
| 云端 LLM | ⚙️ | `CloudClient` + 数字校验已接入 `CoachLoop`；**设置页无 UI**，需编辑 `settings.json` |
| 云端配置项 | | `deep_explain_enabled`、`cloud_base_url`、`cloud_api_key`、`cloud_model`、`cloud_timeout_ms` |

云端 API Key 保存在 `%LocalAppData%/irengineer/settings.json`，勿提交到版本库。

### 状态管理

使用 `flutter_riverpod`：`settingsProvider`、`readyGateProvider`、`reviewControllerProvider`、`coachLoopProvider`。

### 用户数据路径

设置与 TTS 资源保存在 `%LocalAppData%/irengineer/`：

- `settings.json` — 参考圈路径、TTS 配置、云端 API 等
- `tts/` — Sherpa 运行时与语音模型

### 测试策略

- `test/domain/` — golden 测试，对照 `data/` 样本
- `test/platform/`、`test/services/` — LapBuffer、CsvProvider、CoachLoop mock
- `test/features/` — 复盘控制器状态机
- 实机清单：iRacing 连接、TTS 安装播报、托盘退出无僵尸进程

---
