# 测试
- messager: 使用MessagerManager 在游戏内 打开Start属性
- event system: 游戏内打开NarrativeOverlay-test

# 关于QueueManager
- 使用的时候需要注意，它需要一个信号来修改自己的状态以正常进行下一个动画的播放
这个信号应该在上一个动画结束之后发出
如果不发就只能手动管理结束
- onready有时候会出问题，直接使用路径