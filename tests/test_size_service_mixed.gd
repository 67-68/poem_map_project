class_name TestSizeServiceMixed extends GutTest

var lbl: Label
var rtl: RichTextLabel

func before_each():
    # 搭建舞台
    lbl = Label.new()
    rtl = RichTextLabel.new()
    
    # 必须加入场景树，否则 get_combined_minimum_size() 会返回 0
    add_child_autofree(lbl)
    add_child_autofree(rtl)
    
    # 设置基础宽度，这是测量高度的前提
    lbl.custom_minimum_size.x = 300
    rtl.custom_minimum_size.x = 300
    
    # 填入足够撑开高度的内容（至少 2-3 行）
    var long_text = "这是一段很长很长很长很长的测试文本，\n它应该会占据好几行，\n用来测试高度是否超过了基础值。这是一段很长很长很长很长的测试文本，\n它应该会占据好几行，\n用来测试高度是否超过了基础值。"
    lbl.text = long_text
    rtl.text = long_text

func test_mixed_widgets_get_reasonable_size():
    # 1. 执行批处理测量
    # 假设你的 get_size 接受一个 Array
    var size_map = await SizeService.get_size([],lbl, rtl)
    
    # 2. 基本断言：结构是否正确？
    assert_not_null(size_map, "Service 应当返回一个结果字典")
    assert_eq(size_map.size(), 2, "返回的结果应该包含两个节点的尺寸")
    
    # 3. 深度断言：数值是否合理？
    # 我们设定 20px 为一个“安全线”，通常一行文字加间距至少 20px
    # 如果测出来比 20px 小，说明测量逻辑肯定缩水了。
    
    if size_map.has(lbl):
        var h = size_map[lbl].y
        assert_gt(h, 20.0, "Label 的高度 [%f] 应当超过基础线 20px" % h)
        
    if size_map.has(rtl):
        var h = size_map[rtl].y
        assert_gt(h, 20.0, "RichTextLabel 的高度 [%f] 应当超过基础线 20px" % h)
    
    # 4. 稳定性断言：现场是否清理干净？
    assert_eq(lbl.custom_minimum_size.y, 0.0, "测量结束后 Label 的约束应重置")
    assert_false(rtl.fit_content, "测量结束后 RichTextLabel 的 fit_content 应关闭")

func after_each():
    # GUT 的 autofree 会帮我们清理 lbl 和 rtl
    pass
