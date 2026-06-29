class_name PoemRecord extends Resource

## 诗词归档数据结构 — 用于图鉴页面展示已使用的诗词

## 诗词标题
@export var title: String = ""

## 创作日期（游戏内年份）
@export var year: int = 0

## 使用情境描述（如"呈于皇帝御览""题于长安酒肆墙壁"），空则不显示
@export var usage_context: String = ""

## 诗词等级 (0-2)
@export var poem_level: int = 0

## 世俗值
@export var secular_value: float = 0.0

## 文学值
@export var literary_value: float = 0.0

## 诗词类型 (GAN_YE, YING_ZHI, ...)
@export var poem_type: String = ""
