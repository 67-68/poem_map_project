class_name AmbitionHUD extends Control
# g说这里要分离判断逻辑，但我是一个独立游戏设计师🤓

@export var ambition: AmbitionData
@onready var vague_label: Label = $Mar/HBox/VBox/HBox/VagueText
@onready var timer_rect: TextureRect = $Mar/HBox/VBox/HBox/IncenseTimer
@onready var time_label: Label = $ Mar/HBox/VBox/HBox/TimeLabel
@onready var stage_label: Label = $Mar/HBox/VBox/StageName
@onready var deadline_label: Label = $Mar/HBox/VBox/Deadline
@onready var dynamic_state_label: Label = $Mar/HBox/VBox/DynamicStateLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ambition = Global.ambitions.get('first_ambition')
	if not ambition:
		Logging.err("草... AmbitionHUD 没有配置 config，你是打算让 UI 凭空捏造文案吗？😭")
		return
		
	# 1. 挂载阶段名称 (静态)
	stage_label.text = ambition.stage_name
	deadline_label.text = ambition.deadline_warning

	var deadline_text = TimeService.get_era_text(int(Global.year))
	time_label.text = deadline_text

	var buff_description = ambition.buff_description
	vague_label.text = ambition.description + "\n" + buff_description
	
	# 2. 订阅全局状态变更 (这就是提线木偶的线！)
	# 假设你的单例叫 PlayerState，信号叫 stat_changed
	PlayerState.stat_changed.connect(_on_model_stat_changed)
	
	# 3. 初始化时，主动拉取一次 Model 兜底
	_on_model_stat_changed()

func _on_model_stat_changed():
	var current_stage_name = ambition.leveled_stages[ambition.current_stage]
	var operators = ambition.staged_requirements.get(current_stage_name) as ComplexRequirements
	if operators.compare(PlayerState):
		ambition.current_stage += 1
		var vague_text = ambition.staged_perceptions[ambition.leveled_stages[ambition.current_stage]]
		dynamic_state_label.text = vague_text