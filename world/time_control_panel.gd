extends CanvasLayer # 或者你的根节点类型

@onready var label_era: Label = $Margin/Panel/Margin/VBox/Label_Era
@onready var label_greg: Label = $Margin/Panel/Margin/VBox/Label_Gregorian

# 年号词典：[起始年份, 结束年份, 年号名称, 使用"年"还是"载"]
const ERA_TABLE = [
	# --- 初唐：打天下与贞观之治 ---
	[618, 627, "武德", "年"], # 唐高祖 李渊
	[627, 650, "贞观", "年"], # 唐太宗 李世民
	[650, 656, "永徽", "年"], # 唐高宗 李治 (起手式)
	[656, 661, "显庆", "年"],
	[661, 664, "龙朔", "年"],
	[664, 666, "麟德", "年"],
	[666, 668, "乾封", "年"],
	[668, 670, "总章", "年"],
	[670, 674, "咸亨", "年"],
	[674, 676, "上元", "年"],
	[676, 679, "仪凤", "年"],
	[679, 680, "调露", "年"],
	[680, 681, "永隆", "年"],
	[681, 682, "开耀", "年"],
	[682, 683, "永淳", "年"],
	[683, 684, "弘道", "年"],
	# --- 武周代唐：改名狂魔武则天 ---
	[684, 685, "光宅", "年"], # 此年极乱，嗣圣/文明被我无情抹除了
	[685, 689, "垂拱", "年"],
	[689, 690, "永昌", "年"],
	[690, 692, "天授", "年"], # 就在这年，大唐变成了武周
	[692, 694, "长寿", "年"],
	[694, 695, "延载", "年"],
	[695, 696, "万岁登封", "年"], # 不要问我为什么叫这么中二的名字
	[696, 697, "万岁通天", "年"],
	[697, 698, "神功", "年"],
	[698, 700, "圣历", "年"],
	[700, 701, "久视", "年"],
	[701, 705, "长安", "年"],
	# --- 盛唐：复辟与极盛 ---
	[705, 707, "神龙", "年"], # 神龙政变，唐中宗复辟
	[707, 710, "景龙", "年"],
	[710, 712, "景云", "年"], # 唐睿宗
	[712, 713, "先天", "年"], # 唐玄宗 李隆基上号
	[713, 742, "开元", "年"], # 最牛逼的时代来了
	# --- 中唐：安史之乱与藩镇割据 ---
	[742, 756, "天宝", "载"], # 唯一用“载”的时代开始了
	[756, 758, "至德", "载"], # 肃宗在灵武登基，继续用“载”
	[758, 760, "乾元", "年"], # 恢复用“年”
	[760, 762, "上元", "年"],
	[762, 763, "宝应", "年"], # 代宗
	[763, 765, "广德", "年"],
	[765, 766, "永泰", "年"],
	[766, 780, "大历", "年"],
	[780, 784, "建中", "年"], # 德宗
	[784, 785, "兴元", "年"],
	[785, 805, "贞元", "年"],
	[805, 806, "永贞", "年"], # 顺宗 (二王八司马事件)
	[806, 821, "元和", "年"], # 宪宗 (元和中兴)
	# --- 晚唐：牛李党争与宦官专权 ---
	[821, 825, "长庆", "年"], # 穆宗
	[825, 827, "宝历", "年"], # 敬宗
	[827, 836, "太和", "年"], # 文宗 (甘露之变)
	[836, 841, "开成", "年"],
	[841, 847, "会昌", "年"], # 武宗 (会昌灭佛)
	[847, 860, "大中", "年"], # 宣宗 (大中之治)
	[860, 874, "咸通", "年"], # 懿宗
	[874, 880, "乾符", "年"], # 僖宗 (黄巢起义开始)
	[880, 881, "广明", "年"],
	[881, 885, "中和", "年"],
	[885, 888, "光启", "年"],
	[888, 889, "文德", "年"],
	# --- 终局：大厦将倾 ---
	[889, 890, "龙纪", "年"], # 昭宗
	[890, 892, "大顺", "年"],
	[892, 894, "景福", "年"],
	[894, 898, "乾宁", "年"],
	[898, 901, "光化", "年"],
	[901, 904, "天复", "年"],
	[904, 907, "天祐", "年"]  # 哀帝 (907年被朱温篡位，大唐剧终)
]


func on_start_end_btn_pressed():
	if TimeService.time_start:
		TimeService.pause()
	else: TimeService.play()

func _on_next_poet_button_pressed() -> void:
	if Global.current_selected_poet:
		TimeService.jump_to(
			Global.current_selected_poet.get_next_path_point(
			Global.year).
		point_year)
	else:
		Global.request_text_popup.emit('choose a poet')

func speed_up():
	TimeService.speed_up()

func slow_down():
	TimeService.slow_down()

func _ready():
	# 监听时间流动
	Global.year_changed.connect(_on_year_changed)
	Global.speed_changed.connect(on_speed_changed)
	
func on_speed_changed(spd: float):
	if spd == -1:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "烂柯(⏸)"
	elif spd >= 30:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "驷马难追(4)"
	elif spd >= 21:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "光阴似箭(3)"
	elif spd >= 12:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "时不我待(2)"
	elif spd >= 3:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "度日如年(1)"

	
func _on_year_changed(current_float_year: float):
	var current_year = int(floor(current_float_year))
	# 比如 755.5 -> 0.5 * 12 + 1 = 7月
	var current_month = int(floor((current_float_year - current_year) * 12.0)) + 1 
	
	# 1. 更新公元小字 (直白，功能性)
	label_greg.text = "公元 %d 年 %d 月" % [current_year, current_month]
	
	# 2. 查表计算大唐年号 (氛围，沉浸感)
	var era_text = "未知年号"
	for era in ERA_TABLE:
		if current_year >= era[0] and current_year <= era[1]:
			var era_year_num = current_year - era[0] + 1
			var num_str = _get_chinese_number(era_year_num)
			
			# 拼装：比如 "天宝 十四 载"
			era_text = "%s %s %s" % [era[2], num_str, era[3]]
			break
			
	label_era.text = era_text

# 一个简单的数字转中文辅助函数（1-99够用了）
func _get_chinese_number(num: int) -> String:
	if num == 1: return "元" # 第一年永远叫元年/元载
	
	var digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if num <= 10: return digits[num]
	if num < 20: return "十" + digits[num % 10]
	
	var tens = num / 10
	var ones = num % 10
	var res = digits[tens] + "十"
	if ones > 0: res += digits[ones]
	return res
