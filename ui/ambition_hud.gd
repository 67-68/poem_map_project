class_name AmbitionHUD extends Control
# g说这里要分离判断逻辑，但我是一个独立游戏设计师🤓

var ambition
@onready var vague_label: Label = $Mar/HBox/VBox/VagueText
@onready var timer_rect: TextureRect = $Mar/HBox/VBox/HBox/IncenseTimer
@onready var time_label: Label = $Mar/HBox/VBox/HBox/TimeLabel
@onready var ambition_label: Label = $Mar/HBox/VBox/HBox/StageName
@onready var deadline_label: Label = $Mar/HBox/VBox/DeadlineResult
@onready var dynamic_state_label: Label = $Mar/HBox/VBox/DynamicStateLabel
@onready var progress_bar: ProgressBar = $Mar/HBox/VBox/ProgressContainer/ProgressFrame/ProgressBar
@onready var progress_label: Label = $Mar/HBox/VBox/ProgressContainer/ProgressLabel
@onready var progress_overlay_label: Label = $Mar/HBox/VBox/ProgressContainer/ProgressFrame/ProgressOverlayLabel

var _tracked_prop: Property  # 缓存的属性资源引用，避免每次查 Database

func _ready() -> void:
	Logging.info("AmbitionHUD: Starting initialization")
	PlayerState.player_stat_changed.connect(_on_model_stat_changed)
	Logging.info("AmbitionHUD: Connected to player_stat_changed signal")
	
	# 修正你的幽灵 Lambda：必须更新自身的 ambition 引用！
	PlayerState.ambition_changed.connect(func(new_ambition): 
		Logging.info("AmbitionHUD: Received ambition_changed signal with new ambition: %s" % str(new_ambition))
		ambition = new_ambition # <--- 救命的赋值
		_load_static()
		_on_model_stat_changed('')
	)
	Logging.info("ambition hud connected to player stat changed signal")

	# 2. 状态嗅探与潜伏模式
	Logging.info("AmbitionHUD: Checking initial ambition state")
	ambition = PlayerState.ambition
	if not ambition:
		# 允许初始状态没有抱负！只是隐藏或者报警，绝对不能 return 断送生命周期！
		Logging.warn("HUD 还没等到抱负数据，进入潜伏模式等待信号...")
		hide() # 建议直接隐藏，等有了数据再显示
		Logging.info("AmbitionHUD: Entering stealth mode, hiding HUD")
		return # 这里的 return 是安全的，因为信号已经绑好了
	
	# 3. 如果一开始就有数据，正常兜底（已注册 HoverPopupManager，不主动 show）
	Logging.info("AmbitionHUD: Initial ambition found, loading static content")
	_load_static()
	_on_model_stat_changed("")
	Logging.info("AmbitionHUD: Initialization complete")
	
func _load_static():
	if not ambition: return
	# 不再主动 show()——由 HoverPopupManager 控制显示时机
	Logging.info("AmbitionHUD: Loading static content for ambition: %s" % str(ambition))

	# 1. 挂载阶段名称 (静态)
	Logging.info("AmbitionHUD: Setting ambition name: %s" % ambition.name)
	ambition_label.text = ambition.name
	if ambition.current_stage < 0 or ambition.current_stage >= ambition.leveled_stages.size():
		Logging.err("AmbitionHUD: current_stage %d out of bounds [0, %d] for ambition %s" % [ambition.current_stage, ambition.leveled_stages.size() - 1, ambition.name])
	Logging.info("AmbitionHUD: Setting deadline warning: %s" % ambition.deadline_warning)
	deadline_label.text = ambition.deadline_warning

	var deadline_text = TimeService.get_era_text(int(GameState.year))
	Logging.info("AmbitionHUD: Setting time text: %s" % deadline_text)
	time_label.text = deadline_text

	var full_text = ambition.description
	Logging.info("AmbitionHUD: Setting vague text: %s" % full_text)
	vague_label.text = full_text

	# 初始化阶段感知文本（动态状态标签）
	var initial_perception = _find_perception_by_stage_id(ambition.leveled_stages[ambition.current_stage])
	if initial_perception:
		dynamic_state_label.text = initial_perception.perception_text
		Logging.info("AmbitionHUD: Initial perception text set: %s" % initial_perception.perception_text)

	# 解析追踪的属性资源，并刷新进度显示
	_resolve_tracked_property()
	_update_progress()
	Logging.info("AmbitionHUD: Static content loading complete")

func _resolve_tracked_property() -> void:
	"""根据 ambition.tracked_property 从 Database 中取出对应的 Property 资源"""
	if not ambition or ambition.tracked_property.is_empty():
		_tracked_prop = null
		Logging.warn("AmbitionHUD: No tracked property configured for ambition")
		return
	
	_tracked_prop = Database.get_property(ambition.tracked_property)
	if not _tracked_prop:
		Logging.err("AmbitionHUD: tracked property '%s' not found in Database" % ambition.tracked_property)
	else:
		Logging.info("AmbitionHUD: Resolved tracked property '%s' (soft_max=%d, val=%d)" % [ambition.tracked_property, _tracked_prop.soft_max, _tracked_prop.val])

func _update_progress() -> void:
	"""更新进度显示：优先展示属性的 staged_perception 文本，无配置时回退到裸数字"""
	if not _tracked_prop:
		progress_bar.hide()
		progress_label.hide()
		progress_overlay_label.hide()
		Logging.warn("AmbitionHUD: No tracked property to display progress")
		return
	
	var val = _tracked_prop.val
	var soft_max = _tracked_prop.soft_max
	
	# 优先使用设计师在 .tres 中配置的阶段感知文本（文学化描述）
	if _tracked_prop.staged_perceptions.size() > 0:
		var perception_text = _tracked_prop.get_staged_perception_text()
		Logging.info("AmbitionHUD: Using staged perception text: '%s' (val=%d)" % [perception_text, val])
		if soft_max >= 0:
			progress_bar.show()
			progress_overlay_label.show()
			progress_label.hide()
			progress_bar.max_value = soft_max
			progress_bar.value = val
			progress_overlay_label.text = perception_text
		else:
			progress_bar.hide()
			progress_overlay_label.hide()
			progress_label.show()
			progress_label.text = perception_text
		return
	
	# 无设计师配置 → 回退裸数字显示（旧逻辑）
	Logging.info("AmbitionHUD: No staged_perceptions configured, falling back to raw numbers")
	if soft_max >= 0:
		progress_bar.show()
		progress_overlay_label.show()
		progress_label.hide()
		progress_bar.max_value = soft_max
		progress_bar.value = val
		progress_overlay_label.text = "%d / %d" % [val, soft_max]
		Logging.info("AmbitionHUD: ProgressBar updated: %d/%d" % [val, soft_max])
	else:
		progress_bar.hide()
		progress_overlay_label.hide()
		progress_label.show()
		progress_label.text = str(val)
		Logging.info("AmbitionHUD: Progress number updated: %d" % val)

func _on_model_stat_changed(_prop_name):
	Logging.info("AmbitionHUD: Stat changed signal received, prop: %s" % _prop_name)
	if not ambition:
		Logging.warn('AmbitionHUD: No ambition available for display')
		return
	# 不再主动 show()——由 HoverPopupManager 控制显示时机
	Logging.info("ambition hud received stat changed signal")

	# 从高到低扫描所有 staged_requirements，找到第一个满足的 → 直接赋值
	var new_stage = _evaluate_stage()
	if new_stage != ambition.current_stage:
		Logging.info("AmbitionHUD: Stage changed from %d to %d" % [ambition.current_stage, new_stage])
		ambition.current_stage = new_stage
		var perception = _find_perception_by_stage_id(ambition.leveled_stages[ambition.current_stage])
		if perception:
			Logging.info("AmbitionHUD: Setting perception text: %s" % perception.perception_text)
			dynamic_state_label.text = perception.perception_text
		else:
			Logging.warn("AmbitionHUD: No perception found for stage: %s" % ambition.leveled_stages[ambition.current_stage])

	# 如果变更的属性是追踪的属性，更新进度显示
	if not ambition.tracked_property.is_empty() and _prop_name == ambition.tracked_property:
		_update_progress()

# 从高到低扫描 staged_requirements，找到第一个条件满足的 stage 索引
# 语义：满足 staged_requirements[i] 的条件 → 直接进入 staged_requirements[i].stage_id
# 无一满足 → 默认返回 stage 0（起始阶段）
func _evaluate_stage() -> int:
	for i in range(ambition.staged_requirements.size() - 1, -1, -1):
		var req_data = ambition.staged_requirements[i]
		if req_data.requirement and req_data.requirement.compare(PlayerState):
			var stage_idx = ambition.leveled_stages.find(req_data.stage_id)
			if stage_idx >= 0:
				Logging.info("AmbitionHUD: Requirement matched for stage '%s' (idx=%d)" % [req_data.stage_id, stage_idx])
				return stage_idx
			else:
				Logging.warn("AmbitionHUD: stage_id '%s' not found in leveled_stages" % req_data.stage_id)
	return 0

func _find_perception_by_stage_id(stage_id: String) -> StagedPerceptionData:
	Logging.info("AmbitionHUD: Searching for perception with stage_id: %s" % stage_id)
	for perception in ambition.staged_perceptions:
		if perception.stage_id == stage_id:
			Logging.info("AmbitionHUD: Found perception for stage: %s" % stage_id)
			return perception
	Logging.warn("AmbitionHUD: No perception found for stage_id: %s" % stage_id)
	return null
