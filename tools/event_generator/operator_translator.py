"""
Operator → Prompt 语义翻译层 — Python 侧实现。

将 DSL Operator（prop_add, emo_add, imagery_add, trait_add 等）
自动翻译为 LLM 可理解的语义锚点文本，消除「语义撕裂」。

架构文档: DOCUMENTATIONS/plans/operator_prompt_translation_architecture.md
"""

import json
import re
from dataclasses import dataclass, field
from typing import Optional


# ════════════════════════════════════════════════════════════════
# 数据模型
# ════════════════════════════════════════════════════════════════


@dataclass
class PropAnchor:
    """属性语义锚点。"""
    prop_name: str          # "money"
    delta: int              # +50
    human_text: str         # "一笔不小的进项"（来自 change_perceptions）
    direction: str          # "gain" | "loss"


@dataclass
class EmotionAnchor:
    """情绪语义锚点。"""
    emotion_name: str       # "SORROW"
    delta: int              # +15
    cn_name: str            # "悲悯"
    description: str        # "愁苦/悲凉，涵盖送别与怀古"


@dataclass
class TraitAnchor:
    """特质语义锚点。"""
    trait_name: str         # "corrupt"
    human_name: str         # "贪腐"（来自 Trait.name）


@dataclass
class ImageryAnchor:
    """意象语义锚点。"""
    tag: str                # "ENV_NATURE_SNOWSTORM:lone_snow"
    name: str               # "孤雪"
    description: str        # "独钓寒江雪的孤绝意象..."


@dataclass
class SemanticAnchorSet:
    """一次 translate() 调用产生的完整语义锚点集合。"""
    props: list[PropAnchor] = field(default_factory=list)
    emotions: list[EmotionAnchor] = field(default_factory=list)
    traits: list[TraitAnchor] = field(default_factory=list)
    imageries: list[ImageryAnchor] = field(default_factory=list)

    def is_empty(self) -> bool:
        return not (self.props or self.emotions or self.traits or self.imageries)


# ════════════════════════════════════════════════════════════════
# DSL 正则解析
# ════════════════════════════════════════════════════════════════

# 匹配单个 DSL 表达式: func(key1=val1; key2=val2)
_DSL_EXPR_RE = re.compile(
    r'(?P<func>\w+)\s*\(\s*(?P<params>[^)]*?)\s*\)'
)

# 拆分 key=value 参数对
_PARAM_RE = re.compile(
    r'(?P<key>\w+)\s*=\s*(?P<value>[^;]+)'
)

# DSL 函数名 → 分组
_FUNCTIONS_TRANSLATED = {
    'prop_add', 'prop_sub', 'prop_set',
    'emo_add', 'emo_sub', 'emo_set',
    'trait_add', 'trait_remove',
    'imagery_add',
}


def _parse_dsl_params(params_str: str) -> dict[str, str]:
    """将 'name=money; val=50' 解析为 {'name': 'money', 'val': '50'}。"""
    result = {}
    for m in _PARAM_RE.finditer(params_str):
        result[m.group('key')] = m.group('value').strip()
    return result


def _parse_dsl(dsl_string: str) -> list[tuple[str, dict[str, str]]]:
    """
    将完整 DSL 字符串解析为 (func_name, params_dict) 列表。

    输入: "prop_add(name=talent; val=5) | emo_add(name=TRANQUILITY; val=10)"
    输出: [('prop_add', {'name': 'talent', 'val': '5'}),
           ('emo_add', {'name': 'TRANQUILITY', 'val': '10'})]
    """
    results = []
    for m in _DSL_EXPR_RE.finditer(dsl_string):
        func = m.group('func')
        params = _parse_dsl_params(m.group('params'))
        results.append((func, params))
    return results


# ════════════════════════════════════════════════════════════════
# 核心翻译器
# ════════════════════════════════════════════════════════════════


class OperatorSemanticTranslator:
    """
    DSL Operator → 人类可读语义锚点 翻译器。

    构造时加载 4 个 JSON 数据源（均从 Godot 端导出）。
    """

    def __init__(
        self,
        properties_path: str,
        traits_path: str,
        emotions_path: str,
        imageries_path: str,
    ):
        with open(properties_path, 'r', encoding='utf-8') as f:
            self._properties: dict = json.load(f)
        with open(traits_path, 'r', encoding='utf-8') as f:
            self._traits: dict = json.load(f)
        with open(emotions_path, 'r', encoding='utf-8') as f:
            self._emotions: dict = json.load(f)
        with open(imageries_path, 'r', encoding='utf-8') as f:
            self._imageries: dict = json.load(f)

    # ── 主入口 ──

    def translate(self, dsl_string: str) -> SemanticAnchorSet:
        """
        输入: "prop_add(name=talent; val=5) | emo_add(name=TRANQUILITY; val=10) | imagery_add(name=VIBE_PHILOSOPHY_ZEN:temple_bell)"
        输出: SemanticAnchorSet(props=[...], emotions=[...], traits=[...], imageries=[...])
        """
        anchor_set = SemanticAnchorSet()
        expressions = _parse_dsl(dsl_string)

        for func, params in expressions:
            if func not in _FUNCTIONS_TRANSLATED:
                continue  # 跳过不翻译的 Operator

            name = params.get('name', '').strip()
            # val 可能缺失（trait/imagery 没有 val）
            val_str = params.get('val', '').strip()

            # ── 属性类 ──
            if func == 'prop_add':
                delta = int(val_str) if val_str else 0
                anchor = self.translate_prop_add(name, delta)
                anchor_set.props.append(anchor)
            elif func == 'prop_sub':
                delta = int(val_str) if val_str else 0
                # prop_sub → 将 delta 取负
                anchor = self.translate_prop_add(name, -delta)
                anchor_set.props.append(anchor)
            elif func == 'prop_set':
                # prop_set: delta 未知 → 特殊文案
                anchor = self._translate_prop_set(name)
                anchor_set.props.append(anchor)

            # ── 情绪类 ──
            elif func == 'emo_add':
                delta = int(val_str) if val_str else 0
                anchor = self.translate_emo_add(name, delta)
                anchor_set.emotions.append(anchor)
            elif func == 'emo_sub':
                delta = int(val_str) if val_str else 0
                anchor = self.translate_emo_add(name, -delta)
                anchor_set.emotions.append(anchor)
            elif func == 'emo_set':
                anchor = self._translate_emo_set(name)
                anchor_set.emotions.append(anchor)

            # ── 特质类 ──
            elif func == 'trait_add':
                anchor = self.translate_trait_add(name)
                anchor_set.traits.append(anchor)
            elif func == 'trait_remove':
                anchor = self.translate_trait_remove(name)
                anchor_set.traits.append(anchor)

            # ── 意象类 ──
            elif func == 'imagery_add':
                anchor = self.translate_imagery_add(name)
                anchor_set.imageries.append(anchor)

        return anchor_set

    # ── 属性翻译 ──

    def translate_prop_add(
        self, prop_name: str, delta: int
    ) -> PropAnchor:
        """
        查 semantic_properties.json → 找 delta 区间 → 返回对应文案。

        delta > 0 用 gain_text, delta < 0 用 loss_text (取绝对值匹配)。
        """
        prop_data = self._properties.get(prop_name)
        if prop_data is None:
            # fallback: 未在数据中找到的属性
            direction = 'gain' if delta >= 0 else 'loss'
            return PropAnchor(
                prop_name=prop_name,
                delta=delta,
                human_text=f'属性 "{prop_name}" 发生变化',
                direction=direction,
            )

        abs_delta = abs(delta)
        direction = 'gain' if delta >= 0 else 'loss'
        perceptions = prop_data.get('change_perceptions', [])

        # 遍历 change_perceptions，找 delta 在 [min_delta, max_delta] 区间
        human_text = f'{prop_data.get("name", prop_name)} 发生变化'
        for p in perceptions:
            min_d = p.get('min_delta', 0)
            max_d = p.get('max_delta', 9999)
            if min_d <= abs_delta <= max_d:
                human_text = p.get('gain' if direction == 'gain' else 'loss', human_text)
                break

        return PropAnchor(
            prop_name=prop_name,
            delta=delta,
            human_text=human_text,
            direction=direction,
        )

    def _translate_prop_set(self, prop_name: str) -> PropAnchor:
        """prop_set 的 delta 在生成阶段未知，标记为强制设为。"""
        prop_data = self._properties.get(prop_name)
        display_name = prop_data.get('name', prop_name) if prop_data else prop_name
        return PropAnchor(
            prop_name=prop_name,
            delta=0,
            human_text=f'{display_name} 被强制设为某个值（具体量取决于当前游戏状态）',
            direction='gain',
        )

    # ── 情绪翻译 ──

    def translate_emo_add(
        self,
        emotion_name: str,
        delta: int,
        local_registry: Optional[dict] = None,
    ) -> EmotionAnchor:
        """
        查 emotion 描述。
        优先级: local_registry[emotion_name] > semantic_emotions.json > 纯枚举名 fallback

        local_registry 格式: {"TRANQUILITY": {"cn_name": "旷达", "description": "..."}}
        """
        abs_delta = abs(delta)

        # 优先级 1: local_registry
        if local_registry and emotion_name in local_registry:
            entry = local_registry[emotion_name]
            return EmotionAnchor(
                emotion_name=emotion_name,
                delta=abs_delta,
                cn_name=entry.get('cn_name', emotion_name),
                description=entry.get('description', ''),
            )

        # 优先级 2: semantic_emotions.json
        if emotion_name in self._emotions:
            entry = self._emotions[emotion_name]
            return EmotionAnchor(
                emotion_name=emotion_name,
                delta=abs_delta,
                cn_name=entry.get('cn_name', emotion_name),
                description=entry.get('description', ''),
            )

        # 优先级 3: 纯枚举名 fallback
        return EmotionAnchor(
            emotion_name=emotion_name,
            delta=abs_delta,
            cn_name=emotion_name,
            description='',
        )

    def _translate_emo_set(self, emotion_name: str) -> EmotionAnchor:
        """emo_set 的 delta 在生成阶段未知。"""
        # 先查全局情绪数据获取 cn_name
        entry = self._emotions.get(emotion_name, {})
        return EmotionAnchor(
            emotion_name=emotion_name,
            delta=0,
            cn_name=entry.get('cn_name', emotion_name),
            description=(
                f'{entry.get("cn_name", emotion_name)} 被强制设为某个值（具体取决于当前游戏状态）'
            ),
        )

    # ── 特质翻译 ──

    def translate_trait_add(self, trait_name: str) -> TraitAnchor:
        """查 semantic_traits.json → 返回 trait 的 name 字段。"""
        trait_data = self._traits.get(trait_name)
        if trait_data:
            human_name = trait_data.get('name', trait_name)
        else:
            human_name = trait_name  # fallback: key 作为 human_name
        return TraitAnchor(
            trait_name=trait_name,
            human_name=human_name,
        )

    def translate_trait_remove(self, trait_name: str) -> TraitAnchor:
        """查 semantic_traits.json → 返回 trait 的 name 字段（标记为失去）。"""
        trait_data = self._traits.get(trait_name)
        if trait_data:
            human_name = trait_data.get('name', trait_name)
        else:
            human_name = trait_name
        return TraitAnchor(
            trait_name=trait_name,
            human_name=f'失去 {human_name}',
        )

    # ── 意象翻译 ──

    def translate_imagery_add(self, tag: str) -> ImageryAnchor:
        """查 image_dictionary.json → 返回 name + description。"""
        image_data = self._imageries.get(tag)
        if image_data:
            return ImageryAnchor(
                tag=tag,
                name=image_data.get('name', tag),
                description=image_data.get('description', ''),
            )
        # fallback: 用 tag 的短名
        short_name = tag.split(':')[-1] if ':' in tag else tag
        return ImageryAnchor(
            tag=tag,
            name=short_name,
            description='',
        )

    # ── Prompt 格式化 ──

    def to_prompt_fragment(
        self,
        anchor_set: SemanticAnchorSet,
        local_emotions: Optional[dict] = None,
    ) -> str:
        """
        将 SemanticAnchorSet 格式化为可注入 Prompt 的 Markdown 文本块。

        输出示例:
        ```markdown
        ## 🎯 语义锚点（本选项的实际效果）
        - 💰 才气：才气微涨，灵光一闪（+5）
        - 💖 旷达（TRANQUILITY）：超脱物外的淡然与通透（+10）
        - 🎨 意象：晨钟 — 万籁此俱寂，但余钟磬音...
        - 🏷️ 特质：贪腐
        ```
        """
        if anchor_set.is_empty():
            return ''

        lines = ['## 🎯 语义锚点（本选项的实际效果）']

        # 属性
        for p in anchor_set.props:
            delta_str = f'+{p.delta}' if p.delta > 0 else str(p.delta) if p.delta < 0 else ''
            suffix = f'（{delta_str}）' if delta_str else ''
            lines.append(f'- 💰 {p.prop_name}：{p.human_text}{suffix}')

        # 情绪
        for e in anchor_set.emotions:
            delta_str = f'+{e.delta}' if e.delta > 0 else str(e.delta) if e.delta != 0 else ''
            # 尝试从 local_emotions 获取更精确的 cn_name
            cn = e.cn_name
            desc = e.description
            if local_emotions and e.emotion_name in local_emotions:
                local_e = local_emotions[e.emotion_name]
                cn = local_e.get('cn_name', cn)
                desc = local_e.get('description', desc)
            suffix = f'（{delta_str}）' if delta_str else ''
            desc_part = f' — {desc}' if desc else ''
            lines.append(f'- 💖 {cn}（{e.emotion_name}）：{desc_part}{suffix}')

        # 特质
        for t in anchor_set.traits:
            lines.append(f'- 🏷️ 特质：{t.human_name}')

        # 意象
        for im in anchor_set.imageries:
            desc_part = f' — {im.description}' if im.description else ''
            lines.append(f'- 🎨 意象：{im.name}{desc_part}')

        return '\n'.join(lines)
