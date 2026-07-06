# 系统菜单存档面板

## 涉及文件

- `core/game_save.gd` — 新增 `save_to_file()`、`load_from_file()`、`list_saves()` 三个文件 I/O 方法
- `ui/game_data_panel.gd` — 新建，挂到 `game_data_panel.tscn` 上，管理单个存档槽
- `ui/game_data_panel.tscn` — 挂载 `game_data_panel.gd` 脚本
- `ui/system_menu.gd` — 新增 6 个面板引用、`_refresh_save_panels()`、`open_menu()` 时刷新存档

## 预期效果

玩家按 Esc 打开系统菜单后，右侧 6 个存档面板自动扫描 `user://saves/` 目录。已有存档的面板显示玩家名、年份、天数；空档位显示「空存档」。点击「保存到此」写入存档（空档位自动生成 UUID，已占用档位覆盖写入），点击「依此加载」读取存档并 `reload_current_scene`。

## 状态转换

### 存档槽状态机

```
Empty ──「保存到此」──→ 生成 UUID → save_to_file → Occupied
Occupied ──「保存到此」──→ save_to_file（覆盖同 UUID）→ Occupied
Occupied ──「依此加载」──→ load_from_file → reload_current_scene → [*]
```

### 系统菜单打开流程

1. `open_menu()` 被调用（Esc 或手动）
2. 调用 `_refresh_save_panels()`
3. 内部调用 `GameSave.list_saves()` 扫描 `user://saves/*.save`
4. 逐个文件读取 `get_var()` 提取元数据（uuid, player_name, year, total_days_elapsed, current_location）
5. 前 6 个存档按顺序填充 6 个 `GameDataPanel`，超出 6 个的不显示
6. 剩余空面板调用 `configure({})` 设为空档位

### 保存流程

1. 玩家点击「保存到此」
2. 空档位：`GameDataPanel._generate_uuid()` 生成 UUID v4
3. 已占用：复用已有 UUID
4. `GameSave.save_to_file(uuid)`：`data.to_dict()` → `store_var` 二进制写入 `user://saves/{uuid}.save`
5. 保存后面板自动 `_refresh_after_save()` 从刚写入的文件回读元数据并刷新 UI

### 加载流程

1. 玩家点击「依此加载」
2. 先 `TimeService.resume_world()` 恢复时间（防止 load 后世界卡死）
3. `GameSave.load_from_file(uuid)`：`get_var` 读取 → `data.from_dict(dict)`
4. `get_tree().reload_current_scene.call_deferred()` — 延迟一帧等信号链走完

## 关键设计决策

- **文件格式**：`store_var`/`get_var` 二进制，非 JSON。项目已有先例 [`Util.save_to`](core/util.gd:206)
- **存档目录**：`user://saves/`，Godot 标准用户路径，Web 导出兼容
- **UUID 生成**：客户端 `randi()` 生成 UUID v4 格式，不用 `ResourceUID`
- **最多 6 个槽位**：由 tscn 中 6 个 `PanelContainer` 实例决定，超出文件不删除仅不显示
- **加载后生效**：所有 Autoload getter 代理到 `GameSave.data`，`from_dict()` 后立即可读，reload 确保场景节点也刷新
- **Resource 对象**：`created_poems` 和 `imaginaries_detail` 的 Resource 需要外部注入，当前 `from_dict` 不处理（与 [`game_save_data.md`](game_save_data.md:52) 一致）

## 存档文件元数据结构

```gdscript
# GameSave.list_saves() 返回 Array[Dictionary]
[
  {
    "uuid": "a1b2c3d4-...",
    "file_path": "user://saves/a1b2c3d4-....save",
    "player_name": "杜甫",
    "year": 745.3,
    "current_location": "yong_zhou",
    "total_days_elapsed": 42
  }
]
```
