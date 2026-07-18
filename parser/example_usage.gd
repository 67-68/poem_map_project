# DSL Parser 使用示例
class_name TestDSLParser extends Node

static func test_parsing():
    # 示例CSV数据行（新语法）
    var example_csv_row = {
        "Event_ID": "evt_changan_01",
        "Trigger_Tags": "actor:status:drunk,city:econ:prosperous,action:study:poetry,intel:event:anlushan_rebel",
        "requirements": "prop_gt(name=money, val=50), trait_has(name=official)",
        "Title": tr("EVT_TEST1_TITLE"),
        "Desc": tr("EVT_TEST1_DESC"),
        "Opt_A_Text": tr("CODE_EXAMPLE_USAGE_77392360EA"),
        "Opt_A_Req": "prop_gt(name=money, val=100)",
        "Opt_A_Result": "prop_sub(name=money, val=100), trait_add(name=corrupt)",
        "Opt_B_Text": tr("EVT_LIBAI_FORCE_CHANGHE_OPT0_TITLE"),
        "Opt_B_Req": "trait_has(name=proud)",
        "Opt_B_Result": "prop_add(name=prestige, val=50)",
        "weight": "15.5",
        "background": "bg_rural_poor"
    }
    
    # 解析事件
    var event = DSLParser.parse(example_csv_row)
    
    if event:
        Logging.info("成功解析事件:  %s" % [event.uuid])
        Logging.info("标题:  %s" % [event.name])
        Logging.info("描述:  %s" % [event.description])
        Logging.info("触发标签:  %s" % [event._target_tags])
        Logging.info("选项数量:  %s" % [event.options.size()])
        Logging.info("图片存在:  %s" % [event.icon != null])
        
        # 验证解析结果
        if DSLParser.validate_event(event):
            Logging.info("事件验证通过")
        else:
            Logging.info("事件验证失败")
    else:
        Logging.info("解析事件失败")

# 批量解析示例
func test_batch_parsing():
    var csv_data = [
        {
            "Event_ID": "evt_changan_01",
            "Trigger_Tags": "actor:status:drunk,city:econ:prosperous",
            "requirements": "prop_gt(name=money, val=50)",
            "Title": tr("EVT_TEST1_TITLE"),
            "Desc": tr("CODE_EXAMPLE_USAGE_BB27B4F5E7"),
            "Opt_A_Text": tr("CODE_EXAMPLE_USAGE_77392360EA"),
            "Opt_A_Req": "prop_gt(name=money, val=100)",
            "Opt_A_Result": "prop_sub(name=money, val=100), trait_add(name=corrupt)",
            "Opt_B_Text": tr("EVT_LIBAI_FORCE_CHANGHE_OPT0_TITLE"),
            "Opt_B_Req": "trait_has(name=proud)",
            "Opt_B_Result": "prop_add(name=prestige, val=50)"
        },
        {
            "Event_ID": "evt_market_02",
            "Trigger_Tags": "action:study:poetry,city:econ:prosperous",
            "requirements": "prop_gt(name=prestige, val=30)",
            "Title": tr("CODE_EXAMPLE_USAGE_34A3241C28"),
            "Desc": tr("CODE_EXAMPLE_USAGE_3A241EDFCE"),
            "Opt_A_Text": tr("CODE_EXAMPLE_USAGE_DB5BB25CD0"),
            "Opt_A_Req": "prop_gt(name=prestige, val=20)",
            "Opt_A_Result": "prop_add(name=prestige, val=10), prop_sub(name=money, val=20)",
            "Opt_B_Text": tr("CODE_EXAMPLE_USAGE_A456365D59"),
            "Opt_B_Result": "prop_add(name=prestige, val=5)"
        }
    ]
    
    var events = DSLParser.parse_csv_data(csv_data)
    Logging.info("批量解析完成，共解析 %d 个事件" % events.size())
    
    for event in events:
        Logging.info("- 事件: %s, 选项数: %d" % [event.uuid, event.options.size()])

# 测试各种DSL格式（新语法）
func test_dsl_formats():
    Logging.info("\n=== 测试DSL格式解析（新语法）===")
    
    # 测试触发标签解析
    var tags = MicroDSLParser.parse_tags("actor:status:drunk,city:econ:prosperous,action:study:poetry")
    Logging.info("触发标签:  %s" % [tags])
    
    # 测试属性需求解析（新语法）
    var prop_req = MicroDSLParser.parse_property_requirement("prop_gt(name=money, val=50)")
    if prop_req:
        Logging.info("属性需求: %s %s %d" % [prop_req.property, ">", prop_req.value])
    
    # 测试特性需求解析（新语法）
    var trait_req = MicroDSLParser.parse_trait_requirement("trait_has(name=official)")
    Logging.info("特性需求解析:  %s" % [trait_req != null])
    
    # 测试结果操作符解析（新语法）
    var operators = MicroDSLParser.parse_consequence_operators("prop_sub(name=money, val=100), trait_add(name=corrupt)")
    Logging.info("结果操作符数量:  %s" % [operators.size()])
    
    # 测试复合需求解析（新语法）
    var complex_req_str = "prop_gt(name=money, val=50), prop_gt(name=prestige, val=30)"
    var complex_req = DSLParser.parse_requirements(complex_req_str)
    Logging.info("复合需求解析:  %s" % [complex_req != null])
