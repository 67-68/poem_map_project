@tool
class_name ShopBuyOperator extends BaseOperator

## ShopBuyOperator — 进入商店购买界面（翻页操作符）
##
## 用法：在 shop_main 事件的"购买物品"选项 choice_result 中添加此 operator，
## shop_id + page 决定翻到哪一页。购买商品后也会重新 push 当前页（刷新库存显示）。
##
## DSL 示例（在 choice_result 的 results 列）：
##   shop_buy(shop_id="market"; page=1)

## 商店标识符，对应 ShopManager.init_shop 时使用的 shop_id
@export var shop_id: String = ""

## 页码（1-based）
@export var page: int = 1

## 当前事件的 context，在 init 时捕获
var _captured_context: Dictionary = {}


func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("[ShopBuyOperator] init: shop_id='%s' page=%d, context keys=%s" % [shop_id, page, _captured_context.keys()])
	return context


func operate():
	if shop_id.is_empty():
		Logging.err("[ShopBuyOperator] operate: shop_id 为空，无法推送购买界面")
		return

	# 将 shop_id 和 page 注入 context，供 ShopManager.build_buy_event() 使用
	var ctx = _captured_context.duplicate()
	ctx["shop_id"] = shop_id
	ctx["shop_page"] = page

	Logging.info("[ShopBuyOperator] operate: pushing buy page for shop_id='%s' page=%d" % [shop_id, page])
	ShopManager.push_buy_page(shop_id, page, ctx)
