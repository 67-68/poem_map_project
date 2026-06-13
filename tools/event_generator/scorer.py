"""
V2 情绪-意象正交打分器 — 策略函数域。

包含:
  extract_image_pool    从维度 tags 提取意象 ID 池
  is_valid_combination  场景×情绪剪枝过滤器
  pick_best_image       按情绪亲缘度打分选出最佳意象
"""

import logging
import random
from typing import Optional

# 延迟导入避免循环依赖，仅在类型检查时导入
from tools.config import ImageryItem


def extract_image_pool(
    combos: list,       # list[DimensionCombo]
    scene_dim_id: str,  # 场景维度的 id，如 "scene"
) -> list[str]:
    """
    从场景维度值的 tags 中提取意象 ID 列表。

    每个 tag 可以是：
    - 两段式冒号格式，如 "VIBE_PHILOSOPHY_ZEN:temple_bell" → 整个 tag 就是 image_dict 的 key
    - 三段式冒号格式，如 "ENV:NATURE_NIGHTMOON:cold_moon:general" → 取 "NATURE_NIGHTMOON:cold_moon"
    - 下划线格式，如 "TARGET_PLACE_JADESTEP_DAILOU" → 取 "PLACE:JADESTEP"

    提取规则：
    - 跳过以 "action:" 开头的 tag（这些是动作标签，不是意象）
    - 优先按冒号分割：
      1. len(parts) >= 3 → 取 parts[1]:parts[2]（兼容旧格式）
      2. len(parts) == 2 → 整个 tag 就是 image_dict 的 key，直接使用（🆕 两段式冒号）
    - 回退到下划线分割（兼容 "TARGET_PLACE_JADESTEP_DAILOU" 格式）：
      3. len(parts) >= 3 → 取 parts[1]:parts[2]

    返回: 去重后的意象 ID 列表（保持首次出现顺序）
    """
    seen: set[str] = set()
    result: list[str] = []

    for combo in combos:
        if combo.dimension.id != scene_dim_id:
            continue

        for tag in combo.value.tags:
            if tag.startswith("action:"):
                continue

            # ── 优先尝试冒号分割 ──
            parts = tag.split(":")
            if len(parts) >= 3:
                # 旧格式：如 "ENV:NATURE_NIGHTMOON:cold_moon:general" → "NATURE_NIGHTMOON:cold_moon"
                key = f"{parts[1]}:{parts[2]}"
            elif len(parts) == 2:
                # 🆕 两段式冒号：如 "VIBE_PHILOSOPHY_ZEN:temple_bell" → 整个 tag 就是 key
                key = tag
            else:
                # ── 回退到下划线分割 ──
                parts = tag.split("_")
                if len(parts) >= 3:
                    # 如 "TARGET_PLACE_JADESTEP_DAILOU" → "PLACE:JADESTEP"
                    key = f"{parts[1]}:{parts[2]}"
                else:
                    continue

            if key not in seen:
                seen.add(key)
                result.append(key)

    return result


# ── 默认场景×情绪互斥黑名单 ──
_DEFAULT_BLACKLIST: dict[str, list[str]] = {
    "scene_temple": ["AMBITION", "ARROGANCE"],  # 佛门不出野心/狂傲
    "scene_brawl": ["TRANQUILITY"],             # 打架时不可能旷达
    "scene_palace": ["FATIGUE"],                # 朝堂上不能表露疲惫
}


def is_valid_combination(
    combos: list,         # list[DimensionCombo]
    scene_dim_id: str,    # 场景维度的 id
    emotion_dim_id: str,  # 情绪维度的 id
    blacklist: dict[str, list[str]] | None = None,
) -> bool:
    """
    场景×情绪互斥检查。

    默认黑名单（硬编码）:
      scene_temple    → [AMBITION, ARROGANCE]   # 佛门不出野心/狂傲
      scene_brawl     → [TRANQUILITY]          # 打架时不可能旷达
      scene_palace    → [FATIGUE]              # 朝堂上不能表露疲惫

    如果传入 blacklist 参数，则使用传入的黑名单（合并覆盖默认）。

    从 combos 中按 scene_dim_id/emotion_dim_id 找到对应的维度值，
    用场景值的 id 查黑名单，如果情绪值的 id 在黑名单中 → 返回 False。

    返回: True = 合法组合，False = 应丢弃
    """
    # 合并黑名单：传入的 blacklist 覆盖默认的同名 key
    merged = (
        {**_DEFAULT_BLACKLIST, **blacklist}
        if blacklist is not None
        else _DEFAULT_BLACKLIST
    )

    scene_value_id: str | None = None
    emotion_value_id: str | None = None

    for combo in combos:
        if combo.dimension.id == scene_dim_id:
            scene_value_id = combo.value.id
        elif combo.dimension.id == emotion_dim_id:
            emotion_value_id = combo.value.id

    if scene_value_id is None or emotion_value_id is None:
        # 找不到场景或情绪维度值 → 保守放行
        return True

    forbidden = merged.get(scene_value_id)
    if forbidden is not None and emotion_value_id in forbidden:
        return False

    return True


def pick_best_image(
    image_pool: list[str],
    target_emotion: str,
    image_dict: dict,  # dict[str, ImageryItem]
    min_score: int = 30,
) -> str | None:
    """
    在 image_pool 中找出对 target_emotion 亲缘度最高的意象。

    遍历 image_pool 中每个意象 ID：
    - 从 image_dict 查找对应的 ImageryItem
    - 如果 image_dict 中找不到该 ID → 跳过（记录 warning 日志）
    - 取 item.affinities.get(target_emotion, 0) 作为得分
    - 跟踪最高分

    边界情况：
    - 最高分 < min_score → 返回 None（丢弃组合）
    - 多意象并列最高分 → 用 random.choice 选一个（增加多样性）
    - image_pool 为空 → 返回 None
    - 所有意象在 image_dict 中都不存在 → 返回 None

    返回: 意象 ID 或 None
    """
    if not image_pool:
        return None

    best_score = -1
    best_candidates: list[str] = []

    for image_id in image_pool:
        item = image_dict.get(image_id)
        if item is None:
            logging.warning("意象 ID '%s' 在 image_dict 中不存在，跳过", image_id)
            continue

        score = item.affinities.get(target_emotion, 0)

        if score > best_score:
            best_score = score
            best_candidates = [image_id]
        elif score == best_score:
            best_candidates.append(image_id)

    if not best_candidates or best_score < min_score:
        return None

    if len(best_candidates) == 1:
        return best_candidates[0]

    return random.choice(best_candidates)
