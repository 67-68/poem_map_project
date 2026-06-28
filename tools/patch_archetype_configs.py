#!/usr/bin/env python3
"""
Phase 3: 批量修改事件库 JSON 配置文件

1. 单行动库 → 设置 config 级 archetype_id
2. 跨行动库 → 维度值加 archetype_id（从 stored_to 提取） + 清洗 operator_dsl（删除 prop_*，保留 emo_*/imagery_*）
"""
import json
import re
import os

BASE_DIR = "/Users/a67_68/projects/dufu_simulator/tools"

# ── 单行动事件库（config 级 archetype_id） ──
SINGLE_ACTION_LIBRARIES = {
    "event_base_747kuangda_denggao.json": "denggao",
    "event_base_config_scene_imagery.json": "baiye",
    "event_base_config_ganlu_journey.json": "ganlu",
    "bai_ye_honeymoon_config.json": "baiye",
    # bai_ye_real_appearance 已设置，跳过
}

# ── 跨行动事件库（维度值级 archetype_id） ──
MULTI_ACTION_LIBRARIES = [
    # 格式: (config_filename, [维度ID列表], 归档的store_to提取规则)
    "event_base_config_duotai_humiliation.json",
    "event_base_config_kuangke_qingliu.json",
    "event_base_config_kuangke_zhuoliu.json",
    "event_base_config_qingliu_passive_benefits.json",
    "event_base_config_qingliu_fengying.json",
    "event_base_config_qingliu_zuanying.json",
    "event_base_config_qingliu_daoxin_posui.json",
    "event_base_config_qingliu_jiaolv.json",
    "event_base_config_zhuoliu_fengying.json",
    "event_base_config_zhuoliu_zuanying.json",
    "event_base_config_zhuoliu_lieqi.json",
    "event_base_config_zize.json",
]


def clean_operator_dsl(dsl: str) -> str:
    """清洗 operator_dsl：删除所有 prop_* 操作，保留 emo_* 和 imagery_*。"""
    if not dsl:
        return dsl
    parts = dsl.split("|")
    cleaned = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        # 只保留 emo_* 和 imagery_* 操作
        if part.startswith("prop_"):
            continue  # 删除属性操作
        cleaned.append(part)
    return "|".join(cleaned)


def extract_archetype_from_stored_to(stored_to: str) -> str:
    """从 stored_to 提取 archetype_id。
    如 '747_kuangda.fangshi' → 'fangshi', '755_backhome.ganlu' → 'ganlu'
    """
    if "." in stored_to:
        return stored_to.split(".")[-1]
    return stored_to


def patch_single_action(filename: str, archetype_id: str):
    """为单行动库设置 config 级 archetype_id。"""
    path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(path):
        print(f"  ❌ 文件不存在: {filename}")
        return False
    
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    old = data.get("archetype_id", "")
    if old == archetype_id:
        print(f"  ⏭️  {filename}: 已是 archetype_id={archetype_id}")
        return False
    
    data["archetype_id"] = archetype_id
    
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"  ✅ {filename}: archetype_id {old or '(空)'} → {archetype_id}")
    return True


def patch_multi_action(filename: str):
    """为跨行动库的维度值加 archetype_id + 清洗 operator_dsl。"""
    path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(path):
        print(f"  ❌ 文件不存在: {filename}")
        return False
    
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    changed = False
    
    for dim in data.get("dimensions", []):
        for val in dim.get("values", []):
            stored_to = val.get("stored_to", "")
            original_dsl = val.get("operator_dsl", "")
            
            # ── 加 archetype_id ──
            if stored_to:
                archetype = extract_archetype_from_stored_to(stored_to)
                if val.get("archetype_id", "") != archetype:
                    print(f"  📌 {filename}/{val['id']}: archetype_id → {archetype}")
                    val["archetype_id"] = archetype
                    changed = True
            
            # ── 清洗 operator_dsl ──
            if original_dsl:
                cleaned = clean_operator_dsl(original_dsl)
                if cleaned != original_dsl:
                    print(f"  🧹 {filename}/{val['id']}: operator_dsl 清洗")
                    print(f"      旧: {original_dsl}")
                    print(f"      新: {cleaned}" if cleaned else f"      新: (空)")
                    val["operator_dsl"] = cleaned
                    changed = True
    
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"  ✅ {filename}: 已更新")
    else:
        print(f"  ⏭️  {filename}: 无变更")
    
    return changed


def main():
    print("=" * 60)
    print("Phase 3: 批量修改事件库 JSON 配置文件")
    print("=" * 60)
    
    # ── 单行动库 ──
    print("\n--- 单行动库 (config 级 archetype_id) ---")
    for filename, archetype_id in SINGLE_ACTION_LIBRARIES.items():
        patch_single_action(filename, archetype_id)
    
    # 检查 bai_ye_real_appearance 是否已设
    path = os.path.join(BASE_DIR, "event_base_config_bai_ye_real_appearance.json")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    print(f"  ℹ️  bai_ye_real_appearance: archetype_id={data.get('archetype_id','(空)')} (已有)")
    
    # ── 跨行动库 ──
    print("\n--- 跨行动库 (维度值级 archetype_id + operator_dsl 清洗) ---")
    for filename in MULTI_ACTION_LIBRARIES:
        patch_multi_action(filename)
    
    print("\n" + "=" * 60)
    print("Phase 3 完成！")
    print("=" * 60)


if __name__ == "__main__":
    main()
