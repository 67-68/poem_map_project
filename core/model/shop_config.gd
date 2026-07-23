@tool
class_name ShopConfig extends Resource

## ShopConfig — 商店商品配置 Resource
## 描述单个商品的属性：id、名称、价格、库存、hover 详情和购买后执行的 operators

## 商品唯一标识符（如 "dried_fish"）
@export var product_id: String = ""

## 商品显示名称（如 "金枪鱼"）
@export var product_name: String = ""

## 商品单价（消耗 MONEY 属性）
@export var price: int = 0

## 初始库存数量
@export var initial_stock: int = 0

## hover 时显示的详细信息
@export_multiline var detail_description: String = ""

## 可选图标
@export var icon: Texture2D

## 购买后额外执行的 operators（如给物品 trait、触发事件等）
## 会在扣钱减库存之后执行
@export var purchase_operators: Array[BaseOperator] = []
