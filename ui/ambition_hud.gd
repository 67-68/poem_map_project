class_name AmbitionHUD extends Control
# g说这里要分离判断逻辑，但我是一个独立游戏设计师🤓

var ambition
@onready var vague_label: Label = $Mar/HBox/VBox/VagueText
@onready var timer_rect: TextureRect = $Mar/HBox/VBox/HBox/IncenseTimer
@onready var time_label: Label = $Mar/HBox/VBox/HBox/TimeLabel
@onready var ambition_label: Label = $Mar/HBox/VBox/HBox/StageName
@onready var deadline_label: Label = $Mar/HBox/VBox/DeadlineResult
@onready var dynamic_state_label: Label = $Mar/HBox/VBox/DynamicStateLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ambition = PlayerState.ambition
	if not ambition:
		Logging.err("草... AmbitionHUD 没有配置 config，你是打算让 UI 凭空捏造文案吗？😭")
		return
		
	# 1. 挂载阶段名称 (静态)
	ambition_label.text = ambition.name
	var stage_name_placeholer = ambition.leveled_stages[ambition.current_stage] # placeholder
	deadline_label.text = ambition.deadline_warning

	var deadline_text = TimeService.get_era_text(int(Global.year))
	time_label.text = deadline_text

	var buff_description = ambition.buff_description
	vague_label.text = ambition.description + "\n" + buff_description
	
	# 2. 订阅全局状态变更 (这就是提线木偶的线！)
	# 假设你的单例叫 PlayerState，信号叫 stat_changed
	PlayerState.player_stat_changed.connect(_on_model_stat_changed)
	
	# 3. 初始化时，主动拉取一次 Model 兜底
	_on_model_stat_changed("")

func _on_model_stat_changed(prop_name):
	var current_stage_name = ambition.leveled_stages[ambition.current_stage]
	var operators = _find_requirement_by_stage_id(current_stage_name)
	if operators and operators.compare(PlayerState):
		ambition.current_stage += 1
		var perception = _find_perception_by_stage_id(ambition.leveled_stages[ambition.current_stage])
		if perception:
			dynamic_state_label.text = perception.perception_text

func _find_requirement_by_stage_id(stage_id: String) -> BaseRequirements:
	for requirement in ambition.staged_requirements:
		if requirement.stage_id == stage_id:
			return requirement.requirement
	return null

func _find_perception_by_stage_id(stage_id: String) -> StagedPerceptionData:
	for perception in ambition.staged_perceptions:
		if perception.stage_id == stage_id:
			return perception
	return null
