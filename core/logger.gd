extends Node

enum Level { DEBUG, INFO, WARN, ERROR }
var current_level = Level.INFO # 修改这个来过滤日志

func _log(level: int, msg: String, color: String):
    if level < current_level: return
    
    var time = Time.get_time_string_from_system()
    var label = Level.keys()[level]
    # 使用 print_rich 支持颜色
    print_rich("[color=%s][%s] [%s] %s[/color]" % [color, time, label, msg])

func debug(msg): _log(Level.DEBUG, msg, "gray")
func info(msg):  _log(Level.INFO,  msg, "white")
func warn(msg):  _log(Level.WARN,  msg, "yellow")
func err(msg):   _log(Level.ERROR, msg, "red")
func exists(source: String,...obj):
    var i := 0
    for o in obj:
        if not o:
            err('the %s object from %s not found' % [i,source])
            breakpoint

func done(name: String,domain = ''):
    if domain:
        Logging.info('[%s] %s done loading' % [domain,name])    
        return
    Logging.info('%s done loading' % name)


func change(source,target):
    Logging.info('change %s to %s' % [source,target])