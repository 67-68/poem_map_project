## 测试指令（更新版）

### Step 1: 设属性值

```
# PlayerState.set_stat_val("astuteness", 50)
# PlayerState.set_stat_val("talent", 50)
# PlayerState.set_stat_val("composure", 50)
# PlayerState.set_stat_val("prestige", 30)
# PlayerState.set_stat_val("money", 100)
# PlayerState.set_stat_val("health", 90)
# PlayerState.set_stat_val("inspiration", 40)
# PlayerState.set_stat_val("momentum", 80)
```

### Step 2: 测试无派系效果

```
$ test_modifier_no_faction
```

### Step 3: 测试浊流交互（先设 NPC tag）

```
$ set_tag lilinfu
$ test_modifier_zhuoliu_faction
```

A 选项「钱-40」应显示 `城府 +10` 注解，实际扣款约 -30。

### Step 4: 清流交互

```
$ set_tag gaoshi
$ test_modifier_qingliu_faction
```

A 选项「钱-40」应显示 `才华 +10` 注解，实际扣款约 -30。

### Step 5: 势衰减

```
$ time_clean 751.1
```

momentum 应下降 ~3-5（城府 dampen 后）。