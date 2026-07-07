class_name Disease extends Trait

## 诊断事件 key — trait 获得时触发 guarantee_next
@export var on_enter_event: String = ""

## 选项劫持 Provider（如狂症的 ManiaProvider）
@export var hijack_provider: BaseProvider = null

## ⚠️ progression_target / progression_xun 已上移至 Trait 基类，统一使用 duration_xun + expiry_trait。
## Disease 仅保留 on_enter_event（诊断事件）和 hijack_provider（选项劫持）两个独有字段。
## 注意：Database 加载时 Disease .tres 文件仍使用 script_class="Disease"，但 progression 字段不再解析。
