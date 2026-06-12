# data/event_base/ —— 事件库目录

## 目录结构约定

```
data/event_base/
├── actions/                 【高频复用区】玩家主动点击抽取的事件池
│   ├── baiye/               拜谒相关事件
│   ├── denggao/             登高/游山玩水事件
│   └── ...                  按交互类型创建子文件夹
├── random_encounters/       【被动触发区】每旬随机砸到玩家头上的事件
│   └── weather_changes/     天气变化类事件
└── story_arcs/              【强线性剧本区】绝对不允许随机抽取的特殊场景！
    ├── exam_747_fraud/       747科举断头台
    └── changan_rain_walk/    漫步长安事件
```

## 命名空间机制

- **文件夹层级 = 命名空间**：例如 `actions/baiye/` 下的文件命名空间为 `actions.baiye.`
- **运行时扁平化**：`EventBaseLoader` 将目录树扫描为平坦的 `{ "ns.uuid": Resource }` 字典
- **按 Base 分表**：每个顶层文件夹自动成为一个独立的表，可通过 `Database.event_bases["actions"]["uuid"]` 访问
- **查询语法**：支持 `Database.find_from_all("actions.event_id")` 点号语法

## 如何添加新事件

1. 在合适的分类文件夹下创建 `.tres` 资源文件
2. 确保资源文件包含 `uuid` 字段（字符串类型，全局唯一）
3. 重启游戏或重新加载场景即可自动注册

## 规则

- 每个事件 `.tres` 必须包含 `uuid` 字段（无 uuid 的文件会被跳过并 warn）
- `uuid` 需全局唯一（跨所有 base），否则加载时报 `push_error` 冲突
- 避免在 `event_base/` 根目录直接放 `.tres` 文件（应放在子分类文件夹中）
- `.DS_Store` 等系统文件会自动跳过
