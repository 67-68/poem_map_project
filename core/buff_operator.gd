@tool
class_name BuffOperator extends BaseOperator
## BuffOperator — 理念 Buff 操作器
##
## 对 GameSave.data.properties 中的指定属性执行纯加法修正。
## operate() 应用 buff，on_exit() 反转生效（移除 buff）。
##
## 理念激活周期：
##   IdeaPage 选择理念 → operate() 应用 buff
##   理念过期/替换 → on_exit() 移除 buff

@export var prop_name: String = '' # GameSave.data.properties 内的属性名
@export var amount: int = 1        # 永远执行 addition（正数=增益，负数=减益）


func operate():
    """应用 buff：对 prop_name 执行 +amount"""
    if prop_name.is_empty():
        Logging.err("BuffOperator.operate: prop_name 为空，跳过执行")
        return
    if amount == 0:
        Logging.debug("BuffOperator.operate: amount=0，无效果，跳过")
        return

    Logging.info("BuffOperator.operate: 应用 buff — prop='%s', amount=%+d" % [prop_name, amount])
    PlayerState.append_stat(prop_name, amount)
    Logging.info("BuffOperator.operate: buff 已应用 — prop='%s', amount=%+d" % [prop_name, amount])


func on_exit(_context: Dictionary) -> Dictionary:
    """移除 buff：对 prop_name 执行 -amount（反转生效）"""
    if prop_name.is_empty():
        Logging.err("BuffOperator.on_exit: prop_name 为空，跳过清理")
        return _context
    if amount == 0:
        Logging.debug("BuffOperator.on_exit: amount=0，无效果，跳过")
        return _context

    Logging.info("BuffOperator.on_exit: 移除 buff — prop='%s', amount=%+d（反转=%+d）" % [prop_name, amount, -amount])
    PlayerState.append_stat(prop_name, -amount)
    Logging.info("BuffOperator.on_exit: buff 已移除 — prop='%s'" % prop_name)
    return _context


func init(_context: Dictionary) -> Dictionary:
    """初始化：验证 prop_name 在 Database 中是否存在"""
    if prop_name.is_empty():
        Logging.warn("BuffOperator.init: prop_name 为空，跳过验证")
        return _context
    var prop = Database.get_property(prop_name)
    if not prop:
        Logging.err("BuffOperator.init: prop '%s' 在 Database 中不存在，buff 可能在运行时失效" % prop_name)
    else:
        Logging.debug("BuffOperator.init: prop '%s' 验证通过" % prop_name)
    return _context


func describe_preview() -> String:
    """Alt 预览：展示 buff 效果文本"""
    if prop_name.is_empty() or amount == 0:
        return ""
    var prop = Database.get_property(prop_name)
    if not prop:
        return "%s %+d" % [prop_name, amount]
    var cn_name = prop.get_display_name() if not prop.name.is_empty() else prop_name
    var arrow = "↑" if amount > 0 else "↓"
    return "%s %s %+d" % [cn_name, arrow, amount]


func get_referenced_props() -> Array:
    if prop_name.is_empty():
        return []
    return [prop_name]


func get_demanded_props() -> Array:
    if prop_name.is_empty():
        return []
    return [prop_name]