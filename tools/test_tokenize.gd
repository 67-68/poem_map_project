@tool
extends SceneTree

func _init() -> void:
	print("\n=== _tokenize_bbcode 分词逻辑测试 ===\n")
	_test_basic_glitch()
	_test_multiple_tags()
	_test_no_tags()
	_test_empty()
	_test_unclosed_tag()
	_test_tag_with_params()
	_test_only_bbcode()
	_test_nested_like()
	print("\n=== 全部测试完成 ===\n")
	quit()


func _tokenize_bbcode(text: String) -> Array:
	var result: Array = []
	var i := 0
	var current_literal := ""

	while i < text.length():
		if text[i] == "[":
			var close_bracket := text.find("]", i)
			if close_bracket == -1:
				current_literal += text[i]
				i += 1
				continue

			var tag_section := text.substr(i + 1, close_bracket - i - 1)

			if tag_section.begins_with("/"):
				current_literal += text[i]
				i += 1
				continue

			var space_idx := tag_section.find(" ")
			var tag_name: String
			if space_idx == -1:
				tag_name = tag_section
			else:
				tag_name = tag_section.substr(0, space_idx)

			if tag_name.is_empty():
				current_literal += text[i]
				i += 1
				continue

			var closing_tag := "[/%s]" % tag_name
			var closing_idx := text.find(closing_tag, close_bracket + 1)

			if closing_idx == -1:
				current_literal += text[i]
				i += 1
				continue

			var bbcode_text := text.substr(i, closing_idx + closing_tag.length() - i)

			if not current_literal.is_empty():
				result.append({"is_bbcode": false, "text": current_literal})
				current_literal = ""

			result.append({"is_bbcode": true, "text": bbcode_text})
			i = closing_idx + closing_tag.length()
		else:
			current_literal += text[i]
			i += 1

	if not current_literal.is_empty():
		result.append({"is_bbcode": false, "text": current_literal})

	return result


func _print_segments(segments: Array) -> void:
	for seg in segments:
		print("  [%s] \"%s\"" % ["BB" if seg["is_bbcode"] else "LIT", seg["text"]])


func _assert(condition: bool, msg: String) -> void:
	if condition:
		print("  ✅ %s" % msg)
	else:
		printerr("  ❌ FAIL: %s" % msg)


func _test_basic_glitch() -> void:
	print("[TEST 1] 基础 [glitch]...[/glitch]")
	var text := "风夹着一股[glitch]柴烟[/glitch]味。"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 3, "应有 3 个段")
	_assert(not segs[0]["is_bbcode"] and segs[0]["text"] == "风夹着一股", "段0: 普通文本")
	_assert(segs[1]["is_bbcode"] and segs[1]["text"] == "[glitch]柴烟[/glitch]", "段1: bbcode块")
	_assert(not segs[2]["is_bbcode"] and segs[2]["text"] == "味。", "段2: 普通文本")
	print()


func _test_multiple_tags() -> void:
	print("[TEST 2] 多个不同标签")
	var text := "还有[glitch]抖[/glitch]和[wave]飘[/wave]的感觉。"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 5, "应有 5 个段")
	_assert(segs[1]["text"] == "[glitch]抖[/glitch]", "段1: glitch块")
	_assert(segs[3]["text"] == "[wave]飘[/wave]", "段3: wave块")
	print()


func _test_no_tags() -> void:
	print("[TEST 3] 无 BBCode 标签")
	var text := "普通文本，没有任何标签。"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 1, "应有 1 个段")
	_assert(not segs[0]["is_bbcode"] and segs[0]["text"] == text, "全量普通文本")
	print()


func _test_empty() -> void:
	print("[TEST 4] 空字符串")
	var segs := _tokenize_bbcode("")
	_print_segments(segs)
	_assert(segs.size() == 0, "应有 0 个段")
	print()


func _test_unclosed_tag() -> void:
	print("[TEST 5] 未闭合的标签")
	var text := "开头[glitch]没有闭合标签"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 1, "应有 1 个段（全部当作普通文本）")
	_assert(not segs[0]["is_bbcode"] and segs[0]["text"] == text, "全量普通文本")
	print()


func _test_tag_with_params() -> void:
	print("[TEST 6] 带参数的标签")
	var text := "有[glitch level=5]抖动[/glitch]效果"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 3, "应有 3 个段")
	_assert(segs[1]["is_bbcode"] and segs[1]["text"] == "[glitch level=5]抖动[/glitch]", "段1: bbcode含参数")
	print()


func _test_only_bbcode() -> void:
	print("[TEST 7] 纯 BBCode 文本")
	var text := "[glitch]全部都是抖动[/glitch]"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 1, "应有 1 个段")
	_assert(segs[0]["is_bbcode"] and segs[0]["text"] == text, "纯bbcode块")
	print()


func _test_nested_like() -> void:
	print("[TEST 8] 含有 Zalgo 乱码的 glitch 块（模拟真实数据）")
	var text := "风夹着一股[glitch]柴̧̧̱̰̣̱̈̄̃̇́̀́̄烟̄̂̈̆̂̇̌̀[/glitch]味。"
	var segs := _tokenize_bbcode(text)
	_print_segments(segs)
	_assert(segs.size() == 3, "应有 3 个段")
	_assert(segs[1]["is_bbcode"], "段1: 是bbcode块")
	_assert(segs[1]["text"].begins_with("[glitch]"), "段1: glitch 标签开头")
	_assert(segs[1]["text"].ends_with("[/glitch]"), "段1: glitch 标签结尾")
	print()
