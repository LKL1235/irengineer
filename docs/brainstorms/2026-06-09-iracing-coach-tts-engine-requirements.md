---
date: 2026-06-09
topic: iracing-coach-tts-engine
origin: docs/brainstorms/2026-06-09-iracing-lap-coach-requirements.md
supersedes_tts: piper-cli-embed
---

# iRacing 教练 — 本地 TTS 引擎选型 Requirements

## Summary

将 `iracing-coach` 的语音合成从已归档的 Piper 预编译二进制方案，迁移为 **Sherpa-ONNX 离线 TTS CLI + Piper 兼容神经语音模型** 的外部依赖模式。不把模型或推理运行时打进 `iREngineer`；通过配置目录或 PATH 引用本地工具，并由未来 UI 提供一键下载安装。优先级：**中文自然度 > 安装简单 > 首句延迟**。

## Problem Frame

v1 计划选用 Piper CLI + ONNX 模型（R11）。原 `rhasspy/piper` 仓库已 archived，继任者 [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) 为 **Python 包**（`pip install piper-tts`），无官方 Windows 独立二进制。将 Python 运行时与模型嵌入 `iREngineer` 会导致体积大、冷启动慢、常驻内存高，与「性能优先、不影响 iRacing」冲突。需要新的默认可持续 TTS 路径，同时保留神经语音质量以满足圈末教练体验。

---

## Key Decisions

- **默认引擎 = Sherpa-ONNX 离线 TTS（CLI）** — 使用预编译 `sherpa-onnx-offline-tts`（Windows x64 release），模型采用 HuggingFace 上 **Piper 兼容** 中文 ONNX（如 `vits-piper-zh_CN-huayan-medium`）。推理在**子进程**中完成，内存与 `iREngineer` 隔离。
- **不嵌入 coach 构建产物** — `iREngineer` 不包含 ONNX 模型、不包含 Python、不包含 Sherpa 运行时；首次使用通过 UI/脚本下载到用户缓存目录或 `%LocalAppData%/irengineer/tools/`。
- **保留 `Speaker` 抽象** — 教练主流程只依赖「文本 → 可播放音频」；引擎可替换，队列与打断语义不变。
- **降级档 = Windows SAPI（可选配置）** — 仅用于演示、应急或用户主动选择；**不作为默认**，因中文自然度不足。
- **常驻 Sidecar 推迟** — 首句延迟优先级最低；仅当实测无法满足 R12（p90 开播 ≤10s）时再增加可选 `coach-tts` 常驻服务。
- **弃用路径** — Piper 旧 release 二进制、`go:embed` 捆绑 Piper、默认 Python `piper-tts` 子进程均不作为产品默认方案。

---

## Priority Stack（用户确认）

| 顺序 | 维度 | 含义 |
|------|------|------|
| 1 | 中文自然度 | 默认使用 medium 级神经语音；不为省体积降级到 x_low 或 SAPI |
| 2 | 安装简单 | 一键下载固定版本 Sherpa + 默认模型 + espeak-ng-data；校验后写配置 |
| 3 | 首句延迟 | 接受每句子进程冷启动；可用 WAV 缓存与同圈预合成缓解；Sidecar 为后续选项 |

---

## Actors

- **A1. 车手** — 听到圈末中文教练语音；期望发音自然、可听懂弯号与秒数。
- **A2. 教练系统（iREngineer）** — 渲染模板文本，调用 TTS 后端，管理播报队列与打断。
- **A3. 安装器 / 设置 UI（后续）** — 检测依赖、下载资产、写入 `coach.yaml` 中的 TTS 路径。

---

## Requirements

**引擎与依赖**

- T1. 系统默认使用 Sherpa-ONNX 离线 TTS 作为本地合成后端；不要求 GPU。
- T2. 合成在独立子进程中执行，`iREngineer` 进程不加载 ONNX 模型权重。
- T3. 配置项至少包含：`tts_engine`（默认 `sherpa`）、`tts_bin`、`tts_model`、`tts_data_dir`（espeak-ng 数据目录）；可选 `tts_fallback_engine`。
- T4. 启动时校验 TTS 依赖；缺失时给出可操作错误（含「请运行安装」或 UI 入口），而非静默失败。
- T5. 允许用户通过配置覆盖模型路径以更换音色，但产品默认提供中文 medium 模型的一键安装包。

**质量与性能**

- T6. 默认中文语音须为神经 TTS（Piper 兼容 ONNX），不得将 SAPI 作为出厂默认。
- T7. 单句合成 + 播放须支持 `Cancel()`，与新圈打断策略（KTD-7）兼容。
- T8. 对相同文本+模型合成结果允许磁盘缓存（WAV），以减少重复合成延迟。
- T9. 圈末走线播报 p90 启动延迟仍遵守原 R12（≤10s）；TTS 迁移不得显著恶化该指标；若恶化，Sidecar 列入 follow-up。

**安装与分发**

- T10. 不提供「单文件 iREngineer 内含语音模型」作为默认分发形态。
- T11. 安装流程须可脚本化或 UI 一键完成：下载 Sherpa Windows 二进制、默认中文模型、`espeak-ng-data`，并写入配置。
- T12. 版本锁定：安装包记录 Sherpa release 版本与模型 ID，升级由 UI/文档引导，避免静默漂移。

**兼容与弃用**

- T13. 现有 `piper_bin` / `piper_model` 配置字段在迁移期可映射或废弃并文档说明；新字段以 `tts_*` 为准。
- T14. README 与示例配置不再指向 `rhasspy/piper` archived 仓库作为首选安装源。

---

## Key Flows

- F-TTS1. **首次配置 TTS**
  - **Trigger:** 用户首次启动 coach 或打开设置页。
  - **Steps:** 检测 `tts_bin` → 若缺失则提示一键安装 → 下载资产 → 校验 → 写入 `coach.yaml` → 试播一句。
  - **Outcome:** 用户无需手动找 Piper 旧 release 即可听到中文试播。

- F-TTS2. **圈末播报（不变）**
  - **Trigger:** 圈完成，模板文本入队。
  - **Steps:** 查 WAV 缓存 → 若无则调用 Sherpa CLI 合成 → Windows 播放 → 支持 Cancel。
  - **Outcome:** 车手听到与 CoachReport 数值一致的中文播报。

- F-TTS3. **应急降级（可选）**
  - **Trigger:** 用户设置 `tts_engine: sapi` 或神经引擎不可用且用户确认降级。
  - **Steps:** 系统 SAPI 合成播放。
  - **Outcome:** 有声音但质量下降；日志标明降级原因。

---

## Acceptance Examples

- AE-TTS1. **一键安装后试播**
  - **Given:** 新用户，无 TTS 文件。
  - **When:** 完成 UI 一键安装并启动 coach。
  - **Then:** 10 秒内听到中文试播句；日志无 Piper/Python 依赖。

- AE-TTS2. **圈末自然度**
  - **Given:** 已安装 medium 中文模型。
  - **When:** 完成练习圈。
  - **Then:** 走线播报含弯号与秒数，发音为神经 TTS 而非机械 SAPI。

- AE-TTS3. **新圈打断**
  - **Given:** 走线段正在播放。
  - **When:** 下一圈完成并入队新播报。
  - **Then:** 当前播放停止，仅播报最新一圈内容。

---

## Success Criteria

- 默认安装路径下，中文圈末播报被评价为「可听懂且不像系统机械音」。
- `iREngineer` 本体体积不因 TTS 模型显著增大（模型外置）。
- 无 Python 运行时作为默认依赖。
- p90 圈末开播延迟仍 ≤10s（标准赛道）；若达不到，Sidecar 方案进入计划而非回退 SAPI 默认。

---

## Scope Boundaries

**Deferred for later**

- 常驻 TTS Sidecar（模型 warm、命名管道/HTTP）
- 预录 clip 与神经 TTS 混音
- 多音色在线商店、用户自选声音
- macOS / Linux TTS 后端（v1 仅 Windows）

**Outside this product's identity**

- 云 TTS 替代本地合成（违反 R11 本地优先）
- GPU 推理 TTS
- 将 TTS 引擎嵌入 iRacing 进程

---

## Dependencies & Assumptions

- [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 继续提供 Windows x64 预编译 release。
- Piper 兼容中文模型（如 `csukuangfj/vits-piper-zh_CN-huayan-medium`）可公开下载且许可允许本地使用。
- `espeak-ng-data` 与 Sherpa 文档要求的数据目录布局保持稳定。
- 设置 UI 为 follow-up work，v1.1 可先提供 PowerShell 安装脚本达到 T11。

---

## Outstanding Questions

- 默认模型选 **medium**（~60MB，自然度优先）还是提供 medium/x_low 让用户在安装向导里选？（倾向默认 medium，高级用户可换 x_low）
- Sherpa CLI 参数与 espeak 数据路径以哪份 upstream 文档为验收基准？（实现时在 plan 阶段对照 release 附带的示例命令）

---

## Related

- 原产品需求：`docs/brainstorms/2026-06-09-iracing-lap-coach-requirements.md`（R11–R12）
- 实现计划：`docs/plans/2026-06-09-001-feat-iracing-lap-coach-plan.md`（U6 TTS — 待修订）
- 竞品参考：Full Grip 类本地 CPU 教练、Piper 生态迁移至 OHF piper1-gpl
