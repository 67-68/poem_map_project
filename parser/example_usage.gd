# DSL Parser 使用示例
class_name TestDSLParser extends Node

static func test_parsing():
    # 示例CSV数据行（新语法）
    var example_csv_row = {
        "Event_ID": "evt_changan_01",
        "Trigger_Tags": "actor:status:drunk,city:econ:prosperous,action:study:poetry,intel:event:anlushan_rebel",
        "requirements": "prop_gt(name=money, val=50), trait_has(name=official)",
        "Title": "长安酒馆奇遇",
        "Desc": "你在长安的一家酒馆中遇到了一位神秘的诗人，他似乎喝醉了，但眼中却闪烁着智慧的光芒。",
        "Opt_A_Text": "塞钱贿赂",
        "Opt_A_Req": "prop_gt(name=money, val=100)",
        "Opt_A_Result": "prop_sub(name=money, val=100), trait_add(name=corrupt)",
        "Opt_B_Text": "拂袖而去",
        "Opt_B_Req": "trait_has(name=proud)",
        "Opt_B_Result": "prop_add(name=prestige, val=50)",
        "weight": "15.5",
        "background": "bg_rural_poor"
    }
    
    # 解析事件
    var event = DSLParser.parse(example_csv_row)
    
    if event:
        print("成功解析事件: ", event.uuid)
        print("标题: ", event.name)
        print("描述: ", event.description)
        print("触发标签: ", event._target_tags)
        print("选项数量: ", event.options.size())
        print("图片存在: ", event.icon != null)
        
        # 验证解析结果
        if DSLParser.validate_event(event):
            print("事件验证通过")
        else:
            print("事件验证失败")
    else:
        print("解析事件失败")

# 批量解析示例
func test_batch_parsing():
    var csv_data = [
        {
            "Event_ID": "evt_changan_01",
            "Trigger_Tags": "actor:status:drunk,city:econ:prosperous",
            "requirements": "prop_gt(name=money, val=50)",
            "Title": "长安酒馆奇遇",
            "Desc": "你在长安的一家酒馆中遇到了一位神秘的诗人。",
            "Opt_A_Text": "塞钱贿赂",
            "Opt_A_Req": "prop_gt(name=money, val=100)",
            "Opt_A_Result": "prop_sub(name=money, val=100), trait_add(name=corrupt)",
            "Opt_B_Text": "拂袖而去",
            "Opt_B_Req": "trait_has(name=proud)",
            "Opt_B_Result": "prop_add(name=prestige, val=50)"
        },
        {
            "Event_ID": "evt_market_02",
            "Trigger_Tags": "action:study:poetry,city:econ:prosperous",
            "requirements": "prop_gt(name=literary_fame, val=30)",
            "Title": "市场诗会",
            "Desc": "市场上正在举行一场诗会，许多文人墨客聚集于此。",
            "Opt_A_Text": "参与诗会",
            "Opt_A_Req": "prop_gt(name=literary_fame, val=20)",
            "Opt_A_Result": "prop_add(name=literary_fame, val=10), prop_sub(name=money, val=20)",
            "Opt_B_Text": "默默观察",
            "Opt_B_Result": "prop_add(name=literary_fame, val=5)"
        }
    ]
    
    var events = DSLParser.parse_csv_data(csv_data)
    print("批量解析完成，共解析 %d 个事件" % events.size())
    
    for event in events:
        print("- 事件: %s, 选项数: %d" % [event.uuid, event.options.size()])

# 测试各种DSL格式（新语法）
func test_dsl_formats():
    print("\n=== 测试DSL格式解析（新语法）===")
    
    # 测试触发标签解析
    var tags = MicroDSLParser.parse_tags("actor:status:drunk,city:econ:prosperous,action:study:poetry")
    print("触发标签: ", tags)
    
    # 测试属性需求解析（新语法）
    var prop_req = MicroDSLParser.parse_property_requirement("prop_gt(name=money, val=50)")
    if prop_req:
        print("属性需求: %s %s %d" % [prop_req.property, ">", prop_req.value])
    
    # 测试特性需求解析（新语法）
    var trait_req = MicroDSLParser.parse_trait_requirement("trait_has(name=official)")
    print("特性需求解析: ", trait_req != null)
    
    # 测试结果操作符解析（新语法）
    var operators = MicroDSLParser.parse_consequence_operators("prop_sub(name=money, val=100), trait_add(name=corrupt)")
    print("结果操作符数量: ", operators.size())
    
    # 测试复合需求解析（新语法）
    var complex_req_str = "prop_gt(name=money, val=50), prop_gt(name=literary_fame, val=30)"
    var complex_req = DSLParser.parse_requirements(complex_req_str)
    print("复合需求解析: ", complex_req != null)
