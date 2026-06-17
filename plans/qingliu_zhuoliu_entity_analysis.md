# 清流/浊流实体整理报告

> 生成时间: 2026-06-17
> 数据源: 747_kuangda 时代事件库 + trait relation 系统 + 五维宪法 Tag 词典

---

## 实体层级全景图

```
Layer 1: 五维宪法 TARGET 层 (Tag 词典枚举)
├── TARGET_FACTION_QINGLIU   — 清流 (抽象概念)
├── TARGET_FACTION_ZHUOLIU   — 浊流 (抽象概念)
├── TARGET_FACTION_ROYAL     — 皇室
├── TARGET_FACTION_MILITARY  — 藩镇
├── TARGET_NPC_LIBAI         — 李白
├── TARGET_NPC_DUFU          — 杜甫 (玩家)
├── TARGET_NPC_WANGWEI       — 王维
└── TARGET_NPC_YANGGUIFEI    — 杨贵妃

Layer 2: Relation 系统 (traits.csv 人物关系)
├── 清流侧 NPC
│   ├── gaoshi     — 高适 (沉默援助型)
│   ├── wangwei    — 王维 (文化庇护型)
│   ├── zhengqian  — 郑虔 (精神锚点型)
│   └── libai      — 李白 (狂客独立型)
├── 浊流侧 NPC
│   ├── lilinfu        — 李灵甫/李林甫 (右相)
│   ├── youxiangfu     — 右相府 (权力机构)
│   ├── jiwen          — 吉温 (酷吏)
│   ├── yangguozhong   — 杨国忠 (外戚)
│   ├── guoguofuren    — 虢国夫人 (外戚)
│   ├── hushang        — 商人 (资金方)
│   └── waiqi          — 外戚 (集团)
└── 事件文本露脸但无 relation 的 NPC
    ├── 张垍     — 集贤院人物 (清流圈)
    ├── 韦左丞   — 清流权贵
    ├── 崔九爷   — 浊流圈
    ├── 王郎中   — 户部郎中 (浊流官僚)
    └── 赵主事   — 清流/官僚系统

Layer 3: 身份/职位实体 (事件文本提取)
├── 清流身份
│   ├── 清流主人   — 雅集召集者/审美裁判
│   ├── 集贤院学士 — 官方学术机构
│   └── 县尉       — 清流出身的基层官员
├── 浊流身份
│   ├── 右相/右相门生   — 权力顶点
│   ├── 掮客            — 权力交易中介
│   ├── 紫袍胖子权贵    — 浊流具象化身
│   ├── 清客            — 依附权贵的文人
│   └── 户部郎中        — 浊流官僚
└── 跨阵营身份 (清浊分水岭)
    ├── 商人     — 清流排斥/浊流接纳 ← 核心分水岭
    ├── 胡姬/胡商 — 场景装饰
    ├── 新科进士  — 双方争夺对象
    └── 歌伎      — 被物化的功能性角色

Layer 4: 玩家立场 Archetype Traits
├── kuangda_kuangke  — 狂客 (清流左翼/狂放派)
├── kuangda_fengying — 逢迎 (骑墙派/委曲求全)
└── kuangda_zuanying — 钻营 (浊流投机派/计算派)
```

---

## 关键缺口

### 缺口 1: TARGET_NPC Tag 宪法缺口
当前五维宪法只枚举了 libai, dufu, wangwei, yangguifei 四个 NPC。gaoshi, zhengqian, lilinfu, jiwen, yangguozhong 等关键人物没有 TARGET Tag，无法通过标签匹配触发他们的专属事件。

### 缺口 2: 浊流侧 NPC 事件密度严重不足
清流侧有 6 个形象鲜明的 NPC（李白、王维、高适、郑虔、张垍、韦左丞），每个有多层事件。浊流侧 relation 系统有 7 个实体，但事件文本中真正有具体形象的只有「紫袍胖子」和「掮客」——李林甫、吉温、杨国忠这些历史重量级人物几乎没出场。

### 缺口 3: 商人作为「清浊分水岭」未被充分利用
从 qingliu_zuanying_events 可见清流排斥商人，而浊流接纳商人。但当前没有系统性地利用商人作为玩家清浊立场的温度计。

### 缺口 4: kuangda 积分语义模糊
`flag_int_append(name=kuangda; val=±N)` 混用了两种语义：正的 kuangda 值到底是「狂放/清流」还是「不妥协」？负值是「妥协」还是「浊流接纳」？需要拆成双轴。

---

## 建议的后续动作

1. **补全 TARGET_NPC 宪法条目** — gaoshi, zhengqian, lilinfu, jiwen, yangguozhong
2. **为浊流侧 NPC 创建专属事件** — 给李林甫、杨国忠等加"脸"
3. **重构 kuangda 积分为双轴** — 清流亲和度 vs. 浊流亲和度
4. **利用商人作为清浊温度计** — 扩展现有事件，让对待商人的方式反映立场
