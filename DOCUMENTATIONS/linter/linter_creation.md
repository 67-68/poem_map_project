根据文档，写一个新的 Linter Rule 需要遵守以下契约：

## 1. 继承基类契约

```gdscript
class_name YourLinterRule extends BaseLinterRule
```

必须继承 `BaseLinterRule`，它提供了基础框架：
- `rule_name` - 规则名称
- `errors` / `warnings` - 错误/警告数组
- `add_error()` / `add_warning()` - 添加错误/警告的方法
- `get_result()` - 获取检查结果
- `print_result()` - 打印结果

## 2. 实现核心方法契约

```gdscript
## 必须重写：执行检查逻辑
func execute(event_data: DataHelper.EventData) -> void:
    # 你的检查逻辑
    # 使用 add_error("错误信息") 和 add_warning("警告信息")
```

**关键要求：**
- 必须重写 `execute()` 方法
- 通过 `add_error()` 和 `add_warning()` 记录问题，不要直接 push_error

## 3. 使用数据接口契约

```gdscript
func execute(event_data: DataHelper.EventData) -> void:
    # 使用统一接口获取所有事件，不要硬编码事件类型
    var all_events = event_data.get_all_events_iterator()
    
    # 如果需要访问 flags
    if event_data.flags:
        var flags = event_data.flags
```

**禁忌：**
- ❌ 不要硬编码 `event_data.history_events` / `random_events` 等具体类型
- ✅ 使用 `event_data.get_all_events_iterator()` 获取所有事件

## 4. 扩展性契约（如果需要检查依赖关系）

如果你的 Rule 需要检查 Trait/Flag 的引用关系，必须使用**契约方法**而非反射：

```gdscript
# 正确做法：使用契约方法
if obj is BaseRequirements and obj.has_method('get_referenced_traits'):
    var traits = obj.get_referenced_traits()
    for trait in traits:
        # 处理 trait

# 错误做法：使用反射 💀
for prop in obj.get_property_list():  # 禁止！
    # ...
```

## 5. 完整示例

```gdscript
# core/linter_rules/location_linter_rule.gd
class_name LocationLinterRule extends BaseLinterRule

func _init():
    rule_name = "地理位置检查官"

func execute(event_data: DataHelper.EventData) -> void:
    var all_events = event_data.get_all_events_iterator()  # 契约接口
    
    for event_uuid in all_events:
        var event = all_events[event_uuid]
        _validate_event_location(event, event_uuid)

func _validate_event_location(event: Variant, event_uuid: String) -> void:
    if _has_location_conflict(event):
        add_error("事件 %s 存在地理位置冲突" % event_uuid)
```

## 6. 注册到流水线

```gdscript
func _initialize_rule_pipeline() -> void:
    linter_rules.append(YourLinterRule.new())  # 添加你的 Rule
```

## 核心原则总结

**契约即自由** 🤓☝️：
- 明确的接口避免反射猜测
- 单一职责，只管你的检查逻辑
- 统一数据接口，不依赖具体实现
- 通过继承扩展，不修改核心代码

遵循这些契约，你的 Linter Rule 就能完美融入系统，既有性能又易维护 🚀