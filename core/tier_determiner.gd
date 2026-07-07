class_name TierDeterminer
extends RefCounted

## 碎片 Tier 运行时判定器
## 在意象获取时调用 determine_tier() 判定当前碎片属于 Tier 1/2/3

# ── 阈值常量 ───────────────────────────────────────────
const TRANQUILITY_THRESHOLD := 30
const ARROGANCE_THRESHOLD := 30
const ANGER_THRESHOLD := 30
const SORROW_THRESHOLD := 30
const AMBITION_THRESHOLD := 25
# ── Tier 判定 ──────────────────────────────────────────
static func determine_tier() -> int:
	# Step 1: 判断当前 IAM（通过 KuangdaState 统一查询）
	var iam := KuangdaState.current()

	# Step 2: 读取情绪值
	var tranquility: int = PlayerState.get_emotion(ENUMS.EMOTION.TRANQUILITY)
	var arrogance: int = PlayerState.get_emotion(ENUMS.EMOTION.ARROGANCE)
	var anger: int = PlayerState.get_emotion(ENUMS.EMOTION.ANGER)
	var sorrow: int = PlayerState.get_emotion(ENUMS.EMOTION.SORROW)
	var ambition: int = PlayerState.get_emotion(ENUMS.EMOTION.AMBITION)

	# Step 3: 按优先级判定
	# Tier 3 (高洁): kuangke + (tranquility >= 30 or arrogance >= 30)
	if iam == "kuangke" and (tranquility >= TRANQUILITY_THRESHOLD or arrogance >= ARROGANCE_THRESHOLD):
		return 3

	# Tier 2 (沉重): anger >= 30 or sorrow >= 30 (任意 IAM)
	if anger >= ANGER_THRESHOLD or sorrow >= SORROW_THRESHOLD:
		return 2

	# Tier 1 (污染): zuanying/fengying + ambition >= 25
	if iam in ["zuanying", "fengying"] and ambition >= AMBITION_THRESHOLD:
		return 1

	# 兜底污染
	return 1
