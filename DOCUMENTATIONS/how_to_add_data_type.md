# 如何添加新的数据类型

**所有数据类型，无论加载方式，都必须经过 `core/database.gd` — 这是统一的数据入口。**

如果你想在游戏中新增一种资源（例如"文物"数据），操作流程如下：

## Step 1: `model/enumerates.gd` — 注册 URN 类型

在 `enum URN_TYPE` 末尾追加：

```gdscript
ARTIFACT,  # artifacts — 文物数据
```

## Step 2: `core/database.gd` — 声明变量 + 加载数据

### 2a. 声明变量

在文件顶部加入变量声明：

```gdscript
var artifacts: Dictionary
```

### 2b. 在 `_init()` 中加入加载逻辑

根据数据来源，四种方式选一：

```gdscript
# 方式 1: Registry (.tres 注册表) — 适用于分散的 .tres 资源文件
artifacts = Util.create_dict_from_registry(load("res://data/tres_artifacts_registry.tres"))

# 方式 2: CSV 模型 — 适用于表格数据
artifacts = Util.create_dict(DataLoader.load_csv_model(Artifact, 'artifacts'))

# 方式 3: DataHelper 事件系统 — 适用于事件相关数据
var event_data = DataHelper.load_event_data()
artifacts = event_data.artifacts

# 方式 4: 直接加载单个资源（极少用）
artifacts = { "my_artifact": load("res://data/artifacts/my_artifact.tres") }
```

**重要：** 如果数据目录还没有 registry 文件（方式 1），需要：
1. 在 `data/` 下创建类型目录（如 `data/artifacts/`）
2. 放入 `.tres` 资源文件
3. 给资源类加 `@export var uuid: String` 字段
4. 在每个 `.tres` 文件中设置 `uuid = "唯一标识"`
5. 创建 registry 文件 `data/artifacts_registry.tres`，参考格式：
```
[gd_resource type="Resource" script_class="ResourceRegistry" format=3]

[ext_resource type="Script" path="res://core/model/resources.gd" id="1"]

[resource]
script = ExtResource("1")
resources = {
"my_artifact": "res://data/artifacts/my_artifact.tres"
}
```

## Step 3: `core/database.gd` — 加入查找链

如果新类型需要通过 `find_triggerable_item(uuid)` 按 uuid 查到，在函数末尾加对应分支：

```gdscript
if artifacts.get(uuid):
    return artifacts[uuid]
```

## Step 4: `DOCUMENTATIONS/urn_system.md` — 更新类型表格

在资源类型表格中追加一行：

```
| artifact | artifacts | Registry/CSV/DataHelper | 文物数据 |
```

## 概览

| 步骤 | 文件 | 改动量 |
|------|------|--------|
| 注册 URN 类型 | `model/enumerates.gd` | +1 行 enum |
| 声明变量 | `core/database.gd` 顶部 | +1 行 |
| 加载数据 | `core/database.gd` _init() | +1 行 |
| 创建 registry（如需） | `data/<type>_registry.tres` | 新建文件 |
| 查找链 | `core/database.gd` find_triggerable_item() | +3 行 |
| 更新文档 | `DOCUMENTATIONS/urn_system.md` | +1 行表格 |
