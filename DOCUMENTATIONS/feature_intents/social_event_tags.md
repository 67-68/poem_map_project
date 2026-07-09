# 社交事件 Tag 分类

每个社交事件必须至少存在一个如下分类 tag，写入事件的 `target_tags` 数组。

## 社交分类 Tags

| Tag | 含义 | 使用方 | 备注 |
|-----|------|--------|------|
| `social:acquaint` | 首次结识 | 雅集、同游长安、宴席推荐信 | 玩家第一次「发现」一个 NPC |
| `social:baiye` | 拜谒行卷 | 广发行卷 | 投递诗文/行卷场景 |
| `social:leverage` | 把柄/刺探 | 暗巷刺探 | 涉及获取他人隐秘 |
| `social:upgrade` | 关系升级 | 普通拜谒 | 关系状态从 A → B |
| `social:intro` | 引荐推荐信 | 宴席（推荐信） | 获得某人的引荐信 |

## NPC Tag 格式

NPC 使用四段式 tag：**`actor:npc:{target_tag}`**

| target_tag | NPC Tag |
|-----------|---------|
| libai | `actor:npc:libai` |
| hushang | `actor:npc:hushang` |
| wangwei | `actor:npc:wangwei` |
| zhengqian | `actor:npc:zhengqian` |
| gaoshi | `actor:npc:gaoshi` |
| qingliu | `actor:npc:qingliu` |
| lilinfu | `actor:npc:lilinfu` |
| jiwen | `actor:npc:jiwen` |
| youxiangfu | `actor:npc:youxiangfu` |
| waiqi | `actor:npc:waiqi` |
| yangguozhong | `actor:npc:yangguozhong` |
| guoguofuren | `actor:npc:guoguofuren` |

## 事件匹配机制

事件扫描使用 **AND 模式**（`tag_match_mode='all'`），
事件必须 **同时** 拥有 NPC tag + 社交分类 tag 才能被命中。

### 示例

一个雅集事件「初遇李白」的 `target_tags`：
```gdscript
["actor:npc:libai", "social:acquaint"]
```

一个暗巷刺探事件「窥见商人秘密」的 `target_tags`：
```gdscript
["actor:npc:hushang", "social:leverage"]
```

### Fallback

如果池空未命中任何事件，使用 Action 的 `fallback_event_uuid` 兜底叙事。
Fallback 事件中可通过 `{@npc_name}` 动态插值展示 NPC 名。
