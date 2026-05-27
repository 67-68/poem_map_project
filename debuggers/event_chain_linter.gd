class_name EventChainLinter extends BaseLinterRule

func execute(event_data: DataHelper.EventData) -> void:
    rule_name = 'chain event linter'
    var events = event_data.get_all_events_iterator() as Dictionary # [String, BaseEvent]
    
    # 🤓☝️ 核心修正 1：图的构建绝对只能做一次！
    var adjacency_list = creates_adjacency_list(events.values())
    
    var visited = {} # 0: white, 1: gray, 2: black
    for e_uuid in events.keys(): 
        visited[e_uuid] = 0 
        
    var death_cycles: Array[Array] = []
    
    # 🤓☝️ 核心修正 2：全局收集群组，直接使用类的成员变量或者闭包外的引用传递
    var all_groups: Array[Array] = []

    for node_uuid in visited.keys():
        if visited[node_uuid] == 0:
            var current_group: Array = []
            var path_stack: Array = []
            # 启动 DFS 时，传的是 UUID 字符串，不要传对象！
            _dfs(node_uuid, path_stack, adjacency_list, visited, death_cycles, current_group)
            all_groups.append(current_group)
            
    _output_results(all_groups, adjacency_list, death_cycles)
        

func _output_results(all_groups: Array[Array], adjacency_list: Dictionary, death_cycles: Array[Array]) -> void:
    print("============================================================")
    print("📊 事件链分析报告")
    print("============================================================")

    # 1. 事件链统计
    print("\n📈 统计概览")
    print("  - 独立事件链数量: %d" % all_groups.size())
    print("  - 死循环数量: %d" % death_cycles.size())

    # 2. 事件链详情
    print("\n🔗 事件链详情")
    for i in range(all_groups.size()):
        var chain = all_groups[i]
        print("  链 %d: %d 个事件" % [i, chain.size()])
        print("    %s" % ", ".join(chain))

    # 3. Mermaid 图
    var mermaid_content = _generate_mermaid_diagram(all_groups, adjacency_list)
    _save_mermaid_to_file(mermaid_content)

    # 4. 死循环报告
    print("\n🌀 死循环报告")
    if death_cycles.is_empty():
        print("  ✅ 未发现死循环，事件依赖关系健康")
    else:
        print("  💀 发现 %d 个死循环" % death_cycles.size())
        for i in range(death_cycles.size()):
            var cycle = death_cycles[i]
            var chain_idx = _find_chain_for_cycle(cycle, all_groups)
            print("\n  循环 %d:" % i)
            print("    路径: %s" % " -> ".join(cycle))
            print("    所属链: %d" % chain_idx)
            print("    链完整内容:")
            print("      %s" % ", ".join(all_groups[chain_idx]))

    print("")
    print("============================================================")

func _sanitize_mermaid_id(uuid: String) -> String:
    # 替换 Mermaid 不支持的特殊字符
    var safe_id = uuid.replace("://", "_").replace("/", "_").replace("-", "_")
    # 如果太长，只取前20个字符
    if safe_id.length() > 20:
        safe_id = safe_id.substr(0, 20)
    return safe_id

func _save_mermaid_to_file(mermaid_content: String) -> void:
    var file = FileAccess.open("res://debuggers/event_chain_diagram.mmd", FileAccess.WRITE)
    if file:
        file.store_string(mermaid_content)
        file.close()
        print("  📁 Mermaid 图已保存到: res://debuggers/event_chain_diagram.mmd")
    else:
        printerr("  ❌ 无法保存 Mermaid 图文件")

func _generate_mermaid_diagram(all_groups: Array[Array], adjacency_list: Dictionary) -> String:
    var lines = ["flowchart TD"]
    lines.append("    %% 事件链依赖关系图")
    lines.append("")

    # 事件链分组
    for i in range(all_groups.size()):
        var chain = all_groups[i]
        lines.append("    subgraph Chain%d[链 %d: %d个事件]" % [i, i, chain.size()])
        for uuid in chain:
            var safe_id = _sanitize_mermaid_id(uuid)
            var display_name = uuid.substr(0, 8)
            lines.append("        %s[%s]" % [safe_id, display_name])
        lines.append("    end")
        lines.append("")

    # 依赖边
    for source_uuid in adjacency_list:
        for target_uuid in adjacency_list[source_uuid]:
            var safe_source = _sanitize_mermaid_id(source_uuid)
            var safe_target = _sanitize_mermaid_id(target_uuid)
            lines.append("    %s --> %s" % [safe_source, safe_target])

    return "\n".join(lines)

func _find_chain_for_cycle(cycle: Array, all_groups: Array[Array]) -> int:
    for chain_idx in range(all_groups.size()):
        var chain = all_groups[chain_idx]
        var cycle_in_chain = true
        for cycle_uuid in cycle:
            if not cycle_uuid in chain:
                cycle_in_chain = false
                break
        if cycle_in_chain:
            return chain_idx
    return -1

# 🤓☝️ 核心修正 3：严谨的三色标记状态机，不返回任何多余垃圾
func _dfs(current_uuid: String, stack: Array, adjacency_list: Dictionary, visited: Dictionary, death_cycles: Array, group: Array) -> void:
    # 1. 刚进来，自己先染灰，并压入追踪栈
    visited[current_uuid] = 1
    stack.append(current_uuid)
    group.append(current_uuid)
    
    # 获取下游节点列表（注意：这里面存的是 String UUID）
    var next_nodes: Array = adjacency_list.get(current_uuid, [])
    
    for next_uuid in next_nodes:
        var next_color = visited.get(next_uuid, 0)
        
        if next_color == 0:
            # 下游是白的，继续深挖
            _dfs(next_uuid, stack, adjacency_list, visited, death_cycles, group)
        elif next_color == 1:
            # 💀 下游是灰的！撞车了！提取环路切片！
            var loop_start_idx = stack.find(next_uuid)
            var cycle = stack.slice(loop_start_idx, stack.size())
            cycle.append(next_uuid) # 首尾相连
            death_cycles.append(cycle)
        else:
            # 下游是黑的，说明那条路别人已经走过且安全，直接忽略
            pass
            
    # 2. 所有下游探索完毕，自己染黑，并退出追踪栈
    visited[current_uuid] = 2
    stack.pop_back()

func creates_adjacency_list(events: Array) -> Dictionary:
    # 创建邻接表，说明谁依赖了什么 trait 和 flag，进而找出事件的依赖情况
    var ev_reliance = {} # uuid -> Array[String] (依赖的资源集合)
    var resource_providers = {} # 🤓☝️ 核心契约：倒排索引！资源名 -> Array[uuid] (谁产出了它)

    for e in events:
        # 🤓☝️ 鸭子类型：检查对象是否具有事件所需的属性
        if not e.has_method("get") or e.get("uuid") == null or e.get("options") == null:
            printerr("⚠️ 跳过非事件对象: type=%s" % e.get_class())
            continue

        var relies_set = {} # Dictionary 模拟 Set 进行去重
        var provides_set = {} # Dictionary 模拟 Set 进行去重

        var options = e.options
        if options == null:
            printerr("⚠️ Event has null options: event_uuid=%s" % e.uuid)
            continue
        for o in options:
            if o == null:
                printerr("⚠️ Event has null option: event_uuid=%s" % e.uuid)
                continue
            var req = o.requirements
            if req:
                var flags = req.get_referenced_flags()
                if flags:
                    for flag_name in flags:
                        relies_set[flag_name] = true
                var traits = req.get_referenced_traits()
                if traits:
                    for trait_name in traits:
                        relies_set[trait_name] = true

            var choice_result = o.choice_result
            if choice_result and choice_result.operators:
                for op in choice_result.operators:
                    if op:
                        var ref_flags = op.get_demanded_flags()
                        if ref_flags:
                            for flag_name in ref_flags:
                                relies_set[flag_name] = true
                        var ref_traits = op.get_demanded_traits()
                        if ref_traits:
                            for trait_name in ref_traits:
                                relies_set[trait_name] = true

                        var prov_flags = op.get_provided_flags()
                        if prov_flags:
                            for flag_name in prov_flags:
                                provides_set[flag_name] = true
                        var prov_traits = op.get_provided_traits()
                        if prov_traits:
                            for trait_name in prov_traits:
                                provides_set[trait_name] = true

        ev_reliance[e.uuid] = relies_set.keys()

        # 🚨 构建倒排索引！把当前事件注册为这些资源的"供应商"
        for res in provides_set.keys():
            if not resource_providers.has(res):
                resource_providers[res] = []
            resource_providers[res].append(e.uuid)

    # =========================================================
    # 基于倒排索引，真正找出事件到事件的依赖 (Provider -> Consumer)
    # =========================================================
    var adjacency_list = {}
    for e in events:
        # 🤓☝️ 鸭子类型：检查对象是否具有事件所需的属性（与第一次遍历保持一致）
        if not e.has_method("get") or e.get("uuid") == null or e.get("options") == null:
            printerr("⚠️ 跳过非事件对象（第二次遍历）: type=%s" % e.get_class())
            continue
        adjacency_list[e.uuid] = [] # 初始化所有节点的边

    for consumer_uuid in ev_reliance:
        for required_res in ev_reliance[consumer_uuid]:
            # 查表：谁提供了这个资源？
            if resource_providers.has(required_res):
                for provider_uuid in resource_providers[required_res]:
                    # 避免自环（自己依赖自己产出的资源）
                    if provider_uuid != consumer_uuid:
                        # 建立连线：供应商 -> 消费者 (也就是前置事件 -> 后续事件)
                        if not adjacency_list[provider_uuid].has(consumer_uuid):
                            adjacency_list[provider_uuid].append(consumer_uuid)

    print('+==================================+')
    print(adjacency_list)
    print('+==================================+')
    return adjacency_list