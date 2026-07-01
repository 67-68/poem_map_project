@tool
class_name EventBase extends Resource

## 事件库唯一标识，如 "745_jiaoyou"
@export var uuid: String = ""

## 事件库显示名称，如 "野心交游事件库"
@export var name: String = ""

## 所属时代标识，如 "745_ambition"。空字符串表示全时代可用
@export var era: String = ""

## 抽取策略，"AVERAGE" 或空字符串（无策略）
@export var draw_strategies: String = ""

## AVERAGE 策略：所有事件都被封禁后是否清空黑名单重新开始
@export var reset_on_empty: bool = false

## 该事件库包含的事件 uuid 列表
@export var events: Array[String] = []

## 生成配置原始 JSON（暂不解析），来自 eb_*.json 的 generation_configs 字段
@export var generation_configs: Dictionary = {}
