"""
情绪对意象插件 — Hook 4 实现。

每个事件维度的值携带 emotion_pair_id（通过维度值 tags 中的
"emotion_pair:<id>" 标签标记），每个选项通过 pair_role 绑定情绪对中的分支。

管线流程:
  Phase 0: init(cfg) — 读取 cfg.plugin_config 获取维度映射 +
                       cfg.emotion_pairs 定义 + 加载 image_dictionary.json
  Phase 4: get_option_result_extras(combos, choice) —
    1. 从 choice.pair_role 获取分支角色（"branch_A" / "fallback" / "branch_B"）
    2. 从 combos 中找 emotion_dimension_id 维度值 → 扫描 tags 获取 emotion_pair_id
    3. 从 cfg.emotion_pairs[pair_id].{role}.emotion 解析目标情绪
    4. 从场景维度值的 tags 中 extract_image_pool
    5. 调用 pick_best_image() 按亲缘度打分
    6. 返回 "imagery_add(name=<image_id>)" DSL

用法:
  在 JSON 配置的顶层 plugins 中引用:
    {
      "plugins": ["emotion_pair_imagery"],
      "plugin_config": {
        "emotion_pair_imagery": {
          "emotion_dimension_id": "emotion",
          "scene_dimension_id": "scene_climb"
        }
      },
      "emotion_pairs": {
        "pair_rebellion": {
          "branch_A": {"emotion": "ARROGANCE", "desc": "狂傲"},
          "branch_B": {"emotion": "TRANQUILITY", "desc": "静谧"},
          "fallback": {"emotion": "FATIGUE", "desc": "疲惫"}
        }
      },
      ...
    }
  每个 option_feature 需设置 pair_role:
    {"id": "opt_kuangke",  "pair_role": "branch_A", ...}
    {"id": "opt_fengying", "pair_role": "fallback", ...}
    {"id": "opt_zuanying", "pair_role": "branch_B", ...}
  每个 emotion_dimension_id 维度值需在 tags 中包含:
    "emotion_pair:pair_rebellion"

向后兼容:
  未配置 plugin_config 时，插件默认:
    emotion_dimension_id = "humiliation_type"
    scene_dimension_id = "gateway"
  以保证现有 duotai_humiliation 配置无需修改即可正常工作。
"""

import json
import logging
from pathlib import Path

from tools.plugin_base import EventPromptPlugin, register_plugin
from tools.event_generator.scorer import extract_image_pool, pick_best_image


_IMAGE_DICT_PATH = Path(__file__).resolve().parent.parent / "data" / "image_dictionary.json"

# ── 默认维度 ID（向后兼容：未配置 plugin_config 时使用） ──
_DEFAULT_EMOTION_DIM_ID = "humiliation_type"   # 情绪维度（第一维）
_DEFAULT_SCENE_DIM_ID = "gateway"              # 场景维度（第二维）

# Tags 前缀常量
_TAG_EMOTION_PAIR_PREFIX = "emotion_pair:"


def _load_image_dict() -> dict:
    """加载意象字典，返回 {image_id: ImageryItem}"""
    from tools.config import ImageryItem
    image_dict: dict = {}
    if _IMAGE_DICT_PATH.exists():
        raw = json.loads(_IMAGE_DICT_PATH.read_text(encoding="utf-8"))
        for k, v in raw.items():
            image_dict[k] = ImageryItem(**v)
        logging.info("🖼️  情绪对意象插件: 意象字典已加载, %d 条", len(image_dict))
    else:
        logging.warning("⚠️  情绪对意象插件: 意象字典不存在: %s", _IMAGE_DICT_PATH)
    return image_dict


def _extract_emotion_pair_id(combos: list, dim_id: str) -> str | None:
    """从 combos 中指定维度值的 tags 里提取 emotion_pair_id。

    扫描 tags 中形如 "emotion_pair:pair_rebellion" 的标签，
    返回 "pair_rebellion" 部分，未找到返回 None。

    参数:
        combos: 维度组合列表
        dim_id: 要扫描的维度 ID（如 "emotion" / "humiliation_type"）
    """
    for combo in combos:
        if combo.dimension.id != dim_id:
            continue
        for tag in combo.value.tags:
            tag = tag.strip()
            if tag.startswith(_TAG_EMOTION_PAIR_PREFIX):
                return tag[len(_TAG_EMOTION_PAIR_PREFIX):]
    return None


class EmotionPairImageryPlugin(EventPromptPlugin):
    """情绪对意象插件 — 通过 emotion_pair_id + pair_role 做 per-option 意象打分。"""

    @property
    def plugin_id(self) -> str:
        return "emotion_pair_imagery"

    # ── Phase 0: 初始化 ──

    def init(self, cfg) -> None:
        """读取 plugin_config 获取维度映射 + emotion_pairs 配置 + 加载意象字典。

        从 cfg.plugin_config["emotion_pair_imagery"] 中读取:
          - emotion_dimension_id: 哪个维度的 tags 存放 emotion_pair: 标签（默认 "humiliation_type"）
          - scene_dimension_id:    哪个维度的 tags 存放意象 whitelist（默认 "gateway"）
        """
        self._cfg = cfg
        self._emotion_pairs = cfg.emotion_pairs
        self._image_dict = _load_image_dict()
        self._has_pairs = bool(self._emotion_pairs)

        # ── 从 plugin_config 读取维度映射 ──
        plugin_cfg = {}
        if hasattr(cfg, "plugin_config") and cfg.plugin_config:
            plugin_cfg = cfg.plugin_config.get("emotion_pair_imagery", {})
        self._emotion_dim_id = plugin_cfg.get(
            "emotion_dimension_id", _DEFAULT_EMOTION_DIM_ID,
        )
        self._scene_dim_id = plugin_cfg.get(
            "scene_dimension_id", _DEFAULT_SCENE_DIM_ID,
        )
        logging.info(
            "🔌  情绪对意象插件: emotion_dim=%s, scene_dim=%s",
            self._emotion_dim_id, self._scene_dim_id,
        )

        if not self._has_pairs:
            logging.warning("⚠️  情绪对意象插件: cfg.emotion_pairs 为空，插件将不产生任何效果")

    # ── Phase 4: 选项结果 DSL 扩展 ──

    def get_option_result_extras(
        self,
        combos: list,
        choice: any,
    ) -> str:
        """为选项生成意象 DSL。

        解析链：
          choice.pair_role
            → [{emotion_dim_id}].tags 中的 emotion_pair_id
              → cfg.emotion_pairs[pair_id].{role}.emotion
                → extract_image_pool(combos, scene_dim_id)
                  → pick_best_image → "imagery_add(name=<image_id>)"

        维度 ID 来自 init() 中从 cfg.plugin_config 读取的配置，
        未配置时默认 emotion_dim_id="humiliation_type", scene_dim_id="gateway"。

        返回: "imagery_add(name=<image_id>)" 或空字符串。
        """
        if not self._has_pairs:
            return ""

        # Step 1: 检查选项是否有 pair_role
        pair_role = getattr(choice, "pair_role", "")
        if not pair_role:
            return ""   # 非情绪对选项，不处理

        # Step 2: 提取 emotion_pair_id（从配置的维度扫描）
        pair_id = _extract_emotion_pair_id(combos, self._emotion_dim_id)
        if not pair_id:
            logging.warning(
                "⚠️  情绪对意象插件: combos 中未找到 emotion_pair tag "
                "(在维度 '%s' 的 tags 中搜索 '%s' 前缀)",
                self._emotion_dim_id, _TAG_EMOTION_PAIR_PREFIX,
            )
            return ""

        # Step 3: 查找情绪对配置
        pair_cfg = self._emotion_pairs.get(pair_id)
        if not pair_cfg:
            logging.warning(
                "⚠️  情绪对意象插件: cfg.emotion_pairs 中未定义 '%s'", pair_id,
            )
            return ""

        # Step 4: 解析目标情绪
        branch = getattr(pair_cfg, pair_role, None)
        if not branch:
            logging.warning(
                "⚠️  情绪对意象插件: emotion_pair '%s' 中无 '%s' 分支", pair_id, pair_role,
            )
            return ""

        target_emotion = branch.emotion
        if not target_emotion:
            logging.warning(
                "⚠️  情绪对意象插件: emotion_pair '%s'.%s.emotion 为空", pair_id, pair_role,
            )
            return ""

        # Step 5: 提取意象池（从配置的场景维度）
        image_pool = extract_image_pool(combos, self._scene_dim_id)
        if not image_pool:
            logging.info(
                "🔍  情绪对意象插件: 场景维度 '%s' 无意象 tag，跳过", self._scene_dim_id,
            )
            return ""

        # Step 6: 按情绪亲缘度打分
        best_image_id = pick_best_image(
            image_pool,
            target_emotion,
            self._image_dict,
            min_score=30,
        )
        if best_image_id is None:
            logging.info(
                "🔍  情绪对意象插件: 意象池中无对 '%s'(%s) 亲缘度 >=30 的意象",
                target_emotion, branch.desc or "",
            )
            return ""

        # Step 7: 生成 DSL
        logging.info(
            "🖼️  情绪对意象插件: [%s/%s/%s] → emotion=%s → image=%s",
            pair_id, pair_role, choice.id, target_emotion, best_image_id,
        )
        return f"imagery_add(name={best_image_id})"


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(EmotionPairImageryPlugin())
