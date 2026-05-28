# 文件命名规范 (File Naming Style Guide)

> **原则：一致性高于一切。丑得统一比美得混乱好一万倍。**
> 禁止一个目录里同时出现 `foo_bar.tres` 和 `foo-bar.tres`。

---

## 1. GDScript 脚本文件 (`.gd`)

**规则：`snake_case.gd`**

无论是否声明 `class_name`，一律使用 `snake_case`。

| ✅ 正确 | ❌ 错误 |
|---|---|
| `urn.gd` (`class_name URN`) | `URN.gd` |
| `enumerates.gd` (`class_name ENUMS`) | `Enumerates.gd` |
| `database.gd` (`class_name Database`) | `Database.gd` |
| `data_loader.gd` | `DataLoader.gd` |
| `event_manager.gd` | `EventManager.gd` |

> **例外：** `addons/gut/`（第三方测试框架，保留上游命名）

---

## 2. 场景文件 (`.tscn`)

**规则：`snake_case.tscn`**

| ✅ 正确 | ❌ 错误 |
|---|---|
| `main_menu.tscn` | `MainMenu.tscn` |
| `character_point.tscn` | `characterPoint.tscn` |
| `poem_popup.tscn` | `poem-popup.tscn` |

---

## 3. 资源文件 (`.tres`)

### 3.1 数据资源

**规则：`snake_case.tres`**，优先使用 `uuid` 作为文件名。

```
poem_libai_001.tres
poet_dufu_002.tres
relation_libai_close.tres
relation_libai_core.tres
event_money_lower_0.tres
flag_player_health.tres
```

**生成规则**（见 `resource_asset_exporter.gd`）：

```
优先级: uuid > resource_name > resource_path > class_name
产出: snake_case (所有特殊字符 → `_`)
```

### 3.2 Registry 文件

**规则：`<type>_registry.tres`**

```
poet_data_registry.tres
poem_data_registry.tres
flags_registry.tres
traits_registry.tres
actions_registry.tres
```
注：有些内容会加tres_

> Registry 是纯配置索引文件，位于 `data/` 根目录。对应的数据文件放在 `data/<type>/` 子目录。

### 3.3 配置 / 主题文件

**规则：`snake_case.tres`**

```
global_theme.tres
stamp_config.tres
editor_radio_button.tres
```

---

## 4. CSV 数据文件 (`.csv`)

**规则：`snake_case.csv`**，集合名词用复数。

| ✅ 正确 | ❌ 错误 |
|---|---|
| `flags.csv` | `flag.csv`（单数，但存多条记录） |
| `traits.csv` | `trait.csv` |
| `random_events.csv` | `random_event.csv` |
| `base_province.csv` | `base_provinces.csv`（"base_province" 是表名，固定） |

> 注意 `base_province.csv` 和 `territories.csv` 是地图核心数据，表名本身是单数概念，不做改动。

---

## 5. 着色器文件 (`.gdshader`)

**规则：`snake_case.gdshader`**

```
candle_shader.gdshader
flash_light.gdshader
faction_shader.gdshader
province_border.gdshader
height_shader.gdshader
```

> 放在 `shaders/` 下，分类子目录 `shaders/map_shaders/` 等。

---

## 6. 图片 / 音频资产

**规则：`snake_case.<ext>`**，全英文命名。

```
bg_changan_street.png
bg_court_dark.png
msg_normal.png
msg_critical.png
msg_tax_wheat.png
```

> **遗留例外：** 已有的中文名文件（如 `石壕吏.png`、`唐朝疆域（繁）.png`）暂不处理，新资产禁止使用中文名。

---

## 7. 目录命名

**规则：`snake_case`**，顶层目录尽量单数/短名。

| 目录 | 说明 |
|---|---|
| `model/` | 数据模型 |
| `core/` | 核心系统 |
| `core/operators/` | 操作器 |
| `core/requirements/` | 需求系统 |
| `core/utils/` | 工具函数 |
| `parser/` | DSL 解析器 |
| `ui/` | UI 组件 |
| `world/` | 游戏世界 |
| `data/<type>/` | 某类型资源的数据目录（如 `data/flags/`, `data/traits/`） |

> `data/<type>/` 目录名必须与对应的 `<type>_registry.tres` 中的 `<type>` 完全一致。

---

## 8. 枚举命名

**规则：`SCREAMING_SNAKE_CASE`**

### 8.1 通用枚举

```gdscript
enum PROPS {
    OFFICIAL_PRESTIGE,
    LITERARY_FAME,
    TALENT,
    MONEY,
    HEALTH,
}
```

### 8.2 带层级/前缀的枚举

层级用单 `_` 分隔，前缀大写：

```gdscript
enum TRAITS {
    WANDERING_WITHOUT_LIVING_PLACE,
    
    # 主线行动等级
    MAIN_BAIYE_1,
    MAIN_BAIYE_2,
    MAIN_JIAOYOU_1,
    MAIN_DENGGAO_1,
    
    # 角色状态
    OFFICIAL,
    CORRUPT,
    PROUD,
}
```

### 8.3 ~~双下划线 `__` 模式（已彻底移除）~~

**状态：已彻底移除。** 不再使用 `__` 作为 `:` 的文件系统安全替代符。

**历史：**
- `__` 曾用于 `TRAITS` 枚举（如 `POEM__GAN_YE__1`），作为 `:`（冒号）的文件系统安全替代符
- 配套的 `to_traits_str()` / `from_traits_str()` 曾做 `__`↔`:` 双向转换
- `resource_asset_exporter` 和 `csv_cloud_loader` 曾用 `replace(":", "__")` 做文件名 sanitize

**替代方案：** Trait 的 `topic` / `specific_topic` 字段直接承载语义，不再通过 UUID name-parse 寻址。

---

## 9. 总结：快速对照表

| 文件类型 | 命名规则 | 示例 |
|---|---|---|
| GDScript | `snake_case.gd` | `urn.gd`, `event_manager.gd` |
| Scene | `snake_case.tscn` | `main_menu.tscn` |
| 数据资源 | `snake_case.tres` (uuid) | `poem_libai_001.tres` |
| Registry | `<type>_registry.tres` | `poet_data_registry.tres` |
| CSV | `snake_case.csv` (复数) | `flags.csv`, `random_events.csv` |
| Shader | `snake_case.gdshader` | `candle_shader.gdshader` |
| 图片资源 | `snake_case.png/jpg` (英文) | `bg_changan_street.png` |
| 目录 | `snake_case` | `core/operators/` |
| 枚举 | `SCREAMING_SNAKE_CASE` | `MAIN_BAIYE_1` |
| ~~双下划线~~ | ~~`__` 替代 `:`~~ | **DEPRECATED** |

---

> **最后一条铁律：** 如果你发现新文件不知道该叫什么，翻翻同目录下已有的文件，按最普遍的那个模式来。**宁可抄一个已有的丑约定，也不要发明一个漂亮的新约定。** 🤓☝️
