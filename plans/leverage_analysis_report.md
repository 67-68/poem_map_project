# 身份杠杆/把柄分析报告

> 扫描范围: `data/4_eras/747_kuangda/` 下 13 个 CSV 文件，共 130+ 事件行  
> 分析方法: 逐事件审查 description 列，判断玩家从交互中自然获知的关于该身份的可利用信息  
> 排除原则: 纯自然/内心事件（登高全部 18 个事件、道心破碎全部 10 个事件、焦虑 4 个事件中 3 个）、不涉及人类交互的事件

---

## 扫描摘要

| 文件 | 事件数 | 涉及人类交互 | 含杠杆潜力 |
|------|--------|------------|-----------|
| `_duotai_humiliation_events.csv` | 27 | 27 | 2 |
| `_kuangke_qingliu_events.csv` | 8 | 8 | 0* |
| `_kuangke_zhuoliu_events.csv` | 6 | 6 | 3 |
| `_qingliu_daoxin_posui_events.csv` | 10 | 4 | 0 |
| `_qingliu_fengying_events.csv` | 6 | 6 | 1 |
| `_qingliu_jiaolv_events.csv` | 4 | 1 | 0 |
| `_qingliu_passive_benefits_events.csv` | 8 | 8 | 0 |
| `_qingliu_zuanying_events.csv` | 6 | 6 | 2 |
| `_zhuoliu_fengying_events.csv` | 6 | 6 | 1 |
| `_zhuoliu_lieqi_events.csv` | 5 | 5 | 4 |
| `_zhuoliu_zuanying_events.csv` | 6 | 6 | 0** |
| `_zize_events.csv` | 6 | 4 | 1 |
| `denggao/_747kuangda_denggao_events.csv` | 18 | 3 | 0 |

> \* kuangke_qingliu 的交互本质是知音共振，不是把柄收集  
> \** zhuoliu_zuanying 的事件多为玩家被他人抓住把柄（反向），非玩家获得杠杆

---

## 分析说明

### 关于把柄方向

本报告区分两种方向：
- **正向杠杆（玩家获得把柄）**: 玩家从事件中自然了解到关于某身份/NPC的秘密、污点、弱点，可以用于未来交涉
- **反向杠杆（玩家被抓住把柄）**: 事件中其他角色发现了玩家的秘密/污点（如 `zhuoliu_zuanying` 系列），**不在本次分析范围内**

### 关于 kuangke_qingliu

狂客×清流事件库的设计理念是"理想主义共振腔"——NPC向狂客暴露脆弱是出于信任，不是可以被利用的弱点。将李白扔诗稿、王维思友、郑虔愤懑、高适抱怨标记为"把柄"会从根本上违背这个事件库的设计意图。因此这 8 个事件全部排除。

### 关于纯内心/自然事件

`_qingliu_daoxin_posui_events.csv` 的 10 个事件中仅 4 个涉及人际交互（举杯饮寒酸、散席、偏席、旧痕），其余为独处/内心戏，不产生杠杆。  
登高 18 个事件中仅 3 个涉及人际交互，且均为擦肩而过的路人，不产生杠杆。

---

## 逐身份分析

---

## 权贵 (TARGET_IDENTITY_QUANGUI)

### 事件文件: [_zhuoliu_lieqi_events.csv](data/4_eras/747_kuangda/_zhuoliu_lieqi_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 斗鸡坊的诗价 | 紫袍胖子权贵 | 权贵靠在锦垫上吃荔枝，汁水沿指缝往下走。家丁扣住杜甫肘弯。权贵用下巴指角落毡垫上的鸡毛:"杜审言的孙子？正好。我这鸡刚赢三场，缺一首压轴的。" | 权贵沉溺斗鸡赌博、挥霍无度、以羞辱文人（连带其祖父）为乐。知道此人日常消遣和道德水准的具体证据。 | 1 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QUANGUI; val=1)` |
| 泔水赌局 | 浊流大员（权贵阶层） | 浊流大员斜靠胡床，用筷子指墙边矮几上的金锭和纸:"你只有一炷香的时间。金子归你或者举荐信归你。然后——你喝这个。"筷子上的油星滴进泔水。 | 权贵以羞辱落魄文人为娱乐——设下不人道的赌局，用金钱和仕途做饵，迫人喝泔水。这是极度恶劣的权力滥用。 | 2 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QUANGUI; val=2)` |
| 纸灰未冷 | 浊流大员（权贵阶层） | 杜甫在庙中烧纸钱，权贵的仆人停在门槛外:"杜先生，就一句——今日午时，一首贺诗，老地方，要喜庆。"没进来，踩着你昨夜烧的纸灰转身走了。 | 权贵在丧期（杜甫正在烧纸祭奠）派人催要贺诗。知道此人毫无同理心，在他人哀悼时也能若无其事地索要服务。 | 1 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QUANGUI; val=1)` |

### 事件文件: [_zize_events.csv](data/4_eras/747_kuangda/_zize_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 地上的湿痕 | 权贵 | 权贵走后，酒保被往后厨拖。靴底在砖缝上划出一道深色痕迹。桌上碎银子沾着血沫。 | 亲眼目击权贵对平民施暴。碎银+血沫=权贵用钱打发暴力后果。这是直接的人身伤害证据。 | 2 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QUANGUI; val=2)` |

### 汇总 (权贵)
- 可获得的把柄数: **4**
- 涉及的事件数: **4**
- 总 leverage 值: **6**（分散在 4 个事件中，避免单事件刷满）
- 建议权重: 全部添加到"拒绝/反抗"option（中位选项）或特定的"观察/记录"option

---

## 浊流官员 (TARGET_IDENTITY_ZHUOLIU_OFFICIAL)

### 事件文件: [_kuangke_zhuoliu_events.csv](data/4_eras/747_kuangda/_kuangke_zhuoliu_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 浊流设宴，诗成铁证 | 浊流官员 | 浊流官员在宴上念杜甫的诗"野老墙低还似旧"，停下来笑着问"这墙低，说的是谁家的墙？"手指在"墙低"二字上敲三下。随从把门帘放下来。 | 直接目击浊流官员罗织文字狱的手法——故意曲解诗句、制造政治罪名。知道此人惯于用诗作政治陷害。 | 2 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_ZHUOLIU_OFFICIAL; val=2)` |
| 保释金 | 书吏（浊流体系） | 书吏翻到杜甫名籍时笔停了。"八贯。"拇指在金额上捻了捻。"上面说了，要是你再当堂骂一句，就十二贯。要是写进诗里，再加两贯。"语气像跟一只被栓住的狗报食价。 | 知道浊流体系内部对言论罪有明码标价——骂一句+4贯，写进诗里+2贯。这个定价机制的知情本身就是对体制的把柄。 | 1 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_ZHUOLIU_OFFICIAL; val=1)` |

### 事件文件: [_zhuoliu_fengying_events.csv](data/4_eras/747_kuangda/_zhuoliu_fengying_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 旧账上的墨点 | 张主簿（浊流吏员） | 张主簿推过账册翻到第四页，笔杆点了点数字:"跟第七页对不上吧。"语气像在吩咐知道规矩的人。上次杜甫帮他整理说不清来源的租契时，他用同样的笔杆在同样的位置点了两下。那个墨点还在。 | 知道张主簿经手账目造假，且杜甫曾参与（至少知情）之前的不明来源租契整理。现在他又在暗示杜甫继续配合掩盖。这是财务腐败的直接证据。 | 2 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_ZHUOLIU_OFFICIAL; val=2)` |

### 事件文件: [_zhuoliu_lieqi_events.csv](data/4_eras/747_kuangda/_zhuoliu_lieqi_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 碑记与刀环 | 浊流（两个人） | 年老的那个挡在面前三步处，年轻的站在身后用手指一下一下拨刀环。年老的那个把那个名字放慢了说，像在教孩童认字。从袖中取出空白纸——上方端正压了一方朱砂印。放在膝边冻土上，压了一小块碎银。 | 浊流势力用武力胁迫（刀环声+围堵）和空头支票（空白纸+朱砂印+碎银）逼迫杜甫替人写碑文。知道浊流用暴力手段进行文化敲诈。 | 2 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_ZHUOLIU_OFFICIAL; val=2)` |

### 汇总 (浊流官员)
- 可获得的把柄数: **4**
- 涉及的事件数: **4**
- 总 leverage 值: **7**
- 设计发现: 浊流官员的把柄多集中在"权力滥用"和"财务腐败"两类，与清流官员的"品位歧视"+"学术造假"形成对照

---

## 清流官员/文人 (TARGET_IDENTITY_QINGLIU_OFFICIAL)

### 事件文件: [_qingliu_zuanying_events.csv](data/4_eras/747_kuangda/_qingliu_zuanying_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 席上少了一行姓名 | 清流主人 | 清流主人写信给另一位常客，历数席上"尽皆佳士"列了四人。玩家带了五个人来，被略掉的是商人——他的茧子太厚、端盏时小指翘得过了、对南唐摹本说了"这纸真新"。只有主人皱了一下眉。 | 清流文人圈有严格的隐性阶级门槛——商人因"不够雅"被黜落而不自知。知道清流圈子的排外标准，这可以用于未来评价或对抗清流的伪善面。 | 1 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QINGLIU_OFFICIAL; val=1)` |
| 韵脚撞车 | 某公子/王参军/陈明府 | 坊间传抄某公子的新作，王参军翻出杜甫去年的干谒诗——两首诗的韵脚结构"如出一辙"。陈明府眼睛眯起来，什么也没问，在等。 | 直接涉及清流子弟的学术造假——用杜甫代笔的诗冒充自己的作品。且被王参军发现。这是可以直接毁掉某个清流公子声誉的证据。 | 2 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QINGLIU_OFFICIAL; val=2)` |

> 注意: `qingliu_zuanying` 的其余 4 个事件（锦匣已空、对账单、辨认书风、冬至对账）都是**反向杠杆**——玩家被他人抓住把柄（当掉托管的端砚、粥棚账目差一石六斗、密议中途离席被记住、同一天向多人求助被识破）。这些不产生正向 leverage。

### 事件文件: [_qingliu_fengying_events.csv](data/4_eras/747_kuangda/_qingliu_fengying_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 席间纸笔 | 郑家公子 | 郑家公子摸出叠得齐整的纸铺在湿漉漉的桌面上。"上回那首《秋兴》改得好，家父逢人便夸。"席上无人抬眼——他们都记得上次雅集你替这位公子的诗润色了整整一个时辰。那支笔的笔锋微秃，正是你上次落在郑家的。 | 知道郑家公子长期依赖杜甫代笔，且将代笔之作当作自己的作品炫耀（"家父逢人便夸"）。这是清流子弟学术不端的证据。 | 1 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_QINGLIU_OFFICIAL; val=1)` |

### 汇总 (清流官员)
- 可获得的把柄数: **3**
- 涉及的事件数: **3**
- 总 leverage 值: **4**
- 设计发现: 清流的把柄集中在"品位伪善"和"学术造假"两个主题，与浊流的"暴力+腐败"形成美学上的对立

---

## 商人/摊主/掌柜 (TARGET_IDENTITY_VENDOR)

### 事件文件: [_duotai_humiliation_events.csv](data/4_eras/747_kuangda/_duotai_humiliation_events.csv)

| 事件标题 | 身份角色 | 事件描述摘要 | 暴露的把柄/信息 | leverage 值 | 建议 DSL |
|---------|---------|------------|---------------|------------|---------|
| 三文钱的润笔 | 胡商刘三娘（布庄老板） | 杜甫写了三副对联和四封家书。她摸出三文钱搁在算盘旁的木台上:"活计不错，拿去买饼吃罢。"一只绿头蝇落在铜钱上搓了搓前足。她转身去招呼看绸缎的客人，没有等杜甫回话。 | 了解长安商人如何压榨落魄文人的劳动力——三副对联+四封家书只值三文钱。这更多是社会观察而非具体把柄，但知道一个具体商户的刻薄程度。 | 1 | `flag_int_append(name=flag_gen_leverage_TARGET_IDENTITY_VENDOR; val=1)` |

### 汇总 (商人)
- 可获得的把柄数: **1**
- 涉及的事件数: **1**
- 设计发现: 商人/摊主在事件中更常作为**反向杠杆持有者**出现——他们知道玩家的秘密（`zhuoliu_zuanying` 的"旧衣摊前的账本"、"茶案上的价码"），而非玩家获得他们的把柄

---

## 门子 (TARGET_IDENTITY_MENZI)

### 分析

扫描了 `_duotai_humiliation_events.csv` 中涉及门子的 4+ 个事件（门房冷眼、茶凉诗契、名帖抄录、门内门外、门缝里的纸条等），结论是:

- 门子在所有事件中的行为都是**执行规则**（主人的命令或门房的惯例），不涉及个人秘密
- 门子的势利、看人下菜碟是结构性行为，不是个人污点——暴露这些不会给玩家带来交涉筹码
- 门子没有独立权力，知道门子做了什么无助于影响其背后的主人

**判定: 不产生 leverage。** 跳过。

---

## 清客 (TARGET_IDENTITY_QINGKE)

### 分析

扫描了 `_kuangke_zhuoliu_events.csv` 的"雪阶"和 `_zhuoliu_fengying_events.csv` 的相关事件:

- 清客周七在雪阶上拦杜甫，讽刺"上回不是说不写干谒诗了吗"——这是个人的小肚鸡肠，不构成可用于交涉的把柄
- 清客在"改诗于王府"中替主人划掉杜甫的诗句——这是执行主人意志
- 清客本身是依附权贵的角色，没有独立权力，其个人行为难以转化为杠杆

**判定: 不产生 leverage。** 跳过。

---

## 乞丐/流民 (TARGET_IDENTITY_POOR)

### 分析

扫描了 `_duotai_humiliation_events.csv` 的"半包干粮"和 `_zize_events.csv` 的"坊墙下":

- "半包干粮": 乞丐偷了杜甫的干粮——这是生存行为，不是把柄
- "坊墙下": 冻死的无名尸体——这是社会现实的呈现，不涉及杠杆

穷人的把柄没有价值——他们已经被社会碾压到最底层，知道他们的秘密无法转化为任何形式的交涉筹码。

**判定: 不产生 leverage。** 跳过。

---

## 具名 NPC

### 李白 (TARGET_NPC_LIBAI)

涉及事件: `_kuangke_qingliu_events.csv`（2个）、`_qingliu_passive_benefits_events.csv`（2个）

李白向狂客杜甫暴露的是创作焦虑和不羁，这些是**信任关系的证明**而非**把柄**。kuangke_qingliu 的设计意图是共振而非交易。

**判定: 不产生 leverage。** 跳过。

### 王维 (TARGET_NPC_WANGWEI)

涉及事件: `_kuangke_qingliu_events.csv`（2个）、`_qingliu_passive_benefits_events.csv`（2个）

同上，王维暴露的思念友人和沉默关怀是信任行为。

**判定: 不产生 leverage。** 跳过。

### 郑虔 (TARGET_NPC_ZHENGQIAN)

涉及事件: `_kuangke_qingliu_events.csv`（2个）、`_qingliu_passive_benefits_events.csv`（2个）

郑虔在井台上暴露的职业倦怠和对教育系统的失望——这更接近社会批判而非个人把柄。

**判定: 不产生 leverage。** 跳过。

### 高适 (TARGET_NPC_GAOSHI)

涉及事件: `_kuangke_qingliu_events.csv`（2个）、`_qingliu_passive_benefits_events.csv`（2个）

高适暴露的军旅边缘感和等待的焦虑——同样是信任行为。

**判定: 不产生 leverage。** 跳过。

---

## 总汇总

### 按身份统计

| 身份 | TARGET_TAG | 把柄数 | 总 leverage 值 | 来源文件 |
|------|-----------|--------|---------------|---------|
| 权贵 | `TARGET_IDENTITY_QUANGUI` | 4 | 6 | zhuoliu_lieqi (3), zize (1) |
| 浊流官员 | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` | 4 | 7 | kuangke_zhuoliu (2), zhuoliu_fengying (1), zhuoliu_lieqi (1) |
| 清流官员 | `TARGET_IDENTITY_QINGLIU_OFFICIAL` | 3 | 4 | qingliu_zuanying (2), qingliu_fengying (1) |
| 商人 | `TARGET_IDENTITY_VENDOR` | 1 | 1 | duotai_humiliation (1) |
| 门子 | `TARGET_IDENTITY_MENZI` | 0 | 0 | — |
| 清客 | `TARGET_IDENTITY_QINGKE` | 0 | 0 | — |
| 乞丐/流民 | `TARGET_IDENTITY_POOR` | 0 | 0 | — |
| 李白 | `TARGET_NPC_LIBAI` | 0 | 0 | — |
| 王维 | `TARGET_NPC_WANGWEI` | 0 | 0 | — |
| 郑虔 | `TARGET_NPC_ZHENGQIAN` | 0 | 0 | — |
| 高适 | `TARGET_NPC_GAOSHI` | 0 | 0 | — |

### 全局统计

- **可获得的把柄总数**: 12
- **涉及的事件数**: 12（分布在 6 个 CSV 文件中）
- **涉及的身份数**: 4（权贵、浊流官员、清流官员、商人）
- **总 leverage 值**: 18
- **不产生杠杆的身份**: 7（门子、清客、乞丐/流民 + 4个具名NPC）

### 建议的 option 定位

当前事件中已有三态 option 结构：
- **option1** (拒绝/反抗): `flag_int_append(name=kuangda; val=3)` — 建议**同时追加** leverage DSL
- **option2** (屈从/投靠): `flag_int_append(name=kuangda; val=-2)` 或 `val=1` — 不建议追加 leverage（屈从者不记录把柄）
- **option3** (中间/观察): 部分事件有第三选项 — 建议在此追加 leverage

**设计原则**: leverage 应加在玩家**选择不合作但仍保持观察**的 option 上——因为这暗示玩家虽然不正面冲突，但默默记下了对方的污点。反抗option也可以加（当场看清了对方嘴脸），但屈从option不加（屈从者在道德上没有记录他人把柄的立场）。

---

## 重要的设计发现

### 1. 反向杠杆事件库

`_zhuoliu_zuanying_events.csv` 和 `_qingliu_zuanying_events.csv` 中约一半的事件是**反向杠杆**——玩家被他人抓住把柄。这些事件在当前 DSL 中没有对应的 `flag_gen_leverage` 记录（因为 leverage 系统目前只设计给玩家持有），但它们是未来"被敲诈"系统的重要素材。

反向杠杆事件清单：
- `zhuoliu_zuanying_poverty_persona`: 摊主老周知道玩家替人写密信
- `zhuoliu_zuanying_intelligence_commodity`: 绸缎商知道玩家替盐商"问"过事
- `qingliu_zuanying_double_agent_slip`: 密议中离席被记住
- `qingliu_zuanying_triple_dipped_suffering`: 同一天向多人求助被揭穿
- `qingliu_zuanying_skimmed_charity`: 粥棚账目被赵崇嗣发现差了一石六斗
- `qingliu_zuanying_pawned_artifact`: 当掉李十二娘托管的端砚

建议未来设计 `flag_gen_exposed_TARGET_TAG` 或类似的"被掌握把柄"标记系统。

### 2. 浊流 vs 清流的把柄类型对立

- **浊流把柄**: 权力滥用（暴力、贪腐、文字狱）→ 政治性把柄，可用于官场博弈
- **清流把柄**: 品位伪善（阶级歧视）+ 学术造假（代笔）→ 道德性把柄，可用于舆论博弈

这个对立设计精巧，建议在后续 game design 中保持和强化。

### 3. 权贵把柄集中在 zhuoliu_lieqi

`_zhuoliu_lieqi_events.csv` 5 个事件中有 3 个产生权贵把柄（斗鸡坊、泔水赌局、纸灰未冷），1 个产生浊流官员把柄（碑记与刀环）。这个事件库被设计为"猎奇"——浊流对狂客的异化消费——天然就是杠杆的富矿。

### 4. 缺少 leverage 的身份

门子、清客因权力依附性不产生杠杆是合理的。乞丐/流民不产生杠杆也是合理的（他们没有社会资本可供威胁）。

但**县尉/官府吏员** (`TARGET_IDENTITY_COUNTY_SHERIFF`) 在当前事件库中几乎没有出现——只有一个登高事件中的"张郎"（银冠年轻官员），而且他只是在城楼摆席，没有暴露可杠杆的信息。这可能是未来事件库扩展的方向。

### 5. kuangke 事件库的杠杆豁免

`_kuangke_qingliu_events.csv` 和 `_kuangke_zhuoliu_events.csv` 中的 kuangke 路线，前者的交互是信任和共振，后者的交互是浊流对狂客的单向压迫。建议 kuangke_qingliu 永远不产生杠杆（保持其纯粹性），而 kuangke_zhuoliu 可以产生杠杆（因为浊流对狂客的压迫是单向的、不值得尊重的）。

---

## 附录: 扫描文件列表

### CSV 文件 (13个)
1. `data/4_eras/747_kuangda/_duotai_humiliation_events.csv` (27 events)
2. `data/4_eras/747_kuangda/_kuangke_qingliu_events.csv` (8 events)
3. `data/4_eras/747_kuangda/_kuangke_zhuoliu_events.csv` (6 events)
4. `data/4_eras/747_kuangda/_qingliu_daoxin_posui_events.csv` (10 events)
5. `data/4_eras/747_kuangda/_qingliu_fengying_events.csv` (6 events)
6. `data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv` (4 events)
7. `data/4_eras/747_kuangda/_qingliu_passive_benefits_events.csv` (8 events)
8. `data/4_eras/747_kuangda/_qingliu_zuanying_events.csv` (6 events)
9. `data/4_eras/747_kuangda/_zhuoliu_fengying_events.csv` (6 events)
10. `data/4_eras/747_kuangda/_zhuoliu_lieqi_events.csv` (5 events)
11. `data/4_eras/747_kuangda/_zhuoliu_zuanying_events.csv` (6 events)
12. `data/4_eras/747_kuangda/_zize_events.csv` (6 events)
13. `data/4_eras/747_kuangda/denggao/_747kuangda_denggao_events.csv` (18 events)

### Config JSON 文件 (12个，均无 dimensions 字段)
所有 Config JSON 的 `dimensions.values` 为空数组或不含 dimensions 字段。身份角色需从事件描述文本中推断。
