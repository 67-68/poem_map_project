@tool
class_name GlitchPreprocessor

# ── 日志标签 ──────────────────────────────────────────────
const LOG_TAG := "GlitchPreprocessor"

# ── 编译期默认注入参数 ────────────────────────────────────
## 初始化时对所有事件文本注入的默认参数映射。
## 格式：{tag_name: {key: value}}
## 后续可扩展为从配置文件读取。
const DEFAULT_TAG_PARAMS: Dictionary = {
	"glitch": {"level": 2.0, "color_shift": 0.5},
}

# ── 正则模板 ──────────────────────────────────────────────
## 匹配裸露的 [TAG] 开标签模板，运行时用 tag 名填充。
## 防御：不会误伤 [/TAG]（有 /）、[TAG key=val]（已有参数）、[TAGxxx]（字符串不同）。
const _BARE_TAG_TEMPLATE := "\\[%s\\]"


# ============================================================
# 公共接口 — 类比 named_dsl_parser.gd 的分发模式
# ============================================================

## 核心分发方法：根据 {tag_name: params} 映射对文本中多个不同标签批量注入参数。
##
## 类比 [NamedDSLParser.parse_single()] 返回 func_name + params 让调用方分发，
## 本方法接收 {tag_name: params} 字典，内部按 tag 名路由注入。
##
## [param raw_text]   包含裸 BBCode 标签的原始文本，如 "[glitch]抖[/glitch] [wave]飘[/wave]"
## [param tag_params]  {tag_name: {key: value}} 映射
##                     如 {"glitch": {"level": 5.0}, "wave": {"freq": 2.0}}
##
## [returns] 注入参数后的文本
##
## [b]示例：[/b]
## [codeblock]
## GlitchPreprocessor.inject_params(
##     "[glitch]抖[/glitch] [wave]飘[/wave]",
##     {"glitch": {"level": 5.0}, "wave": {"freq": 2.0}}
## )
## # → "[glitch level=5.0]抖[/glitch] [wave freq=2.0]飘[/wave]"
## [/codeblock]
##
## [b]防御边界（每个 tag 独立保证）：[/b]
## - [TAG] → 注入参数
## - [/TAG] → 不动（闭标签）
## - [TAG key=val] → 不动（已有参数，不覆盖）
## - [TAGxxx] → 不动（不是目标标签）
func inject_params(raw_text: String, tag_params: Dictionary) -> String:
	if tag_params.is_empty():
		return raw_text

	var result := raw_text
	for tag: String in tag_params:
		var params = tag_params[tag]
		if not (params is Dictionary):
			push_warning(tr("CODE_GLITCH_PREPROCESSOR_8E14EED932") % [LOG_TAG, tag])
			continue
		var d := params as Dictionary
		if d.is_empty():
			continue
		result = _inject_one(result, tag, d)

	return result


## 便捷方法：单标签注入（向后兼容旧的 inject_params(raw_text, params) 调用）
##
## [param raw_text] 原始文本
## [param tag]      BBCode 标签名，如 "glitch"
## [param params]   参数字典，如 {"level": 5.0}
func inject_single(raw_text: String, tag: String, params: Dictionary) -> String:
	return inject_params(raw_text, {tag: params})


# ============================================================
# 编译期预处理 — Database 初始化时调用
# ============================================================

## 对单个 Resource 实体中所有文本字段做编译期参数注入。
##
## 遍历实体的 description、on_returned、epitaph_text、example 等字段，
## 以及 BaseEvent.options 中每个选项的 description，
## 使用 [member DEFAULT_TAG_PARAMS] 注入参数。
##
## [param res] 需要预处理的 Resource（通常为 BaseEvent / GameEntity）
##
## [b]注意：[/b]
## - 只替换裸标签 [glitch]，已有参数的标签如 [glitch level=5] 不受影响
## - 空字符串/无文本字段的实体直接跳过
func preprocess_entity(res: Resource) -> void:
	if res == null:
		return

	# ── 处理 description（GameEntity / BaseEvent 共有字段）──
	if "description" in res:
		var desc: String = res.get("description")
		if not desc.is_empty():
			var processed := inject_params(desc, DEFAULT_TAG_PARAMS)
			if processed != desc:
				res.set("description", processed)

	# ── 处理 BaseEvent 独有文本字段 ──
	if "on_returned" in res:
		var on_ret: String = res.get("on_returned")
		if not on_ret.is_empty():
			var processed := inject_params(on_ret, DEFAULT_TAG_PARAMS)
			if processed != on_ret:
				res.set("on_returned", processed)

	if "epitaph_text" in res:
		var epi: String = res.get("epitaph_text")
		if not epi.is_empty():
			var processed := inject_params(epi, DEFAULT_TAG_PARAMS)
			if processed != epi:
				res.set("epitaph_text", processed)

	if "example" in res:
		var ex: String = res.get("example")
		if not ex.is_empty():
			var processed := inject_params(ex, DEFAULT_TAG_PARAMS)
			if processed != ex:
				res.set("example", processed)

	# ── 处理 BaseEvent.options 中每个选项的 description ──
	if "options" in res:
		var opts: Array = res.get("options")
		for opt in opts:
			if opt == null:
				continue
			if "description" in opt:
				var od: String = opt.get("description")
				if not od.is_empty():
					var processed := inject_params(od, DEFAULT_TAG_PARAMS)
					if processed != od:
						opt.set("description", processed)


# ============================================================
# 内部方法 — 单标签注入管线
# ============================================================

## 对单个标签执行参数注入
func _inject_one(text: String, tag: String, params: Dictionary) -> String:
	var regex := RegEx.new()
	var pattern := _BARE_TAG_TEMPLATE % tag
	var err := regex.compile(pattern)
	if err != OK:
		push_error(tr("CODE_GLITCH_PREPROCESSOR_FB8806A61B") % [LOG_TAG, tag, pattern])
		return text

	var injected_tag := _build_injected_tag(tag, params)
	var result := regex.sub(text, injected_tag, true)

	return result


## 构建注入后的开标签字符串
## 输入: tag="glitch", params={"level": 5.0, "color_shift": 0.8}
## 输出: "[glitch level=5.0 color_shift=0.8]"
func _build_injected_tag(tag: String, params: Dictionary) -> String:
	var parts: Array[String] = ["[%s" % tag]
	for key: String in params:
		parts.append(" %s=%s" % [key, str(params[key])])
	parts.append("]")
	return "".join(PackedStringArray(parts))
