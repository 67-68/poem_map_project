# 商店系统 (Shop System)

**状态**: 🏗️ 实现中

---

## 意图摘要（<200字）

为游戏引入市场/商店交互场景。商店通过事件栈机制运作：静态主界面事件提供「购买物品」「和店员说话」「退出」三个选项。点击购买后动态构建商品分页事件推入栈顶（每页4个商品），通过 flag 系统管理库存状态。翻页用 Pop+Push 组合保持栈深度恒为1。商品售罄后灰化显示「已售罄」。购买时自动扣钱减库存。

---

## 核心玩法

- **商店主界面**：静态 .tres 事件，展示商店氛围描述，3 个固定选项
- **商品分页**：运行时动态生成 RandomEvent，每页最多 4 个商品 + 2 个导航选项
- **库存管理**：通过 `shop_{shop_id}_{product_id}_stock` int flag 追踪实时库存，售罄后灰化
- **翻页机制**：PopEventOperator(当前页) + ShopBuyOperator(新页码)，保持栈深度不变
- **购买后果**：FlagOperator(stock-1) + PropertyOperator(money,-price) + 可选额外后果

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `core/model/shop_config.gd` | **新建** | 商品配置 Resource（product_id/name/price/stock/description/operators） |
| `core/shop_manager.gd` | **新建** | 商店管理器 Autoload（init_shop/get_stock/build_buy_event/push_buy_page） |
| `core/operators/shop_buy_operator.gd` | **新建** | 翻页/进入购买界面 Operator（shop_id + page） |
| `data/events/shop_main.tres` | **新建** | 商店主界面静态事件 |
| `data/events/shop_talk.tres` | **新建** | 店员对话静态事件 |
| `project.godot` | **修改** | 注册 ShopManager 为 Autoload（EventManager 之后） |

---

## 状态转换

```
[商店入口]
    │
    ├─ 外部调用 ShopManager.init_shop("market", products)
    │     ├─ 为每个 product 注册虚拟 flag: shop_{shop_id}_{product_id}_stock
    │     └─ 设置初始库存到 PlayerState
    │
    ├─ PushEventOperator → shop_main.tres 入栈
    │
    └─ shop_main 显示
          │
          ├─ 选项1: "购买物品"
          │     └─ ShopBuyOperator(shop_id="market", page=1)
          │           └─ ShopManager.push_buy_page() → build_buy_event(1)
          │                 └─ RandomEvent 入栈 → buy_page_1 显示
          │                       │
          │                       ├─ 商品1-4 (EventOption)
          │                       │     ├─ stock > 0: FlagRequirement(stock > 0) 可见
          │                       │     ├─ stock = 0: NarrativeLockRequirement("已售罄") 灰化
          │                       │     └─ 点击: FlagOperator(stock,-1) + PropertyOperator(money,-price) + extras
          │                       │
          │                       ├─ 选项5: "返回"/"上一页"
          │                       │     ├─ page=1: PopEventOperator → 回到 shop_main
          │                       │     └─ page>1: PopEventOperator + ShopBuyOperator(page-1)
          │                       │
          │                       └─ 选项6: "下一页"
          │                             ├─ page < total: PopEventOperator + ShopBuyOperator(page+1)
          │                             └─ page >= total: NarrativeLockRequirement("没有下一页了") 灰化
          │
          ├─ 选项2: "和店员说话"
          │     └─ PushEventOperator("shop_talk")
          │           └─ shop_talk.tres 入栈显示
          │                 └─ "返回" → PopEventOperator → 回到 shop_main
          │
          └─ 选项3: "退出"
                └─ PopEventOperator → 回到上层事件
```

---

## 使用示例

```gdscript
# 在游戏初始化时配置商店
func _setup_market():
    var products = [
        {
            "product_id": "dried_fish",
            "product_name": "金枪鱼",
            "price": 10,
            "initial_stock": 5,
            "detail_description": "上等金枪鱼，肥美鲜嫩。食用可恢复少量健康。",
        },
        {
            "product_id": "rice_wine",
            "product_name": "米酒",
            "price": 8,
            "initial_stock": 3,
            "detail_description": "农家自酿米酒，醇厚甘甜。饮后灵感涌动。",
        },
        # ... 更多商品
    ]
    ShopManager.init_shop("market", products)

# 进入商店
EventBus.push_event.emit("shop_main", {})
```
