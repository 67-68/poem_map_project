# 商店系统 (Shop System)

**状态**: 🏗️ 实现中

---

## 意图摘要（<200字）

为游戏引入市场/商店交互场景。商店通过事件栈机制运作：静态主界面事件提供「购买物品」「和店员说话」「退出」三个选项。点击购买后动态构建商品分页事件推入栈顶（每页4个商品），通过 flag 系统管理库存状态。商品购买通过 TraitOperator + BuffOperator 组合赋予玩家特殊效果（每旬被动/定向加成/伤害减免/使用次数消费）。

---

## 核心玩法

- **商店主界面**：静态 .tres 事件，展示商店氛围描述，3 个固定选项
- **商品分页**：运行时动态生成 RandomEvent，每页最多 4 个商品 + 2 个导航选项
- **库存管理**：通过 `shop_{shop_id}_{product_id}_stock` int flag 追踪实时库存，售罄后灰化
- **翻页机制**：PopEventOperator(当前页) + ShopBuyOperator(新页码)，保持栈深度不变
- **购买后果**：FlagOperator(stock-1) + PropertyOperator(money,-price) + TraitOperator(ADD) + BuffOperator

---

## 商品列表

| 商品 | 价格 | 效果 | 机制 |
|------|------|------|------|
| 西域斗鸡 | 200 | 每旬 +3 兴 | `per_xun_passive` + `s_xing_gain` |
| 极品行卷 | 50 | 下次势获取 +30% | `efficiency` + `target_prop=momentum` + `max_uses=1` |
| 貂裘 | 200 | 生命扣除 -5% | `damage_reduction` + `target_prop=health` + `mod_pct_5` |
| 拨浪鼓 | 5 | 无效果 | 纯叙事 trait |

---

## BuffOperator 新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `target_prop` | String | 目标属性过滤（空=全局）。efficiency/damage_reduction 类型可用 |
| `max_uses` | int | 最大使用次数。>0 启用，每次 append_stat 触发后递减，归零自动移除 modifier + trait |
| `damage_reduction` | modifier_type 新值 | 属性扣除百分比减免，对负 delta 生效 |

## ModifierRegistry 新增方法

| 方法 | 说明 |
|------|------|
| `get_damage_reduction(prop_name)` | 返回指定属性的伤害减免倍率总和 |
| `consume_and_check_max_uses(type, prop_name)` | 消费 max_uses，返回耗尽时需移除的 trait uuid 列表 |

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `core/model/shop_config.gd` | **新建** | 商品配置 Resource |
| `core/shop_manager.gd` | **新建** | 商店管理器 Autoload |
| `core/operators/shop_buy_operator.gd` | **新建** | 翻页 Operator |
| `data/events/shop_main.tres` | **新建** | 商店主界面 |
| `data/events/shop_talk.tres` | **新建** | 店员对话 |
| `data/3_actions_pool/actions/fang_shi/fangshi_market.tres` | **新建** | 坊市子行动（lead_to_event="shop_main"） |
| `data/3_actions_pool/actions/fang_shi.tres` | **修改** | 追加 fangshi_market 到 sub_actions |
| `data/1_core_rules/traits/xiyu_cockfight.tres` | **新建** | 西域斗鸡 trait |
| `data/1_core_rules/traits/premium_exam_scroll.tres` | **新建** | 极品行卷 trait |
| `data/1_core_rules/traits/fox_fur_coat.tres` | **新建** | 貂裘 trait |
| `data/1_core_rules/traits/rattle_drum.tres` | **新建** | 拨浪鼓 trait |
| `data/1_core_rules/traits/_traits.csv` | **修改** | 追加 4 行 trait 定义 |
| `core/buff_operator.gd` | **修改** | 加 target_prop/max_uses/damage_reduction |
| `core/modifier_registry.gd` | **修改** | 加 get_damage_reduction/consume_and_check_max_uses/target_prop 过滤 |
| `core/player_state.gd` | **修改** | append_stat 加 damage_reduction + max_uses 消费 |
| `tools/data/named_amounts.json` | **修改** | 加 mod_pct_5/mod_pct_30 |
| `project.godot` | **修改** | 注册 ShopManager Autoload |

---

## 使用示例

```gdscript
# 在游戏初始化时配置商店
func _setup_market():
    var cockfight_buff := BuffOperator.new()
    cockfight_buff.named_amount_key = "s_xing_gain"
    cockfight_buff.modifier_type = "per_xun_passive"
    cockfight_buff.source_uuid = "xiyu_cockfight"

    var scroll_buff := BuffOperator.new()
    scroll_buff.named_amount_key = "mod_pct_30"
    scroll_buff.modifier_type = "efficiency"
    scroll_buff.target_prop = "momentum"
    scroll_buff.max_uses = 1
    scroll_buff.source_uuid = "premium_exam_scroll"

    var coat_buff := BuffOperator.new()
    coat_buff.named_amount_key = "mod_pct_5"
    coat_buff.modifier_type = "damage_reduction"
    coat_buff.target_prop = "health"
    coat_buff.source_uuid = "fox_fur_coat"

    var products = [
        {
            "product_id": "xiyu_cockfight",
            "product_name": "西域斗鸡",
            "price": 200,
            "initial_stock": 1,
            "detail_description": "一只来自西域的斗鸡，羽毛如霞。每旬额外获得3点兴。",
            "purchase_operators": [
                _make_trait_add_op("xiyu_cockfight"),
                cockfight_buff,
            ],
        },
        {
            "product_id": "premium_exam_scroll",
            "product_name": "极品行卷",
            "price": 50,
            "initial_stock": 1,
            "detail_description": "精装行卷，封面烫金。下次获得势时额外加成30%，用过即废。",
            "purchase_operators": [
                _make_trait_add_op("premium_exam_scroll"),
                scroll_buff,
            ],
        },
        {
            "product_id": "fox_fur_coat",
            "product_name": "貂裘",
            "price": 200,
            "initial_stock": 1,
            "detail_description": "上等狐皮制成的大氅，轻软如云。生命值扣除减免5%。",
            "purchase_operators": [
                _make_trait_add_op("fox_fur_coat"),
                coat_buff,
            ],
        },
        {
            "product_id": "rattle_drum",
            "product_name": "拨浪鼓",
            "price": 5,
            "initial_stock": 1,
            "detail_description": "一面小巧的拨浪鼓，送给孩子的最好礼物。",
            "purchase_operators": [
                _make_trait_add_op("rattle_drum"),
            ],
        },
    ]
    ShopManager.init_shop("market", products)

static func _make_trait_add_op(trait_id: String) -> TraitOperator:
    var op := TraitOperator.new()
    op.str_traits = trait_id
    op.operator = REQ_OPERATOR.CRUD.ADD
    return op
```
