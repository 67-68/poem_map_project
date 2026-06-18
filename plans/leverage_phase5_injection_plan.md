# Phase 5: leverage_add 注入现存事件 — 执行方案

## 数据流

```
Config JSON (event_base_config_*.json) --reassembly--> CSV (_*_events.csv) --Godot import--> .tres
```

修改 Config JSON → 跑 `--reassembly` → 验证 .tres

## DSL 优先级链 (io_csv.py:157-167)

```
dimension_value.option_results[choice.id]  >  choice.result (option_features)  >  空
```

## 12 杠杆点 → 7 个 Config JSON

| # | Config ID | Event ID | Target Tag | Leverage Key | 需改的 Option |
|---|-----------|----------|------------|--------------|---------------|
| 1 | `zhuoliu_lieqi` | `cockfight_ode` | `TARGET_IDENTITY_QUANGUI` | `quangui_cockfight_gambling` | opt_kuangke, opt_fengying, opt_zuanying |
| 2 | `zhuoliu_lieqi` | `swill_gambit` | `TARGET_IDENTITY_QUANGUI` | `quangui_swill_gamble` | opt_kuangke, opt_fengying, opt_zuanying |
| 3 | `zhuoliu_lieqi` | `hijacked_grief` | `TARGET_IDENTITY_QUANGUI` | `quangui_paper_ash` | opt_kuangke, opt_fengying, opt_zuanying |
| 4 | `zhuoliu_lieqi` | `ghostwriter_blood` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` | `zhuoliu_epitaph_coercion` | opt_kuangke, opt_fengying, opt_zuanying |
| 5 | `zize` | `wine_boy` | `TARGET_IDENTITY_QUANGUI` | `quangui_wine_boy_violence` | opt_zize_bear |
| 6 | `kuangke_zhuoliu` | `malicious_misinterpretation` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` | `zhuoliu_textual_trap` | opt_kuangke（锁定的 opt_fengying/opt_zuanying 不改） |
| 7 | `kuangke_zhuoliu` | `zoo_animal` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` | `zhuoliu_speech_pricing` | opt_kuangke（锁定的 opt_fengying/opt_zuanying 不改） |
| 8 | `zhuoliu_fengying` | `ledger_gap` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` | `zhuoliu_accounting_fraud` | opt_kuangke, opt_fengying, opt_zuanying |
| 9 | `qingliu_zuanying` | `monetized_guest_list` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` | `qingliu_class_discrimination` | opt_zuanying |
| 10 | `qingliu_zuanying` | `ghostwriter_collision` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` | `qingliu_ghostwriter_scandal` | opt_zuanying |
| 11 | `qingliu_fengying` | `ghostwriting` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` | `qingliu_academic_fraud` | opt_fengying |
| 12 | `duotai_humiliation` | `cheap_labor` × 4 gateways | `TARGET_IDENTITY_VENDOR` | `vendor_cheap_labor` | opt_kuangke, opt_fengying, opt_zuanying |

## 修改细则

### 1. zhuoliu_lieqi (4 events, 每个 3 options = 12 行修改)

**cockfight_ode** → `dimensions[0].values[]` 中 id=cockfight_ode 的 `option_results`:
```
opt_kuangke 末尾追加:  | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_cockfight_gambling")
opt_fengying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_cockfight_gambling")
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_cockfight_gambling")
```

**swill_gambit** → `option_results`:
```
opt_kuangke 末尾追加:  | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_swill_gamble")
opt_fengying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_swill_gamble")
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_swill_gamble")
```

**hijacked_grief** → `option_results`:
```
opt_kuangke 末尾追加:  | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_paper_ash")
opt_fengying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_paper_ash")
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_paper_ash")
```

**ghostwriter_blood** → `option_results`:
```
opt_kuangke 末尾追加:  | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_epitaph_coercion")
opt_fengying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_epitaph_coercion")
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_epitaph_coercion")
```

### 2. zize (1 event, 1 option = 1 行修改)

**wine_boy** → `dimensions[0].values[]` 中 id=wine_boy 的 `option_results`:
```
opt_zize_bear 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_wine_boy_violence")
```

### 3. kuangke_zhuoliu (2 events, 仅 opt_kuangke = 2 行修改)

**malicious_misinterpretation** → `option_results`:
```
opt_kuangke 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_textual_trap")
(opt_fengying, opt_zuanying 不改 — 已锁)
```

**zoo_animal** → `option_results`:
```
opt_kuangke 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_speech_pricing")
(opt_fengying, opt_zuanying 不改 — 已锁)
```

### 4. zhuoliu_fengying (1 event, 3 options = 3 行修改)

**ledger_gap** → `dimensions[0].values[]` 中 id=ledger_gap 的 `option_results`:
```
opt_kuangke 末尾追加:  | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_accounting_fraud")
opt_fengying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_accounting_fraud")
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_ZHUOLIU_OFFICIAL"; key="zhuoliu_accounting_fraud")
```

### 5. qingliu_zuanying (2 events, 仅 opt_zuanying = 2 行修改)

**monetized_guest_list** → `option_results`:
```
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QINGLIU_OFFICIAL"; key="qingliu_class_discrimination")
```

**ghostwriter_collision** → `option_results`:
```
opt_zuanying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QINGLIU_OFFICIAL"; key="qingliu_ghostwriter_scandal")
```

### 6. qingliu_fengying (1 event, 1 option = 1 行修改)

**ghostwriting** → `dimensions[0].values[]` 中 id=ghostwriting 的 `option_results`:
```
opt_fengying 末尾追加: | leverage_add(target_tag="TARGET_IDENTITY_QINGLIU_OFFICIAL"; key="qingliu_academic_fraud")
```

### 7. duotai_humiliation (cheap_labor dimension value, 3 options = 新建 3 行)

`cheap_labor` dimension value 当前**没有** `option_results`，需要新建：
- 将 `option_features[].result` 复制过来
- 追加 ` | leverage_add(target_tag="TARGET_IDENTITY_VENDOR"; key="vendor_cheap_labor")`

新建的 `option_results`:
```json
"option_results": {
    "opt_kuangke": "prop_add(name=kuangda; val=2)|prop_sub(name=fatigue; val=3)|leverage_add(target_tag=\"TARGET_IDENTITY_VENDOR\"; key=\"vendor_cheap_labor\")",
    "opt_fengying": "prop_add(name=kuangda; val=1)|prop_sub(name=money; val=3)|leverage_add(target_tag=\"TARGET_IDENTITY_VENDOR\"; key=\"vendor_cheap_labor\")",
    "opt_zuanying": "prop_add(name=kuangda; val=-1)|prop_add(name=money; val=5)|prop_sub(name=health; val=2)|leverage_add(target_tag=\"TARGET_IDENTITY_VENDOR\"; key=\"vendor_cheap_labor\")"
}
```

**⚠️ 关键**：`dimension_value.option_results` 会**完全覆盖** `option_features[].result`（优先级更高），所以必须包含完整的 result DSL 而不只是 leverage_add 片段。

## Reassembly 执行顺序（7 次）

1. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly zhuoliu_lieqi`
2. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly zize`
3. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly kuangke_zhuoliu`
4. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly zhuoliu_fengying`
5. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly qingliu_zuanying`
6. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly qingliu_fengying`
7. `.venv/bin/python tools/generate_orthogonal_events.py --reassembly duotai_humiliation`

## 验证方式

- 检查 CSV option 行的 `results` 列是否包含 `leverage_add(...)`
- 检查 .tres 中是否有 `LeverageAddOperator` sub-resource（`[ext_resource type="Resource" path=...]` 或 inline SubResource）
- `grep -r "leverage_add" data/4_eras/747_kuangda/*.csv` 应有输出

---

## Phase 6: CSV → .tres 导入 (COMPLETED ✅)

### 6a: DATA_MANIFEST 补充
- `_zhuoliu_lieqi_events.csv` 添加到 `core/csv_cloud_loader.gd` 的 DATA_MANIFEST

### 6b: Godot 全量导入
- 触发 `_import_generated_events_from_csv()`，16 个生成事件库全部成功导入
- 生成 .tres 文件分布在各 gateway 目录（baiye/jiaoyou/fangshi/duzhuo/fengzhao 等）

### 6c: LeverageAddOperator 验证
| 事件库 | CSV 杠杆行数 | .tres 含杠杆事件数 | 状态 |
|--------|------------|------------------|------|
| zhuoliu_lieqi | 12 | 4/5 | ✅ (poverty_tourism 无杠杆为预期) |
| zhuoliu_fengying | 3 | 1 | ✅ |
| zhuoliu_zuanying | 0 | 0 | ✅ (未注入杠杆) |
| qingliu_fengying | 1 | 1 | ✅ |
| qingliu_zuanying | 2 | 2 | ✅ |
| kuangke_zhuoliu | 2 | 2 | ✅ |
| duotai_humiliation | 12 | 4 | ✅ (每 gateway 含 3 个 operator) |
| zize | 1 | 1 | ✅ |
| **总计** | **33** | — | ✅ **全部匹配** |

### Bug 修复记录
- `tools/event_generator/main.py:896` — UUID fallback 匹配（_identity_* 后缀）
- `tools/event_generator/io_csv.py:160` — accept_influence 过滤修复 (accepted → combos)
- `tools/event_generator/dsl_parser.py:22` — leverage_add 加入 KNOWN_NON_PROP_OPS 白名单
