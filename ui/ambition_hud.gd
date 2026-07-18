class_name AmbitionHUD extends Control
# g说这里要分离判断逻辑，但我是一个独立游戏设计师🤓

var ambition
@onready var vague_label: Label = $Mar/VBox/VagueText
@onready var ambition_label: Label = $Mar/VBox/StageName
@onready var deadline_label: Label = $Mar/VBox/DeadlineResult
@onready var dynamic_state_label: Label = $Mar/VBox/DynamicStateLabel
@onready var progress_dots_label: Label = $Mar/VBox/ProgressDots

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

	# ── StyleManager: 绑定 decay_dirt_crack 策略（必须走在所有 return 之前）──
	_bind_decay_dirt_crack_strategy()

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
	if not ambition or ambition.tracked_property.is_empty():
		_tracked_prop = null
		Logging.warn("AmbitionHUD: No tracked property configured for ambition")
		return
	
	_tracked_prop = Database.get_property(ambition.tracked_property)
	if not _tracked_prop:
		Logging.err("AmbitionHUD: tracked property '%s' not found in Database" % ambition.tracked_property)
	else:
		Logging.info("AmbitionHUD: Resolved tracked property '%s' (soft_max=%d, val=%d)" % [ambition.tracked_property, _tracked_prop.soft_max, PlayerState.get_stat_val(ambition.tracked_property)])

func _update_progress() -> void:
	if not _tracked_prop:
		progress_dots_label.hide()
		Logging.warn("AmbitionHUD: No tracked property to display progress")
		return
	
	var val: int = PlayerState.get_stat_val(ambition.tracked_property)
	# soft_max 优先；若未配置（默认 -1）则回退到 hard_max
	var max_val: int = _tracked_prop.soft_max if _tracked_prop.soft_max > 0 else _tracked_prop.hard_max
	
	var dots_text := _generate_dots(val, max_val)
	if dots_text.is_empty():
		progress_dots_label.hide()
		return
	
	progress_dots_label.show()
	AudioManager.play_sfx_category("ink_flip", 0.05)
	
	# 附加文学化描述文本（如果有 staged_perceptions 配置）
	if _tracked_prop.staged_perceptions.size() > 0:
		var perception_text = _tracked_prop.get_staged_perception_text()
		Logging.info("AmbitionHUD: dots='%s' + perception='%s'" % [dots_text, perception_text])
		progress_dots_label.text = "%d(%s)  %s" % [val, perception_text, dots_text]
	else:
		Logging.info("AmbitionHUD: dots='%s' (no staged_perceptions)" % dots_text)
		progress_dots_label.text = "%d  %s" % [val, dots_text]


## 将 val / max_val 映射为 5 档 Unicode 圆点：
##   0~9%→○○○○○  10~19%→◐○○○○  20~29%→●○○○○ ... 90~99%→●●●●◐  100%→●●●●●
func _generate_dots(val: float, max_val: float) -> String:
	if max_val <= 0:
		return ""
	
	var pct: float = clampf(val / max_val, 0.0, 1.0)
	var filled: int = floori(pct * 5)              # 完整 ● 数量
	var is_half: bool = (pct * 10) >= (filled * 2 + 1)  # 是否有半圆 ◐
	var empty: int = 5 - filled - (1 if is_half else 0)
	
	var result := ""
	for _i in filled:
		result += "●"
	if is_half:
		result += "◐"
	for _i in empty:
		result += "○"
	
	return result

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

# ── StyleManager: decay_dirt_crack 策略绑定 ────────────────

## 向 StyleManager 注册自身并绑定 decay_dirt_crack 策略
## progress=0 时 progress=0.0（完好），progress=100 时 progress=1.0（彻底毁坏）
const DECAY_MATERIAL := preload("res://shaders/decay_shader_material.tres")

func _bind_decay_dirt_crack_strategy() -> void:
	var data := StyleData.new()
	data.strategy_name = "decay_dirt_crack"
	data.target_property = "progress"
	data.start_property_value = 0.0
	data.target_property_value = 100.0
	# shader 只在 progress ∈ [0.27, 0.326] 有可见效果，remap 到这个区间
	data.progress_output_min = 0.27
	data.progress_output_max = 0.326
	data.shader_material = DECAY_MATERIAL
	data.shader_parameter_names = ["progress"]
	data.container = self
	# AmbitionHUD 是 TextureRect，非 PanelContainer，stylebox 不适用
	StyleManager.bind(data)
	# decay_dirt_crack 仅在事件触发时由 StyleStrategyOperator 激活，默认不挂载 shader
	Logging.info("AmbitionHUD: decay_dirt_crack 策略已注册 → AmbitionHUD (等待事件激活, progress remap: 0→[%.3f, %.3f])" % [data.progress_output_min, data.progress_output_max])
