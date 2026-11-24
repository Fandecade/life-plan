# 人生规划 · Life Planner

跨平台个人成长与时间管理系统。把「长期方向 → 能力建设 → 具体行动 → 时间安排 → 输出学习 → 习惯养成 → 周期复盘」串成一条可执行的闭环，而不是一堆彼此割裂的待办列表。

- **技术栈**：Flutter / Dart（纯 Dart 本地存储，桌面、Web、移动端零原生数据库依赖）
- **架构**：Core Host + Feature Plugins（模块可开关，关闭后隐藏入口与扩展槽位但保留数据）
- **设计原则**：极简高级感（大量留白、低饱和中性色、克制语义色）；先看事实再动笔；结论必须落成可执行动作
- **当前状态**：五个业务模块 + 设置页已完成，`flutter analyze` 0 error / 0 warning，**105 项自动化测试全部通过**

---

## 一、快速开始

### 1. 环境要求
- Flutter 3.50+ / Dart 3.14+
- macOS（桌面验证）、Chrome（Web）、iOS/Android（可构建）

### 2. 拉取依赖并运行

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn

flutter pub get

# macOS 桌面
flutter run -d macos
# 或构建后直接打开
flutter build macos --debug
open build/macos/Build/Products/Debug/life_planner.app

# Web
flutter build web --release
```

### 3. 首次启动会看到什么
首次启动会写入一份种子数据，便于立刻体验完整链路：

- 一个愿景「成为能独立交付产品的创造者」
- 两个能力：「产品设计与实现」「结构化表达与输出」
- 若干任务与一个已排期时间块

数据保存在本机 Hive 数据库（应用支持目录下的 `life_planner` 子目录）。清空数据可在「设置 → 数据」里操作。

### 4. 基本操作
- 左侧导航切换模块（窄屏为底部导航）
- `⌘K` / `Ctrl+K` 呼出任务池
- 顶部「安排记录」只在时间盒界面出现，可点击条目跳回对应时间块
- 点击任意任务卡片打开右侧详情抽屉；详情抽屉底部会挂载已启用模块的扩展槽位

---

## 二、五大模块详解

### 2.1 人生规划（vision_map）

用一张纵向树状图谱表达「愿景 → 能力 → 任务 → 子任务（最多 3 级）」。

**核心能力**
- **自动布局**：愿景在左、能力纵向排列、任务按子树高度分列排布，自动避免重叠
- **画布交互**：缩放/平移（0.35x–2.2x）、贝塞尔连线、路径高亮、节点拖拽微调（位置持久化）
- **节点配色**：愿景 / 能力 / 任务 / 子任务四类语义色（低饱和）
- **折叠**：折叠能力后其任务节点从画布移除，展开恢复
- **键盘流（XMind 式）**
  - 空格：打开所选节点详情
  - Enter：创建同级任务
  - Tab：创建子任务
  - 编辑态：Tab 提交并继续建子节点，Esc 取消
- **愿景管理**
  - 新建愿景默认追加到切换栏末尾
  - 切换栏胶囊支持**拖动排序**（落点左侧细线提示）
  - 胶囊右键/长按：前移 / 后移 / 删除这个愿景
  - 画布卡片菜单：重命名 / 添加能力 / 删除愿景（删除会连带软删除其能力与任务）
- **能力与任务**
  - 添加/重命名能力，设置目标水平
  - 任务可设置截止日（月视图显示 DDL 徽章）
  - 任务详情抽屉内可继续创建子任务、调整预估时长与状态

**用于**：把「想成为什么样的人」翻译成「今年该建哪些能力 → 这周做哪些任务」。

---

### 2.2 时间盒（time_box）

把任务放进具体时间，用「计划 vs 实际」驱动复盘。四个粒度解决不同问题。

**共同结构**
- 顶部：日/周/月/年胶囊 + 日期导航（左右箭头、今天）+「固定安排」入口
- 顶部入口：任务池（⌘K 呼出）、安排记录面板（仅时间盒显示，可跳转定位）
- 拖拽任务到时间轴即可排期，排期后任务状态变为「已排期」

**日视图**
- 24 小时时间轴，15 分钟吸附
- **滚轮 / 普通拖动 = 滚动时间轴**
- **长按约 0.5 秒后拖动 = 圈选时间格**，松手弹出「安排任务」选择器
- 单击空白 = 直接安排
- 时间块可上下拖动改开始时间、拖右下角手柄改时长（15 分钟吸附）
- 重叠时间块自动分列显示
- 今日显示当前时间线
- 今日顶部显示「今日微习惯」轻提示条（点胶囊即打卡，不占时间轴格子）

**周视图**
- 7 天 × 时间轴矩阵
- 块左右拖动 = 跨天改期（保留时刻）；上下拖动 = 同一天内改开始时间（15 分钟吸附）
- 固定安排块在周视图内按固定规则生成，可单周跳过

**月视图**
- 每日负荷热力（已完成时长）、复习节点图标、任务 DDL 徽章、月复盘状态
- 点击日期先弹「当天简报」（负荷 / 时间块概览 / 复习节点），再由简报进入当日时间盒
- 底部显示每日微习惯节律点（当天完成几个习惯，最多 4 个 + `+n`）

**年视图**
- 12 个月卡片、每月活跃度与复盘轨迹点、年度方向
- 点击月份下钻到月视图

**固定安排**
- 两类：`fixedRoutine`（纯固定事项，如课程）与 `linkedTask`（固定安排绑定的任务实例）
- 懒生成：按需把模板实例化到具体日期
- 单周例外：`RoutineException`（仅本周跳过）与块上的 `isOverridden`
- 右键菜单：编辑 / 仅本周跳过 / 恢复默认 / 删除
- 支持整周复制（copyDay）

---

### 2.3 输出式学习（output_learning）

学习监督台：**今日待学 / 到期复习 / 进行中草稿 / 输出成果库**四个筛选。

**五类学习方法（各 4 步）**

| 类型 | 步骤 | 复习间隔 |
|---|---|---|
| 陈述性知识（概念·费曼） | 课前/读前设问 → 定向输入与建网 → 独立输出（费曼/摘要）→ 输出校验与间隔排期 | 1/3/7/15/30 天 |
| 程序性知识（实操·刻意练习） | 锁定单一短板 → 闭卷实战与反馈 → 错因归因输出 → 薄弱点重练排期 | 1/3/7 天 |
| 项目式学习 | 搭建最小骨架 → 按需定向补盲 → 产出可运行原型 → 边界与迁移总结 | 1/7/15/30 天 |
| 语言学习 | 盲听与精听拆解 → 影子跟述训练 → 脱稿复述与造句 → 语料检索排期 | 1/3/7/15 天 |
| 自定义输出 | 目标与输入 → 独立输出 → 自检与补盲 → 总结与排期 | 1/3/7/15/30 天 |

**双档模式**
- 完整输出：走完四步
- 5 分钟微输出：只保留核心输出步骤（陈述性与自定义支持）

**功能细节**
- 列表式逐点输入（回车落点），草稿按步骤断点保存（切换模式不丢）
- 完成门禁三选：按方法自检后才允许完成
- 卡点速记（1–3 句）+ 外部成果链接（Obsidian / Notion / GitHub / 本地文件）
- **间隔复习（主动回忆）**
  - 结果三选：顺畅（间隔 ×2，上限 60 天）、模糊（保持）、遗忘（回到 1 天）
  - 连续两次顺畅可提前通关
  - 复习块自动落到时间盒 20:00，点开块直接进入回忆
- **两层状态**
  - `待巩固`（权重 0.7）→ `彻底完成`（权重 1.0）
  - 项目式学习可直接完成；其余按复习检验推进
- **输出成果库**：按步骤分块折叠查看、删除记录、重新学习
- **任务详情槽位**：在任务抽屉里直接推进学习（今日待学/复习/成果入口）

---

### 2.4 福格习惯（fogg_habit）

行为设计模块，理论与学习系统解耦，只通过扩展槽位与其他模块联动。

**页面结构**
- 顶部胶囊：`今日锚点 · N` / `全部习惯` / `行动线诊断` / `配方调整记录`
- 今日锚点按锚点时段分组：晨间锚点 / 日间间隙 / 晚间收尾 / 随时触发
- 右上「新建习惯」

**习惯卡片**
- 锚点时段标签、连续天数（温和计算，今天没做不清零）
- 锚点提示 → 微行为（已完成划线）
- 14 天低饱和点阵（无红叉、无断签惩罚）
- 右侧圆圈一键打卡/撤销；「今天顺势多做 · 记超额」（只记增量，不抬高次日门槛）
- 「⋯」：调整配方 / 行动线诊断与推演 / 停用 / 删除微习惯
- 卡片右键/长按菜单提供同样入口

**6 步配方**
1. 锚点场景（在什么已有动作之后）
2. 微行为（15 秒 ~ 2 分钟内可启动）
3. 即时庆祝
4. 锚点时段（四选一）
5. 5 维阻力检查（时间/金钱/体力/脑力/日程习惯）+ 降阻准备
6. 行为集群 + 焦点地图 + 关联任务/能力 + 动作升级

**焦点地图**
- 中间十字坐标轴：横轴左「难做」右「易做」，纵轴下「低影响」上「高影响」，右上为「黄金区」（impact ≥ 4 且 effort ≤ 2）
- 节点宽度随名称长度自适应；同档位节点自动散开；拖动为连续坐标（`mapX/mapY`），松手停在原地并换算回档位
- 点击节点确认是否放入本次配方；支持拖动调整影响力/难度

**行动线诊断与推演**
- 顶部公式说明：`B = M（动机）× A（能力）× P（提示）`
- 多习惯散点图：行动线分区（上浅绿=易触发 / 下浅粉=卡阻），点击节点选中并可直接拖动
- 诊断面板：习惯胶囊切换、当前落点状态、行为公式、诊断建议
- 四个可调参数：能力值 / 动机值 / 行动线门槛 / 行动线弯曲度
- 「应用并生成新配方」：削减阻力（优先级 体力→脑力→时间→日程→金钱）、补强庆祝/锚点、生成 v+1 版本
- 历史版本对比：配方记录点开后显示灰色历史落点与 `历史 vN：线上/线下`
- 值班区域标注「节奏偏缓」而非考勤式评价

**其他联动**
- 任务详情槽位：绑定微习惯、打卡、调整配方、行动线推演、右键删除
- 时间盒日视图顶部「今日微习惯」条
- 月历微节律点

---

### 2.5 及时复盘（review）

复盘不是写日记，而是「事实校准 → 根因归因 → 去偏 → 行动转化」。

**周期与状态**
- 日 / 周 / 月 / 年四页签 + 日期导航 + `未复盘/已完成`
- 「标记完成」可随时点（不强制清零）；再次点击「已完成」会弹确认框，确认后撤销完成标记
- 右上「历史」列出所有写过/完成的复盘，点击跳回对应周期

**客观数据看板（自动读取四大模块）**
- 时间投入：完成时长 / 计划时长 / 完成率（含「较上期 ±」）
- 任务与学习：完成数、新增巩固数、独立输出次数
- 微习惯节律：完成率、打卡次数、节奏偏缓数量
- 能力精力分布条：按能力统计时间块时长，点击可跳图谱并定位该能力

**引导问答（按周期差异化，600ms 自动保存）**
- 日：今日亮点 + 明日最关键 1–3 件事
- 周：有效模式（Keep）+ 最大瓶颈/元认知自问 + 结构性调整 + If–Then 预案
- 月：能力推进评估 + 停滞与偏离 + 目标减法（Stop Doing）
- 年：年度代表作 + 愿景对齐 + 下一年布局
- 周/月/年底部提供「沉淀为微习惯」「存为学习模板」

**待校准事项（5 类，均为可执行动作 + 可撤销）**

| 事项 | 动作 | 结果 |
|---|---|---|
| 未完成时间块 | `安排日期` | 自由选择日期/时间/时长（时长可改），同步回时间盒 |
| 未完成时间块 | `⋯` 拆解任务（去图谱） | 跳到图谱对应任务节点，自己拆子任务 |
| 未完成时间块 | `⋯` 回任务池 / 取消 | 解除排期 / 删块并把任务标为已延后 |
| 逾期复习 | `安排时间` | 自由选择时间与时长，更新到期时间并生成时间盒块 |
| 逾期复习 | `⋯` 分散复习负载… | 可配天数/每日上限/晚上时间 |
| 节奏偏缓习惯 | `调配方` | 打开行动线诊断与推演 |
| 停滞任务 | `归档` | 任务标记为已延后 |
| 学习卡点 | `生成补盲任务` / `确认补盲` | 主动记录直接生成；关键词命中需确认，可忽略 |

- 每项都有「暂不调整（维持现状）」：点击即写入已处理，允许「看过但决定先不动」
- 处理后可「撤销」，回滚数据动作与已处理标记（会话内）

**周/月/年扩展区**
- 学习系统摘要（应复习/已复习/按时率/独立输出/盲区）
- 能力推进（完成/巩固中/投入，点击定位图谱）
- 月负荷热力 / 年 12 月活跃度热力
- 配方版本执行率（v1 → v2 对比）
- 内嵌「习惯行动线」迷你散点图（点节点调配方，右上「改固定安排」）
- 年复盘「年度成果精选」（输出式学习作品 + 摘要，点击打开任务详情）

---

## 三、模块之间如何联动

### 3.1 总览

| 源模块 | 去向 | 联动内容 |
|---|---|---|
| 人生规划 | 时间盒 | 拖拽任务到时间轴 → 生成时间块，任务变「已排期」 |
| 人生规划 | 输出式学习 / 福格习惯 | 任务详情槽位：学习推进、微习惯绑定 |
| 时间盒 | 人生规划 | 勾选时间块完成 → 普通任务置「已完成」；学习任务只推进到「进行中」 |
| 时间盒 | 复盘 | 计划/实际时长、完成率、能力分布、未完成块进入待校准 |
| 输出式学习 | 时间盒 | 完成学习后生成 1/3/7… 天复习块（20:00），点块直接进回忆 |
| 输出式学习 | 人生规划 | 学习任务状态（待巩固/彻底完成）驱动任务进度与能力进度 |
| 输出式学习 | 复盘 | 独立输出次数、复习按时率、卡壳盲区、补盲任务 |
| 福格习惯 | 时间盒 | 日视图微习惯条、月历微节律点 |
| 福格习惯 | 复盘 | 节律完成率、节奏偏缓习惯、配方版本执行率、内嵌行动线 |
| 复盘 | 全部 | 安排日期/时间、拆解去图谱、分散负载、生成补盲任务、归档、调配方、定位能力/任务 |
| 设置 | 全部 | 模块开关（隐藏入口与槽位、保留数据）、主题、清空数据 |

### 3.2 关键链路示例

1. **愿景落地**：图谱建任务 → 拖到时间盒排期 → 完成后任务完成 → 月复盘能力推进 +1
2. **学习闭环**：任务标记为输出式学习 → 四步输出 → 完成门禁 → 生成复习块 → 复习结果调整间隔 → 两层状态变为「彻底完成」
3. **习惯养成**：建微习惯配方 → 每日点阵打卡 → 行动线诊断 → 应用生成 v2 配方 → 下月复盘对比 v1/v2 执行率
4. **复盘收尾**：打开日复盘 → 看数据卡 → 未完成块「安排日期」到明天 → 逾期复习「安排时间」 → 写明日 1–3 件事 → 标记完成

---

## 四、数据库概况

### 4.1 存储方案
- Hive（纯 Dart），所有实体以 JSON 字符串落在各自 box
- 数据库位置：应用支持目录 `life_planner/`
- 共 **13 个业务 box + 1 个设置 box**

| box | 对应实体 | 用途 |
|---|---|---|
| `visions` | Vision | 愿景 |
| `capabilities` | Capability | 能力 |
| `action_items` | ActionItem | 任务/子任务（含学习、习惯任务） |
| `time_blocks` | TimeBlock | 时间盒块 |
| `learning_sessions` | LearningSession | 学习会话与草稿 |
| `learning_reviews` | LearningReview | 间隔复习 |
| `weekly_routines` | WeeklyRoutine | 固定安排模板 |
| `routine_exceptions` | RoutineException | 单周跳过 |
| `fogg_habits` | FoggHabit | 微习惯配方 |
| `habit_logs` | HabitLog | 每日打卡 |
| `behavior_candidates` | BehaviorCandidate | 焦点地图候选行为 |
| `habit_recipe_versions` | HabitRecipeVersion | 配方版本快照 |
| `review_logs` | ReviewLog | 复盘文本与统计快照 |
| `settings` | — | 主题、模块开关 |

### 4.2 公共字段
所有实体继承 `SyncEntity`：

- `id`（UUID v4）
- `createdAt` / `updatedAt`
- `deletedAt`（软删除；`all` 默认过滤）
- `syncStatus`（`pendingUpdate` / `pendingDelete` 等，二期服务端同步预留）

### 4.3 实体关系

```
Vision 1──n Capability
Capability 1──n ActionItem（capabilityId）
ActionItem 1──n ActionItem（parentId，最多 3 级）
ActionItem 1──1 TimeBlock（actionItemId，可空=独立块）
TimeBlock n──1 LearningReview（learningReviewId）
TimeBlock n──1 WeeklyRoutine（routineId）
ActionItem 1──n LearningSession（actionItemId）
LearningSession 1──n LearningReview（sessionId）
FoggHabit n──1 ActionItem / Capability（可选关联）
FoggHabit 1──n HabitLog（habitId + dateKey）
FoggHabit 1──n HabitRecipeVersion（habitId + revision）
ReviewLog（periodType + periodKey）独立
```

### 4.4 关键字段速查

- **ActionItem**：capabilityId、parentId、title、note、executionMode（标准/输出式学习/福格微习惯）、estimatedMinutes、status（任务池/已排期/进行中/待巩固/已完成/已延后）、posX/posY、completedAt、dueDate、isCollapsed
- **TimeBlock**：actionItemId、learningReviewId、routineId、title、startAt、endAt、isCompleted、isOverridden、actualMinutes；`plannedMinutes` 由起止时间计算
- **LearningSession**：actionItemId、learningType、mode（完整/微输出）、stepsDataJson（步骤文本+卡点+链接）、currentStepIndex、isFinished、completedAt
- **LearningReview**：sessionId、actionItemId、dueDate、intervalDays、isDone、outcome（顺畅/模糊/遗忘）、doneAt
- **FoggHabit**：linkedCapabilityId、linkedActionItemId、anchorPrompt、tinyBehavior、anchorPeriod、celebration、frictionsJson（5 维）、abilityFrictionTip、motivationNote、isActive
- **HabitLog**：habitId、dateKey、isCompleted、isExtra、adjustmentNote
- **BehaviorCandidate**：title、impact(1–5)、effort(1–5)、isSelected、mapX/mapY（连续坐标）
- **HabitRecipeVersion**：habitId、revision、anchorPrompt、tinyBehavior、celebration、frictionsJson、note、completedIn7Days（历史落点还原用）
- **ReviewLog**：periodType、periodKey（`2026-11-24` / `2026-W48` / `2026-11` / `2026`）、winsText、blockersText、adjustmentsText、focusText、ifThenText、isCompleted、handledItemsJson、snapshotStatsJson

### 4.5 数据安全设计
- 删除均为**软删除**：界面消失但数据保留，可恢复/二期同步
- 复盘「已处理」条目持久化在 `handledItemsJson`，跨会话保留
- 清空数据需二次确认，只清业务数据、保留设置（`wipeData`）

---

## 五、核心业务规则速查

1. **排期**：排期即创建/更新时间块并把任务置「已排期」
2. **完成同步**：时间块勾完成 → 普通任务完成；学习任务只到「进行中」（由学习自检决定最终状态）
3. **学习掌握度**：待巩固 0.7 → 彻底完成 1.0；连续两次顺畅可提前通关
4. **间隔复习**：顺畅 ×2（≤60 天）、模糊保持、遗忘回 1 天
5. **福格打卡**：超额只记增量，不抬高次日门槛；连续天数温和计算
6. **黄金行为**：impact ≥ 4 且 effort ≤ 2
7. **行动线**：`required(ability) = threshold + (10 - threshold) × (1 - ability/10) ^ curvature`
8. **复盘数据口径**：时间盒按计划分钟与完成分钟；能力分布按计划分钟；习惯按「完成次数 / (活跃习惯 × 周期天数)」
9. **复盘动作优先级**：阻力削减 体力 → 脑力 → 时间 → 日程习惯 → 金钱
10. **默认值可改**：时间、时长、分散天数等默认值只是一次性建议，均可随手调整

---

## 六、界面与导航

- **Shell**：桌面左侧导航 + 移动端底部导航；内容区自适应
- **TopBar**：当前模块、任务池入口（⌘K）、安排记录入口（仅时间盒）
- **任务池（Inbox）**：右侧滑出，快速接住临时想法，回车加入；拖到时间盒直接排期
- **安排记录**：时间盒内的滑动面板，展示待执行与已完成，点击跳转定位
- **详情抽屉**：右侧抽屉，展示任务字段、截止日、子任务，底部挂载模块槽位（学习/习惯）
- **设置**：外观（跟随系统/浅色/深色）、模块管理（开关）、清空数据
- **主题**：浅色背景 `#FAF9F6`、卡片 `#FFFFFF`、分隔线 `#EDEFF2`、强调色 `#4A5F7A`；深色对应 `#121417` / `#1C1F24` / `#2A2E37`

---

## 七、目录结构

```
lib/
├── main.dart
├── app/
│   ├── app.dart                 # MaterialApp + Provider 装配 + 滚动行为
│   ├── bootstrap.dart           # 组合根：数据库、仓储、服务、模块注册
│   ├── theme/                   # AppPalette / 字体 / 主题
│   ├── router/module_routes.dart
│   └── shell/                   # 侧栏、底栏、TopBar、任务池、安排记录、详情抽屉
├── core/
│   ├── models/                  # 12 个实体文件 + barrel
│   ├── database/                # LocalDatabase、仓储、种子数据
│   ├── services/                # 排期、固定安排、学习掌握度、习惯、复盘、行动线
│   ├── plugin/                  # 模块描述符、注册中心、内置模块清单
│   ├── state/                   # UiController、ThemeController
│   ├── utils/                   # 日期、节点配色、进度权重
│   └── widgets/                 # 卡片、按钮、胶囊、输入、状态视图
└── modules/
    ├── vision_map/              # 图谱页面、画布、布局、节点、编辑器
    ├── time_box/                # 日/周/月/年视图、固定安排、任务选择器
    ├── output_learning/         # 学习监督台、会话流、复习流、详情槽位
    ├── fogg_habit/              # 习惯页、配方、焦点地图、行动线、槽位、日视图条
    ├── review/                  # 复盘页、安排对话框
    ├── settings/
    └── shared/
```

---

## 八、开发与验证

### 命令

```bash
flutter analyze          # 0 error / 0 warning（既有 70+ 条 info 为 material 弃用提示）
flutter test             # 105 项
flutter build macos --debug
flutter build web --release
```

### 测试覆盖（23 个文件）

| 领域 | 文件 |
|---|---|
| 骨架与导航 | `widget_test.dart`、`app_smoke_test.dart` |
| 图谱 | `vision_layout_test.dart`、`vision_crud_test.dart` |
| 时间盒 | `time_box_test.dart`、`time_box_scroll_test.dart`、`schedule_sync_test.dart`、`routine_test.dart`、`routine_ui_test.dart` |
| 输出式学习 | `learning_methods_test.dart`、`learning_ui_test.dart`、`learning_review_test.dart`、`learning_mastery_test.dart` |
| 福格习惯 | `habit_test.dart`、`habit_ui_test.dart`、`habit_delete_test.dart`、`habit_focus_map_test.dart`、`habit_link_test.dart`、`habit_action_line_test.dart`、`habit_action_line_ui_test.dart`、`habit_recipe_history_test.dart` |
| 及时复盘 | `review_service_test.dart`、`review_ui_test.dart` |

测试约定：Hive 写入放在 `setUpAll`（真实异步环境）；widget 测试用 `runAsync + pump(duration)` 推进写盘与动画。

### 已知边界与后续方向
- 二期服务端同步未接入（`syncStatus` 已预留）
- 学习盲区关键词为启发式，需人工确认才生成补盲任务
- 暂未提供导入/导出、复盘报告分享
- 删除末尾配方版本后再保存，版本号按现存最大值续编（可能复用编号）
- Material 的 `material_ui` 迁移暂未进行（当前统一使用 `flutter/material`）

---

## 九、总结

这个项目的核心不是「记录」，而是**让每一次思考都能向下传导成具体动作**：

- **图谱**回答「我要成为谁、要建什么能力」
- **时间盒**回答「这些事什么时候做、实际做了多少」
- **输出式学习**回答「我是否真的学会了」
- **福格习惯**回答「怎么让好行为自然发生，而不是靠意志力」
- **及时复盘**把前四者的数据汇成事实，再把结论变成明天真的会发生的安排

数据全部本地、软删除、字段为同步预留；模块可开关；界面保持低干扰的极简工作台风格。当前五个模块已完整跑通闭环，具备继续扩展（同步、导出、移动端打磨）的基础。