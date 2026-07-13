class_name HintProfile extends RefCounted
## 行动提示构建 Profile 枚举
##
## DEFAULT: 详版，完整调用 op.describe_preview()，含箭头+数值+知觉文本+ModifierConfig 注解
## SIMPLE:  简版，仅显示属性名+箭头（S/M/L→1/2/3个），无数值、无知觉文本、无来源注解、
##          TimeOperator 缩为「⏱N天」、TraitOperator 缩为「获/失 名」、PoemRewardOperator 缩为短标签

enum Profile {
	DEFAULT,
	SIMPLE,
}
