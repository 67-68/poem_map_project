# AudioManager — 四轨音频架构

## 相关文件
- [`core/audio_manager.gd`](core/audio_manager.gd:1) — 全部四轨实现
- [`core/operators/ambient_audio_operator.gd`](core/operators/ambient_audio_operator.gd:1) — DSL 触发入口（Ambient / AmbientMusic）
- [`ui/main_action_button.gd`](ui/main_action_button.gd:16) — ActionAmbient 触发入口
- [`ui/action_panel_manager.gd`](ui/action_panel_manager.gd:19) — 行动面板中文名
- [`main.gd`](main.gd:311) — profile 注册

## 四轨架构

| 轨道 | 优先级 | 驱动方式 | 播放模型 |
|------|--------|---------|---------|
| **BGM** | 最高 | 叙事驱动 `play_music()` | 双轨淡入淡出 |
| **ActionAmbient** | 中 | 行动按钮点击触发 | 单曲播放 → 60s 上限/曲终自动停止 |
| **Ambient** | 低 | DSL Operator 驱动 | 多层并行环境音 |
| **AmbientMusic** | 低 | Timer 自主随机循环 | 单轨 → 静默 → 下一首 |

## 互斥规则

```
BGM 播放 → 暂停所有（ActionAmbient + Ambient + AmbientMusic）
BGM 结束 → 恢复（按优先级）

ActionAmbient 播放 → 暂停 Ambient + AmbientMusic（同优先级但仍暂停低优先级）
ActionAmbient 结束 → 恢复 Ambient + AmbientMusic

Ambient ↔ AmbientMusic 同级互斥
```

## ActionAmbient — 行动触发环境音

### 触发时机
[`MainActionButton._on_clicked()`](ui/main_action_button.gd:16) 最开头，cost 扣除之前。

### 文件命名规则
`assets/sounds/backgrounds/actions/{action_uuid}.ogg`

### 生命周期
```
[按钮点击] → play_action_ambient(parent_uuid)
   ├─ 停止旧 ActionAmbient
   ├─ 暂停 Ambient + AmbientMusic
   ├─ 加载 assets/sounds/backgrounds/actions/{uuid}.ogg
   ├─ 播放 + 启动 60s 上限 Timer
   │
   ├─ [BGM 开始] → stream_paused + timer stop
   ├─ [BGM 结束] → stream_paused=false + timer restart(60s)
   │
   ├─ [下次行动] → 替换为新 action ambient
   │
   └─ [曲终 或 60s] → 停止 → 恢复 Ambient/AmbientMusic
```

### API
```gdscript
AudioManager.play_action_ambient(action_uuid)    # 播放
AudioManager.stop_action_ambient()               # 停止
AudioManager.is_action_ambient_active()          # 查询
```

## Ambient / AmbientMusic — 同前

### Public API

```gdscript
# Ambient（环境音）
AudioManager.register_ambient_profile(key, layers)
AudioManager.set_ambient_profile(key)
AudioManager.clear_ambient_profile()

# AmbientMusic（不定时氛围音乐）
AudioManager.register_ambient_music_profile(key, pool, min_silence=30.0, max_silence=90.0, volume_db=0.0)
AudioManager.set_ambient_music_profile(key)
AudioManager.clear_ambient_music_profile()
AudioManager.ambient_music_force_silence()

# ActionAmbient（行动触发）
AudioManager.play_action_ambient(action_uuid)
AudioManager.stop_action_ambient()
```

## DSL Operator 使用

```
# Ambient
ambient_audio(action=set_profile; profile_key=755_backhome)
ambient_audio(action=clear)

# AmbientMusic
ambient_audio(action=set_music_profile; profile_key=royal_ambient)
ambient_audio(action=clear_music)
```
