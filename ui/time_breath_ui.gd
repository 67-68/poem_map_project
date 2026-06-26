class_name TimeBreathUI extends CanvasLayer

# 未来可以做节日的展示，不仅仅是四季
func _ready():
    hide()
    TimeService.on_year_tick.connect(_on_year_changed)
    TimeService.on_season_tick.connect(_on_season_changed)

func get_season_text():
    #breakpoint
    if TimeService.current_day_of_year == null:
        return "季节更替"
    var season_index = (TimeService._total_days_elapsed / 90) % 4
    match season_index:
        0:
            return "万物复苏"
        1:
            return "夏至"
        2:
            return "树叶枯黄"
        3:
            return "天寒地冻"
        _:
            return "季节更替"

# 监听 TimeService 的跨年/跨季信号
func _on_season_changed() -> void:
    show()
    var season_label = $TimeChangeReminderLabel
    if season_label != null:
        season_label.text = get_season_text()
        var tween = create_tween()
        # 🤓☝️ 只有两行核心逻辑：花 2 秒渐显，再花 2 秒渐隐
        tween.tween_property(season_label, "modulate:a", 1.0, 2.0)
        tween.tween_property(season_label, "modulate:a", 0.0, 2.0)
        tween.tween_callback(hide)

func _on_year_changed():
    OperatorFactory.create_event_operator('new_year_come')
