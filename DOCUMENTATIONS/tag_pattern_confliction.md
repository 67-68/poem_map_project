你现在的标签体系，经历了 **三段式（3-part）→ 四段式（4-part）** 的升级；引擎侧同时提供了 **3 段式向后兼容的 normalize**，所以两种写法会在一段时间内共存。[[1]](https://www.notion.so/2026-03-28-2026-03-30-a5bd6831531d82b4a6e281b329452849?pvs=21)

---

## 1) 三段式（旧版 / 仍被兼容）

**格式：** `domain:category:value`（你文档里也叫“领域:子类:具体属性”）[[2]](https://www.notion.so/SOP-284d6831531d82b38aab010fa4d1472e?pvs=21)[[3]](https://www.notion.so/AI-234d6831531d82d4a7ad01a6c0bf435d?pvs=21)

**典型例子：**[[2]](https://www.notion.so/SOP-284d6831531d82b38aab010fa4d1472e?pvs=21)

- `actor:status:drunk`（人物状态-醉酒）
- `city:econ:prosperous`（城市经济-繁华）
- `action:study:poetry`（行动意图-学习-诗歌）
- `intel:event:anlushan_rebel`（情报/剧情锁-事件-安禄山谋反）

**它解决的问题：**

- 给事件池/行动/城市环境提供一个稳定、可检索、可“前缀匹配”的命名空间（避免“喝酒/饮酒/drunk”混乱）。[[3]](https://www.notion.so/AI-234d6831531d82d4a7ad01a6c0bf435d?pvs=21)

---

## 2) 四段式（新版 / 你在推进的“现代化”结构）

**格式：** `domain:category:type:specific`  （你更新日志里明确写了这个结构名）[[1]](https://www.notion.so/2026-03-28-2026-03-30-a5bd6831531d82b4a6e281b329452849?pvs=21)

可以把它理解成：在旧的三段式基础上，再拆一刀，让“第三段不要承担太多语义”，把更细的“实例化/私人记忆/上下文”放到第 4 段。你在“醉酒”案例里说得最直接：[[4]](https://www.notion.so/tag-08bd6831531d82b7b4ea012499e66d64?pvs=21)

- 旧：`actor:health:drunk`（太粗）
- 新（你想要的细化方向）：
    - `actor:health:drunk:sad`
    - `actor:health:drunk:with_li_bai`
    - 或者没有上下文时显式写 `actor:health:drunk:general`

**为什么要四段式：**  

你遇到的问题是：**系统调度只需要“大方向”（我醉了），但诗词/意象/回忆等表现层需要“私人记忆/上下文”（我和谁醉、醉得如何）**。三段式会逼你把这些细节塞进枚举/固定集合里，导致爆炸。[[4]](https://www.notion.so/tag-08bd6831531d82b7b4ea012499e66d64?pvs=21)

---

## 3) 工程落地：你当前的折中方案（“4 段字符串 + 中央 TagDB/TagManager 兜底”）

你在那篇“3 段式大问题”里其实已经定了今天能做的现实方案：**前端仍然把 tag 当 `::::` 字符串传来传去，但后台用一个全局 TagDatabase/TagManager 集中解析与维护映射**，把 split/解析的“脏活”封印在一个地方。[[4]](https://www.notion.so/tag-08bd6831531d82b7b4ea012499e66d64?pvs=21)

这样做的直接收益是：

- 你未来如果从 A（字符串后缀）演进到更理想的 B（Tag + Metadata 解耦），反悔成本主要被锁在 TagManager 内部，而不是全工程到处改。[[4]](https://www.notion.so/tag-08bd6831531d82b7b4ea012499e66d64?pvs=21)

---

### 你问的“目前是三层还是四层？”

结论是：**规范目标是四段式；数据/旧内容仍可能是三段式；引擎侧通过 `TagManager.normalize_3part_depreciated_tag()` 做兼容，让两者在运行时可以统一进入同一套匹配/显示逻辑。**[[1]](https://www.notion.so/2026-03-28-2026-03-30-a5bd6831531d82b4a6e281b329452849?pvs=21)

如果你愿意，我也可以按你现在实际用到的 domain（actor/city/action/intel/…）把“4 段式里每段分别允许哪些取值”的草案整理成一张小表，方便你后续批量填表时不乱。