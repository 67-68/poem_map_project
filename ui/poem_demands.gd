extends PanelContainer

## 诗词需求面板 — V7: 从 Database.recipe_index 遍历食谱，查 Imaginary 填充
##
## V7 变更: concept 引用改为查 Imaginary（Database.imaginaries_detail）

const _POEM_DEMAND_SCENE := preload("res://ui/poem_demand.tscn")


func _ready() -> void:
	Logging.info('PoemDemands: initializing V7')
	call_deferred("_populate")


func _populate() -> void:
	var container := $PoemDemands/V
	if not container:
		Logging.warn('PoemDemands: PoemDemands/V 容器不存在，跳过填充')
		return

	for child in container.get_children():
		child.queue_free()

	for recipe in Database.recipe_index.values():
		if not (recipe is Poem):
			continue

		var demand := _POEM_DEMAND_SCENE.instantiate()

		var title_label := demand.get_node("Title") as Label
		if title_label:
			title_label.text = tr(recipe.name)

		# 查询 Imaginary 的中文名
		var frag_names: Array[String] = []
		for frag_uuid in recipe.required_fragments:
			var imag = Database.get_imaginary_detail(frag_uuid)
			if imag and imag is Imaginary and not imag.name.is_empty():
				frag_names.append(imag.name)
			else:
				frag_names.append(frag_uuid)

		var demand_label := demand.get_node("ImaginaryDemand") as Label
		if demand_label:
			demand_label.text = " + ".join(frag_names)

		container.add_child(demand)

	Logging.info('PoemDemands: populated, %d recipes rendered' % Database.recipe_index.size())
