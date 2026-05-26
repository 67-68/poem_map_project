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
            
    # Linter 阶段结束，你可以打印死亡循环或者生成 Mermaid 图了
    if not death_cycles.is_empty():
        push_error("💀 发现 %d 个死循环！" % death_cycles.size())

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

func creates_adjacency_list(events: Array[BaseEvent]) -> Dictionary:
    # 创建邻接表，说明谁依赖了什么 trait 和 flag，进而找出事件的依赖情况
    var ev_reliance = {} # uuid -> Array[String] (依赖的资源集合)
    var resource_providers = {} # 🤓☝️ 核心契约：倒排索引！资源名 -> Array[uuid] (谁产出了它)

    for e in events:
        var relies_set = {} # Dictionary 模拟 Set 进行去重
        var provides_set = {} # Dictionary 模拟 Set 进行去重

        var options = e.options
        for o in options:
            var req = o.requirements
            for flag_name in req.get_reference_flags():
                relies_set[flag_name] = true
            for trait_name in req.get_reference_traits():
                relies_set[trait_name] = true

            for op in o.choice_result:
                for flag_name in op.get_referenced_flags():
                    relies_set[flag_name] = true
                for trait_name in op.get_referenced_traits():
                    relies_set[trait_name] = true

                for flag_name in op.get_provided_flags():
                    provides_set[flag_name] = true
                for trait_name in op.get_provided_traits():
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

    return adjacency_list