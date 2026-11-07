## #23 のデモ：実行時エラーの原因の演算に、名前で参照した値の名前と値が出ることを見る。
## 実行：godot --headless --path . -s res://demo/error_names_demo.gd
extends SceneTree


func _init() -> void:
	_show("stock / divisor（除算）", "stock / divisor", 0.0, 0.0)
	_show("stock % divisor（剰余）", "stock % divisor", 7.0, 0.0)
	_show("pow(stock, divisor)（べき乗）", "pow(stock, divisor)", 10.0, 400.0)
	_show("sqrt(stock)（関数呼び出し）", "sqrt(stock)", -4.0, 0.0)
	_show("stock / (divisor - divisor)（名前でない値は出さない）", "stock / (divisor - divisor)", 5.0, 0.0)
	quit()


func _show(title: String, expression: String, stock_value: float, divisor_value: float) -> void:
	var model := SimModel.new()
	model.add_stock("stock", stock_value)
	model.add_stock("divisor", divisor_value)
	model.add_stock("sink", 0.0)
	model.add_flow_expr("f", "", "sink", expression)
	model.step()
	print("%s\n  %s" % [title, model.last_error])
