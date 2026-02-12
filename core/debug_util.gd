# ----------------------------------------------------------------
# 大唐地理系统 - 运行时视觉调试工具 (The Auditor)
# ----------------------------------------------------------------
# 资深架构师评价：当 Shader 欺骗了你，就去翻它的底牌。
# ----------------------------------------------------------------
class_name DebugUtils extends Node

# 方案 A：暴力导出法 (最推荐，直接看原始像素)
# 将 ImageTexture 导出为 PNG 文件
static func save_texture_to_disk(tex: Texture2D, file_name: String = "debug_baked_map.png"):
	if not tex:
		printerr("💀 错误：你给我的纹理是空的，你想导出一片虚无吗？")
		return

	var img: Image = tex.get_image()
	var path = "user://" + file_name # 通常在 AppData/Roaming/Godot/app_userdata/项目名/
	
	var err = img.save_png(path)
	if err == OK:
		# 这里会打印出真实物理路径，直接去资源管理器打开它
		print("✅ 审计成功！图片已保存至: ", ProjectSettings.globalize_path(path))
	else:
		printerr("❌ 导出失败，错误代码: ", err)

# 方案 B：实时监视窗 (Quick & Dirty)
# 在屏幕左上角强行创建一个预览图层
static func show_runtime_preview(parent: Node, tex: Texture2D):
	# 如果已经有了，先删掉旧的
	if parent.has_node("DebugPreview"):
		parent.get_node("DebugPreview").queue_free()
		
	var rect = TextureRect.new()
	rect.name = "DebugPreview"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# 设置一个显眼的位置和大小
	rect.custom_minimum_size = Vector2(300, 300)
	rect.position = Vector2(20, 20)
	
	# 给它一个紫色的边框，防止它和背景混在一起 🤣
	var frame = ReferenceRect.new()
	frame.border_color = Color.PURPLE
	frame.editor_only = false
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.add_child(frame)
	
	parent.add_child(rect)
	print("👀 运行时预览已挂载，就在你屏幕左上角。")

# ----------------------------------------------------------------
# 架构师的调试建议：
# 1. 如果导出的 PNG 是全黑的，说明你的 bake_index_map 循环里逻辑全灭了。
# 2. 如果导出的 PNG 是全红的（R=1.0），说明你的颜色匹配容差 (Tolerance) 设置得太极端了。
# 3. 重点看 Alpha 通道：如果 Alpha 是 0，Shader 里的 mask 就会把你的大唐直接抹除。💀
