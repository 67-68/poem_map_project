# Old Bugs

## 2026-06-01: 🚀 Tag 系统革新 — 前缀匹配消灭三段式/四段式补丁链

### 变更内容
从**精确字符串匹配**（`e.target_tags.has(tag)`）改为**前缀匹配**（`TagManager.prefix_match(tag, target_tag, 3)`）。

### 解决的历史问题
- **三段式 vs 四段式不匹配**（见下方案例）— 不再需要 `normalize_3part_depreciated_tag()` 补 `:general`
- **3-part 标签注入即报警**（`action_tag_filter.gd` 中的校验代码）— 直接删除
- **精确匹配灵活性不足**— `actor:health:sick:general` 无法匹配 `actor:health:sick:plague`，现在可以

### 新匹配规则
- **前缀匹配**：短的 tag 作为前缀，匹配长的 tag，按冒号分段
- 不限制级数，输几级就用几级匹配
- 例如：`actor:health` → 匹配 `actor:health:sick:general` ✅
- 例如：`actor:health:sick` → 匹配 `actor:health:sick:general` ✅
- 例如：`actor:health` → 不匹配 `actor:healthcare` ❌（分段边界保护）

### 原理
```gdscript
# 改前：必须完全相等
e.target_tags.has(tag)

# 改后：灵活的字符串前缀匹配 + 冒号分段边界检查
TagManager.prefix_match(tag, target_tag)
# 逻辑：短的 tag 作为前缀，检查长的 tag 是否以它开头，且剩余部分为空或 : 开头
```

### 涉及文件
- [`core/tag_manager.gd`](core/tag_manager.gd) — 新增 `get_prefix()` / `prefix_match()`
- [`core/model/action_tag_filter.gd`](core/model/action_tag_filter.gd) — 匹配逻辑改造
- [`core/event_manager.gd`](core/event_manager.gd) — `scan_poem_events` 匹配改造
- [`ui/scene_action_panel.gd`](ui/scene_action_panel.gd) — 删除 `normalize_3part_depreciated_tag` 调用
- [`model/random_event.gd`](model/random_event.gd) — 删除 `normalize_3part_depreciated_tag` 调用
- [`core/model/time_operator.gd`](core/model/time_operator.gd) — 删除 `normalize_3part_depreciated_tag` 调用

## 核心教训速览 — 场景 → 诱因

- **标签三段式 vs 四段式不匹配** → `ENUMS.to_action_str()` 生成三段式（`actor:health:sick`），`TagManager.normalize_3part_depreciated_tag()` 补成四段式（`actor:health:sick:general`），精确字符串匹配直接爆炸 💀
- **枚举重构后数据残留旧索引** → 删了部分 `ACTION_TAGS` 枚举值（0-24），但 RandomEvent 的 `.tres` 文件里还躺着 `[44, 30, 36, ...]` 这种阴间索引，`to_action_str(44)` 直接触发断点 💀
- **三段式 tag + 自动补全成死循环** → action_tag_filter 自动补全 3→4 段，但新的 deepseek action 本身是 3 段，补完反而和目标不匹配，滤镜修出反效果 😭
- **只改代码不改缓存** → 改了资源创建/注册逻辑，但没清 `create_resources_registry` 缓存，永远在拿过期数据 🤡
- **`super._init(data)` 被注释掉，父类初始化被拦腰截断** → `MapMarker._init` 注释了 `#super._init(data)`，`GameEntity._init` 压根没跑，CSV 加载的 295 个 Territory 全部 `uuid=""` 🤣
- **`_init(data: Dictionary)` 参数没有默认值** → 三个数据加载路径（CSV→`new(data)`、tres→反序列化、手动→`new()`）走三种方式调构造器，不给 `= {}` 默认值就是定时炸弹 💀
- **`@tool` 模式下枚举常量跨脚本引用失效** → `match 13: URN.URN_TYPE.TRAIT:` 命中不了，字典 `get(25)` 查不到——Godot 4 `@tool` 下枚举常量就是摆设，不用字符串 dispatch 必死 🤡
- **`duplicate()` 遇到 `resource_local_to_scene=true` 产生幽灵属性** → 根资源全量开启 `resource_local_to_scene=true`，`duplicate()` 后的对象非 `@export` 属性变成只读，operator 悄无声息丢失，赋值没报错但数据没了 🤡
- **非 `@tool` 类的静态变量被 `@tool` 脚本引用时空** → `SourceOfTruth` 没加 `@tool`，静态字典根本没初始化，`@tool` 脚本查 `get("event_option")` 永远返回 `null` 💀

## 2026-05-23: 标签格式不一致导致事件匹配失败

### 问题描述
Scene Action的`action_tags`和Random Event的`target_tags`之间存在标签格式不一致问题，导致事件匹配失败。

### 根本原因
- **Action.action_tags生成过程**：通过`ENUMS.to_action_str()`将枚举转换为字符串，只做下划线→冒号转换，产生三段式标签（如`actor:health:sick`）
- **Event.target_tags生成过程**：通过`TagManager.normalize_3part_depreciated_tag()`标准化，自动将三段式补全为四段式（如`actor:health:sick:general`）
- **匹配逻辑**：使用精确字符串匹配`if e.target_tags.has(tag)`
- **结果**：三段式标签无法匹配四段式标签，导致事件触发失败

### 影响范围
- 所有基于旧枚举的Scene Action都可能触发不了对应的事件
- 潜在影响游戏核心功能（事件系统）

### 修复方案
1. 在注入`current_action_tags`时统一使用`TagManager.normalize_3part_depreciated_tag()`标准化标签
2. 在`ActionTagFilter.filter()`中添加检查，发现三段式标签时push_error警告
3. 修改所有注入点：
   - `scene_action_panel.gd` - 执行Action时
   - `time_operator.gd` - 时间流逝时
   - `poem_crafter.gd` - 制作诗词时
   - `survival_manager.gd` - 已是四段式，无需修改

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/ui/scene_action_panel.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/model/action_tag_filter.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/model/time_operator.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/ui/poem_crafter.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/survival_manager.gd" />

## 2026-05-24: 枚举重构后RandomEvent数据文件未同步导致tag值超出范围

### 问题描述
在`random_event.gd`第10行调用`ENUMS.to_action_str(tag)`时，tag值为44，触发断点失败。实际`ACTION_TAGS`枚举只有25个值（0-24），但RandomEvent数据文件中存储了超出范围的枚举索引。

### 根本原因
- **枚举重构**：之前删除了部分`ACTION_TAGS`枚举值，枚举总数减少到25个（0-24）
- **RandomEvent数据未同步**：RandomEvent的.tres文件中`_action_tags`数组包含超出当前枚举范围的旧索引，而Action文件保持正常
- **具体问题文件**：
  - `normal_bai_ye.tres`: `_action_tags = Array[int]([44, 30, 36, 35, 37, 39])` ❌
  - 其他RandomEvent文件可能也存在类似问题
- **Action文件正常**：`data/tres_actions/bai_ye.tres`的`_action_tags = Array[int]([4, 9, 10, 14, 18])` ✅ 在有效范围内

### 影响范围
- 包含超出范围枚举值的RandomEvent资源文件
- 导致调用`ENUMS.to_action_str()`时触发断点breakpoint，无法正确转换标签
- 影响事件系统的标签匹配功能，RandomEvent无法正确筛选和触发

### 修复方案
1. 在Godot编辑器中重新打开并保存所有受影响的RandomEvent .tres文件
2. 确保每个`_action_tags`数组中的值都在当前`ACTION_TAGS`枚举的有效范围内（0-24）
3. 验证修复后运行event_action_tag_linter确保没有遗留的无效标签

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/data/tres_random_event/normal_bai_ye.tres" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/model/enumerates.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/model/random_event.gd" />


### 2025.05.25
@enumerates 中action tag非真正四段式 + 中间有个_ + 新的deepseek action是三段式，在 @action tag filter导致问题，因为它会自动补全3段 -> 4, 导致deepseek action 和 target tag无法匹配
准确来说不是这里，前面的某个环节导致了问题

### 2025.05.25
没有！清空！缓存！
使用！create_resources_registry!

### 2025.05.25
如果在@tool有问题，那么重启编辑器

## 2026-05-26: TraitOperator缺少str_traits字段导致Linter警告

### 问题描述
在运行csv_cloud_loader和EventDataLinter时，出现大量"TraitOperator: string trait not set, use enum trait"警告信息。

### 根本原因
状态不同步！！！该死的godot enum
- **ENUMS.TRAITS枚举不完整**：原有的ENUMS.TRAITS只包含POEM_xxx和MAIN_xxx等固定trait，缺少实际使用的动态trait（如corrupt, official, chain_strange_poet_1等）
- **parse_trait_operator逻辑问题**：在micro_dsl_parser.gd中，当trait名称不在枚举中时，from_traits_str()返回-1，导致_trait_key未被设置
- **str_traits字段未被标记@export**：最初的trait_operator.gd中str_traits字段没有@export标记，导致保存到.tres文件时丢失
- **旧.tres文件不兼容**：已存在的.tres文件（如normal_gan_ye.tres）只有_trait_key字段，缺少str_traits字段

### 影响范围
- 所有使用动态trait的RandomEvent资源文件
- TraitOperator在Linter验证时产生大量警告信息
- 影响事件系统的trait供需验证功能

### 修复方案
1. **完善ENUMS.TRAITS枚举**：添加常用的动态trait到枚举中
   - 角色状态特性：OFFICIAL, CORRUPT, PROUD, BRAVE, COWARDLY, CAUTIOUS, BUDDHIST, CONFIDENT, MERCHANT, DILIGENT, FEARFUL, WEAK, CRIMINAL
   - 事件链特性：CHAIN_STRANGE_POET_1, CHAIN_STRANGE_POET_2, CHAIN_STRANGE_POET_3
   - 社会关系特性：CONNECTED, JOYFUL, RESPECTED

2. **修改trait_operator.gd**：
   - 将str_traits字段标记为@export，确保保存到.tres文件
   - 添加setter，当设置str_traits时自动尝试更新_trait_key
   - 修改trait_key getter，移除不必要的警告，优先使用字符串形式

3. **修改parse_trait_operator**：
   - 总是设置str_traits字段
   - 只有当trait存在于枚举中时才设置_trait_key
   - 移除转换失败时的警告，因为动态trait只使用字符串是正常情况

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/model/enumerates.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/model/trait_operator.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/parser/micro_dsl_parser.gd" />

## 2026-05-27: GameEntity._init 缺少默认参数 + MapMarker._init 断开了 super 链

### 问题 1: Trait 加载时 "Invalid access to 'uuid' on Resource"

`load("data/tres_traits/main_baiye_1.tres")` 返回裸 `Resource`，没有挂上 `Trait` 脚本。

**根本原因**：`GameEntity._init(data: Dictionary)` — `data` 参数没有默认值。`.tres` 加载器构造实例时不传参，脚本挂不上去，降级为裸 `Resource`。

**教训**：所有 `_init` 中的 `Dictionary` 参数必须给 `= {}` 默认值。数据加载路径（CSV/tres/new）可能以不同方式调用构造器，不给默认值就是埋雷 💀

### 问题 2: FactionMesh 不显示 — CSV 加载的 Territory uuid 全是空

**现象**：`build_color_index` 只映射了 1 个颜色，`bake_index_map` 284 万像素匹配失败。

**根本原因**：`MapMarker._init` 中的 `#super._init(data)` 被注释掉了，导致 `GameEntity._init` 从未被调用。而 `MapMarker._init` 自己也没读 `data.get('uuid')`。结果 CSV 加载的 295 个 `Territory` 全部 `uuid = ""`，`Util.create_dict` 用空 key 覆盖存储，最后 dict 里只有 1 条。

### 关键教训
1. **永远不要注释掉 `super._init(data)` 除非你明确知道自己在干什么** — 断掉 super 链会让整个继承体系的初始化契约失效。
2. 数据加载的 `_init` 链极其脆弱 — CSV 走 `new(data)`、tres 走反序列化、手动构造走 `new()`，三条路径调用 `_init` 的方式不同。改 `_init` 签名时必须三条路径都验证。
3. `@export var uuid: String` 这种基础字段，要么在 `_init` 里显式从 data 读取，要么确保 super 链能传递。不能指望"Godot 帮我设" — 它只在 tres 反序列化时才自动设属性，`new(data)` 不会。

### 修复文件
- `core/game_entity.gd`
- `model/map_marker_data.gd`

## 2026-05-28: @tool 模式下 enum 跨脚本 match 异常 — 所有 data_type 解析失败

### 问题描述
`csv_cloud_loader.gd` 同步 CSV 数据时，三个数据源（trait、flag、random_event）全部解析失败，输出 `DSLParser 返回空资源数组`。特定报错：
```
ERROR: core/variant/variant_utility.cpp:1024 - 未知的 data_type enum: 8 💀
云端数据注入完成！共注入 0 个资源
```

### 根本原因
`dsl_parser.gd` 和 `_parse_flat_data()` 中使用 `match data_type:` 与 `URN.URN_TYPE.FLAG` / `URN.URN_TYPE.TRAIT` 等跨脚本枚举常量做匹配。

在 **`@tool` 模式**下，Godot 4 的枚举常量跨脚本引用在 `match` 语句中无法正确解析为整数值。尽管 `find_urn_type("trait")` 返回了正确的 `13`，但 `match 13: URN.URN_TYPE.TRAIT:` 不命中，所有 data_type 都落入 `_` 兜底分支。

### 影响范围
- 所有通过 `DSLParser.parse_csv_data()` 进行的数据同步
- 包括 `csv_cloud_loader.gd` 和 `addons/data_syncer.gd`
- 影响 trait、flag、random_event 三种数据类型的注入

### 修复方案
1. **`parse_csv_data()`**：移除 `URN.find_urn_type()` 和 enum 比较逻辑，改用**原始字符串 `match`**
2. **`_parse_flat_data()`**：签名从 `data_type: int` 改为 `data_type: String`，内部 `match` 也改用字符串
3. 全部调用方原本就传字符串（`"random_event"`、`"trait"`、`"flag"`），无需修改

### 后续补刀 1：同样问题在 `urn_resource_config` 字典 key 上又爆了一次
修复完 `_parse_flat_data` 后，新的报错：
```
get_resource_through_urn: URN type event_option (25) 未在配置表中找到
```
`SourceOfTruth.urn_resource_config` 的 key 也是 `URN.URN_TYPE.EVENT_OPTION` 等枚举常量，`get(25)` 在 `@tool` 模式下同样查不到。**不是 `match` 独有的问题——字典 key 用枚举常量也一样炸。**

### 修复 2a
1. **`source_of_truth.gd`**：`urn_resource_config` 的 key 全部从 `URN.URN_TYPE.XXX` 改为字符串 `"xxx"`（小写下划线格式）
2. **`urn.gd` `get_resource_through_urn()`**：不再经过 `find_urn_type()` 转 int，直接用 `type_str.to_lower().replace("-", "_")` 归一化后做字符串 key 查找

### 后续补刀 2：SourceOfTruth 本身不是 @tool，静态变量根本没初始化
即使 key 改成了字符串，`SourceOfTruth.urn_resource_config` 仍然返回空字典 💀

**根因**：`source_of_truth.gd` 没有 `@tool` 标记。在 `@tool` 模式下，非 `@tool` 类的静态变量不会在引用时被初始化——`urn_resource_config` 是空的！
`urn.gd`（`@tool`）调用 `SourceOfTruth.urn_resource_config.get("event_option")` 时，字典里什么都没有。

### 修复 2b
3. **`source_of_truth.gd`**：加上 `@tool` 标记。该类只有纯静态数据（配置字典），无副作用，加 `@tool` 安全。

### 最终教训
**在 `@tool` 模式下：**
1. **所有涉及跨脚本枚举常量的运行时引用（`match`、字典 key）都可能出问题** — 始终用字符串做 dispatch
2. **被 `@tool` 脚本引用的数据类也必须加 `@tool`** — 否则静态变量不会被初始化，字典是空的，`get()` 永远返回 `null`

### 修复文件
- `parser/dsl_parser.gd`
- `core/source_of_truth.gd`
- `model/urn.gd`

## 2026-05-28: EventOption template 的 operators 通过 PDA 链路丢失

### 问题描述
CSV 中 `>option` 行指定 `template=urn:event_option:poem_giving_option` 时，生成的 `.tres` 文件中 EventOption 的 `choice_result.operators` 为空。但 `poem_giving_option.tres` template 文件本身是有 operator 的。

### 根本原因
两层问题叠加：

**第一层（代码逻辑）**：`_pda_transition` 处理 option 行时，调用 `parse_option_row()` 返回 `RandomEvent`，再从中拆包赋值给新 `EventOption`。此链路中 template 的 `choice_result` 经过 `duplicate()` + RandomEvent 包装后丢失了 operator。

**第二层（Godot 4 坑）**：`poem_giving_option.tres` 全量开启了 `resource_local_to_scene = true`（根资源、ChoiceResult、MenuStartOperator 三级全部为 true）。对该资源调用 `duplicate()` 后，返回的对象中非 `@export` 的 `var` 属性变为只读（如 `custom_context_params`），赋值即抛 `Invalid assignment` 错误。但该错误未阻断执行，只是导致 `opt.append` 被跳过（`options.size()=0`）。

### 影响范围
- 所有在 CSV 中通过 template 引用 EventOption 的 option 行
- 表现为 event 生成了但选项丢失（或选项无 operator）

### 修复方案
1. **不在 `_pda_transition` 中用 `template.duplicate()`** — 改用 `EventOption.new()` 手动构造
2. **从 template 原始资源直接拷贝字段**：`choice_result.duplicate()`（只对 ChoiceResult 层调用 duplicate，避免根资源的 `resource_local_to_scene` 副作用）
3. `uuid`、`description`、`requirement` 等从 template 或 CSV 行字段拷贝

### Godot Editor 显示 Bug（额外记录）
修复后文件内容是正确的（operator 存在），但 **Godot Editor 的 Inspector 中可能不显示 operator 内容**。这是 editor 的显示问题，不是数据丢失。以 `.tres` 文件内容为准。

如果遇到 `@tool` 脚本执行后数据看起来不对，但 `.tres` 文件内容正确的情况：
1. **右键 `.tres` 文件 → 重新导入**，或**重启编辑器**
2. 不要仅依赖 Inspector 的显示来判断数据完整性

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/parser/dsl_parser.gd" />

### 关键教训
1. **`resource_local_to_scene = true` 的 Resource 慎用 `duplicate()`** — 返回的对象属性访问行为异常
2. **手动 `new()` + 逐字段拷贝** 比 `duplicate()` 稳定得多，尤其是涉及子资源时
3. **Godot Editor Inspector 可能欺骗你** — 文件内容正确但界面不刷新时，以文件内容为准

## 2026-05-28: `extract_key_from_tres` regex 被 SubResource 的 option UUID 截胡

### 问题描述
`resources_registry_creator.gd` 创建 registry 时，包含嵌套 EventOption 的 RandomEvent 文件被注册成了 option 的 UUID 而非 event 自身的 UUID。例如 `jiaoyou_poem_public.tres` 在 registry 中的 key 被错误记录为 `jiaoyou_poem_public_opt`（option 的 UUID）而不是 `jiaoyou_poem_public`（event 的 UUID）。

### 根本原因
`extract_key_from_tres()` 使用 `RegEx.search(content)` 在全文件范围查找第一个 `uuid = "..."`。Godot 的 `.tres` 序列化顺序是：
1. `[sub_resource]` 块（内含 EventOption 等嵌套资源）
2. `[resource]` 块（主资源）

当 EventOption 有非空 UUID（如 CSV 中 option 行带了 uuid 列）时，序列化结果中 SubResource 的 `uuid = "option_uuid"` 出现在 `[resource]` 段的 `uuid = "event_uuid"` 之前。regex 命中第一个匹配，返回了 option 的 UUID。

### 影响范围
- 所有包含带 UUID 的 EventOption 的 RandomEvent `.tres` 文件
- registry 中 event 的真实 UUID 查不到，但 option UUID 指向了 event 的文件路径
- 当前 CSV 中第 3 行（`test1_give_money`）和第 13 行（`jiaoyou_poem_public_opt`）的 option 有 UUID，这两个事件的 registry key 均受影响

### 修复方案
三层降级策略，按优先级：

1. **方案一（主方案）**：直接 `load()` 资源文件，访问 `resource.uuid` 属性。这是运行时精确值，不受序列化顺序影响。
2. **方案二（兜底）**：文本解析但**仅搜索 `[resource]` 段落**，跳过 `[sub_resource]` 区域。
3. **方案三（最终兜底）**：uuid/id 都找不到时用文件名。

### 核心教训
1. **永远不要依赖 `RegEx.search(content)` 在 `.tres`/`.tscn` 文件中找第一个匹配的属性** — SubResource 先于 Resource 序列化，嵌套资源的同名字段会"截胡"。
2. **能用 `load()` 拿 Resource 对象直接访问属性就别搞文本解析** — 精确、类型安全、不受序列化格式影响。
3. **CSV option 行的 uuid 列**是有副作用的 — 虽然 option UUID 有业务含义（引用），但它会污染基于文本解析的 registry 生成逻辑。

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/resources_registry_creator.gd" />

## 2026-05-28: MenuStartOperator 参数遮蔽成员变量导致 context 丢失

### 问题描述
事件链中积累的 context 数据在 `MenuStartOperator.operate()` 发射下一个事件时全部丢失，下游事件收到的 `context` 始终是 `{}`（空字典）。

具体表现为：前一个 event/operator 在 context 中设置的键值对（如 `stamina`、`power` 等修改后的数值），到了下一个事件 init 时全部消失。

### 根本原因
GDScript 中，函数参数与成员变量同名时，参数优先（shadowing）。

```gdscript
var context: Dictionary          # 成员变量，默认 {}

func init(context: Dictionary):  # ← 参数 context 遮蔽了 self.context
    context[key] = resource      # 修改的是参数（按引用传，原调用方 dict 确实被改了）
    return context               # 返回的也是参数
                                  # self.context 从未被赋值！

func operate():
    emit(next_event_key, context) # 引用的始终是成员变量，一直为 {}
```

- `init(context: Dictionary)` 的**参数** `context` 遮蔽了**成员变量** `context`
- `context[key] = resource` 修改的是参数 dict（按引用传递），不是成员变量
- `self.context` 从未被赋值，始终是 `{}`
- `operate()` 发射下一个事件时用的成员变量 → 传出去的是空字典

### 第二层问题：无条件覆盖
`init` 中 `context[key_of_resource_in_context] = resource_to_put_in_context` 没有做任何保护性检查：
- 如果 `resource_to_put_in_context` 为 null → 在 context 中设了一个 null 值
- 没有检查传入 context 是否已有数据，也不做 logging

### 影响范围
- 所有通过 `MenuStartOperator` 跳转的事件链
- `ChoiceResult.init()` → `MenuStartOperator.init()` 链路积累的所有 context 数据（resource、modifier 等）
- 下游 RandomEvent 的 `merge_context()` 永远基于空字典叠加，效果归零

### 修复方案
1. **参数遮蔽修复**：所有路径上添加 `self.context = context`，确保成员变量始终持有正确的引用
2. **保护逻辑**（你要求）：if 传入 context 非空 && 自身无 resource → `self.context = context` 直接保留，不覆盖
3. **日志**：添加 resource 时记录旧值/新值；跳过时记录原因
4. **移除断点**：去掉 `breakpoint`

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/operators/menu_start_operator.gd" />

## 2026-05-29: Godot 4 导入缓存导致脚本修改不生效

### 问题描述
在 VS Code 中修改 `.gd` 脚本（如 `dsl_parser.gd`）后，Godot 编辑器仍然执行旧版本的代码。修改明明已经保存到文件系统了，但运行时行为完全没变。不是，是资源没有变化

具体表现为：
- `parse_context()` 中逗号分割逻辑代码正确，但合并 context 时 `poem_taste` 的值仍然是脏的完整字符串 `"urn:poem_taste:libai_taste, taste_owner_relation_flag:flag_relation_with_libai"`
- `PoemTypeChooseOperator` 从 context 读不到 `poem_taste` 的正确 URN
- `FlagOperator` 的 `taste_owner_relation_flag` 从未出现在 context 中，`flag_id` 始终为空字符串
- 停掉游戏→改代码→启动游戏，反复循环问题依旧

### 根本原因
**Godot 4 的导入缓存机制**。Godot 4 在 `.godot/` 文件夹中缓存了编译后的脚本字节码（`.gdc` 文件）。当你从外部编辑器（VS Code）修改 `.gd` 源文件时：

1. Godot 的**文件系统监视器**会检测到文件变化
2. 但**不一定会重新编译**脚本字节码，特别是当文件系统监视器出问题时
3. Godot 运行时加载的是缓存的 `.gdc` 字节码，不是修改后的 `.gd` 源码
4. 导致「明明改了代码但完全不生效」的幽灵行为 💀

**关键发现**：Godot 编辑器内打开脚本查看，内容看起来是对的（因为它读取的是 `.gd` 源码），但运行用的却是 `.godot/` 里的旧字节码。这根本不是代码 bug，是构建缓存不一致。

### 影响范围
- 所有在 Godot 编辑器外部修改的 `.gd` 脚本
- 特别是 `@tool` 模式下运行的脚本（因为 `@tool` 脚本在编辑器进程内执行，缓存更顽固）
- 症状：改代码 → 运行 → 没变化 → 再改 → 还是没变化 → 以为是自己逻辑错了 → 开始怀疑人生 🤡

### 修复方案
**方案一（根治）**：删除 `.godot/` 导入缓存文件夹
```bash
# 关闭 Godot 编辑器后执行
rm -rf <project_root>/.godot/
更安全的方式是os
# 重新打开 Godot，它会全量重新导入所有资源
```

**方案二（快速验证）**：在 Godot 编辑器中重新触发生效
1. 在 Godot 编辑器中打开对应的 `.gd` 文件
2. 做任意微小修改（加个空格就行）→ 保存
3. Godot 的文件系统监视器会检测到内部修改并重新编译

**方案三（预防）**：在 `csv_cloud_loader.gd` 中添加了「清空 Godot 缓存」按钮
- 在 Godot 编辑器中选中 `CsvCloudLoader` 节点
- Inspector 面板中找到 `Godot Cache Management > Clear Godot Cache`
- 点击即可执行 `rm -rf res://.godot/`
- ⚠️ 执行后需要重启 Godot 编辑器

### 最终教训
1. **改完代码不生效，先怀疑 Godot 缓存，再怀疑自己的逻辑** — 绝大多数「改代码没反应」都是缓存问题
2. **`.godot/` 删了不可怕** — Godot 启动时会全量重新生成，相当于清理编译器缓存
3. **`@tool` 脚本的缓存更顽固** — 因为编辑器进程内运行的脚本可能被 JIT 编译并缓存
4. **对比「编辑器内显示的代码」和「实际运行的代码」** — 如果编辑器显示正确但行为不对，大概率是缓存问题

### 相关文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/parser/dsl_parser.gd" /> （代码正确，被缓存的旧版本坑了）
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/operators/trait_choose_operator.gd" /> （受影响的 operator）
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/operators/flag_operator.gd" /> （`taste_owner_relation_flag` 没传过来导致 flag_id 为空）
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/csv_cloud_loader.gd" /> （新增的清缓存按钮）

## 2026-05-30: ItemProvider 依赖上游 context 传递，事件链从中道切入导致列表为空

### 问题描述
在文化圈派对事件链中，`start_of_wenhuaquan_party` → option → `mid_of_wenhuaquan_party` → option → `mid_of_wenhuaquan_party_choose_people` 的链路上，`ItemProvider.provide()` 返回空列表：

```
[ItemProvider.provide()] 列表 'guests' 为空，没有生成任何选项
```

但 CSV 中 `welcome_to_wenhuaquan_party` 的 option 行明确定义了 `guests=[libai;wangwei;dengqian]`。数据存在，但下游拿不到。

### 根本原因
**事件链从中道切入，上游 context 从未被填充。**

1. `guests` 数据定义在 `welcome_to_wenhuaquan_party` 事件的 option 行 [`custom_context_params`](data/random_events/random_events.csv:20) 中（CSV 第 20 行：`>option,,guests=[libai;wangwei;dengqian],,去,,queue_event(event_key=start_of_wenhuaquan_party)`）
2. 但从调试控制台执行 `$ start_of_wenhuaquan_party` 触发事件链时，[`controller.gd`](controller.gd:60) 传入的是 `{}` 空 context
3. 后续所有 operator（`QueueEventOperator` / `PushEventOperator`）的 `init()` 都只收到了 `{}`，`_captured_context` 始终为空
4. 事件链一路传导下去，[`mid_of_wenhuaquan_party_choose_people`](data/random_events/mid_of_wenhuaquan_party_choose_people.tres) 的 `ItemProvider.provide()` 调用 `context.get("guests", [])` 时，context 里根本没有 `guests` 键

**这不是代码 bug，是设计契约问题**：`ItemProvider` 依赖上游事件通过 `custom_context_params` 在 context 中填充数据。如果事件链不是从定义 context 的入口事件开始执行，整个下游都拿不到数据。Context 传递是"谁放进去谁负责"的模式，没有隐式的默认值或自动补全。

### 影响范围
- 所有通过 `ItemProvider` 动态生成选项的事件，如果数据来源于上游事件的 `custom_context_params`
- 特别是通过调试控制台 `$ event_key` 直接跳转时，context 始终是 `{}`，所有 `context.get(key, [])` 都会返回空数组
- 事件链越长，中间环节越多，context 丢失的风险越高——因为每个环节的 operator 都必须正确传递 context，任何一个环节出错都会导致下游断粮

### 防御措施
1. **调试时始终从事件链的入口事件触发**（`welcome_to_wenhuaquan_party`），不要直接从 `$ start_of_wenhuaquan_party` 切入
2. **`ItemProvider` 可以考虑加 `fallback_list` 兜底字段**：当 `list_key` 在 context 中不存在或为空时，使用硬编码的 `fallback_list` 作为备选。但这会引入数据冗余，需要权衡。
3. **`event_chain_linter.gd` 已新增检查提醒**：在 linter 执行时输出警告，提示 `ItemProvider` 的 context 依赖风险。

### 关键教训
1. **Context 是事件链的「隐式契约」** — `ItemProvider` 读取的 `list_key` 依赖上游某个事件通过 `custom_context_params` 注入。谁也没保证这个数据一定存在。这不是运行时错误，是契约违约 💀
2. **调试控制台 `$ event_key` 是「逃逸入口」** — 它直接跳过所有前置事件，context 永远是 `{}`。用它测试需要 context 数据的事件链，相当于在没装轮子的车上测试引擎 🤡
3. **`ItemProvider` 的设计本身是合理的**（动态生成，降低数据冗余），但它把数据源的契约责任推给了调用方。如果数据不在 context 里，它无能为力——`provide()` 不是算命先生，没法从虚空里变出列表。
4. **解决方向二选一**：
   - **方案 A（简单粗暴）**：`ItemProvider` 加 `fallback_list: PackedStringArray`，context 找不到时用硬编码兜底。反悔成本低，但数据分散在多个地方。
   - **方案 B（体系化）**：在 DSL 层强制要求 `ItemProvider` 的 `list_key` 来源必须在同一事件链的入口事件中有定义，linter 静态检查。反悔成本高，但根治。
   - 当前倾向于方案 A，因为项目已进入内容填充阶段，快速兜底比重构 DSL 划算。

### 相关文件
- [`core/model/item_provider.gd`](core/model/item_provider.gd) — 核心问题点，`context.get(list_key, [])` 无兜底
- [`core/operators/push_event_operator.gd`](core/operators/push_event_operator.gd) — context 传递链路
- [`core/operators/queue_event_operator.gd`](core/operators/queue_event_operator.gd) — context 传递链路
- [`data/random_events/random_events.csv`](data/random_events/random_events.csv) — 第 20-27 行：wenhuaquan party 事件链定义
- [`data/random_events/welcome_to_wenhuaquan_party.tres`](data/random_events/welcome_to_wenhuaquan_party.tres) — `guests` 定义的源头
- [`data/random_events/mid_of_wenhuaquan_party_choose_people.tres`](data/random_events/mid_of_wenhuaquan_party_choose_people.tres) — `ItemProvider` 使用 `list_key="guests"`
- [`controller.gd`](controller.gd) — 第 60 行：调试控制台传入 `{}` context
## 2026-05-30：Interruption 无限循环（push_event 不检查 target entry requirement）+ ` and ` 语法

### 问题描述

`mid_of_wenhuaquan_party` 的 interruption 条件为 `flag_int_gt(name=flag_relation_with_libai,val=20)`，当李白好感 > 20 时触发 `push_event(event_key=request_libai_changhe)`。但 `request_libai_changhe` 的 entry requirement 是 `flag_int_lt(name=flag_libai_changhe_request,val=1)`。

当 `flag_libai_changhe_request >= 1` 时：
1. interruption 条件（好感 > 20）仍然通过
2. `push_event(request_libai_changhe)` 执行
3. `request_libai_changhe` 显示后用户选择选项
4. `pop_event()` 回到 `mid_of_wenhuaquan_party`
5. interruption 再次检查 → 条件再次通过 → 无限循环

### 根本原因

`push_event` 在推入目标事件时，**不检查目标事件的 entry requirement**。interruption 条件和 entry requirement 是两个独立的检查点，前者在源事件的 `check_interruption()` 中执行，后者在目标事件从 pool 筛选时执行。`push_event` 绕过了 pool 筛选，直接插入栈。

### 影响范围

- 任何通过 `push_event` 触发且目标事件有 entry requirement 的场景都可能触发无限循环
- 根因在 interruption 条件和 entry requirement 之间的语义鸿沟

### 修复方案（双层防御）

**第一层（数据层）**：将目标事件的 entry requirement 合并到 interruption 的条件中，使用 ` and ` 语法

```csv
# 改前
interrupt_event(flag_int_gt(name=flag_relation_with_libai,val=20), random(...))

# 改后
interrupt_event(flag_int_gt(name=flag_relation_with_libai,val=20) and flag_int_lt(name=flag_libai_changhe_request,val=1), random(...))
```

**第二层（代码层）**：在 `narrative_overlay.gd` 的 `_on_push_event()` 中增加防御检查

```gdscript
if ev is RandomEvent and ev.requirement:
    ev.requirement.init(context)
    if not ev.requirement.compare(PlayerState):
        Logging.warn("push_event: 事件 '%s' 的 entry requirement 未通过，忽略 push" % ev.name)
        return
```

### 修复文件
- [`data/random_events/random_events.csv`](data/random_events/random_events.csv) — 第 24 行：`mid_of_wenhuaquan_party` interruption 条件加 ` and flag_int_lt(name=flag_libai_changhe_request,val=1)`
- [`parser/dsl_parser.gd`](parser/dsl_parser.gd) — `parse_interruption_field()` 新增 ` and ` 语法支持
- [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd) — `_on_push_event()` 增加 entry requirement 防御检查

### 关键教训

1. **Interruption 条件和 Entry Requirement 是正交的** — 前者在源事件的 `check_interruption()` 中检查，后者在目标事件 pool 筛选时检查。`push_event` 绕过 pool 筛选，两者之间没有自动的守护关系。
2. **` and ` 语法**填补了 interruption 条件无法表达多条件 AND 守卫的空白。相比用逗号（会被 `split_expressions` 误拆成第 3 个参数），` and ` 作为关键词分隔符是侵入性最小的方案。
3. **防御深度**：数据层（CSV 条件）→ 代码层（`_on_push_event` 检查）→ 提醒层（linter），三层防御确保这个问题不会再次出现。

## 2026-05-31: 飞花令 Runtime — 类型契约断裂 + CSV 转义迷宫

### 场景
实现飞花令（feihualing）玩法全流程：RandomPickOperator 抽意象 → ItemProvider 展示选项 → ContextFetchOperators 查意象数据 → NpcBatchCheckOperator 批量检定 NPC。

### 诱因 1：`parse_context` 产出 `PackedStringArray`，下游只认 `Array`
CSV context 列 `guests=[libai;wangwei;dengqian]` 被 [`dsl_parser.gd:193`](parser/dsl_parser.gd:193) 解析为 `PackedStringArray`（故意选择，内存效率高）。但 [`NpcBatchCheckOperator:62`](core/operators/npc_batch_check_operator.gd:62) 只检查 `is Array`，直接拒绝。ItemProvider 没炸是因为 `for item in target_list` 兼容两种类型。

**根因**：数据生产方（`parse_context`）和消费方（operator）之间的类型契约只靠「运行时撞上才知道」来验证，没有中间层做归一化。`PackedStringArray` 和 `Array` 在 GDScript 里行为相似但不相同，`is` 检查就是分水岭。

**教训**：
- 跨层传递集合数据时，必须在**消费入口**做归一化（NpcBatchCheckOperator 现在先检查 `is Array or is PackedStringArray`，再统一 `Array(participants)` 转成 `Array`）。
- `parse_context` 选 `PackedStringArray` 本身没错（更紧凑），但这个选择应该通过文档或类型守卫传播到所有下游。隐式类型契约 = 定时炸弹 💀

### 诱因 2：CSV 四重引号 `""""` 看似工作其实是运气
[`random_events.csv:32`](data/random_events/random_events.csv:32) 的 provider 列用了 `""""` 四重引号包裹参数值。这个项目的 CSV 解析器（[`csv_parser.gd`](core/utils/csv_parser.gd)）用 `"` toggle 模式（不是标准 CSV 的 `""` → 一个字面量 `"`），所以 `""""` 和 `""` 在功能上完全等价——都只是两次 `in_quotes` 翻转，最终都不产出引号字符。

但**这只是巧合**：如果哪天换上了标准 CSV 解析器（或者把文件塞回 Google Sheets 编辑再导出），`""""` 就真的变成两个字面量 `"` 了。

**教训**：自定义 CSV 解析器用 `"` toggle 模式而非标准 `""` escape 模式，导致与 Google Sheets 的 CSV 格式存在「语义鸿沟」：
- Google Sheets 里：`""` = 一个字面量 `"`
- 本项目：`""` = 两次 in_quotes 翻转，不产出任何字符
- 同一个文件在两种解析器下行为不同，但看起来都「正确」——这是最危险的那种不一致 💀

解决方案：要么保持 toggle 模式且永远不用 Google Sheets 编辑此文件，要么统一成标准 CSV escaping。当前选择前者（文件全手工维护），但这一点应该写进项目文档的 CSV 格式说明里。

### 诱因 3：`ctx.duplicate()` 连带 `PackedStringArray` 进入 `format_args`
[`NpcBatchCheckOperator:97`](core/operators/npc_batch_check_operator.gd:97) 的 `var format_args = ctx.duplicate()` 把整个 context（含 `guests:PackedStringArray`）复制进 format_args。虽然 `String.format()` 只匹配模板中的 `{keyword}` 占位符，不会遍历所有键，但这意味着 `guests` 这样的集合数据被不必要地带入格式化上下文——如果哪天有人在翻译模板里写了 `{guests}`，`String.format()` 遇到 `PackedStringArray` 的行为是未定义的。

**教训**：`format_args` 应该只包含模板实际需要的键。`ctx.duplicate()` 是懒惰的「全部拿来」模式，正确做法是显式构建：
```gdscript
var format_args = {"npc_name": tr("CHAR_NAME_%s" % ...)}
# 只复制模板需要的 context 字段
for key in ["keyword", "imaginary_desc"]:
    if ctx.has(key):
        format_args[key] = str(ctx[key])
```
但这是优化级别的建议——当前实现够用。记住这个隐患就行。

### 相关文件
- [`parser/dsl_parser.gd:193`](parser/dsl_parser.gd:193) — `PackedStringArray()` 产出源头
- [`core/operators/npc_batch_check_operator.gd:62-72`](core/operators/npc_batch_check_operator.gd:62) — 修复：兼容 Array + PackedStringArray + 归一化
- [`data/random_events/random_events.csv:32`](data/random_events/random_events.csv:32) — 四重引号修复
- [`core/utils/csv_parser.gd`](core/utils/csv_parser.gd) — `"` toggle 模式解析器，与标准 CSV 存在语义鸿沟

---

## 2026.05.31 — 飞花令修复补丁（第二阶段）

### 问题 1：Resource.has() 不存在

**诱因**：`doc` 是 `NPCDocument`（extends `Resource`），`Resource` 没有 `.has()` 方法。
`NPCDocument.prop` 有默认值 `= {}`，不会为 null。

**现象**：`Database.query_prop()` 调用 `doc.has("prop")` → 崩溃。

**修复**：`var props: Dictionary = doc.prop; if props.is_empty():` — 直接访问 prop 字段
（保证非 null），判空用 `is_empty()`。

### 问题 2：翻译文件在 Resource 脚本中不生效

**诱因**：Godot 4 的 `[locale] translations=PackedStringArray(...)` 自动加载机制
在 `@tool` Resource 脚本（非 Node）的 `tr()` 调用中可能不工作。引擎只在 Node 初始化时
绑定翻译上下文，Resource 脚本的 `tr()` 绕过 TranslationServer。

**现象**：`tr("FEIHUALING_FAIL")` 返回 `"FEIHUALING_FAIL"` 而非中文文本。
`.zh.translation` 文件内容完整但不被 `tr()` 访问。

**修复**：在 `Database._init()` 中显式调用 `TranslationServer.add_translation(trans)` 注入
翻译资源。同时添加调试日志确认加载状态。

**防御建议**：所有依赖翻译的 `@tool` Resource 都应通过 TranslationServer 而非 `tr()` 获取
翻译，或在 Autoload 中统一注入。

### 相关文件
- [`core/database.gd:48-57`](core/database.gd:48) — 显式加载翻译
- [`data/translations/dynamic_events.csv`](data/translations/dynamic_events.csv) — 翻译表
- [`data/translations/dynamic_events.zh.translation`](data/translations/dynamic_events.zh.translation) — 编译后翻译资源
