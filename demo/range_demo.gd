## #7 のデモ：ストックの上限・下限で値が止まることと、範囲の設定の誤りがエラーになることを見る。
## 実行：godot --headless --path . -s res://demo/range_demo.gd
extends SceneTree


func _init() -> void:
	_show_up()
	_show_down()
	_show_no_lower()
	_show_invalid_range()
	_show_clamp_error()
	quit()


func _show_up() -> void:
	print("1. 食料（下限 0、上限 100）。毎ターン 30 増える（初期値 50）")
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_flow("harvest", "", "food", 30.0)
	_run(model, "food", 4)


func _show_down() -> void:
	print("2. 食料（下限 0、上限 100）。毎ターン 30 減る（初期値 50）")
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_flow("eaten", "food", "", 30.0)
	_run(model, "food", 4)


func _show_no_lower() -> void:
	print("3. お金（範囲なし）。毎ターン 30 減る（初期値 50）")
	var model := SimModel.new()
	model.add_stock("money", 50.0)
	model.add_flow("spend", "money", "", 30.0)
	_run(model, "money", 4)


func _show_invalid_range() -> void:
	print("4. 下限が上限より大きい範囲（下限 100、上限 0）")
	var model := SimModel.new()
	var code := model.add_stock("food", 50.0, StockRange.between(100.0, 0.0))
	print("  add_stock() = %s" % error_string(code))
	print("  %s" % model.last_error)
	print("  定義済みのストック：%s" % str(model.get_stock_names()))


func _show_clamp_error() -> void:
	print("5. 式の clamp(x, lo, hi) で lo > hi（lo = 10、hi = 5 のストック）")
	var model := SimModel.new()
	model.add_stock("x", 7.0)
	model.add_stock("lo", 10.0)
	model.add_stock("hi", 5.0)
	model.add_stock("out", 0.0)
	model.add_flow_expr("f", "", "out", "clamp(x, lo, hi)")
	print("  step() = %s" % error_string(model.step()))
	print("  %s" % model.last_error)


func _run(model: SimModel, stock_name: String, turns: int) -> void:
	print("  ターン 0：%s = %s" % [stock_name, model.get_stock(stock_name).value])
	for turn in turns:
		var code := model.step()
		print("  ターン %d：%s = %s（%s）" % [turn + 1, stock_name, model.get_stock(stock_name).value, error_string(code)])
