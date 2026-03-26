@tool
class_name LinterDebuggerContainer extends Node

@export var test_dsl_parser := false:
    set(value):
        TestDSLParser.test_parsing()
        test_dsl_parser = false