我来读取这个文件，然后为你解释使用方法。

这是一个 Godot 调试控制器，用于在游戏运行时执行调试命令。使用方法如下：

## 打开/关闭控制器
- **Mac**: 按 `Cmd + F2`
- **Windows/Linux**: 按 `Ctrl + F2`

## 支持的调试命令格式

### 1. 发送信号
```
send_signal <signal_name> <argument>
```
示例：`send_signal player_damaged 50`

### 2. 给玩家添加特质
```
give_trait <trait_uuid>
```
示例：`give_trait brave_warrior`

### 3. 触发事件结果
```
event_result <event_id>
```
示例：`event_result bandit_encounter`

### 4. 添加意象
```
add_imaginary <imaginary_name>
```
示例：`add_imaginary mountain`

### 5. 调用 GameState 或 Database 方法
```
<<method_name> <argument>
```
示例：`set_health 100`

### 6. 快捷方式（通过事件键请求事件）
```
$<<event_key>
```
示例：`$battle_start`

## 批量命令
可以在输入框中输入多行命令（用换行符分隔），会按顺序执行所有命令。

**注意**：这是一个调试工具，建议只在开发阶段使用，生产环境应该禁用或移除。