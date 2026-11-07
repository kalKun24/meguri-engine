## 定義の名前の規則のデモ。ストック・定数・フローの名前に、半角英数字と _ 以外の文字や、空白だけの名前を渡すと、規則を示すエラーになる。
## 実行：godot --headless --path . -s res://demo/name_rule_demo.gd
## 不可視文字は、文字コードから char() で作る（ソースに生の文字を書かない）。
extends SceneTree


func _init() -> void:
	var model := SimModel.new()
	model.add_stock("food", 10.0)
	_show("add_stock(\"population\")", model.add_stock("population", 100.0), model)
	_show("add_stock(\"人口\")", model.add_stock("人口", 100.0), model)
	_show("add_stock(\"   \")（空白だけ）", model.add_stock("   ", 1.0), model)
	_show("add_stock(U+200B だけ)", model.add_stock(char(0x200B), 1.0), model)
	_show("add_stock(\" pop\")（前に空白）", model.add_stock(" pop", 1.0), model)
	_show("add_stock(\"1st\")（先頭が数字）", model.add_stock("1st", 1.0), model)
	_show("add_constant(\"rate%\")", model.add_constant("rate%", 0.1), model)
	_show("add_flow(\"増加\")", model.add_flow("増加", "", "food", 1.0), model)
	_show("add_flow_expr(\"growth_rate\")", model.add_flow_expr("growth_rate", "", "food", "food * 0.02"), model)
	_show("add_flow_expr(\"成長\")", model.add_flow_expr("成長", "", "food", "food * 0.02"), model)
	print("定義済みのストック：%s" % str(model.get_stock_names()))
	quit()


func _show(label: String, code: Error, model: SimModel) -> void:
	print("%s -> %s" % [label, "OK" if code == OK else error_string(code)])
	if code != OK:
		print("    %s" % model.last_error)
