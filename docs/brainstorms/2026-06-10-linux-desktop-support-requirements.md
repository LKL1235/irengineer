---
date: 2026-06-10
topic: linux-desktop-support
origin: ce-brainstorm
focus: cursor-cloud-agent-ui-testing
status: draft
---

# feat: Linux 桌面支持（复盘 + Agent 可测 UI）

## Summary

在 **Linux** 上交付与 Windows **同一套 Material 3 UI** 的 iREngineer 桌面构建，使 **Cursor Cloud Agent** 能在云端启动应用、手动操作界面并通过截图验证复盘流程未损坏。**复盘（Review）** 为完整能力；**练车（Practice）** Tab 保留但进入后明确提示「仅 Windows / 需 iRacing」，不尝试连接 SDK 或 TTS。首要用户是 **开发者与 Cloud Agent**，不是 Linux 终端赛车玩家。

## Problem Frame

当前应用仅启用 `windows/` 平台，且运行时导入链依赖 `win32` 与 iRacing 共享内存，Cloud Agent（Linux 云端）无法 `flutter build linux` 或启动 UI，复盘相关的 UI 回归只能人工在 Windows 上点测。复盘算法与 UI 本身已是纯 Dart/Flutter，具备跨平台基础；阻塞点在平台绑定与入口编排，而非分析能力重写。

## Primary Actor

- **A1. Cursor Cloud Agent / 维护者** — 在 Linux 环境启动 App、导入样本 CSV、执行分析、检查图表与弯道表是否正常渲染。
- **A2. Windows 用户（不变）** — 继续使用完整三 Tab 体验；Linux 版不改变 Windows 行为。

## Requirements

实现后必须为真：

| ID | 要求 |
|----|------|
| R1 | 仓库可产出 **Linux 桌面 Release/Debug 构建**（`linux/` 平台目录存在且 CI/Agent 可编译）。 |
| R2 | **复盘 Tab** 在 Linux 上与 Windows **同一导航与视觉结构**：导入 CSV、选参考圈/对比圈、分析、trace 叠加、累计 delta、弯道表、GPS 地图（有 Lat/Lon 时）。 |
| R3 | **练车 Tab** 在 Linux 上 **可见但不可用**：展示明确说明（仅 Windows、需 iRacing），不启动 SDK 轮询、不触发 TTS、不报错崩溃。 |
| R4 | **设置 Tab** 在 Linux 上可用；**TTS 一键安装** 与练车 ReadyGate 相关项 **隐藏或禁用**，并说明原因。 |
| R5 | Linux 构建 **不得依赖** `win32`、iRacing 共享内存或 Windows 专用 `.exe` 才能启动复盘流程。 |
| R6 | 提供 **Agent 可复现的样本加载路径**：在无图形文件对话框或 Cloud 环境受限时，仍能加载仓库内 `data/` 下固定 CSV 完成一次完整分析（见 KTD-2）。 |
| R7 | 用户数据目录沿用 **`%LocalAppData%/irengineer/`** 的 Linux 等价路径（`~/.config/irengineer/` 或 XDG 约定），与 Windows 字段语义一致。 |
| R8 | Cloud Agent 运行说明可文档化：启动命令、虚拟显示前提、推荐样本 CSV、预期可见 UI 状态（成功分析后的最小检查点）。 |

## Key Decisions

**KTD-1: Linux 定位为「复盘 + Agent 测 UI」，非功能对等**

练车、实时 SDK、Sherpa TTS 留在 Windows。Linux 不追求 iRacing 或语音教练。

**KTD-2: Agent 手动测 UI 需要「免文件对话框」样本入口**

仅依赖 GTK 文件选择器时，Cloud Agent 难以稳定完成「导入 CSV」。v1 必须提供 **维护者/Agent 向** 的确定性加载方式（例如：启动参数、环境变量、或设置/dev 入口指向仓库 `data/` 路径），使黄金路径不依赖人工点选文件系统。

**KTD-3: 练车 Tab 保留为 Stub，不删导航**

三 Tab 结构与 Windows 一致，便于 Agent 验证导航未坏；进入练车仅展示说明页，不模拟连接状态。

**KTD-4: 验证方式为 Agent 目视 + 截图，非强制 integration_test**

成功以 Agent 能完成文档化黄金路径并目视确认图表/表/无报错为准。可选后续再加 integration_test，但不作为 v1 阻塞项。

**KTD-5: 运行环境以 Cursor Cloud 为主**

接受虚拟显示（无物理显示器）；不要求 v1 提供 Linux 安装包分发或桌面商店渠道。

## User Flows

### F1 — Agent 黄金路径（Linux）

1. 在 Linux（含虚拟显示）启动 iREngineer。
2. 默认或进入 **复盘** Tab。
3. 通过 KTD-2 机制加载 `data/` 中至少一份 Garage 61 CSV（或等价夹具）。
4. 选择参考圈与对比圈，点击 **分析**。
5. 确认：trace 图、delta 曲线、弯道表有数据；地图在有 GPS 时显示；无崩溃、无无限 loading。

### F2 — Agent 导航抽检

1. 切换到 **练车** Tab → 仅见 Windows 限制说明，无 SDK 连接尝试。
2. 切换到 **设置** Tab → 可见常规设置；TTS 安装不可用且有说明。
3. 切回复盘 → 先前分析状态合理保留或按设计重置（行为需在实现时二选一并写清，见 Outstanding Questions）。

### F3 — Windows 用户（回归）

Windows 构建行为与现网一致，不受 Linux stub 逻辑影响。

## Success Criteria

- Cloud Agent 在 Linux 上按文档完成 F1，截图可证明分析结果与 Windows 同样本 **数值一致**（总 delta、弯数等，容差仅浮点误差）。
- `flutter test` 现有 domain/review 测试在 Linux 环境通过。
- Linux 启动不加载 `win32`；练车 Tab 不产生 SDK/TTS 子进程。
- 仓库 README 或 `irengineer/README.md` 增加 **Agent/Linux 快速验证** 小节（启动、样本、检查点）。

## Scope Boundaries

### In scope (v1)

- Linux 平台工程与复盘完整 UI
- 练车/设置 的 Linux 降级与说明
- Agent 样本加载路径（KTD-2）
- 文档化 Cloud 运行步骤

### Deferred for later

- Flutter Web 复盘（browser/agent-browser 路径）
- `integration_test` 自动化黄金路径
- Linux 终端用户安装包、Flatpak/AppImage
- macOS 桌面
- 复盘模式 TTS 播报
- Linux 版 Sherpa TTS / 练车任何部分

### Outside this product's identity

- 在 Linux 上运行 iRacing 或模拟其共享内存
- 为 Linux 单独维护一套 UI 设计或品牌

## Assumptions

- Cursor Cloud Agent 运行环境可安装 Flutter Linux 桌面依赖，并可使用虚拟 framebuffer 显示 Flutter 窗口。
- 复盘 UI 使用的 `file_picker`、`fl_chart`、`flutter_map`、`just_audio`（若复盘不涉及播放则可不初始化）在目标 Linux 镜像上可解析依赖。
- 网络可用于地图瓦片加载；离线时地图失败可接受，但不应导致分析崩溃。

## Dependencies

- 现有 `domain/` 与 `features/review/` 行为不变。
- 仓库 `data/` 样本 CSV 作为 Agent 验收基准。
- Windows 版继续作为练车与实机 iRacing 的唯一平台。

## Risks

| 风险 | 缓解 |
|------|------|
| Agent 无法操作原生文件对话框 | KTD-2 确定性样本入口 |
| 无头环境 Flutter 首帧/窗口不显示 | 文档化 xvfb 与启动参数；Agent 以进程存活 + 日志 + 可选截图为准 |
| `win32` 仍被间接 import 导致 Linux 编译失败 | 平台隔离练车/SDK 模块，Linux 入口不引用 |
| 地图瓦片在 Cloud 被墙或 403 | 分析核心不依赖地图；地图失败时显示已有降级文案 |

## Outstanding Questions

| 问题 | 建议默认 |
|------|----------|
| KTD-2 具体形态：CLI `--fixture-csv`、环境变量、还是设置页「加载仓库样本」按钮？ | **环境变量 + 设置页 dev 入口** 双轨，Agent 优先用环境变量 |
| Linux 上切换 Tab 后复盘状态是否保留？ | **保留**，与 Windows 一致 |
| Cloud 镜像是否预装 `flutter` 与 GTK dev packages？ | 在 README 列出最小 apt 依赖；Agent 文档引用 |
| 是否在 PR CI 中加 `build linux` job？ | v1 **可选**；主验收以 Cloud Agent 为准 |

## Handoff

- **下一步：** `/ce-plan` — 拆平台隔离、`linux/` 工程、stub 页、Agent 样本入口与文档。
- **相关 ideation：** 上轮讨论 Linux + integration_test 组合；本需求按用户选择以 **Agent 手动测 UI** 为 v1 验证方式，integration_test 推迟。
