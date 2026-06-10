# [irengineer](https://github.com/LKL1235/irengineer)

面向 iRacing 的桌面教练应用：练车时实时语音反馈，复盘时本地完成 Garage 61 式双圈分析，无需上传等待。

Windows 单进程 Flutter 应用，**纯 Dart 实现**，运行时零 Go 依赖。

## 仓库结构

```text
irengineer/          # 主应用（Flutter Desktop，当前开发重点）
iracing-coach/       # 遗留 Go 实现（只读参照与 golden 对照，不发布 coach.exe）
data/                # 验收用 Garage 61 CSV 样本
docs/                # 计划、方案与历史记录
```

## 功能概览

| 模式 | 状态 | 能力 |
|------|------|------|
| **复盘（Review）** | ✅ 已实现 | 导入多圈 CSV，选参考圈/对比圈，trace 叠加、累计 delta、弯道表、GPS 地图 |
| **练车（Practice）** | ✅ 已实现 | iRacing 共享内存 60Hz 采集、圈末规则教练、Sherpa 中文 TTS |
| **云端深度解释（LLM）** | ⚙️ 后端已实现，无设置 UI | 圈末播报后可追加 LLM 文字解释；需在 `settings.json` 手动配置 API |
| **设置** | ✅ 已实现 | `settings.json` 持久化、参考圈选择、TTS 安装向导、ReadyGate 门控 |
| **系统托盘** | ✅ 已实现 | 最小化到托盘，退出时释放 SDK 与 TTS |

### 云端 LLM 配置

练车模式的规则教练不依赖网络。启用**深度解释**时，应用会调用 OpenAI 兼容接口（`POST {base_url}/chat/completions`），并将 LLM 输出与 `CoachReport` 数字做校验。

在 `%LocalAppData%/iracing-coach/settings.json` 中设置（设置页暂无表单，需手动编辑）：

```json
{
  "deep_explain_enabled": true,
  "cloud_base_url": "https://api.openai.com/v1",
  "cloud_api_key": "sk-...",
  "cloud_model": "gpt-4o-mini",
  "cloud_timeout_ms": 8000
}
```

`cloud_api_key` 仅存于本机用户目录，不会写入仓库。若启用深度解释但三项云端配置任一为空，应用会自动关闭该开关。

## 快速开始

```bash
cd irengineer
flutter pub get
flutter run -d windows
```

架构细节、测试与发布说明见 [irengineer/README.md](irengineer/README.md)。

## 样本数据

`data/Garage 61 - *.csv` — Laguna Seca F4 圈速，用于开发与回归测试。
