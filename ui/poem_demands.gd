extends PanelContainer

## 诗词需求面板 — 从 Database.recipe_index 遍历食谱，实例化 poem_demand.tscn 并填充
##
## 完全自治：_ready() 中自填充，不依赖外部调用

const _POEM_DEMAND_SCENE := preload("res://ui/poem_demand.tscn")


func _ready() -> void:
	Logging.info('PoemDemands: initializing, scheduling deferred populate')
	call_deferred("_populate")


func _populate() -> void:
	var container := $PoemDemands/V
	if not container:
		Logging.warn('PoemDemands: PoemDemands/V 容器不存在，跳过填充')
		return

	# 清空已有子节点（tscn 中的默认实例）
	for child in container.get_children():
		child.queue_free()

	# 遍历 recipe_index 构建每次创作需求卡片
	for recipe in Database.recipe_index.values():
		if not (recipe is Poem):
			continue

		var demand := _POEM_DEMAND_SCENE.instantiate()

		# 填充诗词名称
		var title_label := demand.get_node("Title") as Label
		if title_label:
			title_label.text = recipe.name

		# 填充意象要求 —— 查 concept 中文名
		var frag_names: Array[String] = []
		for frag_uuid in recipe.required_fragments:
			var concept := Database.get_imaginary(frag_uuid) as ImaginaryConcept
			if concept and not concept.name.is_empty():
				frag_names.append(concept.name)
			else:
				# fallback: 直接显示 UUID
				frag_names.append(frag_uuid)

		var demand_label := demand.get_node("ImaginaryDemand") as Label
		if demand_label:
			demand_label.text = " + ".join(frag_names)

		container.add_child(demand)

	Logging.info('PoemDemands: populated, %d recipes rendered' % Database.recipe_index.size())
