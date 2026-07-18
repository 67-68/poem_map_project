class_name TimeBreathUI extends CanvasLayer

# 未来可以做节日的展示，不仅仅是四季
func _ready():
    hide()
    TimeService.on_year_tick.connect(_on_year_changed)
    TimeService.on_season_tick.connect(_on_season_changed)

func get_season_text():
    #breakpoint
    if TimeService.current_day_of_year == null:
        return tr("CODE_TIME_BREATH_UI_1640D0A850")
    var season_index = (TimeService._total_days_elapsed / 90) % 4
    match season_index:
        0:
            return tr("CODE_TIME_BREATH_UI_E451C2C5EF")
        1:
            return tr("CODE_TIME_BREATH_UI_63B8A20FF1")
        2:
            return tr("CODE_TIME_BREATH_UI_D99449E075")
        3:
            return tr("CODE_TIME_BREATH_UI_364138561F")
        _:
            return tr("CODE_TIME_BREATH_UI_1640D0A850")

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
