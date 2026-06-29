# _class_registry.gd — 全局类注册表 (HTML5 导出锚点)
#
# 🔪 目的：强迫 Godot HTML5 导出器在预扫描阶段加载这些 class_name 脚本。
# HTML5 导出使用 export_filter="scenes" 时，仅导出场景依赖链中的文件。
# 纯 class_name 脚本（尤其 extends RefCounted 的）因无场景节点引用而被"孤儿剔除"。
# 通过在此 autoload 中声明强类型变量，将这些脚本纳入依赖树，确保导出打包。
#
# 放置位置：project.godot autoload 第一位（在 GameConfig 之前），
# 确保在编译器预扫描所有全局类时最先加载此注册表。

extends Node

# ═══════════════════════════════════════════════════════
# 以下所有 class_name 均被 HTML5 导出器"孤儿剔除"过。
# 通过 var 类型注解强制为每个类建立符号引用，
# 打包器会将这些脚本文件纳入 .pck 依赖图。
# ═══════════════════════════════════════════════════════

# core/model/ — 数据模型
var __reg_Action: Action = null
var __reg_ActionTagFilter: ActionTagFilter = null
var __reg_AmbitionData: AmbitionData = null
var __reg_BaseEvent: BaseEvent = null
var __reg_BaseOperator: BaseOperator = null
var __reg_BaseOption: BaseOption = null
var __reg_Decision: Decision = null
var __reg_Disease: Disease = null
var __reg_Era: Era = null
var __reg_EventTicket: EventTicket = null
var __reg_Flag: Flag = null
var __reg_HistoryEvent: HistoryEvent = null
var __reg_ImaginaryTag: ImaginaryTag = null
var __reg_LegendaryPoem: LegendaryPoem = null
var __reg_RequirementFilter: RequirementFilter = null
var __reg_SceneAction: SceneAction = null
var __reg_StyleData: StyleData = null

# model/ — 事件系统
var __reg_AnimationObject: AnimationObject = null
var __reg_ChoiceResult: ChoiceResult = null
var __reg_FocusedChat: FocusedChat = null
var __reg_RandomEvent: RandomEvent = null
var __reg_EventOption: EventOption = null

# core/ — 核心系统
var __reg_AdjacencyManager: AdjacencyManager = null
var __reg_DataHelper: DataHelper = null
var __reg_DataScanner: DataScanner = null
var __reg_DebugUtils: DebugUtils = null
var __reg_GameEntity: GameEntity = null
var __reg_ManualBuffer: ManualBuffer = null
var __reg_PopupQueue: PopupQueue = null
var __reg_RelationFlagManager: RelationFlagManager = null
var __reg_SocialActionResolver: SocialActionResolver = null
var __reg_SourceOfTruth: SourceOfTruth = null
var __reg_TagManager: TagManager = null
var __reg_TextureResLoader: TextureResLoader = null
var __reg_TierDeterminer: TierDeterminer = null

# characters/ — 角色数据
var __reg_PoemData: PoemData = null
var __reg_PoetData: PoetData = null
var __reg_PoetLifePoint: PoetLifePoint = null

# features/ — 功能模块
var __reg_ImageHandle: ImageHandle = null

# core/operators/ — 运算符
var __reg_PopEventOperator: PopEventOperator = null

# shaders/ — 着色器预处理
var __reg_GlitchPreprocessor: GlitchPreprocessor = null
