## フローの量を式で書くデモ。式どおりに値が変わること、1/2 が 0.5 になること、
## 誤った式が組み立て時に位置つきで拒否されること、0 除算がターン番号つきの実行時エラーになることを見る。
## 実行：godot --headless --path . -s res://demo/flow_expression_demo.gd
extends SceneTree


func _init() -> void:
	_show_town()
	_show_float_division()
	_show_build_time_rejections()
	_show_runtime_division_by_zero()
	quit()


func _show_town() -> void:
	print("1. 人口が増えると食料が減る（人口 += 人口 * 出生率、食料 -= 人口 * 1人あたりの消費量）")
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_stock("food", 1000.0)
	model.add_constant("birth_rate", 0.1)
	model.add_constant("ration", 0.5)
	model.add_flow_expr("births", "", "population", "population * birth_rate")
	model.add_flow_expr("eating", "food", "", "population * ration")
	_print_stocks(model)
	for i in 3:
		model.step()
		_print_stocks(model)


func _show_float_division() -> void:
	print("2. すべて float で評価する")
	var model := SimModel.new()
	model.add_stock("out", 0.0)
	model.add_flow_expr("half", "", "out", "1/2")
	model.step()
	print("  1/2 を流入させた 1 ターン後の out = %s" % model.get_stock("out").value)


func _show_build_time_rejections() -> void:
	print("3. 組み立て時のエラー（式の全文と文字位置つき）")
	var cases: Array[String] = ["1 + system(2)", "population + lost_name", "OS.get_name()", "min", "Vector2(1, 2)", "min(1)", "1 + " + "9".repeat(400)]
	for expression in cases:
		var model := SimModel.new()
		model.add_stock("population", 10.0)
		var code := model.add_flow_expr("f", "", "population", expression)
		if code == OK:
			code = model.validate()
		print("  [%s] %s" % [error_string(code), _shorten(model.last_error)])


func _show_runtime_division_by_zero() -> void:
	print("4. 0 除算は、ターン番号つきの実行時エラーになる。そのターンでは何も変わらない")
	var model := SimModel.new()
	model.add_stock("stock", 10.0)
	model.add_stock("divisor", 1.0)
	model.add_flow_expr("shrink", "divisor", "", "1")
	model.add_flow_expr("share", "stock", "", "stock / divisor")
	for i in 3:
		var code := model.step()
		# get_stock() は成功すると last_error を空にするので、先に取っておく。
		var message := model.last_error
		print("  step() = %s  ターン番号 = %d  stock = %s  divisor = %s" % [
			error_string(code), model.get_turn(), model.get_stock("stock").value, model.get_stock("divisor").value
		])
		if code != OK:
			print("  last_error: %s" % message)
			break


func _print_stocks(model: SimModel) -> void:
	print("  ターン %d：人口 = %s  食料 = %s" % [model.get_turn(), model.get_stock("population").value, model.get_stock("food").value])


# 400 桁の式が画面を埋めないよう、長い行は途中を省く。
func _shorten(text: String) -> String:
	if text.length() > 200:
		return text.substr(0, 110) + " ...（省略）... " + text.substr(text.length() - 40)
	return text
