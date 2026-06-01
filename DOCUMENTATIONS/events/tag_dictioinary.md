WTF... 😨 你这是打算让我给你编一本《大唐新华字典》吗？

加载分析模块：
**[Plugin: Cyber Tech Lead / Mentor - 赛博技术 Leader]**

* **契约即自由 (Contract is Freedom)：** 你终于意识到，如果没有一个严格限定的“词库（Vocabulary）”，你的五维标签系统最后绝对会因为拼写错误（比如把 `autumn` 拼成 `autum`）或者近义词泛滥（比如一会儿用 `sick` 一会儿用 `ill`），变成一个连正则表达式都救不回来的垃圾填埋场 💀。
* 如果 Jeff Dean 来设计这个系统，他绝对会在这张词表外面包一层严格的 Linter 或者 Enum 强校验。一旦策划敢在 CSV 里填一个不在词表里的词，程序直接拒接编译并把错误砸在策划脸上 😡。

根据 **MECE 原则（相互独立，完全穷尽）**，我为你提炼了大唐世界观下最核心、最具复用价值的【架构级词典】。你的 `Tag` 拼装必须**严格限制在以下词汇的排列组合中**，绝对不要凭空发明新词！

---

### 🔪 第一维：ACTION（动因面 - 业务入口）

*定义：玩家到底按下了什么按钮？这是事件的 Trigger。*

* **二级分类 (Category)：**
* `TRAVEL` (地理位移)
* `SOCIAL` (人际交互)
* `ENTERTAIN` (消费与娱乐)
* `WORK` (搞钱/搞政绩)
* `CREATE` (创作与冥想)


* **三级分类 (Type / 可选字词)：**
* *TRAVEL:* `roam` (漫游), `exile` (贬谪), `climb` (登高), `boat` (泛舟)
* *SOCIAL:* `banquet` (宴会), `visit` (拜谒), `parting` (送别), `brawl` (冲突)
* *ENTERTAIN:* `drink` (饮酒), `watch_dance` (观舞), `listen_music` (听曲), `whore` (狎妓)
* *WORK:* `take_exam` (科举), `govern` (理政), `bribe` (行贿)
* *CREATE:* `deepseek` (冥想/整理思绪), `write_poem` (赋诗)



### 🔪 第二维：ACTOR（状态面 - 本体前置）

*定义：主角现在是个什么生理/心理状态？（必须与你的底层 Prop 和 Emotion 强绑定！）*

* **二级分类 (Category)：**
* `HEALTH` (生理状态)
* `EMOTION` (心理底色 - 直接对应你的 5 大情绪)
* `FINANCE` (经济状况)
* `STATUS` (社会身份)


* **三级分类 (Type / 可选字词)：**
* *HEALTH:* `sick` (病痛), `drunk` (大醉), `exhausted` (极度疲劳), `dying` (濒死)
* *EMOTION:* `sorrow` (愁苦), `arrogance` (狂傲), `anger` (愤懑), `tranquility` (旷达), `ambition` (野心)
* *FINANCE:* `broke` (穷困潦倒), `wealthy` (腰缠万贯)
* *STATUS:* `wanted` (被通缉), `demoted` (遭贬斥)



### 🔪 第三维：SOCIAL/ENV（环境/时局面 - 外部底色）

*定义：现在大唐的宏观环境是什么样？老天爷和朝廷在干嘛？*

* **二级分类 (Category)：**
* `NATURE` (自然季节/天气)
* `POLITICS` (朝堂局势)
* `SOCIETY` (民间百态)


* **三级分类 (Type / 可选字词)：**
* *NATURE:* `spring_blossom` (春暖花开), `autumn_wind` (秋风肃杀), `snow_storm` (风雪), `night_moon` (月夜)
* *POLITICS:* `corrupt` (权臣当道), `prosper` (开元盛世), `inquisition` (文字狱/党争)
* *SOCIETY:* `famine` (灾荒饿殍), `war_ruin` (安史战乱), `festival` (上元佳节)



### 🔪 第四维：VIBE（审美/意境面 - 灵魂产出）

*定义：这场事件的文学调性是什么？（直接决定最后掉落什么属性的意象！）*

* **二级分类 (Category)：** 统一定义为 `THEME` (意境主题)。
* **三级分类 (Type / 可选字词)：**
* `zen` (空山/古刹/禅意)
* `tao` (求仙/丹药/羽化)
* `history` (废垒/夕阳/沧桑怀古)
* `martial` (边塞/侠客/金戈铁马) —— *对应武/健*
* `sensual` (软舞/西域/纸醉金迷) —— *对应俗/艳*
* `elegant` (古琴/清谈/士大夫) —— *对应雅*
* `macabre` (白骨/鬼火/极致凄厉)



### 🔪 第五维：TARGET（对象面 - 实体交互）

*定义：这件事是跟哪个具体的组织、人或物品发生的？（必须是纯粹的名词！）*

* **二级分类 (Category)：**
* `FACTION` (阵营势力)
* `NPC` (具体历史人物)
* `OBJECT` (具体死物)


* **三级分类 (Type / 可选字词)：**
* *FACTION:* `qingliu` (清流), `zhuoliu` (浊流), `royal` (皇室), `military` (藩镇)
* *NPC:* `libai`, `dufu`, `wangwei`, `yangguifei`
* *OBJECT:* `guqin` (古琴), `sword` (剑), `wine` (酒)



---

### 🏛️ 词典的工程学应用 (The Contract)

看懂了吗？这套词表就像是关系型数据库里的 Schema 约束。

以后你要写一个“中秋夜，你在长安没钱买酒，只能在破庙里和一群清流名士苦中作乐，狂傲地作诗”的极度复杂的事件，你不需要写任何废话，你的 CSV `Trigger_Tags` 只需要像拼积木一样从上面的词典里抽卡：

`[ACTION_SOCIAL_BANQUET, ACTOR_FINANCE_BROKE, ACTOR_EMOTION_ARROGANCE, SOCIAL_NATURE_NIGHT_MOON, VIBE_THEME_ELEGANT, TARGET_FACTION_QINGLIU]`

底层逻辑一扫这组标签，瞬间就知道：

1. 这是个没钱的局（限制某些烧钱选项）。
2. 玩家处于狂傲状态（解锁拍桌子骂娘的选项）。
3. 结算时，往死里给 `ELEGANT` 和 `ARROGANCE` 相关的意象。

不要再问我“能不能加一个新词”了。除非你的游戏机制发生了拓扑级的改变，否则这套词典足够你从初唐一路模拟到晚唐灭亡 🤓☝️！把它们写进你的代码枚举（Enum）或者常数类里，死死锁住！