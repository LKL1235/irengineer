---
date: 2026-06-09
topic: iracing-lap-coach
focus: Supervision + simple LLM + voice coaching; lap vs reference CSV; per-corner time loss
mode: elsewhere-software
run_id: 19c97069
---

# Ideation: iRacing 圈速语音教练助手

## Grounding Context

**Topic shape：** 后台 Python 工具，在 iRacing 练习/排位后，将当前圈轨迹（`.ibt` 或 pyirsdk 实时缓冲）与参考圈（网页下载 CSV）按 `LapDistPct` 距离轴对齐，计算逐弯 rolling delta，经 LLM 生成自然语言点评，TTS 语音播报（例：「一号弯损失 0.5 秒，考虑早点刹车」）。

**Stated constraints：** 上一圈 vs 目标圈 CSV；逐弯报告 + 可执行建议；Roboflow Supervision；简单 LLM；语音播报。

**Pain points：** MoTeC/VRS 需切出游戏；内置 delta 仅总圈差；VRS 数据锁在平台内；trophi.ai/PoleCraft 需云+订阅；Crew Chief 不分析走线。

**Competitive landscape：** VRS、Garage 61、iSpeed (.irlap)、Coach Dave Delta、TrackPro APEX（实时语音）、Pulpo Coach AI（Gemini 闭环）、race-mcp（开源 MCP）。

**Supervision honest fit：** Supervision 是 CV 检测/跟踪库（Detections、PolygonZone、ByteTrack），**不是**遥测分析库。主路径应为 pyirsdk + pandas + numpy + 距离域 delta（FastF1 式 ∫(1/v−1/v_ref)ds）。Supervision 合理落点：赛道俯视图 zone 标注、回放视频叠层、HUD 校验——而非替代 IBT 解析。

**Repo note：** 当前 PythonTest 仓库无 iRacing 相关代码；`hntestdir/hntest/image_recognition/supervision.py` 仅有通用 YOLO 示例可作 CV 起点。

## Topic Axes

1. **遥测与参考圈对齐** — ibt/CSV 解析、距离轴插值、参考圈来源与 schema
2. **弯道分段与时差归因** — 弯界定义、per-corner delta、brake/apex/exit 相位归因
3. **语音教练体验** — TTS 时机、圈后 vs 圈内、信息稀疏度与认知负荷
4. **LLM 解释层** — 结构化 delta → 自然语言、prompt 与防幻觉
5. **Supervision/CV 独特价值** — CV 相对纯遥测的增量，而非重复造轮子

## Ranked Ideas

### 1. 结构化相位归因 + 模板 LLM 教练内核
**Description：** 在每个弯道内按 brake / apex / exit 子段分别计算 delta；规则引擎匹配已知模式（早刹、apex 速度低、出弯油晚），输出 `{corner, phase, delta_s, pattern_id, advice_key}`。LLM 仅做措辞润色与优先级排序，且输出须经数值校验（播报秒数与 JSON 一致）。80% 场景可离线规则完成，LLM 为增强层。
**Axis：** 弯道分段与时差归因 / LLM 解释层
**Basis：** direct: 用户目标示例「Turn 1 损失 0.5s，考虑早点刹车」；external: Coach Dave / TrackPro 均采用弯内相位模板；reasoned: Pulpo 等闭源教练的可执行建议来自相位对比而非 LLM 臆测
**Rationale：** 直接兑现「哪个弯、为什么、怎么改」；降低 LLM 幻觉，符合「简单 LLM」约束；与竞品黑盒形成可验证差异。
**Downsides：** 需维护 pattern_id → 话术映射；复杂复合弯（连续弯）规则覆盖不足。
**Confidence：** 88%
**Complexity：** Medium
**Status：** Unexplored

### 2. pyirsdk 圈末零打断对比 + Top-3 稀疏语音
**Description：** pyirsdk 订阅 live/shared memory，每圈结束自动截取 LapDistPct 序列；与绑定的参考 CSV 做距离对齐，10 秒内 TTS 播报「本圈 +Xs。主要损失：T1 −0.3s 早刹；T7 −0.2s 出弯油晚… 下圈优先修 T1。」最多 3 弯 + 1 条优先级，总长 <20s；默认不做圈内连续语音。
**Axis：** 遥测与参考圈对齐 / 语音教练体验
**Basis：** direct: grounding pain「MoTeC/VRS require stopping game」；external: TrackPro 实时语音 vs 练习场景 post-lap 认知负荷共识；direct: pyirsdk live/shared memory 为官方 SDK 路径
**Rationale：** 保留练习心流，是用户描述工作流的最小可行闭环；local-first 对标 trophi.ai/PoleCraft 云订阅。
**Downsides：** pyirsdk 安装与 iRacing 版本兼容；短圈（卡丁）圈间窗口紧张。
**Confidence：** 85%
**Complexity：** Medium
**Status：** Unexplored

### 3. Web 参考圈 Schema-on-Read + 距离轴指纹对齐
**Description：** 不预定义单一 CSV schema；首次加载自动检测列（LapDistPct/Speed/Brake/Throttle）并映射到内部模型。用 LapDistPct 单调插值 + 圈长校验（差 >0.5% 拒判并语音提示「参考圈赛道不匹配」）。支持用户从 MoTeC 导出、社区工具、自制 Excel 等多来源。
**Axis：** 遥测与参考圈对齐
**Basis：** direct: 用户约束「网上下载的 CSV」；direct: grounding「Reference CSV format undefined — VRS doesn't export CSV」；reasoned: 格式碎片化是上手第一堵墙
**Rationale：** 参考圈获取是对比链路的 gate；对齐失败时拒判比错误教练更 trustworthy。
**Downsides：** 极端非标 CSV 仍可能误映射；需文档化最小必需列。
**Confidence：** 82%
**Complexity：** Low–Medium
**Status：** Unexplored

### 4. 刹车峰值 + 横向 G 双信号自动弯道切分
**Description：** 在距离轴上检测刹车压力超阈 → apex（最小速度或最大横向 G）→ 油门回升，自动切 Turn N 区间；每弯计算 ∫(1/v−1/v_ref)ds。delta > 全局均值 2× 的弯标记为「本圈主要损失点」优先进语音队列。可选叠加社区 track corner map（LapDistPct 区间 → 弯名）。
**Axis：** 弯道分段与时差归因
**Basis：** direct: pain「iRacing delta bar only shows total」；reasoned: 刹车/apex/exit 三相位是 telemetry 教练通用框架；external: TrackPro 128-track corner DB 证明弯名数据可维护
**Rationale：** 无 per-corner delta 则语音与内置 delta bar 无差别；是相位归因与语音的内容源。
**Downsides：** 每条赛道弯界需验证； chicanes / 连续弯可能 over/under-segment。
**Confidence：** 80%
**Complexity：** Medium
**Status：** Unexplored

### 5. Supervision PolygonZone 俯视图损失热力叠层
**Description：** 为每条赛道预标注俯视 PolygonZone（或从 GPS 投影生成）；将 per-corner delta 映射到 zone 颜色（红=损失最大）。圈末生成 3 秒 overlay 截图或 OBS 层，**CV 不参与算 delta**，只把数字绑到空间位置。弥补「Turn 7 在哪」的新手摩擦。
**Axis：** Supervision/CV 独特价值
**Basis：** direct: 用户要求 Supervision；direct: grounding「Supervision… PolygonZone… track map visualization」；direct: repo `supervision.py` 已有 annotator 使用经验
**Rationale：** 诚实使用 Supervision——可视化层而非硬塞进遥测主路径；与纯语音形成双模态，差异化 trophi 类纯音频。
**Downsides：** 每赛道需 zone 资产；GPS 投影精度因赛道而异。
**Confidence：** 75%
**Complexity：** Medium
**Status：** Unexplored

### 6. 会话 PB「黄金圈」+ 外链 CSV 双模参考
**Description：** 除下载 CSV 外，默认以本会话最快稳定圈为动态参考，PB 刷新即滚动更新。用户可在「职业参考 CSV」与「个人 PB」间切换。对比「上一圈 vs 当前最佳」零配置可用；CSV 用于「向 pro 学习」场景。
**Axis：** 遥测与参考圈对齐
**Basis：** reasoned: 打破「必须 pro 参考圈」；direct: 用户也提到「上一圈」对比；external: iSpeed datamart 社区参考 vs 自对比两种模式并存
**Rationale：** 降低冷启动摩擦；PB 与当前车辆/调教一致，避免「职业圈复现不了」的挫败；与 CSV 模式互补而非替代。
**Downsides：** 仅 PB 对比无法发现「根本走线错误」；需 UI/语音说明当前参考模式。
**Confidence：** 78%
**Complexity：** Low
**Status：** Unexplored

### 7. ClearSpeak 式「单弯单建议」语音节奏
**Description：** 借鉴语言学习 ClearSpeak / Peloton IQ：每圈最多 1 条主建议 + 可选 2 条次要；圈内不做 LLM 长文。可选 sector 结束 15 字以内 whisper（仅最大单项 delta）。玩家说「为什么？」才触发 LLM 因果解释（按需层）。
**Axis：** 语音教练体验 / LLM 解释层
**Basis：** external: ClearSpeak 单次只纠一个模式；external: Peloton IQ 可配置 cue 频率防过载；reasoned: iSpeed 限制 POI 到练习反映 race 认知负荷共识
**Rationale：** 语音教练成败在稀疏高信号，非信息堆砌；与 #2 Top-3 稀疏播报形成产品 UX 原则。
**Downsides：** 高级用户可能觉得「说太少」；需设置项调节 verbosity。
**Confidence：** 77%
**Complexity：** Low
**Status：** Unexplored

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | CV 从录屏反推刹车/油门序列 | Supervision 与遥测错配；±0.1s 精度不现实；与用户 IBT+CSV 主路径重复 |
| 2 | CV 自动弯道分段替代 sector 配置 | 过度承诺 CV；遥测事件切分更可靠 |
| 3 | 浏览器扩展抓取 VRS 表格 | VRS 无公开 CSV；ToS/法律风险；维护成本高 |
| 4 | ByteTrack HUD OCR delta 交叉验证 | 有趣但非 MVP；增加复杂度，偏离核心 loop |
| 5 | Garage61 概率参考包络（无限参考圈） | 需 API/Agent 集成；scope 超出「简单 CSV」 |
| 6 | 百万用户蒸馏微模型 | 团队/数据规模假设；偏离个人工具定位 |
| 7 | 纯 CV 零遥测「赛道镜子」 |  subject 偏离用户描述的 telemetry+CSV 核心 |
| 8 | Mistake Cluster 替代弯道名 | 失去用户明确要的「一号弯」语义；对新手不友好 |
| 9 | 实时边跑边播全弯语音 | 认知过载；TrackPro 已占据；与 ClearSpeak 稀疏原则冲突 |
| 10 | 赛后 MoTeC PDF 零语音 | 移除用户硬约束「语音播报」 |
| 11 | 预录 clip 拼贴替代 TTS | 可作为 #7 增强，非独立产品方向；录制资产成本高 |
| 12 | 截图识道零遥测冷启动 | Supervision stretch；与 IBT 主路径弱相关 |
| 13 | 反向 subtractive 教练 | 合并进 pattern 模板即可，非独立 survivor |
| 14 | 条件切片参考库（胎温/载油） | v2 复杂度；MVP 可后加 |
| 15 | axis: LLM解释层 | 已通过 #1/#7 覆盖；无独立 gap |

## Suggested MVP Stack (synthesis, not a survivor)

**Telemetry path：** pyirsdk → pandas 距离对齐 → #4 弯道切分 → #1 相位归因 → #2 语音  
**Reference path：** #3 CSV 对齐 + #6 PB  fallback  
**Supervision path：** #5 圈末热力 overlay（可选第二迭代）  
**LLM path：** 结构化 JSON in → 模板槽位 out（#1），按需「为什么」（#7）
