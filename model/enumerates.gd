@tool
extends Node
const _Era = preload("res://core/model/era.gd")
const _NarrativeOverlay = preload("res://characters/narrative_overlay.gd")
const _SceneAction = preload("res://core/model/scene_action.gd")
enum AREA_TAGS { # 包括地区特性和地区本身?
    AREA_HORSE_WEALTH,
    AREA_EXCESSIVE_OFFICIAL,
}

enum ACTION_TAGS { 
    # 删除所有的四段 tag，使用 24 个占位符号
    AB, AC, AD, AE, AF, AG, AH, AI, AJ, AK, AL, ALTJ,
    BA, BB, BC, BD, BE, BF, BG, BH, BI, BJ, BK, BL,

    # 死亡
    ACTOR_HEALTH_DEATH_GENERAL,

    # 灵感特殊行动
    ACTION_SPECIAL_DEEPSEEK_GENERAL, # organize thuought

    A,B,C,

    # 3 段式枚举值（用于 bucket 路由和数据层，不含 :general 后缀）
    # 放在末尾避免移位破坏已有 .tres 文件中的整数值
    ACTION_MAIN_BAIYE,
    ACTION_MAIN_JIAOYOU,
    ACTION_MAIN_DENGGAO,
    ACTION_MAIN_FANGSHI,
    ACTION_MAIN_FENGZHAO,
    ACTION_MAIN_DUZHUO,
    ACTION_SPECIAL_DEEPSEEK,
    ACTION_SPECIAL_GANLU,

    ACTION_FANGSHI_BANZHUAN,
    ACTION_FANGSHI_SHIYAO, # 试药
    ACTION_FANGSHI_MAIZI,
    ACTION_FANGSHI_FGMAIZI, # 风骨卖字

    ACTION_DENGGAO_QUJIANGCHI, # 曲江池
    ACTION_DENGGAO_LEYOUYUAN, # 乐游原
    ACTION_DENGGAO_SHAOLINGYUAN, # 少陵原
    
    ACTION_DUZHUO_HEYAOJIU, # 喝药酒
    ACTION_DUZHUO_XIAOZHUO, # 小酌一口

    ACTION_JIAOYOU_RECITE_POEM, # 交游·宣读诗词
    ACTION_FANGSHI_SELL_POEM, # 坊市·卖诗

    ACTION_BAIYE_THREATEN,           # 拜谒·要挟
    ACTION_BAIYE_POEM_VISIT,         # 拜谒·携诗
    ACTION_BAIYE_MASS_DISTRIBUTION,  # 拜谒·广发行卷
    ACTION_BAIYE_NORMAL,             # 拜谒·普通

    ACTION_JIAOYOU_TAVERN_GACHA,     # 交游·坊间买醉
    ACTION_JIAOYOU_LEVERAGE_FARM,    # 交游·暗巷刺探
    ACTION_JIAOYOU_INTRO_GACHA,      # 交游·赴宴雅集
    ACTION_JIAOYOU_HOLD_FEAST,       # 交游·举办宴席

    ACTION_MAIN_ZHUILIU,             # 驻留（父）
    ACTION_ZHUILIU_XISHI,            # 驻留·西市
    ACTION_ZHUILIU_PINGKANGFANG,     # 驻留·平康坊
    ACTION_ZHUILIU_HUANGCHENG,       # 驻留·皇城
}

enum PROPS {
    MONEY,
    HEALTH,
    LITERARY_FAME,
    TALENT,
    PROGRESS,
    TIME
}

enum CHANGAN_PLACES {
    XISHI,
    PINGKANGFANG,
    HUANGCHENG    
}

# 【西市/暗巷】(底层/S级)： 你的黑市、地痞、地下神医都在这。消耗海量 AP，见不得光。
# 【平康坊/曲江池】(中层/M级)： 你的交游、宴会、名士、清流都在这。吞吐金钱和才华，产出名声。
# 【皇城/权相府邸】(顶层/L级)： 你的终极零和博弈之地。没有通行证/请柬你甚至点不进去。

# 2. 核心情绪层 (The Soul - 意象生成的真正温床，建议采用双向坐标系)
# 不要用非黑即白的单向词汇，情绪是有正负极的！
enum EMOTION {
    SORROW,     # 愁苦/悲凉 (替代 DESPAIR，更具诗意，涵盖送别与怀古)
    ARROGANCE,  # 狂傲/得意 (涵盖饮酒作乐、金榜题名、无视权贵)
    ANGER,      # 愤懑 (涵盖被贬、目睹不公)
    TRANQUILITY, # 旷达/空灵 (涵盖山水田园、修道、释怀)
    # 3. 结果/特殊驱动力 (The Catalysts)
    AMBITION,    # 世俗的野心（想做官、想入世），用于区分李白和杜甫的路线
    NUMBNESS,    # 麻木/虚无 (原 Fatigue，放弃抵抗的妥协) -> 产出 [红袖], [空盏]
}

#enum EMOTION {
#    # --- 导向 Tier 3 (绝唱/高洁) 的情绪 ---
#    TRANQUILITY, # 旷达/空灵 (看透生死，物我两忘) -> 产出 [寒月], [孤雪]
#    ARROGANCE,   # 狂傲/得意 (天子呼来不上船) -> 产出 [寒锋], [酒葫芦]
    
#    # --- 导向 Tier 2 (诗史/沉重) 的情绪 ---
#    ANGER,       # 愤懑 (路有冻死骨的怒火) -> 产出 [烽火], [塞旗]
#    SORROW,      # 愁苦/悲凉 (国破山河在的泣血) -> 产出 [饿殍], [残垣]
    
#    # --- 导向 Tier 1 (世俗/污染) 的情绪 ---
#    AMBITION,    # 野心/功利 (想往上爬的欲望) -> 产出 [玉阶], [云日]
#    NUMBNESS,    # 麻木/虚无 (原 Fatigue，放弃抵抗的妥协) -> 产出 [红袖], [空盏]
#}

enum RELATION_TARGET {
    LIBAI,
    HUSHANG, # 商人
    LILINFU,
    JIWEN,
    YOUXIANGFU, # 右相府
    QINGLIU,
    GAOSHI,
    WANGWEI,
    ZHENGQIAN, # 郑虔
    WAIQI, # 外戚
    YANGGUOZHONG,
    GUOGUOFUREN, # 虢国夫人 
}

enum PROVINCES { 
    # 注意！！这里的地区不可以直接对应province.id 这只是用来对应事件和地区的。 
    # eg. 地区YONG_ZHOU雍州实际上对应长安CHANG_AN
    CHANG_AN
}

enum TRAITS {
    _RESERVED_00,
    
    # ── 诗词枚举已移除，占位保留整数值稳定性 ──
    _RESERVED_01,
    _RESERVED_02,
    _RESERVED_03,
    _RESERVED_04,
    _RESERVED_05,
    _RESERVED_06,

    # 主线行动等级标签
    MAIN_BAIYE_1,
    MAIN_BAIYE_2,
    MAIN_BAIYE_3,
    MAIN_BAIYE_4,
    
    MAIN_JIAOYOU_1,
    MAIN_JIAOYOU_2,
    MAIN_JIAOYOU_3,
    
    MAIN_DENGGAO_1,
    MAIN_DENGGAO_2,
    MAIN_DENGGAO_3,
    
    MAIN_FANGSHI_1,
    MAIN_FANGSHI_2,
    MAIN_FANGSHI_3,
    
    MAIN_FENGZHAO_1,
    MAIN_FENGZHAO_2,
    MAIN_FENGZHAO_3,
    MAIN_FENGZHAO_4,
    
    MAIN_DUZHUO_1,
    MAIN_DUZHUO_2,
    MAIN_DUZHUO_3,
    
    # 角色状态特性
    OFFICIAL,
    CORRUPT,
    PROUD,
    BRAVE,
    COWARDLY,
    CAUTIOUS,
    BUDDHIST,
    CONFIDENT,
    MERCHANT,
    DILIGENT,
    FEARFUL,
    WEAK,
    CRIMINAL,
    
    # 事件链特性
    CHAIN_STRANGE_POET_1,
    CHAIN_STRANGE_POET_2,
    CHAIN_STRANGE_POET_3,
    
    # 社会关系特性
    CONNECTED,
    JOYFUL,
    RESPECTED,

    _RESERVED_07,
    _RESERVED_08,
    _RESERVED_09,
    _RESERVED_10,
    _RESERVED_11,
    _RESERVED_12,

    _RESERVED_13,
    _RESERVED_14,
    _RESERVED_15,
    _RESERVED_16,
    _RESERVED_17,
    _RESERVED_18,

    KUANGDA_KUANGKE,
    KUANGDA_FENGYING,
    KUANGDA_ZUANYING,

    # 疾病特性（stage-based disease traits）
    DISEASE_FENGHAN_ACUTE,
    DISEASE_FEILAO_CHRONIC,
    DISEASE_SHIYI_DEPRESSION,
    DISEASE_ZHANWANG_MANIA,

    # 临时负面 Trait — 到期由 Trait.duration_xun + expiry_trait 数据驱动，不再硬编码
    POISONED,
    SPRAINED_ANKLE,
    SEVERE_INJURY,

    # 健康→AP 阶梯特质（health ≤ 30 → 5AP / < 60 → 8AP，由 SurvivalManager 自动增删）
    EXHAUSTION_INITIAL,
    TERMINAL_ILLNESS,
    
    # Imaginary 到期转化疾病（Lv2→风寒 Lv3→呕心沥血）
    DISEASE_FENGHAN_IMAGINARY,
    DISEASE_OUXINLIXUE,
}

enum POEM_TYPE {
    GAN_YE,
    YING_ZHI,
    DENG_GAO,
    HUAI_GU,
    JI_LV,
    SHAN_SHUI
}

## POEM_TYPE → 管道分组映射
const POEM_TYPE_CHANNEL = {
    POEM_TYPE.GAN_YE: "SECULAR",
    POEM_TYPE.YING_ZHI: "SECULAR",
    POEM_TYPE.DENG_GAO: "BROADCAST",
    POEM_TYPE.HUAI_GU: "BROADCAST",
    POEM_TYPE.JI_LV: "BROADCAST",
    POEM_TYPE.SHAN_SHUI: "BROADCAST",
}

## 获取诗词类型的管道分组（SECULAR 功利 / BROADCAST 情绪）
static func get_poem_type_channel(poem_type: int) -> String:
    return POEM_TYPE_CHANNEL.get(poem_type, "BROADCAST")

enum ACTION_TYPE {
    BAI_YE, # 拜谒
    JIAO_YOU,
    DENG_GAO,
    FANG_SHI, # 坊市
    FENG_ZHAO, # 奉召
    DU_ZHUO, # 独酌
    GAN_LU # 赶路
}

## 将 ACTION_TAGS 枚举值映射到 ACTION_TYPE 枚举值。
## 用于 SceneAction._main_tag → Era.accepted_actions 的合法性比对。
## 返回 -1 表示该 tag 不映射到任何基础 action type。
static func action_tag_to_action_type(tag: int) -> int:
    match tag:
        ACTION_TAGS.ACTION_MAIN_BAIYE:
            return ACTION_TYPE.BAI_YE
        ACTION_TAGS.ACTION_MAIN_JIAOYOU:
            return ACTION_TYPE.JIAO_YOU
        ACTION_TAGS.ACTION_MAIN_DENGGAO:
            return ACTION_TYPE.DENG_GAO
        ACTION_TAGS.ACTION_MAIN_FANGSHI:
            return ACTION_TYPE.FANG_SHI
        ACTION_TAGS.ACTION_MAIN_FENGZHAO:
            return ACTION_TYPE.FENG_ZHAO
        ACTION_TAGS.ACTION_MAIN_DUZHUO:
            return ACTION_TYPE.DU_ZHUO
        ACTION_TAGS.ACTION_SPECIAL_GANLU:
            return ACTION_TYPE.GAN_LU
        _:
            return -1

static func to_traits_str(item) -> String:
    var name = TRAITS.keys().get(item)
    if name: return name.to_lower()
    Logging.err("Invalid trait: " + str(item))
    return "default_storable_item"

static func from_traits_str(str_name: String) -> int:
    var normalized = str_name.to_lower()
    for i in range(TRAITS.size()):
        var key = TRAITS.keys()[i]
        if key.to_lower() == normalized:
            return i
    Logging.err("Invalid trait string: " + str_name)
    Logging.err("  💡 提示：如果 trait 名称无误，请检查是否已在 TRAITS 枚举中注册")
    return -1

static func to_action_str(item) -> String:
    if item < 0 or item >= ACTION_TAGS.size():
        Logging.err("Invalid action tag: %d (bounds: [0, %d))" % [item, ACTION_TAGS.size()])
        return "default_storable_item"
    var name = ACTION_TAGS.keys()[item]
    if name:
        name = name.replace("_", ":")
        return name.to_lower()
    Logging.err("Invalid action tag: " + str(item))
    return "default_storable_item"

static func to_area_str(item) -> String:
    var name = AREA_TAGS.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid area tag: " + str(item))
    return "default_storable_item"

static func to_prop_str(item) -> String:
    var name = PROPS.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid prop tag: " + str(item))
    return "default_storable_item"

static func to_province_str(item) -> String:
    var name = PROVINCES.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid province tag: " + str(item))
    return "default_storable_item"

static func to_emotion_str(item) -> String:
    var name = EMOTION.keys().get(item)
    if name:
        name = name.replace("_", ":")
        return name.to_lower()
    Logging.err("Invalid volatile stat: " + str(item))
    return "default_storable_item"

static func to_relation_str(item) -> String:
    var name = RELATION_TARGET.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid province tag: " + str(item))
    return "default_storable_item"

# ── 驻留地点 (CHANGAN_PLACES) 转换方法 ──────────────────────
# GameSaveData 存 String key，运行时转换到中文/枚举
const PLACE_STR_MAP: Dictionary = {
 CHANGAN_PLACES.XISHI: "xishi",
 CHANGAN_PLACES.PINGKANGFANG: "pingkangfang",
 CHANGAN_PLACES.HUANGCHENG: "huangcheng",
}
const PLACE_CN_MAP: Dictionary = {
 "xishi": "西市",
 "pingkangfang": "平康坊",
 "huangcheng": "皇城",
}

## CHANGAN_PLACES 枚举 → String key（用于 GameSave 持久化）
static func to_place_str(place: CHANGAN_PLACES) -> String:
 return PLACE_STR_MAP.get(place, "xishi")

## String key → CHANGAN_PLACES 枚举
static func from_place_str(s: String) -> CHANGAN_PLACES:
 match s:
  "pingkangfang": return CHANGAN_PLACES.PINGKANGFANG
  "huangcheng": return CHANGAN_PLACES.HUANGCHENG
 return CHANGAN_PLACES.XISHI

## String key → 中文名
static func place_to_cn(s: String) -> String:
 return PLACE_CN_MAP.get(s, "西市")

# ── 图片位置枚举 (UV 坐标 0.0~1.0) ─────────────────────────
enum IMAGE_POS {
    CENTER,       # UV(0.5, 0.5) 屏幕正中
    TOP_LEFT,     # UV(0, 0)     左上角
    TOP_CENTER,   # UV(0.5, 0)   顶部居中
    TOP_RIGHT,    # UV(1, 0)     右上角
    CENTER_LEFT,  # UV(0, 0.5)   左侧居中
    CENTER_RIGHT, # UV(1, 0.5)   右侧居中
    BOTTOM_LEFT,  # UV(0, 1)     左下角
    BOTTOM_CENTER,# UV(0.5, 1)   底部居中
    BOTTOM_RIGHT, # UV(1, 1)     右下角
    FULL_SCREEN,  # UV(0.5, 0.5) 全屏拉伸
}

# ── NarrativeOverlay 纸带入场动画策略 ─────────────────
# DEFAULT:           从屏幕顶部外滑入（现有默认行为）
# SLIDE_FROM_BOTTOM: 从屏幕底部外滑入（相反方向）
enum ANIMATION_STRATEGY {
    DEFAULT,
    SLIDE_FROM_BOTTOM,
}
