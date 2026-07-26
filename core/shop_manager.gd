extends Node
## ShopManager — 商店管理 Autoload
##
## 管理商店的商品配置、库存 flag、动态构建购买分页事件。
## 通过 init_shop(dict) 从外部注入商品配置，用 flag 追踪实时库存。
##
## Flag 命名规则：
##   shop_{shop_id}_{product_id}_stock  →  int（当前库存）
##
## 交互流程：
##   1. 外部调用 init_shop("market", [{product_id, name, price, stock, desc}, ...])
##   2. 商店主界面事件 → 选项"购买物品" → ShopBuyOperator(shop_id, page=1)
##   3. ShopBuyOperator.operate() → ShopManager.push_buy_page() → build_buy_event()
##   4. 运行时 RandomEvent 通过 EventBus.push_event 入栈
##   5. 商品选项 choice_result：FlagOperator(stock-1) + PropertyOperator(money, -price)
##   6. 翻页选项 choice_result：PopEventOperator + ShopBuyOperator(page=N)
##   7. 退出 → PopEventOperator 回到 shop_main

const _RandomEvent = preload("res://model/random_event.gd")
const _EventOption = preload("res://model/event/event_option.gd")
const _ChoiceResult = preload("res://model/choice_result.gd")
const _FlagOperator = preload("res://core/operators/flag_operator.gd")
const _PopEventOperator = preload("res://core/operators/pop_event_operator.gd")
const _PropertyOperator = preload("res://core/model/property_operator.gd")
const _FlagRequirement = preload("res://core/requirements/flag_requirement.gd")
const _ShopConfig = preload("res://core/model/shop_config.gd")
const _ShopBuyOperator = preload("res://core/operators/shop_buy_operator.gd")
const _NarrativeLockRequirement = preload("res://core/requirements/narrative_lock_requirement.gd")
const _TraitOperator = preload("res://core/model/trait_operator.gd")
const _BuffOperator = preload("res://core/buff_operator.gd")
const _TraitHintFormatter = preload("res://core/hints/trait_hint_formatter.gd")

## key: shop_id, value: Array
var _shops: Dictionary = {}

## 每页显示的商品数量
const ITEMS_PER_PAGE: int = 4


func _ready() -> void:
	# ── 初始化坊市商店（market） ──
	# BuffOperator 需要在 push 到 purchase_operators 前预先构造好 source_uuid
	var cockfight_buff := _BuffOperator.new()
	cockfight_buff.named_amount_key = "s_xing_gain"
	cockfight_buff.modifier_type = "per_xun_passive"
	cockfight_buff.source_uuid = "xiyu_cockfight"

	var scroll_buff := _BuffOperator.new()
	scroll_buff.named_amount_key = "mod_pct_30"
	scroll_buff.modifier_type = "efficiency"
	scroll_buff.target_prop = "momentum"
	scroll_buff.max_uses = 1
	scroll_buff.source_uuid = "premium_exam_scroll"

	var coat_buff := _BuffOperator.new()
	coat_buff.named_amount_key = "mod_pct_5"
	coat_buff.modifier_type = "damage_reduction"
	coat_buff.target_prop = "health"
	coat_buff.source_uuid = "fox_fur_coat"

	var products: Array = [
		{
			"product_id": "xiyu_cockfight",
			"product_name": "西域斗鸡",
			"price": 200,
			"initial_stock": 1,
			"detail_description": "一只来自西域的斗鸡，羽毛如霞。看它扑腾的样子，连写诗都来劲了——每旬额外获得3点兴。",
			"purchase_operators": [_make_trait_add_op("xiyu_cockfight"), cockfight_buff],
		},
		{
			"product_id": "premium_exam_scroll",
			"product_name": "极品行卷",
			"price": 50,
			"initial_stock": 1,
			"detail_description": "精装行卷，封面烫金，内附名家题跋。下次获得势时额外加成30%，用过即废。",
			"purchase_operators": [_make_trait_add_op("premium_exam_scroll"), scroll_buff],
		},
		{
			"product_id": "fox_fur_coat",
			"product_name": "貂裘",
			"price": 200,
			"initial_stock": 1,
			"detail_description": "上等狐皮制成的大氅，轻软如云。寒冬中穿着，生命值扣除减免5%。",
			"purchase_operators": [_make_trait_add_op("fox_fur_coat"), coat_buff],
		},
		{
			"product_id": "rattle_drum",
			"product_name": "拨浪鼓",
			"price": 5,
			"initial_stock": 1,
			"detail_description": "一面小巧的拨浪鼓，咚咚作响。送给孩子的最好礼物，虽然对你没什么实际用处，但看着它就想起宗文宗武的笑脸。",
			"purchase_operators": [_make_trait_add_op("rattle_drum")],
		},
		{
			"product_id": "qin_instrument",
			"product_name": "古琴",
			"price": 150,
			"initial_stock": 1,
			"detail_description": "一张桐木古琴，弦如流水，抚之清音绕梁。买回后可解锁【抚琴】行动：焚香净手，买壶好酒，弹一曲解千愁。",
			"purchase_operators": [_make_trait_add_op("qin_instrument")],
		},
	]
	init_shop("market", products)
	Logging.info("[ShopManager] _ready: market 商店已初始化，共 %d 个商品" % products.size())


static func _make_trait_add_op(trait_id: String):
	var op := _TraitOperator.new()
	op.str_traits = trait_id
	op.operator = REQ_OPERATOR.CRUD.ADD
	return op


# ════════════════════════════════════════════════════════════════
# 公共 API
# ════════════════════════════════════════════════════════════════

## 初始化一个商店的商品配置。
##
## @param shop_id: 商店标识符（如 "market"）
## @param products: Array[Dictionary]，每个 dict 包含：
##   - product_id: String（必需）
##   - product_name: String（显示名，必需）
##   - price: int（单价，必需）
##   - initial_stock: int（初始库存，默认 0）
##   - detail_description: String（hover 详情，可选）
##   - icon: Texture2D（可选）
##   - purchase_operators: Array（可选，购买后额外执行的 BaseOperator 列表）
func init_shop(shop_id: String, products: Array) -> void:
	if shop_id.is_empty():
		Logging.err("[ShopManager] init_shop: shop_id 为空")
		return

	if products.is_empty():
		Logging.warn("[ShopManager] init_shop: shop_id='%s' 商品列表为空" % shop_id)
		_shops[shop_id] = []
		return

	var configs: Array = []
	for p_dict in products:
		var cfg = _ShopConfig.new()
		cfg.product_id = p_dict.get("product_id", "")
		cfg.product_name = p_dict.get("product_name", "")
		cfg.price = p_dict.get("price", 0)
		cfg.initial_stock = p_dict.get("initial_stock", 0)
		cfg.detail_description = p_dict.get("detail_description", "")
		cfg.icon = p_dict.get("icon", null)
		var ops = p_dict.get("purchase_operators", [])
		cfg.purchase_operators.assign(ops)

		if cfg.product_id.is_empty():
			Logging.err("[ShopManager] init_shop: shop_id='%s' 中存在空 product_id，跳过" % shop_id)
			continue

		configs.append(cfg)

		# 注册虚拟 flag 并初始化库存
		var stock_flag := _make_stock_flag(shop_id, cfg.product_id)
		PlayerState.register_virtual_flag(stock_flag, "int")
		PlayerState.set_flag(stock_flag, cfg.initial_stock, "int")
		Logging.info("[ShopManager] init_shop: shop_id='%s' product='%s' stock=%d flag='%s'" % [shop_id, cfg.product_id, cfg.initial_stock, stock_flag])

	_shops[shop_id] = configs
	Logging.info("[ShopManager] init_shop: shop_id='%s' 初始化完成，共 %d 个商品" % [shop_id, configs.size()])


## 获取某个商店的商品配置列表
func get_products(shop_id: String) -> Array:
	var arr = _shops.get(shop_id, [])
	return arr.duplicate()


## 获取商品当前库存
func get_stock(shop_id: String, product_id: String) -> int:
	var flag_id := _make_stock_flag(shop_id, product_id)
	var val = PlayerState.get_flag(flag_id)
	if val == null:
		return 0
	return int(val)


## 购买商品：检查库存 → 扣库存 → 返回是否成功
## 注意：此方法仅更新 flag，不处理扣钱和额外后果（由 choice_result 中的 operator 链负责）
func try_buy(shop_id: String, product_id: String) -> bool:
	var stock := get_stock(shop_id, product_id)
	if stock <= 0:
		Logging.info("[ShopManager] try_buy: shop_id='%s' product='%s' 库存不足 (stock=%d)" % [shop_id, product_id, stock])
		return false

	var flag_id := _make_stock_flag(shop_id, product_id)
	PlayerState.append_flag(flag_id, -1)
	Logging.info("[ShopManager] try_buy: shop_id='%s' product='%s' 购买成功，剩余库存=%d" % [shop_id, product_id, stock - 1])
	return true


## 计算总页数
func get_page_count(shop_id: String) -> int:
	var products := get_products(shop_id)
	if products.is_empty():
		return 1
	return ceili(float(products.size()) / float(ITEMS_PER_PAGE))


## 构建指定页的购买事件（运行时 RandomEvent）
## 
## 返回的 RandomEvent 结构：
##   - name: "第{page}页"
##   - description: 本页商品摘要（一行一个，格式："商品名（剩余X，Y钱）"）
##   - options[0..3]: 商品购买选项（不足时填充空占位）
##   - options[4]: 返回/上一页
##   - options[5]: 下一页
func build_buy_event(shop_id: String, page: int, context: Dictionary):
	Logging.info("[ShopManager] build_buy_event: shop_id='%s' page=%d" % [shop_id, page])

	var products := get_products(shop_id)
	var total_pages := get_page_count(shop_id)

	# 计算本页商品范围
	var start_idx := (page - 1) * ITEMS_PER_PAGE
	var end_idx := mini(start_idx + ITEMS_PER_PAGE, products.size())
	var page_products: Array = []
	for i in range(start_idx, end_idx):
		page_products.append(products[i])

	# ── 构建 description（商品摘要） ──
	var desc_parts: Array[String] = []
	for p_ref in page_products:
		var p = p_ref as _ShopConfig
		var stock := get_stock(shop_id, p.product_id)
		var line := "%s（剩余%d，%d钱）" % [p.product_name, stock, p.price]
		if stock <= 0:
			line += " — 已售罄"
		if not p.detail_description.is_empty():
			line += "\n  %s" % p.detail_description
		desc_parts.append(line)
		Logging.info("[ShopManager] build_buy_event: product='%s' detail_description appended (%d chars)" % [p.product_id, p.detail_description.length()])
	var description := "\n".join(desc_parts)

	# ── 构建事件 ──
	var event := _RandomEvent.new()
	event.uuid = "shop_buy_%s_p%d" % [shop_id, page]
	event.name = "第%d页" % page
	event.description = description

	var all_options: Array = []

	# ── 商品选项 1-4 ──
	for p_ref in page_products:
		var p = p_ref as _ShopConfig
		var opt = _build_product_option(shop_id, p, context)
		all_options.append(opt)

	# ── 填充空位（商品不足 4 个时） ──
	while all_options.size() < ITEMS_PER_PAGE:
		var empty_opt := _EventOption.new()
		empty_opt.description = "—"
		var lock = NarrativeLockRequirement.new()
		lock.failed_hint = "无商品"
		empty_opt.requirement = lock
		all_options.append(empty_opt)

	# ── 选项5: 返回/上一页 ──
	var prev_opt = _build_nav_option(page, total_pages, shop_id, context, false)
	all_options.append(prev_opt)

	# ── 选项6: 下一页 ──
	var next_opt = _build_nav_option(page, total_pages, shop_id, context, true)
	all_options.append(next_opt)

	event.options.assign(all_options)
	Logging.info("[ShopManager] build_buy_event: 构建完成，%d 个选项（%d 商品 + 2 导航）" % [all_options.size(), page_products.size()])
	return event


## 推送购买分页事件到事件栈
func push_buy_page(shop_id: String, page: int, context: Dictionary) -> void:
	var event = build_buy_event(shop_id, page, context)
	# 直接传入 BaseEvent 对象，绕过 Database.resolve()
	# NarrativeDirector._resolve_event_for_stack 支持 data is BaseEvent 分支
	EventBus.push_event.emit(event, context)
	Logging.info("[ShopManager] push_buy_page: shop_id='%s' page=%d → 事件已推入栈" % [shop_id, page])


# ════════════════════════════════════════════════════════════════
# 内部构建方法
# ════════════════════════════════════════════════════════════════

## 构建单个商品购买选项
func _build_product_option(shop_id: String, product, context: Dictionary):
	var opt := _EventOption.new()
	var stock := get_stock(shop_id, product.product_id)
	opt.description = "%s（剩余%d，%d钱）" % [product.product_name, stock, product.price]

	# ── 构建 detail_description：自动检测 TraitOperator → 用 TraitHintFormatter 生成完整 trait 描述 ──
	var detail_desc: String = ""
	if not product.purchase_operators.is_empty():
		for extra_op in product.purchase_operators:
			if extra_op and extra_op is _TraitOperator:
				var top = extra_op as _TraitOperator
				var trait_obj = Database.get_trait(top.trait_key)
				if trait_obj:
					detail_desc = _TraitHintFormatter.new().build_hint(trait_obj)
					Logging.info("[ShopManager] _build_product_option: product='%s' TraitOperator detected, trait='%s', hint=%d chars" % [product.product_id, top.trait_key, detail_desc.length()])
					break
	if detail_desc.is_empty():
		detail_desc = product.detail_description
		if detail_desc.is_empty():
			detail_desc = product.product_name
		Logging.info("[ShopManager] _build_product_option: product='%s' fallback to product.detail_description (%d chars)" % [product.product_id, detail_desc.length()])

	# 存入 custom_context_params，供 EventBtn hover 链路消费
	opt.custom_context_params["detail_description"] = detail_desc

	# ── requirement: 库存 > 0 ──
	if stock <= 0:
		var lock = NarrativeLockRequirement.new()
		lock.failed_hint = "已售罄"
		opt.requirement = lock
	else:
		var flag_req := _FlagRequirement.new()
		flag_req.flag_id = _make_stock_flag(shop_id, product.product_id)
		flag_req.type = "int"
		flag_req.value = 0
		flag_req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
		opt.requirement = flag_req

	# ── choice_result: 扣库存 + 扣钱 + 额外后果 ──
	var cr := _ChoiceResult.new()
	var operators: Array = []

	# 1. 扣库存 flag
	var stock_op := _FlagOperator.new()
	stock_op.flag_id = _make_stock_flag(shop_id, product.product_id)
	stock_op.type = "int"
	stock_op.value = -1
	stock_op.operation = "append"
	operators.append(stock_op)

	# 2. 扣钱（PropertyOperator, value 为负数）
	if product.price > 0:
		var money_op := _PropertyOperator.new()
		money_op.str_props = "money"
		money_op.value = -product.price
		operators.append(money_op)

	# 3. 额外购买后果（如给物品 trait）
	if not product.purchase_operators.is_empty():
		for extra_op in product.purchase_operators:
			if extra_op:
				operators.append(extra_op)

	cr.operators.assign(operators)
	opt.choice_result = cr

	Logging.info("[ShopManager] _build_product_option: product='%s' stock=%d price=%d ops_count=%d" % [product.product_id, stock, product.price, operators.size()])
	return opt


## 构建翻页导航选项
## @param is_next: true=下一页, false=返回/上一页
func _build_nav_option(page: int, total_pages: int, shop_id: String, context: Dictionary, is_next: bool):
	var opt := _EventOption.new()

	if is_next:
		opt.description = "下一页"
		# 只有还有下一页时才可用
		if page >= total_pages:
			var lock = NarrativeLockRequirement.new()
			lock.failed_hint = "没有下一页了"
			opt.requirement = lock
	else:
		if page <= 1:
			opt.description = "返回"
		else:
			opt.description = "上一页"

	# ── choice_result: PopEvent + ShopBuyOperator（如果是翻页） ──
	var cr := _ChoiceResult.new()
	var operators: Array = []

	# 总是先 pop 当前页面
	var pop_op := _PopEventOperator.new()
	operators.append(pop_op)

	# 翻页：push 新页面
	if is_next and page < total_pages:
		var buy_op := _ShopBuyOperator.new()
		buy_op.shop_id = shop_id
		buy_op.page = page + 1
		operators.append(buy_op)
	elif not is_next and page > 1:
		# 上一页
		var buy_op := _ShopBuyOperator.new()
		buy_op.shop_id = shop_id
		buy_op.page = page - 1
		operators.append(buy_op)
	# else: 仅 pop（返回/退出），回到 shop_main

	cr.operators.assign(operators)
	opt.choice_result = cr

	Logging.info("[ShopManager] _build_nav_option: page=%d/%d is_next=%s desc='%s'" % [page, total_pages, is_next, opt.description])
	return opt


## 生成库存 flag 名称
static func _make_stock_flag(shop_id: String, product_id: String) -> String:
	return "shop_%s_%s_stock" % [shop_id, product_id]
