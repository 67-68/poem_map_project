# CSV随机事件数据目录

本目录用于存放使用DSL定义的随机事件CSV文件。

## 文件说明

### dsl_events_example.csv
完整的DSL事件示例文件，包含10个不同类型的事件示例，展示了DSL的各种语法和用法。

## CSV文件格式

CSV文件必须遵循以下表头结构：

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,
Opt_A_Text,Opt_A_Req,Opt_A_Result,
Opt_B_Text,Opt_B_Req,Opt_B_Result,
Opt_C_Text,Opt_C_Req,Opt_C_Result,
Opt_D_Text,Opt_D_Req,Opt_D_Result,
Opt_E_Text,Opt_E_Req,Opt_E_Result,
Opt_F_Text,Opt_F_Req,Opt_F_Result
```

## 标签格式规范

**推荐使用四段式标签格式**: `domain:category:type:specific`

**示例**:
- `actor:status:temporary:drunk` - 人物状态-临时状态-醉酒
- `city:econ:level:prosperous` - 城市经济-繁荣程度-繁华
- `action:intent:study:poetry` - 行动意图-学习类型-诗歌

**兼容三段式格式**: `domain:category:value`

系统会自动通过 `TagManager.normalize_3part_depreciated_tag()` 处理格式兼容。

## 使用方法

### 1. 创建CSV文件
在当前目录创建新的CSV文件，按照上述格式填写事件数据。

### 2. 解析CSV数据
使用DSLParser解析CSV文件：

```gdscript
var csv_data = CSVCloudLoader.load_csv("res://data/csv_random_events/your_file.csv")
var events = DSLParser.parse_csv_data(csv_data)
```

### 3. 验证事件数据
```gdscript
for event in events:
    if DSLParser.validate_event(event):
        print("事件验证通过: ", event.uuid)
    else:
        print("事件验证失败: ", event.uuid)
```

## 详细文档

- [DSL CSV表格结构指南](../../DOCUMENTATIONS/dsl_csv_structure_guide.md) - 详细的CSV格式说明和示例
- [DSL功能和使用文档](../../DOCUMENTATIONS/dsl_documentation.md) - DSL语法和功能说明

## 注意事项

- 文件编码必须为UTF-8
- 字段分隔符使用逗号(,)
- 空字段直接留空即可
- Event_ID必须唯一
- Trigger_Tags不能为空
- 至少需要包含一个选项

## 示例事件类型

示例文件中包含以下类型的事件：
- 社交事件 (酒馆奇遇、市场诗会)
- 官场事件 (官场会晤)
- 宗教事件 (古寺寻幽)
- 冒险事件 (山贼拦路)
- 节日事件 (节日庆典)
- 学术事件 (学术辩论)
- 生活事件 (求医问药、商机发现、家乡团聚)

## 扩展

如需添加新的CSV文件，请参考 `dsl_events_example.csv` 的格式，并确保遵循DSL语法规范。