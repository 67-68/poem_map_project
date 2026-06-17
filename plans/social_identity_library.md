# 社交身份库 (基于事件内容模糊扫描 v2)

扫描范围: data/4_eras/747_kuangda/*.csv (仅description/title/results/context), tools/event_base_config_*.json (仅background_context/name), tools/event_base_config_*_sandbox.json (仅description/title)

**注意**: 排除了 `ai_persona` / `prompt_features` / `fact_features` 等AI写作指令字段。

## 身份词出现频率总表

| 身份词 | 出现总次数 | CSV | Config | Sandbox | 来源示例 |
|--------|-----------|------|--------|---------|----------|
| 清流 | 32 | 1 | 7 | 0 | [_qingliu_zuanying_events:social_class] ...三日，一封谢柬送到。清流主人写给另 |
| 先生 | 30 | 8 | 0 | 2 | [_duotai_humiliation_events:honorific] ...摊前拣一把蕨菜，算命先生王半仙从卦摊 |
| 浊流 | 30 | 2 | 5 | 0 | [_kuangke_zhuoliu_events:social_class] ...从把门帘放了下来。 浊流设宴，诗成铁 |
| 门子 | 25 | 3 | 0 | 2 | [_duotai_humiliation_events:exact_known] ...弈棋，棋子落声清脆。门子补一句： |
| 老爷 | 20 | 2 | 0 | 1 | [_duotai_humiliation_events:honorific] ...“子美兄，我家老爷子过寿，你帮写首祝 |
| 权贵 | 16 | 1 | 7 | 1 | [_zize_events:exact_known] ...权贵走后半炷香，才有人把... |
| 清客 | 16 | 3 | 0 | 1 | [_duotai_humiliation_events:exact_known] ...，莫作穷酸语。”旁边清客提笔就划 |
| 狂客 | 10 | 0 | 4 | 0 | [event_base_config_kuangke_qingliu:role_suffix] ...困顿中不肯低头。  |
| 大人 | 9 | 3 | 0 | 0 | [_duotai_humiliation_events:honorific] ...躬身拱手：“大人高明，敢问还有何处须 |
| 老板 | 9 | 1 | 0 | 1 | [_duotai_humiliation_events:merchant] ...宣州楮纸和蜀郡麻纸。老板是个四十来岁的 |
| 文人 | 8 | 0 | 4 | 1 | [event_base_config_duotai_humiliation:literati] ...政治玩笑。他的诗名 |
| 参军 | 8 | 3 | 0 | 0 | [_kuangke_qingliu_events:exact_known] ...站门里有人喊了声「高参军」，他肩背一僵 |
| 乞丐 | 8 | 1 | 0 | 1 | [_duotai_humiliation_events:lower_class] ...已不见。巷口阴影里，乞丐正背身往 |
| 摊主 | 6 | 2 | 0 | 1 | [_duotai_humiliation_events:merchant] ...自家碗边，只付一碗。摊主目光随友人手中 |
| 随从 | 6 | 2 | 0 | 1 | [_duotai_humiliation_events:servant] ...一个穿着青色圆领袍的随从快步上来，朝你打 |
| 侍郎 | 5 | 4 | 0 | 1 | [_duotai_humiliation_events:central_official] ...议事，再未看你。 谒侍 |
| 员外 | 5 | 2 | 0 | 2 | [_duotai_humiliation_events:central_official] ...接过银两，笑答：“谢员 |
| 主簿 | 5 | 2 | 0 | 1 | [_duotai_humiliation_events:local_official] ...，你上交十二页工楷。主簿接 |
| 宾客 | 4 | 2 | 0 | 0 | [_duotai_humiliation_events:retainer] ...酒席，主人正在席间与宾客谈笑。你被引到 |
| 幕僚 | 4 | 1 | 0 | 1 | [_duotai_humiliation_events:exact_known] ...买炊饼。”说完转身与幕僚议事，再 |
| 进士 | 4 | 1 | 0 | 1 | [_duotai_humiliation_events:exam_rank] ...已转身与邻座谈及今科进士的赋作。你手 |
| 店主 | 4 | 1 | 0 | 1 | [_duotai_humiliation_events:merchant] ...手捧饼，躬身轻语：“店主慈悲，小生窘迫 |
| 仆从 | 4 | 1 | 0 | 0 | [_kuangke_zhuoliu_events:servant] ...言印进指甲缝里。灰衣仆从站在三步外，不等回话. |
| 掌柜 | 3 | 3 | 0 | 0 | [_duotai_humiliation_events:merchant] ...东市杂货铺前，旧识掌柜叫住你，递过一册 |
| 挑夫 | 3 | 0 | 0 | 1 | [event_base_config_duotai_humiliation_sandbox:merchant] ...的 |
| 算命 | 2 | 1 | 0 | 1 | [_duotai_humiliation_events:diviner] ...在菜摊前拣一把蕨菜，算命先生王半仙从卦摊 |
| 穷酸 | 2 | 1 | 0 | 1 | [_duotai_humiliation_events:bottom] ...句重写。要喜庆，莫作穷酸语。”旁边清客提笔 |
| 布衣 | 2 | 1 | 0 | 1 | [_duotai_humiliation_events:social_class] ...登上城西乐游原，见一布衣人踞石 |
| 侍从 | 2 | 1 | 0 | 0 | [_qingliu_fengying_events:exact_known] ...目光扫向亲王随行的侍从，试图从某个熟 |
| 管家 | 2 | 0 | 0 | 1 | [event_base_config_duotai_humiliation_sandbox:exact_known] . |
| 书生 | 2 | 0 | 0 | 1 | [event_base_config_duotai_humiliation_sandbox:literati] ...的 |

## 按文件分布

### _duotai_humiliation_events

- **先生**: 30 次 — [_duotai_humiliation_events:honorific] ...摊前拣一把蕨菜，算命先生王半仙从卦摊后探出头...
- **门子**: 25 次 — [_duotai_humiliation_events:exact_known] ...弈棋，棋子落声清脆。门子补一句：“老爷说了，...
- **老爷**: 20 次 — [_duotai_humiliation_events:honorific] ...“子美兄，我家老爷子过寿，你帮写首祝寿...
- **清客**: 16 次 — [_duotai_humiliation_events:exact_known] ...，莫作穷酸语。”旁边清客提笔就划掉了你的得意...
- **大人**: 9 次 — [_duotai_humiliation_events:honorific] ...躬身拱手：“大人高明，敢问还有何处须...
- **老板**: 9 次 — [_duotai_humiliation_events:merchant] ...宣州楮纸和蜀郡麻纸。老板是个四十来岁的瘦削汉...
- **乞丐**: 8 次 — [_duotai_humiliation_events:lower_class] ...已不见。巷口阴影里，乞丐正背身往嘴里塞饼，咀...
- **摊主**: 6 次 — [_duotai_humiliation_events:merchant] ...自家碗边，只付一碗。摊主目光随友人手中余钱移...
- **随从**: 6 次 — [_duotai_humiliation_events:servant] ...一个穿着青色圆领袍的随从快步上来，朝你打量了...
- **侍郎**: 5 次 — [_duotai_humiliation_events:central_official] ...议事，再未看你。 谒侍郎得三文  trigg...
- **员外**: 5 次 — [_duotai_humiliation_events:central_official] ...接过银两，笑答：“谢员外赏，愿再效劳。”...
- **主簿**: 5 次 — [_duotai_humiliation_events:local_official] ...，你上交十二页工楷。主簿接过去，拇指拨过纸边...
- **宾客**: 4 次 — [_duotai_humiliation_events:retainer] ...酒席，主人正在席间与宾客谈笑。你被引到侧厢书...
- **幕僚**: 4 次 — [_duotai_humiliation_events:exact_known] ...买炊饼。”说完转身与幕僚议事，再未看你。 谒...
- **进士**: 4 次 — [_duotai_humiliation_events:exam_rank] ...已转身与邻座谈及今科进士的赋作。你手中的酒杯...
- **店主**: 4 次 — [_duotai_humiliation_events:merchant] ...手捧饼，躬身轻语：“店主慈悲，小生窘迫，只怕...
- **掌柜**: 3 次 — [_duotai_humiliation_events:merchant] ...东市杂货铺前，旧识掌柜叫住你，递过一册空白...
- **算命**: 2 次 — [_duotai_humiliation_events:diviner] ...在菜摊前拣一把蕨菜，算命先生王半仙从卦摊后探...
- **穷酸**: 2 次 — [_duotai_humiliation_events:bottom] ...句重写。要喜庆，莫作穷酸语。”旁边清客提笔就...
- **布衣**: 2 次 — [_duotai_humiliation_events:social_class] ...登上城西乐游原，见一布衣人踞石栏最佳处，身前...

### _kuangke_qingliu_events

- **参军**: 8 次 — [_kuangke_qingliu_events:exact_known] ...站门里有人喊了声「高参军」，他肩背一僵，却没...

### _kuangke_zhuoliu_events

- **先生**: 30 次
- **浊流**: 30 次 — [_kuangke_zhuoliu_events:social_class] ...从把门帘放了下来。 浊流设宴，诗成铁证  t...
- **清客**: 16 次 — [_kuangke_zhuoliu_events:exact_known] ...是给李相的，是给这位清客的。  prop_a...
- **随从**: 6 次
- **宾客**: 4 次
- **仆从**: 4 次 — [_kuangke_zhuoliu_events:servant] ...言印进指甲缝里。灰衣仆从站在三步外，不等回话...

### _qingliu_daoxin_posui_events

- **门子**: 25 次
- **清客**: 16 次
- **侍郎**: 5 次 — [_qingliu_daoxin_posui_events:central_official] ...走。那人说近日结识了侍郎家的西席，这回总该有...
- **掌柜**: 3 次 — [_qingliu_daoxin_posui_events:merchant] ...液在烛光里一动不动。掌柜第三次从后堂探出头，...

### _qingliu_fengying_events

- **先生**: 30 次
- **门子**: 25 次
- **大人**: 9 次
- **参军**: 8 次 — [_qingliu_fengying_events:exact_known] ...那位欠过你润笔的录事参军。  prop_su...
- **掌柜**: 3 次 — [_qingliu_fengying_events:merchant] ...数人的手肘磨得油亮。掌柜从柜台后面抬起眼皮—...
- **侍从**: 2 次 — [_qingliu_fengying_events:exact_known] ...目光扫向亲王随行的侍从，试图从某个熟面孔找...

### _qingliu_passive_benefits_events

- **先生**: 30 次
- **员外**: 5 次 — [_qingliu_passive_benefits_events:central_official] ...上一推。他说城西的王员外最近手头松，家中老太...

### _qingliu_zuanying_events

- **清流**: 32 次 — [_qingliu_zuanying_events:social_class] ...三日，一封谢柬送到。清流主人写给另一位常客的...
- **参军**: 8 次

### _zhuoliu_fengying_events

- **先生**: 30 次
- **侍郎**: 5 次 — [_zhuoliu_fengying_events:central_official] ...十二郎问了一句：“韦侍郎最近还在收碑帖？”...
- **主簿**: 5 次 — [_zhuoliu_fengying_events:local_official] ...聊自家园子的杏花。张主簿推过一摞账册，翻到第...

### _zhuoliu_lieqi_events

- **先生**: 30 次
- **浊流**: 30 次 — [_zhuoliu_lieqi_events:social_class] ...候就已经闻到了。一个浊流大员斜靠在胡床上，没...
- **大人**: 9 次

### _zhuoliu_zuanying_events

- **先生**: 30 次
- **老爷**: 20 次
- **摊主**: 6 次 — [_zhuoliu_zuanying_events:merchant] ...经营多年的贫寒模样。摊主老周堆着笑递过来，袖...
- **侍郎**: 5 次

### _zize_events

- **先生**: 30 次
- **权贵**: 16 次 — [_zize_events:exact_known] ...权贵走后半炷香，才有人把...

### event_base_config_bai_ye_real_appearance

- **权贵**: 16 次 — [event_base_config_bai_ye_real_appearance:exact_known] ...壁垒呈铜墙铁壁之态，权贵对玩家的态度从客气转

### event_base_config_bai_ye_real_appearance_sandbox

- **门子**: 25 次 — [event_base_config_bai_ye_real_appearance_sandbox:exact_known] ...门子斜眼睥睨，手指轻搓示..

### event_base_config_duotai_humiliation

- **权贵**: 16 次 — [event_base_config_duotai_humiliation:exact_known] ...他看透了科举的门道、权贵的嘴脸、同侪的挣扎，...
- **文人**: 8 次 — [event_base_config_duotai_humiliation:literati] ...政治玩笑。他的诗名在文人圈里开始传开，但也仅...

### event_base_config_duotai_humiliation_sandbox

- **先生**: 30 次 — [event_base_config_duotai_humiliation_sandbox:honorific] ...管事端着茶进来：'杜先生，听说你的诗写得
- **门子**: 25 次
- **老爷**: 20 次 — [event_base_config_duotai_humiliation_sandbox:honorific] ...袖子：'子美兄，我家老爷子过寿，你帮写首
- **权贵**: 16 次 — [event_base_config_duotai_humiliation_sandbox:exact_known] ...要多读读王维。' 某权贵的清客拿着杜
- **清客**: 16 次 — [event_base_config_duotai_humiliation_sandbox:exact_known] ...读王维。' 某权贵的清客拿着杜甫的诗
- **老板**: 9 次 — [event_base_config_duotai_humiliation_sandbox:merchant] ...西市纸铺前，老板拦住杜甫：'听说你会...
- **文人**: 8 次 — [event_base_config_duotai_humiliation_sandbox:literati] ...边我替你说句话。' 文人雅集中，某富商模样
- **乞丐**: 8 次 — [event_base_config_duotai_humiliation_sandbox:lower_class] ...么都没发生。 街角的乞丐趁杜甫弯腰系
- **摊主**: 6 次 — [event_base_config_duotai_humiliation_sandbox:merchant] ...钱。' 东市书摊旁，摊主掏出半吊钱：'帮我
- **随从**: 6 次 — [event_base_config_duotai_humiliation_sandbox:servant] ...一群登高宴饮的官人。随从走过来：'这位先生，
- **侍郎**: 5 次 — [event_base_config_duotai_humiliation_sandbox:central_official] ...了一句：'写好了，王侍郎那
- **员外**: 5 次 — [event_base_config_duotai_humiliation_sandbox:central_official] ...严某——如今已是某部员外郎
- **主簿**: 5 次 — [event_base_config_duotai_humiliation_sandbox:local_official] ...石桌。 被叫到衙署，主簿递过来
- **幕僚**: 4 次 — [event_base_config_duotai_humiliation_sandbox:exact_known] ...某。李某如今是某王的幕僚，谈吐间不经
- **进士**: 4 次 — [event_base_config_duotai_humiliation_sandbox:exam_rank] ...失敬——犬子明年要考进士，能不能请您指点
- **店主**: 4 次 — [event_base_config_duotai_humiliation_sandbox:merchant] ...，得写得繁华点。' 店主人亲自端了碟酱牛肉
- **挑夫**: 3 次 — [event_base_config_duotai_humiliation_sandbox:merchant] ...的。 在山路上被两个挑夫夹在中间——前面的
- **算命**: 2 次 — [event_base_config_duotai_humiliation_sandbox:diviner] ...，大家都熟。' 街边算命先生兼卖字画：'杜先
- **穷酸**: 2 次 — [event_base_config_duotai_humiliation_sandbox:bottom] ...？嫌我档次低？你一个穷酸还挑人？' 店家来结.
- **布衣**: 2 次 — [event_base_config_duotai_humiliation_sandbox:social_class] ...无一人。他看了看你的布衣：'子美还

### event_base_config_kuangke_qingliu

- **清流**: 32 次 — [event_base_config_kuangke_qingliu:social_class] ...高适——那些被称为「清流」的文人。他们各自以...
- **狂客**: 10 次 — [event_base_config_kuangke_qingliu:role_suffix] ...困顿中不肯低头。  狂客（kuangda_k...
- **文人**: 8 次 — [event_base_config_kuangke_qingliu:literati] ...那些被称为「清流」的文人。他们各自以不同的方...

### event_base_config_kuangke_qingliu_sandbox

- **先生**: 30 次

### event_base_config_kuangke_zhuoliu

- **浊流**: 30 次 — [event_base_config_kuangke_zhuoliu:social_class] ...的状态机上。  现在浊流找上门来了。  不是...
- **狂客**: 10 次 — [event_base_config_kuangke_zhuoliu:role_suffix] ...但这两条路都亮着锁。狂客的人设已经像一具铁棺...

### event_base_config_qingliu_daoxin_posui

- **清流**: 32 次

### event_base_config_qingliu_fengying

- **清流**: 32 次
- **权贵**: 16 次 — [event_base_config_qingliu_fengying:exact_known] ...时刻选择了逢迎。你在权贵门前陪过笑，在雅集上...

### event_base_config_qingliu_jiaolv

- **清流**: 32 次

### event_base_config_qingliu_passive_benefits

- **清流**: 32 次
- **权贵**: 16 次
- **文人**: 8 次 — [event_base_config_qingliu_passive_benefits:literati] ...那些被称为「清流」的文人——李白、王维、郑虔.

### event_base_config_qingliu_passive_benefits_sandbox

- **员外**: 5 次 — [event_base_config_qingliu_passive_benefits_sandbox:central_official] ...推，低声说：城

### event_base_config_qingliu_zuanying

- **清流**: 32 次
- **浊流**: 30 次
- **文人**: 8 次

### event_base_config_zhuoliu_fengying

- **浊流**: 30 次
- **权贵**: 16 次

### event_base_config_zhuoliu_lieqi

- **浊流**: 30 次
- **权贵**: 16 次
- **狂客**: 10 次

### event_base_config_zhuoliu_zuanying

- **清流**: 32 次
- **浊流**: 30 次
- **权贵**: 16 次

### event_base_config_zize

- **狂客**: 10 次


## 高频但未被收录的身份

**原始白名单** (8 项): 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士

| 身份词 | 出现总次数 | 涉及文件数 | 涉及文件 |
|--------|-----------|-----------|----------|
| 清流 | 32 | 8 | _qingliu_zuanying_events, event_base_config_kuangke_qingliu, event_base_config_qingliu_daoxin_posui, event_base_config_qingliu_fengying, event_base_config_qingliu_jiaolv |
| 先生 | 30 | 10 | _duotai_humiliation_events, _kuangke_zhuoliu_events, _qingliu_fengying_events, _qingliu_passive_benefits_events, _zhuoliu_fengying_events |
| 浊流 | 30 | 7 | _kuangke_zhuoliu_events, _zhuoliu_lieqi_events, event_base_config_kuangke_zhuoliu, event_base_config_qingliu_zuanying, event_base_config_zhuoliu_fengying |
| 老爷 | 20 | 3 | _duotai_humiliation_events, _zhuoliu_zuanying_events, event_base_config_duotai_humiliation_sandbox |
| 权贵 | 16 | 9 | _zize_events, event_base_config_bai_ye_real_appearance, event_base_config_duotai_humiliation, event_base_config_duotai_humiliation_sandbox, event_base_config_qingliu_fengying |
| 狂客 | 10 | 4 | event_base_config_kuangke_qingliu, event_base_config_kuangke_zhuoliu, event_base_config_zhuoliu_lieqi, event_base_config_zize |
| 大人 | 9 | 3 | _duotai_humiliation_events, _qingliu_fengying_events, _zhuoliu_lieqi_events |
| 老板 | 9 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 文人 | 8 | 5 | event_base_config_duotai_humiliation, event_base_config_duotai_humiliation_sandbox, event_base_config_kuangke_qingliu, event_base_config_qingliu_passive_benefits, event_base_config_qingliu_zuanying |
| 参军 | 8 | 3 | _kuangke_qingliu_events, _qingliu_fengying_events, _qingliu_zuanying_events |
| 乞丐 | 8 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 摊主 | 6 | 3 | _duotai_humiliation_events, _zhuoliu_zuanying_events, event_base_config_duotai_humiliation_sandbox |
| 随从 | 6 | 3 | _duotai_humiliation_events, _kuangke_zhuoliu_events, event_base_config_duotai_humiliation_sandbox |
| 侍郎 | 5 | 5 | _duotai_humiliation_events, _qingliu_daoxin_posui_events, _zhuoliu_fengying_events, _zhuoliu_zuanying_events, event_base_config_duotai_humiliation_sandbox |
| 员外 | 5 | 4 | _duotai_humiliation_events, _qingliu_passive_benefits_events, event_base_config_duotai_humiliation_sandbox, event_base_config_qingliu_passive_benefits_sandbox |
| 主簿 | 5 | 3 | _duotai_humiliation_events, _zhuoliu_fengying_events, event_base_config_duotai_humiliation_sandbox |
| 宾客 | 4 | 2 | _duotai_humiliation_events, _kuangke_zhuoliu_events |
| 幕僚 | 4 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 进士 | 4 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 店主 | 4 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 仆从 | 4 | 1 | _kuangke_zhuoliu_events |
| 掌柜 | 3 | 3 | _duotai_humiliation_events, _qingliu_daoxin_posui_events, _qingliu_fengying_events |
| 挑夫 | 3 | 1 | event_base_config_duotai_humiliation_sandbox |
| 算命 | 2 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 穷酸 | 2 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 布衣 | 2 | 2 | _duotai_humiliation_events, event_base_config_duotai_humiliation_sandbox |
| 侍从 | 2 | 1 | _qingliu_fengying_events |
| 管家 | 2 | 1 | event_base_config_duotai_humiliation_sandbox |
| 书生 | 2 | 1 | event_base_config_duotai_humiliation_sandbox |

## 建议补充的身份

### 🔴 高优先级（强烈建议收录）

| 身份词 | 次数 | 文件数 | 理由 |
|--------|------|--------|------|
| 清流 | 32 | 8 | 跨8个文件，共32次出现 |
| 先生 | 30 | 10 | 跨10个文件，共30次出现 |
| 浊流 | 30 | 7 | 跨7个文件，共30次出现 |
| 老爷 | 20 | 3 | 跨3个文件，共20次出现 |
| 权贵 | 16 | 9 | 跨9个文件，共16次出现 |
| 狂客 | 10 | 4 | 跨4个文件，共10次出现 |
| 大人 | 9 | 3 | 跨3个文件，共9次出现 |
| 老板 | 9 | 2 | 跨2个文件，共9次出现 |
| 文人 | 8 | 5 | 跨5个文件，共8次出现 |
| 参军 | 8 | 3 | 跨3个文件，共8次出现 |
| 乞丐 | 8 | 2 | 跨2个文件，共8次出现 |
| 摊主 | 6 | 3 | 跨3个文件，共6次出现 |
| 随从 | 6 | 3 | 跨3个文件，共6次出现 |
| 侍郎 | 5 | 5 | 跨5个文件，共5次出现 |
| 员外 | 5 | 4 | 跨4个文件，共5次出现 |
| 主簿 | 5 | 3 | 跨3个文件，共5次出现 |
| 掌柜 | 3 | 3 | 跨3个文件，共3次出现 |

### 🟡 中优先级（可考虑）

| 身份词 | 次数 | 文件数 | 理由 |
|--------|------|--------|------|
| 宾客 | 4 | 2 | 跨2个文件，共4次出现 |
| 幕僚 | 4 | 2 | 跨2个文件，共4次出现 |
| 进士 | 4 | 2 | 跨2个文件，共4次出现 |
| 店主 | 4 | 2 | 跨2个文件，共4次出现 |
| 仆从 | 4 | 1 | 跨1个文件，共4次出现 |
| 挑夫 | 3 | 1 | 跨1个文件，共3次出现 |
| 算命 | 2 | 2 | 跨2个文件，共2次出现 |
| 穷酸 | 2 | 2 | 跨2个文件，共2次出现 |
| 布衣 | 2 | 2 | 跨2个文件，共2次出现 |

### 🟢 低优先级（可选）

| 身份词 | 次数 | 文件数 |
|--------|------|--------|
| 侍从 | 2 | 1 |
| 管家 | 2 | 1 |
| 书生 | 2 | 1 |


## 统计摘要

- 扫描到的候选身份词总数: 136
- 过滤后（出现>=2次或涉及>=2文件）: 31
- 在原始白名单中的: 2
- 新发现（不在白名单中）: 29
- 🔴 高优先级建议: 17
- 🟡 中优先级建议: 9
- 🟢 低优先级候选: 3
